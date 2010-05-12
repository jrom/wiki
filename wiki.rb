
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

class Page < ActiveRecord::Base

  versioned

  before_validation :check_slash

  validates_presence_of :url
  validates_length_of :url, :minimum => 1
  validates_uniqueness_of :url
  validates_exclusion_of :url, :in => ["/e", "/p", "/n"], :message => "URL {{value}} is reserved."
  validates_presence_of :title, :body

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
end

configure do
  enable :inline_templates
end

before do
  content_type :html, 'charset' => 'utf-8'
  @title = ""
end

get '/p' do
  @pages = Page.all
  @title = "List of pages"
  haml :pages
end

post '/p' do
  if params[:page_id] && params[:page_id].to_i > 0
    @page = Page.find(params[:page_id])
    if @page.update_attributes(params[:page])
      redirect @page.url
    else
      @title = "Edit page"
      haml :form
    end
  else
    @page = Page.new(params[:page])
    if @page.save
      redirect @page.url
    else
      @title = "New page"
      haml :form
    end
  end
end

get '/n' do
  @page = Page.new(params[:page])
  @title = "New page"
  haml :form
end

get '/e/*' do
  url = "/#{params[:splat]}"
  @page = Page.find_by_url(url)
  if @page
    @title = "Edit page"
    haml :form
  else
    redirect '/'
  end
end

get '*' do
  @url = params[:splat]
  @page = Page.find_by_url(@url)
  if @page
    @title = @page.title
    haml :page
  else
    @title = "Not found"
    haml :not_found
  end
end

__END__

@@ layout
%html
  %head
    %title= @title
    %link{:href => "/wiki.css", :rel => "stylesheet"}
  %body
    #content
      = yield
    #footer
      #links
        %a{:href => "/"} home
        %a{:href => "/n"} new page
        %a{:href => "/p"} list of pages
        - if @page
          %a{:href => "/e#{@page.url}"} edit
          #pageinfo
            Version:
            = @page.version
            - unless @page.new_record?
              Last update:
              = @page.updated_at.strftime("%d/%m/%Y at %H:%M")

@@ page
%h1
  = @page.title
~ md @page.body


@@ pages
%h1 List of pages
%ul
  - @pages.each do |page|
    %li
      %a{:href => "#{page.url}", :title => "#{page.title}"}= page.title

@@ form
%h1 New page
%form{:action => "/p", :method => "post"}
  %input{:type => "hidden", :name => "page_id", :value => "#{@page.id}"}
  %label{:for => "title"} Title
  %input{:type => "text", :name => "page[title]", :value => "#{@page.title}", :id => "title"}
  %label{:for => "url"} URL
  %input{:type => "text", :name => "page[url]", :value => "#{@page.url}", :id => "url"}
  %label{:for => "body"}
    Body
    (
    %a{:href => "http://daringfireball.net/projects/markdown/", :target => "blank"}> markdown
    )
    
  %textarea{:name => "page[body]", :id => "body"}= @page.body
  %input{:type => "submit", :value => "Save", :class => "save"}
  %a{:href => "#{@page.id ? @page.url : "/"}", :class => "cancel"} cancel

@@ not_found
%h1 Not found
%div
  The URL #{@url} doesn't exist yet. You may want to
  %a{:href => "/n?page[url]=#{@url}"} create it?
