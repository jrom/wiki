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

require 'lib/models'
