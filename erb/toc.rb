#!/usr/bin/env ruby

def usage
  puts "Usage: #{$0} FILE.md"
  exit 1
end

class ToCWriter
  def initialize(source_file, top=2, max=4)
    @source_file = source_file
    @top = top
    @max = max
    @count = 1
    @level  = ""
    @header = ""
    @start  = ""
  end

  def write
    puts "#### Table of contents\n\n"

    File.open(@source_file).each_line do |line|
      next unless line.match(/^#/)

      @level, @header = line.match(/^(#+) *(.*)/).captures
      next if ignore_this_header?

      ref = header_to_ref
      set_start

      puts "#{@start} [#{@header}](##{ref})"
    end
  end

 private

  def ignore_this_header?
    @header == "Table of contents" || \
      @level.length < @top || \
      @level.length > @max
  end

  def header_to_ref
    @header
      .gsub(/\./, "")
      .gsub(/[^a-zA-Z\d]+/, "-")
      .gsub(/-$/, "")
      .downcase
  end

  def set_start
    len = @level.length
    if len == @top
      @start = "#{@count}."
      @count += 1
    else
      bullet = len % 2 == 0 ? "-" : "*"
      @start = "    " * (len - @top) + bullet
    end
  end
end

usage unless ARGV.length == 1
source_file = ARGV[0]

ToCWriter.new(source_file).write
