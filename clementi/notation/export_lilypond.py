from __future__ import annotations
from pathlib import Path
from score_data import FIGURES

SOURCE_ROOT = Path(__file__).resolve().parents[1]
OUT = SOURCE_ROOT / 'lilypond'
OUT.mkdir(exist_ok=True)

NOTE_MAP = {'C':'c','D':'d','E':'e','F':'f','G':'g','A':'a','B':'b'}
ACC_MAP = {'':'','#':'is','b':'es','n':'!'}
DUR_MAP = {4.0:'1',3.0:'2.',2.0:'2',1.5:'4.',1.0:'4',0.75:'8.',0.5:'8',0.375:'16.',0.25:'16',0.125:'32',0.333:'8'}
KEY_MAP = {'C':'c','F':'f','Bb':'bes','Eb':'ees','Ab':'aes'}

def parse_pitch(p):
    letter=p[0].upper(); rest=p[1:]; acc=''
    if rest and rest[0] in ['#','b','n']:
        acc=rest[0]; rest=rest[1:]
    return letter, acc, int(rest)

def ly_pitch(p):
    letter, acc, octv = parse_pitch(p)
    base = NOTE_MAP[letter] + ACC_MAP.get(acc,'')
    # LilyPond: c' = C4, c = C3, c, = C2, c'' = C5
    if octv >= 4:
        return base + "'"*(octv-3)
    else:
        return base + ","*(3-octv)

def ly_events(events):
    return ' '.join(ly_event(e) for e in events)

def ly_event(ev):
    if ev.get('clef'):
        return '\\clef ' + ev['clef']
    if ev.get('tuplet'):
        return '\\tuplet ' + ev['tuplet'] + ' { ' + ly_events(ev['events']) + ' }'
    if ev.get('voices'):
        return '<< ' + ' \\\\ '.join('{ ' + ly_events(part) + ' }' for part in ev['voices']) + ' >>'
    dur = DUR_MAP.get(round(ev.get('dur',1.0),3), '4')
    if ev.get('rest'):
        out = 'r' + dur
        if ev.get('fermata'):
            out += '^\\fermata'
        return out
    prefix = ''
    if ev.get('grace_before'):
        prefix = '\\grace { ' + ' '.join(ly_pitch(p) + '32' for p in ev['grace_before']) + ' } '
    if len(ev['pitches']) == 1:
        out = ly_pitch(ev['pitches'][0]) + dur
    else:
        out = '<' + ' '.join(ly_pitch(p) for p in ev['pitches']) + '>' + dur
        if ev.get('arpeggio'):
            out += '\\arpeggio'
    if ev.get('tie'):
        out += '~'
    if ev.get('slur_start'):
        out += '('
    if ev.get('slur_end'):
        out += ')'
    if ev.get('staccato'):
        out += '-.'
    if ev.get('staccatissimo'):
        out += '-!'
    if ev.get('dynamic'):
        out += '\\' + ev['dynamic']
    if ev.get('accent'):
        out += '->'
    if ev.get('fermata'):
        out += '^\\fermata'
    if ev.get('text'):
        out += '^\\markup { \\italic "' + ev['text'] + '" }'
    return prefix + out

def staff_music(system, staff, staff_key=None, first_staff=False):
    events=[]
    key = KEY_MAP.get(system.get('key','C'), 'c')
    events.append(f'\\key {key} \\major')
    if '/' in system.get('time','4/4'):
        events.append('\\numericTimeSignature')
        events.append('\\time ' + system['time'])
    if first_staff or staff == system.get('clefs', [staff])[0]:
        first_number = system.get('measures', [{}])[0].get('number')
        if isinstance(first_number, int):
            events.append(f'\\set Score.currentBarNumber = #{first_number}')
        if system.get('bar_numbers') == 'all':
            events.append('\\set Score.barNumberVisibility = #all-bar-numbers-visible')
            events.append('\\override Score.BarNumber.break-visibility = ##(#f #t #t)')
        elif system.get('bar_numbers') == 'line_start':
            events.append('\\set Score.barNumberVisibility = #all-bar-numbers-visible')
            events.append('\\override Score.BarNumber.break-visibility = ##(#f #f #t)')
    for meas in system['measures']:
        evs = meas.get(staff_key or ('treble' if staff=='treble' else 'bass'), [])
        if not evs:
            events.append('R1')
        else:
            events.append(ly_events(evs))
        events.append('|')
    return ' '.join(events)

