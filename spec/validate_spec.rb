require 'spec_helper'
require 'yaml'

date_regex = '\d{4}-\d{2}-\d{2}'
title_regex = / *[:,–-] */ # a title like "Foo: bar, Baz: qux"
                           # is "foo-bar-baz-qux" in file name.

describe 'posts' do
  Dir.glob("_posts/*md").each do |file|
    front_matter = YAML.load(File.read(file).split(/---/)[1])

    basename = File.basename(file)

    date_in_file_name = Date.parse(/(#{date_regex})-.*/.match(basename).captures[0])
    title_in_file_name = /#{date_regex}-(.*)\.md/.match(basename).captures[0].gsub(/-/,' ')

    date_in_file_content = front_matter['date']
    title_in_file_content = front_matter['title'].gsub(title_regex,' ').downcase

    context basename do
      it 'filename should match pattern' do
        expect(basename).to match /^#{date_regex}-[0-9a-z_-]+\.md$/
      end

      it 'date should match filename' do
        expect(date_in_file_name).to eq date_in_file_content
      end

      it 'title should match filename' do
        expect(title_in_file_name).to eq title_in_file_content
      end
    end
  end
end
