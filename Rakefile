#!/user/bin/env ruby

require 'rubygems'
require 'rake'

desc "Install/reinstall the tracker-client from GIT repository"
task :reinstall do
  puts %x{rm -vrf tracker-client-*.gem}
  puts %x{gem uninstall tracker-client --all -I -x}
  puts %x{gem build tracker-client.gemspec}
  puts %x{gem install tracker-client-*.gem --local}
end
