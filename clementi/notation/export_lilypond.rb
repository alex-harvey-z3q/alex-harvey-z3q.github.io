# frozen_string_literal: true

require 'fileutils'
require_relative 'score_data'

SOURCE_ROOT = File.expand_path('..', __dir__)
OUT = File.join(SOURCE_ROOT, 'lilypond')

FileUtils.mkdir_p(OUT)

NOTE_MAP = { 'C' => 'c', 'D' => 'd', 'E' => 'e', 'F' => 'f', 'G' => 'g', 'A' => 'a', 'B' => 'b' }.freeze
ACC_MAP = { '' => '', '#' => 'is', 'b' => 'es', 'n' => '!' }.freeze
DUR_MAP = {
  4.0 => '1',
  3.0 => '2.',
  2.0 => '2',
  1.5 => '4.',
  1.0 => '4',
  0.75 => '8.',
  0.5 => '8',
  0.375 => '16.',
  0.25 => '16',
  0.125 => '32',
  0.333 => '8'
}.freeze
KEY_MAP = { 'C' => 'c', 'F' => 'f', 'Bb' => 'bes', 'Eb' => 'ees', 'Ab' => 'aes' }.freeze

def parse_pitch(pitch)
  letter = pitch[0].upcase
  rest = pitch[1..] || ''
  accidental = ''
  if rest[0] && ['#', 'b', 'n'].include?(rest[0])
    accidental = rest[0]
    rest = rest[1..] || ''
  end
  [letter, accidental, Integer(rest)]
end

def ly_pitch(pitch)
  letter, accidental, octave = parse_pitch(pitch)
  base = NOTE_MAP.fetch(letter) + ACC_MAP.fetch(accidental, '')
  octave >= 4 ? base + ("'" * (octave - 3)) : base + (',' * (3 - octave))
end

def ly_events(events)
  events.map { |event| ly_event(event) }.join(' ')
end

def ly_event(event)
  return "\\clef #{event['clef']}" if event['clef']

  if event['tuplet']
    return "\\tuplet #{event['tuplet']} { #{ly_events(event['events'])} }"
  end

  if event['voices']
    return '<< ' + event['voices'].map { |part| "{ #{ly_events(part)} }" }.join(' \\\\ ') + ' >>'
  end

  duration = DUR_MAP.fetch(event.fetch('dur', 1.0).to_f.round(3), '4')

  if event['rest']
    out = "r#{duration}"
    out += '^\\fermata' if event['fermata']
    return out
  end

  prefix = ''
  if event['grace_before']
    prefix = '\\grace { ' + event['grace_before'].map { |pitch| "#{ly_pitch(pitch)}32" }.join(' ') + ' } '
  end

  out = if event['pitches'].length == 1
          ly_pitch(event['pitches'].first) + duration
        else
          chord = '<' + event['pitches'].map { |pitch| ly_pitch(pitch) }.join(' ') + '>' + duration
          event['arpeggio'] ? chord + '\\arpeggio' : chord
        end

  out += '~' if event['tie']
  out += '(' if event['slur_start']
  out += ')' if event['slur_end']
  out += '-.' if event['staccato']
  out += '-!' if event['staccatissimo']
  out += "\\#{event['dynamic']}" if event['dynamic']
  out += '->' if event['accent']
  out += '^\\fermata' if event['fermata']
  out += "^\\markup { \\italic \"#{event['text']}\" }" if event['text']

  prefix + out
end

def staff_music(system, staff, staff_key = nil, first_staff: false)
  events = []
  key = KEY_MAP.fetch(system.fetch('key', 'C'), 'c')
  events << "\\key #{key} \\major"
  if system.fetch('time', '4/4').include?('/')
    events << '\\numericTimeSignature'
    events << "\\time #{system['time']}"
  end

  if first_staff || staff == system.fetch('clefs', [staff]).first
    first_number = system.fetch('measures', [{}]).first['number']
    events << "\\set Score.currentBarNumber = ##{first_number}" if first_number.is_a?(Integer)

    case system['bar_numbers']
    when 'all'
      events << '\\set Score.barNumberVisibility = #all-bar-numbers-visible'
      events << '\\override Score.BarNumber.break-visibility = ##(#f #t #t)'
    when 'line_start'
      events << '\\set Score.barNumberVisibility = #all-bar-numbers-visible'
      events << '\\override Score.BarNumber.break-visibility = ##(#f #f #t)'
    end
  end

  system['measures'].each do |measure|
    measure_events = measure.fetch(staff_key || (staff == 'treble' ? 'treble' : 'bass'), [])
    events << (measure_events.empty? ? 'R1' : ly_events(measure_events))
    events << '|'
  end

  events.join(' ')
