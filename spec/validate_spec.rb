require 'spec_helper'

describe 'posts' do
  Dir.glob("_posts/*md").each do |file|
    context file do
      context 'front matter' do
        it 'date should match filename' do

          date_in_file_name =
            file.gsub(/_posts\/(\d{4}-\d{2}-\d{2})-.*/, '\1')

          date_in_file_content =
            File.read(file).split(/---/)[1].lines.select{ |x| x =~ /^date/ }[0].chomp.split[1]

          expect(date_in_file_name).to eq date_in_file_content
        end
      end
    end
  end
end
