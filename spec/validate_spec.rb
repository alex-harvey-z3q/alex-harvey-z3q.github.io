
require 'spec_helper'
require 'date'
require 'set'
require 'uri'
require 'yaml'

# Documented at https://jekyllrb.com/news/2017/03/02/jekyll-3-4-1-released/
post_regex = %r!^(?:.+/)*(\d{2,4}-\d{1,2}-\d{1,2})-(.*)(\.[^.]+)$!

def date_in_front_matter(date)
  return date if date.is_a?(Date)
  return date.to_date if date.is_a?(Time)
  return Date.parse(date) if date.is_a?(String)
end

def markdown_without_code_blocks(markdown)
  markdown.gsub(/^(```|~~~).*?^\1\s*$/m, '')
end

def post_url_targets
  Dir.glob('_posts/*.md').each_with_object(Set.new) do |file, targets|
    basename = File.basename(file, '.md')
    targets << basename
  end
end

def local_link_target(raw_target)
  target = raw_target.strip
  target = target[/\{\{\s*['"]([^'"]+)['"]\s*\|\s*absolute_url\s*\}\}/, 1] || target
  target = target.sub(/\A<(.+)>\z/, '\1')
  return if target.start_with?('{%')

  target = target.split(/\s+/, 2).first

  return if target.nil? || target.empty?
  return if target.start_with?('#')
  return if target.match?(/\A(?:mailto|tel):/i)

  if target.match?(/\Ahttps?:\/\//i)
    uri = URI.parse(target)
    return unless ['alex-harvey-z3q.github.io', 'alexharv074.github.io'].include?(uri.host)

    target = uri.path
  end

  target.split(/[?#]/, 2).first
end

def existing_site_target?(target, source_file)
  normalized = target.sub(%r!\A/!, '')
  return true if normalized.empty?

  if normalized.match?(%r!\A\d{4}/\d{2}/\d{2}/[^/]+\.html\z!)
    year, month, day, slug = normalized.match(%r!\A(\d{4})/(\d{2})/(\d{2})/([^/]+)\.html\z!).captures
    return File.exist?("_posts/#{year}-#{month}-#{day}-#{slug}.md")
  end

  return File.exist?(normalized) if target.start_with?('/')
  return File.exist?(normalized) if normalized.start_with?('assets/')

  File.exist?(File.expand_path(target, File.dirname(source_file)))
end

describe 'posts' do
  Dir.glob("_posts/*md").each do |file|
    basename = File.basename(file)

    context basename do
      front_matter = YAML.safe_load(File.read(file).split(/---/)[1], permitted_classes: [Date, Time])

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

      it 'local markdown links and images should point to existing targets' do
        markdown = markdown_without_code_blocks(File.read(file))
        targets = markdown.scan(/!?\[[^\]]*\]\(([^)]+)\)/).flatten
        missing_targets = targets.filter_map do |target|
          local_target = local_link_target(target)
          next unless local_target
          next if existing_site_target?(local_target, file)

          local_target
        end

        expect(missing_targets).to be_empty
      end

      it 'post_url tags should point to existing posts' do
        markdown = markdown_without_code_blocks(File.read(file))
        missing_posts = markdown.scan(/\{%\s*post_url\s+([^%\s]+)\s*%\}/).flatten.reject do |target|
          post_url_targets.include?(target)
        end

        expect(missing_posts).to be_empty
      end
    end
  end
end
