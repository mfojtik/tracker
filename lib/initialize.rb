require 'bundler'
require 'require_relative' if RUBY_VERSION =~ /^1\.8/

Bundler.require

unless ENV['RACK_ENV'] == 'production'
  Bundler.require :devel
end

require_relative './db.rb'
require_relative './helpers.rb'
require_relative './tracker.rb'