end

def has_dynamics?(system)
  system['measures'].any? { |measure| measure['dynamics'] }
end

def dynamics_music(system)
  events = []
  events << "\\time #{system['time']}" if system.fetch('time', '4/4').include?('/')
  bar_length = system.fetch('bar_length', 4.0)

  system['measures'].each do |measure|
    cursor = 0.0
    dynamics = measure.fetch('dynamics', []).sort_by { |event| event.fetch('t', 0) }
    if dynamics.empty?
      events << 's' + DUR_MAP.fetch(bar_length.to_f.round(3), '1')
      events << '|'
      next
    end

    dynamics.each_with_index do |event, index|
      t = event.fetch('t', 0.0)
      events << 's' + DUR_MAP.fetch((t - cursor).to_f.round(3), '4') if t > cursor
      ending = index + 1 < dynamics.length ? dynamics[index + 1].fetch('t', bar_length) : bar_length
      spacer = 's' + DUR_MAP.fetch([ending - t, 0.0].max.to_f.round(3), '4')
      spacer += "\\#{event['dynamic']}" if event['dynamic']
      events << spacer
      cursor = ending
    end

    events << 's' + DUR_MAP.fetch((bar_length - cursor).to_f.round(3), '4') if cursor < bar_length
    events << '|'
  end

  events.join(' ')
end

def escaped(text)
  text.gsub('"', '\"')
end

def write_fig(figure)
  blocks = []

  figure['systems'].each do |system|
    blocks << "\\markup { \\bold \"#{escaped(system['label'])}\" }"

    if system['staves']
      staff_blocks = system['staves'].each_with_index.map do |staff_def, index|
        clef = staff_def.fetch('clef', 'treble')
        music = staff_music(system, clef, staff_def['key'], first_staff: index.zero?)
        label = staff_def['label']
        staff_with = label ? " \\with { instrumentName = \"#{escaped(label)}\" }" : ''
        "\\new Staff#{staff_with} { \\clef #{clef} #{music} }"
      end
      indent = system['staves'].any? { |staff_def| staff_def['label'] } ? '14\\mm' : '0\\mm'
      blocks << <<~LILYPOND
        \\score {
          \\new StaffGroup <<
            #{staff_blocks.join("\n    ")}
          >>
          \\layout { indent = #{indent} }
        }
      LILYPOND
    elsif system['clefs'].length == 2
      treble = staff_music(system, 'treble')
      bass = staff_music(system, 'bass')
      dynamics = has_dynamics?(system) ? dynamics_music(system) : ''
      dynamics_block = dynamics.empty? ? '' : "\n    \\new Dynamics { #{dynamics} }"
      blocks << <<~LILYPOND
        \\score {
          \\new PianoStaff <<
            \\new Staff = "RH" { \\clef treble #{treble} }
        #{dynamics_block}
            \\new Staff = "LH" { \\clef bass #{bass} }
          >>
          \\layout { indent = 0\\mm }
        }
      LILYPOND
    else
      clef = system['clefs'].first
      music = staff_music(system, clef)
      blocks << <<~LILYPOND
        \\score {
          \\new Staff { \\clef #{clef} #{music} }
          \\layout { indent = 0\\mm }
        }
      LILYPOND
    end
  end

  content = <<~LILYPOND
    \\version "2.24.0"
    \\paper { #(set-paper-size "a4landscape") page-breaking = #ly:one-page-breaking }
    \\header { title = "#{escaped(figure['title'])}" tagline = ##f }
    #{blocks.join("\n\n")}
  LILYPOND

  File.write(File.join(OUT, "#{figure['id']}.ly"), content, encoding: 'UTF-8')
end

def export_lilypond_sources
  Dir.glob(File.join(OUT, '*.ly')).each { |path| File.delete(path) }
  FIGURES.each { |figure| write_fig(figure) }
  puts "Wrote LilyPond sources to #{OUT}"
end

export_lilypond_sources if $PROGRAM_NAME == __FILE__
