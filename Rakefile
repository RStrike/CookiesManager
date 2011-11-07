require "bundler/gem_tasks"
require 'rspec/core/rake_task'

desc "Run RSpec"
RSpec::Core::RakeTask.new do |t|
  t.verbose = false
end

desc "Run all specs except slow tests"
task :skip_slow do
  system "rake spec SKIP_SLOW=true"
end

task :default => :spec
