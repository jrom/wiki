
begin
  # Require the preresolved locked set of gems.
  require ::File.expand_path('../.bundle/environment', __FILE__)
rescue LoadError
  # Fallback on doing the resolve at runtime.
  require "rubygems"
  require "bundler"
  Bundler.setup
end

require 'sinatra'
require 'sinatra/r18n'
require 'active_record'
require 'bluecloth'
require 'haml'
require 'vestal_versions'

environment = ENV["RACK_ENV"] || 'development'

dbconfig = YAML.load(File.read('config/database.yml'))
ActiveRecord::Base.establish_connection dbconfig[environment]

PASSWORD_PROTECTED = true
USER = ENV["WIKI_USER"] || 'wiki'
PASSWORD = ENV["WIKI_PWD"] || 'wiki'
LOCALE = ENV["WIKI_LOCALE"] || 'en'

class Page < ActiveRecord::Base

  versioned

  before_validation :check_slash

  validates_presence_of :url
  validates_length_of :url, :minimum => 1
  validates_uniqueness_of :url
  validates_exclusion_of :url, :in => ["/e", "/p", "/n", "/r"], :message => "URL {{value}} is reserved."
  validates_presence_of :title, :body

  LOCKING_PERIOD = 1.minute
  def locked?
    self.locked_at && self.locked_at +  LOCKING_PERIOD > Time.now
  end

  private
  # We add the first slash if it wasn't there
  def check_slash
    unless url && !self.url.empty? && self.url[0..0] == "/"
      self.url = "/#{self.url}"
    end
  end

end

if PASSWORD_PROTECTED
  use Rack::Auth::Basic do |username, password|
    [username, password] == [USER, PASSWORD]
  end
end

helpers do
  def md(s)
    BlueCloth.new(s).to_html
  end
  def zebra(val)
    @_zebra = true unless defined?(@_zebra)
    (@_zebra = !@_zebra) ? val : ""
  end
end

configure do
  enable :inline_templates
  set :translations, './locales'
end

before do
  content_type :html, 'charset' => 'utf-8'
  session[:locale] = LOCALE
  @title = ""
end

get '/p' do
  @pages = Page.scoped(:order => "updated_at desc").all
  @title = t.listofpages.capitalize
  haml :pages
end

post '/p' do
  if params[:page_id] && params[:page_id].to_i > 0
    @page = Page.find(params[:page_id])
    @page.locked_at = nil
    if params[:version]
      @page.revert_to!(params[:version].to_i)
      redirect @page.url
    elsif @page.update_attributes(params[:page])
      redirect @page.url
    else
      @title = t.editpage
      haml :form
    end
  else
    @page = Page.new(params[:page])
    @page.locked_at = nil
    if @page.save
      redirect @page.url
    else
      @title = t.newpage.capitalize
      haml :form
    end
  end
end

delete '/p' do
  @page = Page.find(params[:page_id])
  if @page
    @page.destroy
  end
  redirect '/'
end

post '/r' do
  url = params[:url]
  @page = Page.find_by_url(url)
  if @page
    @page.skip_version do
      @page.locked_at = Time.now
    end
  end
end

get '/n' do
  @page = Page.new(params[:page])
  @title = t.newpage.capitalize
  haml :form
end

get '/e/*' do
  url = "/#{params[:splat]}"
  @page = Page.find_by_url(url)
  if @page
    unless @page.locked?
      @page.skip_version do
        @page.locked_at = Time.now
      end
      @title = t.editpage.capitalize
      haml :form
    else
      redirect @page.url
    end
  else
    redirect '/'
  end
end

get '*' do
  @url = params[:splat]
  @page = Page.find_by_url(@url)
  if @page
    @page.revert_to(params[:version].to_i) if params[:version]
    @title = @page.title
    haml :page
  else
    @title = t.notfound
    haml :not_found
  end
end

__END__

