require 'rspec/core/rake_task'
RSpec::Core::RakeTask.new(:spec)

task :mdl do
  puts "Running MDL on all files"
  system("bundle exec mdl -c .mdlrc _posts")
end

desc 'Generate ERB posts'
task :gen do
  require 'erb'
  Dir.glob("erb/*.erb").each do |f|
    real_f = '_posts/' + f.sub(%r{erb/},"").sub(/\.erb/,"")
    template = File.read(f)
    renderer = ERB.new(template, nil, '-')
    File.write(real_f, renderer.result())
  end
end

task :default => :spec