def has_dynamics(system):
    return any(meas.get('dynamics') for meas in system['measures'])

def dynamics_music(system):
    events = []
    if '/' in system.get('time','4/4'):
        events.append('\\time ' + system['time'])
    bar_length = system.get('bar_length', 4.0)
    for meas in system['measures']:
        cursor = 0.0
        dynamics = sorted(meas.get('dynamics', []), key=lambda ev: ev.get('t', 0))
        if not dynamics:
            events.append('s' + DUR_MAP.get(round(bar_length, 3), '1'))
            events.append('|')
            continue
        for i, ev in enumerate(dynamics):
            t = ev.get('t', 0.0)
            if t > cursor:
                events.append('s' + DUR_MAP.get(round(t - cursor, 3), '4'))
            end = dynamics[i + 1].get('t', bar_length) if i + 1 < len(dynamics) else bar_length
            dur = max(end - t, 0.0)
            spacer = 's' + DUR_MAP.get(round(dur, 3), '4')
            if ev.get('dynamic'):
                spacer += '\\' + ev['dynamic']
            events.append(spacer)
            cursor = end
        if cursor < bar_length:
            events.append('s' + DUR_MAP.get(round(bar_length - cursor, 3), '4'))
        events.append('|')
    return ' '.join(events)

def write_fig(fig):
    blocks=[]
    for i, sys in enumerate(fig['systems']):
        blocks.append('\\markup { \\bold "' + sys['label'].replace('"', '\\"') + '" }')
        if sys.get('staves'):
            staff_blocks = []
            has_instrument_names = any(staff_def.get('label') for staff_def in sys['staves'])
            for idx, staff_def in enumerate(sys['staves']):
                clef = staff_def.get('clef', 'treble')
                key = staff_def['key']
                music = staff_music(sys, clef, key, first_staff=(idx == 0))
                label = staff_def.get('label')
                staff_with = ' \\with { instrumentName = "' + label.replace('"', '\\"') + '" }' if label else ''
                staff_blocks.append('\\new Staff' + staff_with + ' { \\clef ' + clef + ' ' + music + ' }')
            indent = '14\\mm' if has_instrument_names else '0\\mm'
            blocks.append(r'''\score {
  \new StaffGroup <<
    ''' + '\n    '.join(staff_blocks) + r'''
  >>
  \layout { indent = ''' + indent + r''' }
}''')
        elif len(sys['clefs']) == 2:
            treble = staff_music(sys, 'treble')
            bass = staff_music(sys, 'bass')
            dynamics = dynamics_music(sys) if has_dynamics(sys) else ''
            dynamics_block = '\n    \\new Dynamics { ' + dynamics + ' }' if dynamics else ''
            blocks.append(r'''\score {
  \new PianoStaff <<
    \new Staff = "RH" { \clef treble ''' + treble + r''' }
''' + dynamics_block + r'''
    \new Staff = "LH" { \clef bass ''' + bass + r''' }
  >>
  \layout { indent = 0\mm }
}''')
        else:
            clef = sys['clefs'][0]
            music = staff_music(sys, clef)
            blocks.append(r'''\score {
  \new Staff { \clef ''' + clef + ' ' + music + r''' }
  \layout { indent = 0\mm }
}''')
    content = '\\version "2.24.0"\n\\paper { #(set-paper-size "a4landscape") page-breaking = #ly:one-page-breaking }\n\\header { title = "' + fig['title'].replace('"','\\"') + '" tagline = ##f }\n' + '\n\n'.join(blocks) + '\n'
    (OUT / (fig['id'] + '.ly')).write_text(content, encoding='utf-8')

def main():
    for p in OUT.glob('*.ly'):
        p.unlink()
    for fig in FIGURES:
        write_fig(fig)
    print(f'Wrote LilyPond sources to {OUT}')

if __name__ == '__main__':
    main()
