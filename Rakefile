require 'rubygems'
require 'bundler'
begin
  Bundler.setup(:default, :development)
rescue Bundler::BundlerError => e
  $stderr.puts e.message
  $stderr.puts "Run `bundle install` to install missing gems"
  exit e.status_code
end
require 'rake'

require 'jeweler'
Jeweler::Tasks.new do |gem|
  # gem is a Gem::Specification... see http://docs.rubygems.org/read/chapter/20 for more options
  gem.name = "Dendrograms"
  gem.homepage = "http://github.com/doches/Dendrograms"
  gem.license = "MIT"
  gem.summary = %Q{Ruby implementation of Clauset's Hierarchical Random Graphs}
  gem.description = %Q{Ruby implementation of Clauset's Hierarchical Random Graphs}
  gem.email = "trevor@texasexpat.net"
  gem.authors = ["Trevor Fountain"]
  gem.version = "0.0.1"
  # Include your dependencies below. Runtime dependencies are required when using your gem,
  # and development dependencies are only needed for development (ie running rake tasks, tests, etc)
  #  gem.add_runtime_dependency 'jabber4r', '> 0.1'
  #  gem.add_development_dependency 'rspec', '> 1.2.3'
  gem.add_runtime_dependency 'progressbar'
end
Jeweler::RubygemsDotOrgTasks.new