@@ layout
%html
  %head
    %title= @title
    %link{:href => "/wiki.css", :rel => "stylesheet"}
    %script{:src => "http://ajax.googleapis.com/ajax/libs/jquery/1.3.2/jquery.min.js"}
    %script{:src => "/showdown.js"}
  %body
    #content
      %h1= @title
      = yield
    #footer
      #links
        %a{:href => "/"}= t.home
        %a{:href => "/n"}= t.newpage
        %a{:href => "/p"}= t.listofpages
        - if @page
          - if @page.locked?
            = t.pagelocked
          -else
            %a{:href => "/e#{@page.url}"}= t.edit
          - unless @page.new_record?
            #versioning
              - if params[:version]
                %form{:action => "/p", :method => "post"}
                  %input{:type => "hidden", :name => "version", :value => "#{params[:version]}"}
                  %input{:type => "hidden", :name => "page_id", :value => "#{@page.id}"}
                  %input{:type => "submit", :value => "#{t.revert}", :class => "revert", :onclick => "return confirm('#{t.confirmrevert}')", :title => "#{t.confirmrevert}"}
                %a{:href => "#{@page.versions.last.versioned.url}"}= t.latestversion
              - if @page.version > 1
                %a{:href => "#{@page.versions.last.versioned.url}?version=#{@page.version-1}"}= t.previousversion

            #pageinfo
              #{t.version}:
              = @page.version
              #{t.lastupdate}:
              = l @page.updated_at, :human
              /= @page.updated_at.strftime("%d/%m/%Y at %H:%M")

@@ page
~ md @page.body

@@ pages
%ul#pages
  %li.page.head
    = t.page
    %span.version= t.version
    %span.updated= t.lastupdate
  - @pages.each do |page|
    %li.page{:class => "#{zebra("odd")}" }
      %a{:href => "#{page.url}", :title => "#{page.title}"}= page.title
      %span.version= page.version
      %span.updated= page.updated_at

@@ form
%form{:action => "/p", :method => "post"}
  %input{:type => "hidden", :name => "page_id", :value => "#{@page.id}"}
  %label{:for => "title"}= t.title
  %input{:type => "text", :name => "page[title]", :value => "#{@page.title}", :id => "title"}
  %label{:for => "url"}= t.url
  %input{:type => "text", :name => "page[url]", :value => "#{@page.url}", :id => "url"}
  %label{:for => "body"}
    = t.body
    (
    %a{:href => "http://daringfireball.net/projects/markdown/", :target => "blank"}> markdown
    )
    
  %textarea{:name => "page[body]", :id => "body"}= @page.body
  #preview
  %input{:type => "submit", :value => "#{t.save}", :class => "save"}
  %input{:type => "button", :value => "#{t.preview}", :class => "previewbtn", :id => "previewbtn"}
  %input{:type => "button", :value => "#{t.edit.capitalize}", :class => "previewbtn", :id => "editbtn"}
  %a{:href => "#{@page.id ? @page.url : "/"}", :class => "cancel"}= t.cancel
- unless @page.new_record?
  %form{:action => "/p", :method => "post"}
    %input{:type => "hidden", :name => "_method", :value => "delete"}
    %input{:type => "hidden", :name => "page_id", :value => "#{@page.id}"}
    %input{:type => "submit", :value => "#{t.deletethispage}", :class => "delete", :onclick => "return confirm('#{t.confirmdelete}')"}

:javascript
  function convertText()
  {
    var text = $("#body").val()
    var converter = new Showdown.converter()
    text = converter.makeHtml(text)
    $("#preview").html(text)
  }
  $(document).ready(function() {
    $("#previewbtn").live('click', function() {
      convertText()
      $("#body").hide()
      $("#editbtn").show()
      $("#previewbtn").hide()
      $("#preview").show()
    })
    $("#editbtn").live('click', function() {
      $("#preview").hide()
      $("#editbtn").hide()
      $("#previewbtn").show()
      $("#body").show()
    })
  })

:javascript
  function relock()
  {
    $.post('/r', { url: "#{@page.url}"} )
    setTimeout('relock()', 30000)
  }
  $(document).ready(function() {
    relock()
  })

@@ not_found
%div
  = t.notfoundmessage(@url)
  %a{:href => "/n?page[url]=#{@url}"}= t.newpage
