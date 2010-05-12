
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

environment = ENV["RACK_ENV"] || 'development'

dbconfig = YAML.load(File.read('config/database.yml'))
ActiveRecord::Base.establish_connection dbconfig[environment]

class Page < ActiveRecord::Base

  validates_presence_of :url
  validates_uniqueness_of :url
  before_save :check_slash

  # We add the first slash if it wasn't there
  def check_slash
    unless self.url[0..0] == "/"
      self.url = "/#{self.url}"
    end
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

get '/p' do
  @pages = Page.all
  haml :pages
end

post '/p' do
  if params[:page_id] && params[:page_id].to_i > 0
    @page = Page.find(params[:page_id])
    if @page.update_attributes(params[:page])
      redirect @page.url
    else
      haml :form
    end
  else
    @page = Page.new(params[:page])
    if @page.save
      redirect @page.url
    else
      haml :form
    end
  end
end

get '/n' do
  @page = Page.new
  haml :form
end

get '/e*' do
  url = params[:splat]
  @page = Page.find_by_url(url)
  if @page
    haml :form
  else
    redirect '/'
  end
end

get '*' do
  url = params[:splat]
  @page = Page.find_by_url(url)
  if @page
    haml :page
  else
    haml "NOT FOUND: #{url}"
  end
end

__END__

@@ layout
%html
  %head
    %title
      Wiki
    %link{:href => "/wiki.css", :rel => "stylesheet"}
  %body
    #content
      = yield
      #footer
        %a{:href => "/n"} new page

@@ page
%h2
  = @page.title
%p
  = md @page.body
#footer
  %a{:href => "/e#{@page.url}"} edit
  Last update:
  = @page.updated_at.strftime("%d/%m/%Y at %H:%M")

@@ pages
%h2 List of pages
%ul
  - @pages.each do |page|
    %li
      %a{:href => "#{page.url}", :title => "#{page.title}"}
        = page.title

@@ form
%h2 New page
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
    
  %textarea{:name => "page[body]", :id => "body"}
    = @page.body
  %input{:type => "submit", :value => "Save", :class => "save"}
  %a{:href => "#{@page.id ? @page.url : "/"}"} cancel