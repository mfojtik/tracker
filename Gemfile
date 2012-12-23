source :rubygems

gem 'sinatra', :require => 'sinatra/base'
gem 'haml'
gem 'data_mapper'
group :production do
  gem 'dm-postgres-adapter'
end
group :development do
  gem 'dm-sqlite-adapter'
end

platform :jruby do
  gem "torquebox-messaging"
end

gem 'time-ago-in-words'
gem 'sinatra-partial', :require => 'sinatra/partial'
gem 'json_pure', :require => 'json/pure'
gem 'dm-serializer'
gem 'dm-constraints'
gem 'pony'
gem 'dm-pager'
gem 'diffy'

platform :mri_19 do
  group :devel do
    gem 'thin'
  end
end
