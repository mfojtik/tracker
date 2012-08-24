lib = File.expand_path('../lib/', __FILE__)
$:.unshift lib unless $:.include?(lib)

Gem::Specification.new do |s|
  s.name        = "tracker-client"
  s.version     = '1.0.7'
  s.platform    = Gem::Platform::RUBY
  s.license     = "ASL"
  s.authors     = ["Michal Fojtik"]
  s.email       = ["mfojtik@redhat.com"]
  s.homepage    = "http://github.com/mifo/tracker"
  s.summary     = "GIT patches tracker client"
  s.description = "An interface to GIT patches tracker"

  s.required_rubygems_version = ">= 1.3.6"

  s.add_dependency "rest-client"
  s.add_dependency "trollop"
  s.add_dependency "json"

  s.files        = Dir['bin/*'] + ['lib/command.rb']
  s.executables  = ['tracker']
  s.require_path = 'lib'
end

