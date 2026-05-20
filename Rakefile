begin
  require 'rspec/core/rake_task'
  RSpec::Core::RakeTask.new(:spec)
rescue LoadError
  task :spec do
    warn "rspec is unavailable; run bundle install to enable the spec task"
  end
end

task :mdl do
  puts "Running MDL on all files"
  system("bundle exec mdl -c .mdlrc _posts")
end

desc 'Regenerate Clementi/Mozart notation figures'
task :clementi do
  system("python clementi/notation/render_figures.py")
end

task :default => :spec
