require 'rspec/core/rake_task'
RSpec::Core::RakeTask.new(:spec)

task :mdl do
  puts "Running MDL on all files"
  system("bundle exec mdl -c .mdlrc _posts")
end

desc 'Generate sed & AWK cookbook'
task :gen do
  require 'erb'
  template = File.read('erb/2019-04-02-my-sed-and-awk-cookbook.md.erb')
  renderer = ERB.new(template, nil, '-')
  File.write('_posts/2019-04-02-my-sed-and-awk-cookbook.md', renderer.result())
end

task :default => [:spec, :mdl]
