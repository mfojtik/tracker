require 'rubygems'

load File.join(File.dirname(__FILE__), 'lib', 'initialize.rb')

use Rack::Reloader
run Tracker::App
