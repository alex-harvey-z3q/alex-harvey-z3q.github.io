require 'spec_helper'

describe 'posts' do
  Dir.glob("_posts/*md").each do |file|
    context file do

      front_matter = File.read(file).split(/---/)[1]

      date_in_file_name     = /_posts\/(\d{4}-\d{2}-\d{2})-.*/.match(file).captures[0]
      date_in_file_content  = front_matter.lines.select{ |x| x =~ /^date/ }[0].chomp.split[1]

      title_in_file_name    = /_posts\/\d{4}-\d{2}-\d{2}-(.*)\.md/.match(file).captures[0].gsub(/-/,' ')
      title_in_file_content = front_matter.lines.select{ |x| x =~ /^title/ }[0].chomp.gsub(/.*"(.*)"/,'\1').gsub(/ *[:,–-] */,' ').downcase

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
