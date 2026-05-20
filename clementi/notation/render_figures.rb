# frozen_string_literal: true

require 'fileutils'
require 'open3'
require_relative 'export_lilypond'

RENDER_SOURCE_ROOT = File.expand_path('..', __dir__)
SITE_ROOT = File.expand_path('..', RENDER_SOURCE_ROOT)
ASSET_DIR = File.join(SITE_ROOT, 'assets', 'clementi')
OUT_PDF = File.join(RENDER_SOURCE_ROOT, 'generated', 'figures')
LY_DIR = File.join(RENDER_SOURCE_ROOT, 'lilypond')

def clear_outputs
  FileUtils.mkdir_p(ASSET_DIR)
  FileUtils.mkdir_p(OUT_PDF)

  ['figure_*.png', 'figure_*.pdf', 'figures.pdf'].each do |pattern|
    Dir.glob(File.join(ASSET_DIR, pattern)).each { |path| File.delete(path) }
  end

  Dir.glob(File.join(OUT_PDF, '*.pdf')).each { |path| File.delete(path) }
end

def lilypond_env
  cache_dir = File.join(RENDER_SOURCE_ROOT, '.cache', 'fontconfig')
  FileUtils.mkdir_p(cache_dir)

  ENV.to_h.merge(
    'XDG_CACHE_HOME' => ENV.fetch('XDG_CACHE_HOME', File.join(RENDER_SOURCE_ROOT, '.cache')),
    'FONTCONFIG_PATH' => ENV.fetch('FONTCONFIG_PATH', '/opt/homebrew/etc/fonts')
  )
end

def run!(*command, chdir: RENDER_SOURCE_ROOT, env: ENV.to_h)
  system(env, *command, chdir: chdir) || raise("Command failed: #{command.join(' ')}")
end

def render_lilypond_pdf(source, out_base)
  run!('lilypond', '-fpdf', '-o', out_base, source, env: lilypond_env)
  "#{out_base}.pdf"
end

def render_png(pdf_path, out_png)
  pattern = File.join(OUT_PDF, "#{File.basename(pdf_path, '.pdf')}-%d.png")
  run!(
    'gs',
    '-dSAFER',
    '-dBATCH',
    '-dNOPAUSE',
    '-sDEVICE=png16m',
    '-r144',
    "-sOutputFile=#{pattern}",
    pdf_path
  )

  pages = Dir.glob(File.join(OUT_PDF, "#{File.basename(pdf_path, '.pdf')}-*.png")).sort
  raise "No PNG pages rendered for #{pdf_path}" if pages.empty?

  if pages.length == 1
    FileUtils.mv(pages.first, out_png)
  else
    # The current figures are one page; fail loudly if that changes so layout is reviewed.
    raise "Expected one rendered page for #{pdf_path}, got #{pages.length}"
  end
end

def main
  clear_outputs
  export_lilypond_sources

  Dir.glob(File.join(LY_DIR, 'figure_*.ly')).sort.each do |ly_path|
    out_base = File.join(OUT_PDF, File.basename(ly_path, '.ly'))
    pdf_path = render_lilypond_pdf(ly_path, out_base)
    png_path = File.join(ASSET_DIR, "#{File.basename(ly_path, '.ly')}.png")
    render_png(pdf_path, png_path)
    File.delete(pdf_path)
  end

  puts "Generated LilyPond-rendered figure PNGs in #{ASSET_DIR}"
end

main if $PROGRAM_NAME == __FILE__
