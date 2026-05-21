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
  sh "bundle exec mdl -c .mdlrc _posts"
end

task :build do
  puts "Building Jekyll site"
  sh "bundle exec jekyll build --strict_front_matter"
end

desc 'Regenerate Clementi/Mozart notation figures'
task :clementi do
  system("ruby clementi/notation/render_figures.rb")
end

task :default => [:spec, :mdl, :build]
