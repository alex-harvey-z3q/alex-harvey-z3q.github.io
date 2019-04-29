
require 'spec_helper'
require 'yaml'

# Documented at https://jekyllrb.com/news/2017/03/02/jekyll-3-4-1-released/
post_regex = %r!^(?:.+/)*(\d{2,4}-\d{1,2}-\d{1,2})-(.*)(\.[^.]+)$!

def date_in_front_matter(date)
  return date if date.is_a?(Date)
  return date.to_date if date.is_a?(Time)
  return Date.parse(date) if date.is_a?(String)
end

describe 'posts' do
  Dir.glob("_posts/*md").each do |file|
    basename = File.basename(file)

    context basename do
      front_matter = YAML.load(File.read(file).split(/---/)[1])

      it 'filename must match documented post regex' do
        expect(basename).to match post_regex
      end

      date_string = post_regex.match(basename).captures[0]

      it 'date in file name should be a valid date' do
        expect { Date.parse(date_string) }.to_not raise_error
      end

      it 'date in file name should be same day as in front matter' do
        date_in_file_name = Date.parse(date_string)
        date_in_front_matter = date_in_front_matter(front_matter['date'])
        expect(date_in_front_matter).to eq date_in_file_name
      end
    end
  end
end

describe 'cookbooks' do
  cookbook = '2019-04-01-my-vim-cookbook.md'
  ignore = [
    '### How to enter Vim visual mode',
    '### A note about tab-completion in commands',
  ]
  context cookbook do
    unsorted = File.readlines("_posts/#{cookbook}").select{|x| x =~ /^### /}.map(&:chomp) - ignore
    it "#{cookbook} should be sorted" do
      expect(unsorted).to eq unsorted.sort
    end
  end

  cookbook = '2019-04-02-my-sed-and-awk-cookbook.md'
  context cookbook do
    unsorted = File.readlines("_posts/#{cookbook}").select{|x| x =~ /^## /}
    it "#{cookbook} should be sorted" do
      expect(unsorted).to eq unsorted.sort
    end
  end

  context 'ERB generation' do
    Dir.glob("erb/*.erb").each do |f|
      real_f = '_posts/' + f.sub(%r{erb/},"").sub(/\.erb/,"")
      template = File.read(f)
      real = File.read(real_f)
      renderer = ERB.new(template, nil, '-')
      it "#{f} should generate #{real_f}" do
        expect(real).to eq renderer.result()
      end
    end
  end
end
