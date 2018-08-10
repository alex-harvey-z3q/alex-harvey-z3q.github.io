require 'spec_helper'
require 'yaml'

describe 'posts' do
  Dir.glob("_posts/*md").each do |file|
    context file do

      front_matter = YAML.load(File.read(file).split(/---/)[1])

      date_in_file_name = Date.parse(/_posts\/(\d{4}-\d{2}-\d{2})-.*/.match(file).captures[0])
      title_in_file_name = /_posts\/\d{4}-\d{2}-\d{2}-(.*)\.md/.match(file).captures[0].gsub(/-/,' ')

      title_regex = / *[:,–-] */ # a title like "Foo: bar, Baz: qux" is "foo-bar-baz-qux" in file name.

      date_in_file_content = front_matter['date']
      title_in_file_content = front_matter['title'].gsub(title_regex,' ').downcase

      it 'filename should match pattern' do
        expect(file).to match /^_posts\/\d{4}-\d{2}-\d{2}-[0-9a-z_-]+\.md$/
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
