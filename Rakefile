require 'rspec/core/rake_task'
RSpec::Core::RakeTask.new(:spec)

task :mdl do
  puts "Running MDL on all files"
  system("bundle exec mdl -c .mdlrc _posts")
end

task :default => [:spec, :mdl]
