# frozen_string_literal: true

# Editable source data for the Clementi/Mozart blog figures.
#
# Pitch names use scientific pitch notation: C4 = middle C.
# Durations are in quarter-note units:
#   4.0 = whole, 2.0 = half, 1.0 = quarter,
#   0.5 = eighth, 0.25 = sixteenth, 0.125 = thirty-second.
#
# Each event may be:
#   n(t, dur, 'C4')                  single note
#   n(t, dur, ['C4', 'E4', 'G4'])    chord
#   r(t, dur)                        rest
#
# This is intentionally simple so you can edit note names/rhythms directly.


def n(t, dur, pitches, stem: 'auto', text: nil, acc: nil, arpeggio: false, staccato: false, staccatissimo: false, grace_before: nil, tie: false, dynamic: nil, accent: false, fermata: false, slur_start: false, slur_end: false)
  pitches = [pitches] if pitches.is_a?(String)
  event = { 't' => t, 'dur' => dur, 'pitches' => pitches, 'stem' => stem, 'text' => text, 'acc' => acc }
  event['arpeggio'] = true if arpeggio
  event['staccato'] = true if staccato
  event['staccatissimo'] = true if staccatissimo
  event['grace_before'] = grace_before.is_a?(String) ? [grace_before] : grace_before if grace_before
  event['tie'] = true if tie
  event['dynamic'] = dynamic if dynamic
  event['accent'] = true if accent
  event['fermata'] = true if fermata
  event['slur_start'] = true if slur_start
  event['slur_end'] = true if slur_end
  event
end

def r(t, dur, fermata: false)
  event = { 't' => t, 'dur' => dur, 'rest' => true }
  event['fermata'] = true if fermata
  event
end

def clef(name)
  { 'clef' => name }
end

def dyn(t, mark)
  { 't' => t, 'dynamic' => mark }
end

def tuplet(ratio, events)
  { 'tuplet' => ratio, 'events' => events }
end

def voices(*parts)
  { 'voices' => parts }
end

def notes(t, dur, pitches)
  pitches.each_with_index.map { |pitch, index| n(t + (index * dur), dur, pitch) }
end

def semis(*groups)
  notes(0, 0.25, groups.flatten)
end

def triplet_quavers(*groups)
  groups.map { |group| tuplet('3/2', group.map { |pitch| n(0, 0.5, pitch) }) }
end

# -----------------------------------------------------------------------------
# NOTE: These are first-pass, editable analytical transcriptions. Some passages
# preserve only the relevant voice/pattern when the comparison turns on that
# pattern rather than the entire pianistic texture.
# -----------------------------------------------------------------------------

FIGURES = [
    {
        'id' => 'figure_01_clementi_magic_flute',
        'title' => 'Figure 1. Clementi and The Magic Flute',
        'subtitle' => 'Opening motif of Clementi Op. 24 No. 2 beside the later Magic Flute overture Allegro subject.',
        'systems' => [
            {
                'label' => 'Clementi, Sonata in B-flat, Op. 24 No. 2, Allegro con brio, opening motif',
                'clefs' => ['treble', 'bass'], 'key' => 'Bb', 'time' => '4/4', 'bar_length' => 4.0, 'bar_numbers' => 'line_start',
                'measures' => [
                    {'number' => 1,
                     'treble' => [n(0.0,0.5,'Bb3'), n(0.5,0.5,'Bb3'), n(1.0,0.5,'Bb3'), n(1.5,0.5,'Bb3'),
                                n(2.0,0.5,'Bb3'), n(2.5,0.5,'Bb3'), n(3.0,0.25,'C4', slur_start: true), n(3.25,0.25,'Bb3'), n(3.5,0.25,'A3'), n(3.75,0.25,'Bb3')],
                     'bass' => [r(0,1.0), n(1.0,1.0,'F3', slur_start: true), n(2.0,1.0,'D3'), n(3.0,1.0,'Bb2')]},
                    {'number' => 2,
                     'treble' => [n(0.0,0.5,'F4', slur_end: true), n(0.5,0.5,'F4'), n(1.0,0.5,'F4'), n(1.5,0.5,'F4'),
                                n(2.0,0.5,'F4'), n(2.5,0.5,'F4'), n(3.0,0.25,'G4', slur_start: true), n(3.25,0.25,'F4'), n(3.5,0.25,'E4'), n(3.75,0.25,'F4')],
                     'bass' => [n(0,1,'A2'), n(1,1,'C3'), n(2,1,'A2'), n(3,1,'Eb2')]},
                    {'number' => 3,
                     'treble' => [n(0.0,0.5,'Bb4', slur_end: true), n(0.5,0.5,'Bb4'), n(1.0,0.5,'Bb4'), n(1.5,0.5,'Bb4'),
                                n(2.0,0.5,'Bb4'), n(2.5,0.5,'Bb4'), n(3.0,0.25,'C5', slur_start: true), n(3.25,0.25,'Bb4'), n(3.5,0.25,'A4'), n(3.75,0.25,'Bb4', slur_end: true)],
                     'bass' => [n(0,1,'D2'), n(1,1,'F2'), n(2,1,'D2'), n(3,1,'Bb1', slur_end: true)]},
                    {'number' => 4,
                     'treble' => [n(0.0,1.0,['G4','Bb4','Eb5','G5'], arpeggio: true),
                                n(1.0,1.0,['F4','Bb4','D5','F5'], arpeggio: true),
                                r(2.0,0.5),
                                n(2.5,0.5,'F4', staccato: true),
                                n(3.0,0.5,'F4', staccato: true),
                                n(3.5,0.5,'F4', staccato: true)],
                     'bass' => [n(0.0,1.0,['Eb2','Eb3']),
                              n(1.0,1.0,['Bb1','Bb2']),
                              r(2.0,2.0)]},
                ],
            },
            {
                'label' => 'Mozart, The Magic Flute overture, Allegro subject',
                'staves' => [{'key' => 'violin1', 'clef' => 'treble'},
                           {'key' => 'violin2', 'clef' => 'treble'}],
                'clefs' => ['treble'], 'key' => 'Eb', 'time' => '4/4', 'bar_length' => 4.0,
                'measures' => [
                    {'number' => 16,
                     'violin1' => [r(0,4)],
                     'violin2' => [n(0,0.5,'Eb4', staccato: true, dynamic: 'p'), n(0.5,0.5,'Eb4', staccato: true), n(1,0.5,'Eb4', staccato: true), n(1.5,0.5,'Eb4', staccato: true), n(2,0.5,'Eb4', staccato: true), n(2.5,0.5,'Eb4', staccato: true),
                                 n(3,0.25,'F4', dynamic: 'f', slur_start: true), n(3.25,0.25,'Eb4'), n(3.5,0.25,'D4'), n(3.75,0.25,'Eb4', slur_end: true)]},
                    {'number' => 17,
                     'violin1' => [r(0,4)],
                     'violin2' => [n(0,0.5,'Bb4', staccato: true, dynamic: 'p'), n(0.5,0.5,'Bb4', staccato: true), n(1,0.5,'Bb4', staccato: true), n(1.5,0.5,'Bb4', staccato: true), n(2,0.5,'Bb4', staccato: true), n(2.5,0.5,'Bb4', staccato: true),
                                 n(3,0.25,'C5', dynamic: 'f', slur_start: true), n(3.25,0.25,'Bb4'), n(3.5,0.25,'A4'), n(3.75,0.25,'Bb4', slur_end: true)]},
                    {'number' => 18,
                     'violin1' => [r(0,4)],
                     'violin2' => [n(0,0.5,'G4', staccato: true, dynamic: 'p'), n(0.5,0.5,'G4', staccato: true), n(1,0.5,'C5', staccato: true), n(1.5,0.5,'C5', staccato: true),
                                 n(2,0.5,'F4', staccato: true), n(2.5,0.5,'F4', staccato: true), n(3,0.5,'Bb4', staccato: true, dynamic: 'f'), n(3.5,0.5,'Bb4', staccato: true)]},
                    {'number' => 19,
                     'violin1' => [r(0,4)],
                     'violin2' => [n(0,0.5,'G4', staccato: true, dynamic: 'p'), n(0.5,0.5,'G4', staccato: true), n(1,0.5,'C5', staccato: true), n(1.5,0.5,'C5', staccato: true),
                                 n(2,0.5,'F4', staccato: true), n(2.5,0.5,'F4', staccato: true), n(3,0.5,'Bb4', staccato: true, dynamic: 'f'), n(3.5,0.5,'Bb4', staccato: true)]},
                    {'number' => 20,
                     'violin1' => [n(0,0.5,'Bb4', staccato: true, dynamic: 'p'), n(0.5,0.5,'Bb4', staccato: true), n(1,0.5,'Bb4', staccato: true), n(1.5,0.5,'Bb4', staccato: true), n(2,0.5,'Bb4', staccato: true), n(2.5,0.5,'Bb4', staccato: true),
                                 n(3,0.25,'C5', dynamic: 'f', slur_start: true), n(3.25,0.25,'Bb4'), n(3.5,0.25,'A4'), n(3.75,0.25,'Bb4', slur_end: true)],
                     'violin2' => [n(0,0.5,'G4', staccato: true, dynamic: 'p'), n(0.5,0.5,'A4', staccato: true), n(1,0.5,'G4', staccato: true), n(1.5,0.5,'F4', staccato: true),
                                 n(2,0.5,'Eb4', staccato: true), n(2.5,0.5,'F4', staccato: true), n(3,0.5,'Eb4', staccato: true, dynamic: 'f'), n(3.5,0.5,'D4', staccato: true)]},
                    {'number' => 21,
                     'violin1' => [n(0,0.5,'Eb5', staccato: true, dynamic: 'p'), n(0.5,0.5,'Eb5', staccato: true), n(1,0.5,'Eb5', staccato: true), n(1.5,0.5,'Eb5', staccato: true), n(2,0.5,'Eb5', staccato: true), n(2.5,0.5,'Eb5', staccato: true),
                                 n(3,0.25,'F5', dynamic: 'f', slur_start: true), n(3.25,0.25,'Eb5'), n(3.5,0.25,'D5'), n(3.75,0.25,'Eb5', slur_end: true)],
                     'violin2' => [n(0,0.5,'C4'), n(0.5,0.5,'D4'), n(1,0.5,'Eb4'), n(1.5,0.5,'F4'), n(2,0.5,'F#4'), n(2.5,0.5,'G4'), n(3,0.5,'Ab4'), n(3.5,0.5,'A4')]},
                    {'number' => 22,
                     'violin1' => [n(0,0.5,'D5', staccato: true, dynamic: 'p'), n(0.5,0.5,'D5', staccato: true), n(1,0.5,'G5', staccato: true), n(1.5,0.5,'G5', staccato: true),
                                 n(2,0.5,'C5', staccato: true), n(2.5,0.5,'C5', staccato: true), n(3,0.5,'F5', staccato: true, dynamic: 'f'), n(3.5,0.5,'F5', staccato: true)],
                     'violin2' => [n(0,0.5,'Bb4'), r(0.5,0.5), n(1,2,'Bb4', dynamic: 'sfp', slur_start: true), n(3,1,'A4', slur_end: true)]},
                    {'number' => 23,
                     'violin1' => [n(0,0.5,'D5', staccato: true, dynamic: 'p'), n(0.5,0.5,'D5', staccato: true), n(1,0.5,'G5', staccato: true), n(1.5,0.5,'G5', staccato: true),
                                 n(2,0.5,'C5', staccato: true), n(2.5,0.5,'C5', staccato: true), n(3,0.5,'F5', staccato: true, dynamic: 'f'), n(3.5,0.5,'F5', staccato: true)],
                     'violin2' => [n(0,0.5,'Bb4'), r(0.5,0.5), n(1,2,'Bb4', dynamic: 'sfp', slur_start: true), n(3,1,'A4', slur_end: true)]},
                ],
            },
        ],
    },
    {
        'id' => 'figure_02_chord_pattern',
        'title' => 'Figure 2. Early chord pattern',
        'subtitle' => 'Mozart K.281, m.3 compared with Clementi Op.24 No.2, m.4.',
        'systems' => [
            {
                'label' => 'Mozart K.281, m.3',
                'clefs' => ['treble','bass'], 'key' => 'Bb', 'time' => '2/4', 'bar_length' => 2.0,
                'measures' => [
                    {'number' => 3,
                     'treble' => [n(0.0,0.5,['Bb4','Eb5','G5'], arpeggio: true),
                                n(0.5,0.5,['Bb4','D5','F5'], arpeggio: true),
                                n(1.0,0.125,'F5'), n(1.125,0.125,'Bb5'), n(1.25,0.125,'A5'), n(1.375,0.125,'Bb5'),
                                n(1.5,0.125,'D6'), n(1.625,0.125,'Bb5'), n(1.75,0.125,'A5'), n(1.875,0.125,'Bb5')],
                     'bass' => [n(0.0,0.5,['Eb3','Eb4']),
                              n(0.5,0.5,['Bb2','Bb3']),
                              r(1.0,0.5), r(1.5,0.5)]}
                ],
                'note' => 'Analytical encoding of the chordal punctuation and following flourish.'
            },
            {
                'label' => 'Clementi Op.24 No.2, m.4',
                'clefs' => ['treble','bass'], 'key' => 'Bb', 'time' => '4/4', 'bar_length' => 4.0,
                'measures' => [
                    {'number' => 4,
                     'treble' => [n(0.0,1.0,['G4','Bb4','Eb5','G5'], arpeggio: true),
                                n(1.0,1.0,['F4','Bb4','D5','F5'], arpeggio: true),
                                r(2.0,0.5),
                                n(2.5,0.5,'F4', staccato: true),
                                n(3.0,0.5,'F4', staccato: true),
                                n(3.5,0.5,'F4', staccato: true)],
                     'bass' => [n(0.0,1.0,['Eb2','Eb3']),
                              n(1.0,1.0,['Bb1','Bb2']),
                              r(2.0,2.0)]}
                ]
            },
        ],
    },
    {
        'id' => 'figure_03_rising_scale_trill_drop',
        'title' => 'Figure 3. Rising scale, trill, and fall',
        'subtitle' => 'Mozart K.281, mm.7-11 compared with Clementi Op.24 No.2, mm.7-15.',
        'systems' => [
            {
                'label' => 'Mozart K.281, mm.7-11',
                'clefs' => ['treble','bass'], 'key' => 'Bb', 'time' => '2/4', 'bar_length' => 2.0,
                'measures' => [
                    {'number' => 7,
                     'treble' => [tuplet('3/2', [n(0,0.25,'G4'), n(0,0.25,'C5'), n(0,0.25,'Eb5'), n(0,0.25,'C5'), n(0,0.25,'Eb5'), n(0,0.25,'G5')]),
                                n(1,0.25,'F5', grace_before: 'G5'), n(1.25,0.125,'Eb5'), n(1.375,0.125,'D5'),
                                n(1.5,0.25,'C5', grace_before: 'D5'), n(1.75,0.125,'Bb4'), n(1.875,0.125,'A4')],
                     'bass' =>[n(0,1,['Eb3','G3','C4'], arpeggio: true, dynamic: 'f'), voices([n(1,0.5,'D4'), n(1.5,0.5,'Eb4')], [n(1,1,'F3')])]},
                    {'number' => 8,
                     'treble' => [n(0,1,'Bb4'), r(1,0.25), n(1.25,0.25,'Bb4', slur_start: true), n(1.5,0.25,'A4'), n(1.75,0.25,'Ab4', slur_end: true)],
                     'bass' =>[n(0,0.25,['Bb3','D4']), n(0.25,0.25,['Bb3','D4']), n(0.5,0.25,['Bb3','D4']), n(0.75,0.25,['Bb3','D4']),
                             n(1,0.25,['Bb3','D4']), n(1.25,0.25,['Bb3','D4']), n(1.5,0.25,['Bb3','D4']), n(1.75,0.25,['Bb3','D4'])]},
                    {'number' => 9,
                     'treble' => [n(0,0.25,'G4'), n(0.25,0.125,'A4'), n(0.375,0.125,'Bb4'), n(0.5,0.125,'C5'), n(0.625,0.125,'D5'), n(0.75,0.125,'Eb5'), n(0.875,0.125,'F5'),
                                n(1,0.125,'G5', slur_start: true), n(1.125,0.125,'A5'), n(1.25,0.125,'Bb5'), n(1.375,0.125,'A5'), n(1.5,0.125,'Bb5'), n(1.625,0.125,'A5'), n(1.75,0.125,'Bb5'), n(1.875,0.125,'G5', slur_end: true)],
                     'bass' =>[n(0,0.25,['Bb3','Eb4']), n(0.25,0.25,['Bb3','Eb4']), n(0.5,0.25,['Bb3','Eb4']), n(0.75,0.25,['Bb3','Eb4']),
                             n(1,0.25,['Bb3','Eb4']), n(1.25,0.25,['Bb3','Eb4']), n(1.5,0.25,['Bb3','Eb4']), n(1.75,0.25,['Bb3','Eb4'])]},
                    {'number' =>10,
                     'treble' =>[n(0,1,'F5'), r(1,0.25), n(1.25,0.25,'Bb4', slur_start: true), n(1.5,0.25,'A4'), n(1.75,0.25,'Ab4', slur_end: true)],
                     'bass' =>[n(0,0.25,['Bb3','D4']), n(0.25,0.25,['Bb3','D4']), n(0.5,0.25,['Bb3','D4']), n(0.75,0.25,['Bb3','D4']),
                             n(1,0.25,['Bb3','D4']), n(1.25,0.25,['Bb3','D4']), n(1.5,0.25,['Bb3','D4']), n(1.75,0.25,['Bb3','D4'])]},
                    {'number' =>11,
                     'treble' =>[n(0,0.25,'G4'), n(0.25,0.125,'A4'), n(0.375,0.125,'Bb4'), n(0.5,0.125,'C5'), n(0.625,0.125,'D5'), n(0.75,0.125,'Eb5'), n(0.875,0.125,'F5'),
                               n(1,0.125,'G5', slur_start: true), n(1.125,0.125,'A5'), n(1.25,0.125,'Bb5'), n(1.375,0.125,'A5'), n(1.5,0.125,'Bb5'), n(1.625,0.125,'A5'), n(1.75,0.125,'Bb5'), n(1.875,0.125,'G5', slur_end: true)],
                     'bass' =>[n(0,0.25,['Bb3','Eb4']), n(0.25,0.25,['Bb3','Eb4']), n(0.5,0.25,['Bb3','Eb4']), n(0.75,0.25,['Bb3','Eb4']),
                             n(1,0.25,['Bb3','Eb4']), n(1.25,0.25,['Bb3','Eb4']), n(1.5,0.25,['Bb3','Eb4']), n(1.75,0.25,['Bb3','Eb4'])]},
                ],
                'note' => 'Condensed to the scale/trill/drop line and harmonic bass.'
            },
            {
                'label' => 'Clementi Op.24 No.2, mm.7-15',
                'clefs' => ['treble','bass'], 'key' => 'Bb', 'time' => '4/4', 'bar_length' => 4.0,
                'measures' => [
                    {'number' => 7,
                     'treble' =>[r(0,0.5),
                               n(1,0.5,'G5', slur_start: true), n(1.5,0.5,'Eb5'), n(2,0.5,'C5'), n(2.5,0.5,'Bb4'), n(3,0.5,'D5'), n(3.5,0.5,'C5'), n(3.5,0.5,'A4', slur_end: true)],
                     'bass' =>[voices([n(0,1,'G3', slur_start: true), n(1,1,'C4'), n(2,1,'D4'), n(4,1,'Eb4')], [n(0,2,'Eb3'), n(0,2,'F3')])]},
                    {'number' => 8,
                     'treble' =>[n(0,0.75,'Bb4', slur_start: true), tuplet('3/2', [n(0.5,0.125,'C5'), n(0.5,0.125,'Bb4'), n(0.5,0.125,'A4', slur_end: true)]),
                               n(1,0.5,'Bb4'), n(1.5,0.5,'C5'), n(2,0.5,'D5'), r(2.5,0.25),
                               n(2.75,0.25,'F5', slur_start: true), n(3,0.25,'E5'), n(3.25,0.25,'F5'), n(3.5,0.25,'G5'), n(3.75,0.25,'F5', slur_end: true)],
                     'bass' =>[voices([n(0,1.5,'D4'), n(3,0.5,'Eb4'), n(3.5,0.5,'F4', slur_end: true)], [n(0,3,'Bb3'), r(3,1)])]},
                    {'number' => 9,
                     'treble' =>[n(0,0.5,'Eb5', slur_start: true), n(0.5,0.5,'F5'), n(1,0.5,'D5'), n(1.5,0.5,'F5'),
                               n(2,0.5,'C5', slur_end: true), r(2.5,0.25),
                               n(2.75,0.25,'F5', slur_start: true), n(3,0.25,'E5'), n(3.25,0.25,'F5'), n(3.5,0.25,'G5'), n(3.75,0.25,'F5', slur_end: true)],
                     'bass' =>[voices([n(0,1,['A3','C4'], slur_start: true), n(1,1,['Bb3','D4']), n(2,1,['C4','Eb4'], slur_end: true)],
                                    [n(0,3,'F3'), r(3,1)])]},
                    {'number' =>10,
                     'treble' =>[n(0,0.5,'D5', slur_start: true), n(0.5,0.5,'F5'), n(1,0.5,'C5'), n(1.5,0.5,'F5'),
                               n(2,0.5,'Bb4', slur_end: true), r(2.5,0.5), r(3,1)],
                     'bass' =>[voices([n(0,1,['Bb3','D4'], slur_start: true), n(1,1,['C4','Eb4']), n(2,1,['D4','F4'], slur_end: true), r(3,1)],
                                    [n(0,2,'F3'), r(2,0.5), n(2.5,0.5,['D3','F3'], staccato: true), n(3,0.5,['D3','F3'], staccato: true), n(3.5,0.5,['D3','F3'], staccato: true)])]},
                    {'number' =>11,
                     'treble' =>[tuplet('3/2', [r(0,0.5), n(0.5,0.5,'F#5', slur_start: true), n(0.75,0.5,'A5')]),
                               tuplet('3/2', [n(1,0.5,'G5'), n(1.5,0.5,'Eb5'), n(1.75,0.5,'C5', slur_end: true)]),
                               n(2,0.5,'Bb4', slur_start: true), n(2.5,0.5,'D5'),
                               n(3,0.5,'C5'), n(3.5,0.5,'A4', slur_end: true)],
                     'bass' =>[voices([n(0,1,'G3', slur_start: true), n(1,1,'C4'), n(2,1,'D4'), n(3,1,'Eb4', slur_end: true)], [n(0,2,'E3'), n(2,2,'F3')])]},
                    {'number' =>12, 'treble' =>[n(0,0.25,'Bb4'),n(0.25,0.25,'F4'),n(0.5,0.25,'G4'),n(0.75,0.25,'A4'),n(1,0.25,'Bb4'),n(1.25,0.25,'C5'),n(1.5,0.25,'D5'),n(1.75,0.25,'Eb5'),
                                           n(2,0.25,'F5'),n(2.25,0.25,'G5'),n(2.5,0.25,'A5'),n(2.75,0.25,'Bb5'),n(3,0.25,'A5'),n(3.25,0.25,'Bb5'),n(3.5,0.25,'A5'),n(3.75,0.25,'Bb5')],
                     'bass' =>[n(0,0.5,'D4'), n(0.5,0.5,'Bb3'), n(1,0.5,'D4'), n(1.5,0.5,'Bb3'), n(2,0.5,'D4'), n(2.5,0.5,'Bb3'), n(3,0.5,'D4'), n(3.5,0.5,'Bb3')]},
                    {'number' =>13, 'treble' =>[n(0,2,'G4'), n(2,1.5,'A4',text: 'tr'), n(3.5,0.25,'G4'), n(3.75,0.25,'A4')],
                     'bass' =>[n(0,0.5,'Eb4'), n(0.5,0.5,'Bb3'), n(1,0.5,'Eb4'), n(1.5,0.5,'Bb3'), n(2,0.5,'Eb4'), n(2.5,0.5,'Bb3'), n(3,0.5,'Eb4'), n(3.5,0.5,'Bb3')]},
                    {'number' =>14,
                     'treble' =>[n(0,0.25,'Bb4'),n(0.25,0.25,'F4'),n(0.5,0.25,'G4'),n(0.75,0.25,'A4'),n(1,0.25,'Bb4'),n(1.25,0.25,'C5'),n(1.5,0.25,'D5'),n(1.75,0.25,'Eb5'),
                               n(2,0.25,'F5'),n(2.25,0.25,'G5'),n(2.5,0.25,'A5'),n(2.75,0.25,'Bb5'),n(3,0.25,'A5'),n(3.25,0.25,'Bb5'),n(3.5,0.25,'A5'),n(3.75,0.25,'Bb5')],
                     'bass' =>[n(0,0.5,'D4'), n(0.5,0.5,'Bb3'), n(1,0.5,'D4'), n(1.5,0.5,'Bb3'), n(2,0.5,'D4'), n(2.5,0.5,'Bb3'), n(3,0.5,'D4'), n(3.5,0.5,'Bb3')]},
                    {'number' =>15, 'treble' =>[n(0,2,'G4'), n(2,1.5,'A4',text: 'tr'), n(3.5,0.25,'G4'), n(3.75,0.25,'A4')],
                     'bass' =>[n(0,0.5,'Eb4'), n(0.5,0.5,'Bb3'), n(1,0.5,'Eb4'), n(1.5,0.5,'Bb3'), n(2,0.5,'Eb4'), n(2.5,0.5,'Bb3'), n(3,0.5,'Eb4'), n(3.5,0.5,'Bb3')]},
                ],
            },
        ],
    },
    {
        'id' => 'figure_05_descending_figuration_low_chord',
        'title' => 'Figure 5. Descending figuration and sudden low chord',
        'subtitle' => 'Mozart K.281, mm.34-37 compared with Clementi Op.24 No.2, mm.20-23.',
        'systems' => [
            {
                'label' => 'Mozart K.281, mm.34-37',
                'clefs' => ['treble','bass'], 'key' => 'Bb', 'time' => '2/4', 'bar_length' => 2.0,
                'measures' => [
                    {'number' =>34,
                     'treble' =>[r(0,0.25), n(0.25,0.125,'C6'), n(0.375,0.125,'A5'), n(0.5,0.125,'F5'), n(0.625,0.125,'C5'), n(0.75,0.125,'A4'), n(0.875,0.125,'F4'),
                               n(1,1,['C4','Eb4'], tie: true)],
                     'bass' =>[n(0,0.5,['F4','A4']), r(0.5,0.75), n(1.25,0.25,['F2','F3']), n(1.5,0.25,['A2','A3']), n(1.75,0.25,['F2','F3'])]},
                    {'number' =>35,
                     'treble' =>[n(0,0.25,['C4','Eb4']), n(0.25,0.25,'D4'), r(0.5,0.25), n(0.75,0.25,['Bb4','D5']),
                               r(1,0.25), n(1.25,0.25,['A4','C5']), r(1.5,0.25), n(1.75,0.25,['Bb3','E4'])],
                     'bass' =>[n(0,0.5,['Bb2','Bb3']), n(0.5,0.5,'G3'), n(1,0.5,'C4'), n(1.5,0.5,'C3')]},
                    {'number' =>36,
                     'treble' =>[r(0,0.25), n(0.25,0.125,'C6'), n(0.375,0.125,'A5'), n(0.5,0.125,'F5'), n(0.625,0.125,'C5'), n(0.75,0.125,'A4'), n(0.875,0.125,'F4'),
                               n(1,1,['C4','Eb4'], tie: true)],
                     'bass' =>[n(0,0.5,['F3','A3']), r(0.5,0.75), n(1.25,0.25,['F2','F3']), n(1.5,0.25,['A2','A3']), n(1.75,0.25,['F2','F3'])]},
                    {'number' =>37,
                     'treble' =>[n(0,0.25,['C4','Eb4']), n(0.25,0.25,'D4'), r(0.5,0.25), n(0.75,0.25,['Bb4','D5']),
                               r(1,0.25), n(1.25,0.25,['A4','C5']), r(1.5,0.25), n(1.75,0.25,['Bb3','E4'])],
                     'bass' =>[n(0,0.5,['Bb2','Bb3']), n(0.5,0.5,'G3'), n(1,0.5,'C4'), n(1.5,0.5,'C3')]},
                ],
            },
            {
                'label' => 'Clementi Op.24 No.2, mm.20-23',
                'clefs' => ['treble','bass'], 'key' => 'Bb', 'time' => '4/4', 'bar_length' => 4.0,
                'measures' => [
                    {'number' =>20,
                     'treble' =>[n(0,1,['E4','C5']),r(1,0.25),n(1.25,0.25,'G4'),n(1.5,0.25,'A4'),n(1.75,0.25,'B4'),n(2,0.25,'C5'),n(2.25,0.25,'B4'),n(2.5,0.25,'A4'),n(2.75,0.25,'G4'),n(3,0.25,'F4'),n(3.25,0.25,'E4'),n(3.5,0.25,'D4'),n(3.75,0.25,'C4')],
                     'bass' =>[r(0,0.25),n(0.25,0.25,'C2'),n(0.5,0.25,'D2'),n(0.75,0.25,'E2'),n(1,0.25,'F2'),n(1.25,0.25,'G2'),n(1.5,0.25,'A2'),n(1.75,0.25,'B2'),n(2,1,'C3'),r(3,1)]},
                    {'number' =>21,
                     'treble' =>[clef('bass'),n(0,2,['F3','A3'], dynamic: 'fz'), n(2,1.5,['D3','B3'],text: 'tr'), n(3.5,0.25,'A3'), n(3.75,0.25,'Bb3'), clef('treble')],
                     'bass' =>[n(0,0.5,'C2'),n(0.5,0.5,'C3'),n(1,0.5,'C2'),n(1.5,0.5,'C3'),n(2,0.5,'C2'),n(2.5,0.5,'C3'),n(3,0.5,'C2'),n(3.5,0.5,'C3')]},
                    {'number' =>22,
                     'treble' =>[n(0,1,['E4','C5']),r(1,0.25),n(1.25,0.25,'G4'),n(1.5,0.25,'A4'),n(1.75,0.25,'B4'),n(2,0.25,'C5'),n(2.25,0.25,'B4'),n(2.5,0.25,'A4'),n(2.75,0.25,'G4'),n(3,0.25,'F4'),n(3.25,0.25,'E4'),n(3.5,0.25,'D4'),n(3.75,0.25,'C4')],
                     'bass' =>[r(0,0.25),n(0.25,0.25,'C2'),n(0.5,0.25,'D2'),n(0.75,0.25,'E2'),n(1,0.25,'F2'),n(1.25,0.25,'G2'),n(1.5,0.25,'A2'),n(1.75,0.25,'B2'),n(2,1,'C3'),r(3,1)]},
                    {'number' =>23,
                     'treble' =>[clef('bass'),n(0,2,['F3','A3'], dynamic: 'fz'), n(2,1.5,['D3','B3'],text: 'tr'), n(3.5,0.25,'A3'), n(3.75,0.25,'Bb3'), clef('treble')],
                     'bass' =>[n(0,0.5,'C2'),n(0.5,0.5,'C3'),n(1,0.5,'C2'),n(1.5,0.5,'C3'),n(2,0.5,'C2'),n(2.5,0.5,'C3'),n(3,0.5,'C2'),n(3.5,0.5,'C3')]},
                ],
            },
        ],
    },
    {
        'id' => 'figure_04_rising_thirds',
        'title' => 'Fig 4. Rising thirds',
        'subtitle' => 'Mozart K.281, mm.1-2 compared with Clementi Op.24 No.2, m.10.',
        'systems' => [
            {
                'label' => 'Mozart K.281, mm.1-2',
                'clefs' => ['treble','bass'], 'key' => 'Bb', 'time' => '2/4', 'bar_length' => 2.0, 'bar_numbers' => 'line_start',
                'measures' => [
                    {'number' =>1,
                     'treble' =>[n(0,0.75,'Bb4', text: 'tr'), n(0.75,0.125,'C5'), n(0.875,0.125,'D5'),
                               tuplet('6/4', [n(1,0.25,'Bb4', slur_start: true), n(1.166,0.25,'A4'), n(1.333,0.25,'C5'),
                                              n(1.5,0.25,'Bb4'), n(1.666,0.25,'A4'), n(1.833,0.25,'Eb5', slur_end: true)])],
                     'bass' =>[n(0,1,['Bb3','D4']), n(1,1,['C4','Eb4'])]},
                    {'number' =>2,
                     'treble' =>[tuplet('6/4', [n(0,0.25,'C5', slur_start: true), n(0.166,0.25,'Bb4'), n(0.333,0.25,'D5'),
                                              n(0.5,0.25,'C5'), n(0.666,0.25,'Bb4'), n(0.833,0.25,'F5', slur_end: true)]),
                               n(1,0.5,'D5', staccato: true), r(1.5,0.5)],
                     'bass' =>[n(0,1,['D4','F4']), r(1,1)]}
                ],
            },
            {
                'label' => 'Clementi Op.24 No.2, m.10',
                'clefs' => ['treble','bass'], 'key' => 'Bb', 'time' => '4/4', 'bar_length' => 4.0,
                'measures' => [
                    {'number' =>10,
                     'treble' =>[n(0,0.5,'D5', slur_start: true), n(0.5,0.5,'F5'), n(1,0.5,'C5'), n(1.5,0.5,'F5'),
                               n(2,0.5,'Bb4', slur_end: true), r(2.5,0.5), r(3,1)],
                     'bass' =>[voices([n(0,1,['Bb3','D4'], slur_start: true), n(1,1,['C4','Eb4']), n(2,1,['D4','F4'], slur_end: true), r(3,1)],
                                    [n(0,2,'F3'), r(2,0.5), n(2.5,0.5,['D3','F3'], staccato: true), n(3,0.5,['D3','F3'], staccato: true), n(3.5,0.5,['D3','F3'], staccato: true)])]}
                ],
            },
        ],
    },
    {
        'id' => 'figure_06_development_texture',
        'title' => 'Figure 6. Four-note figuration in the development',
        'subtitle' => 'Mozart K.281, mm.55-56 compared with Clementi Op.24 No.2, m.59 onward.',
        'systems' => [
            {
                'label' => 'Mozart K.281, mm.55-56 - thirty-second-note figuration over octaves',
                'clefs' => ['treble','bass'], 'key' => 'Bb', 'time' => '2/4', 'bar_length' => 2.0,
                'measures' => [
                    {'number' =>55,
                     'treble' =>notes(0,0.125,['D5','G5','F#5','G5','A5','G5','F#5','G5','Bb5','G5','F#5','G5','Eb5','G5','F#5','G5']),
                     'bass' =>[n(0,1,['Bb2','Bb3']), r(1,0.5), n(1.5,0.5,['C3','C4'])]},
                    {'number' =>56,
                     'treble' =>notes(0,0.125,['D5','G5','F#5','G5','A5','G5','F#5','G5','Bb5','G5','F#5','G5','C5','G5','F#5','G5']),
                     'bass' =>[n(0,1,['Bb2','Bb3']), r(1,0.5), n(1.5,0.5,['Eb3','Eb4'])]},
                ],
            },
            {
                'label' => 'Clementi Op.24 No.2, mm.59-79 - extended four-note figuration',
                'clefs' => ['treble','bass'], 'key' => 'Bb', 'time' => '4/4', 'bar_length' => 4.0,
                'measures' => [
                    {'number' =>59,
                     'treble' => semis(['Eb4','C4','B3','C4'], ['F4','D4','C4','D4'], ['G4','Eb4','D4','Eb4'], ['F4','D4','C4','D4']),
                     'bass' =>[n(0,1,['C2','C3']), r(1,1), r(2,1), n(3,1,['G1','G2'])]},
                    {'number' =>60,
                     'treble' => semis(['Eb4','C4','B3','C4'], ['F4','D4','C4','D4'], ['G4','Eb4','D4','Eb4'], ['F4','D4','C4','D4']),
                     'bass' =>[n(0,1,['C2','C3']), r(1,1), r(2,1), n(3,1,['G1','G2'])]},
                    {'number' =>61,
                     'treble' => semis(['E4','C4','B3','C4'], ['F4','D4','C4','D4'], ['G4','E4','D4','E4'], ['Ab4','F4','Eb4','F4']),
                     'bass' =>[voices([n(0,4,'C3', tie: true)], [n(0,4,'C2', tie: true)])]},
                    {'number' =>62,
                     'treble' => semis(['Bb4','G4','F4','G4'], ['Bb4','G4','F4','G4'], ['C5','Ab4','G4','Ab4'], ['Bb4','G4','F4','G4']),
                     'bass' =>[voices([n(0,1,'C3'), n(1,1,'C3'), n(2,1,'C3'), n(3,1,'C3')], [n(0,4,'C2')])]},
                    {'number' =>63,
                     'treble' => semis(['Ab4','F4','E4','F4'], ['Bb4','G4','F4','G4'], ['C5','Ab4','G4','Ab4'], ['Bb4','G4','F4','G4']),
                     'bass' =>[n(0,1,['F2','F3']), r(1,1), r(2,1), n(3,1,['C2','C3'])]},
                    {'number' =>64,
                     'treble' => semis(['Ab4','F4','E4','F4'], ['Bb4','G4','F4','G4'], ['C5','Ab4','G4','Ab4'], ['Bb4','G4','F4','G4']),
                     'bass' =>[n(0,1,['F2','F3']), r(1,1), r(2,1), n(3,1,['C2','C3'])]},
                    {'number' =>65,
                     'treble' => semis(['Ab4','F4','E4','F4'], ['Bb4','G4','F4','G4'], ['C5','Ab4','G4','Ab4'], ['Db5','Bb4','Ab4','Bb4']),
                     'bass' =>[voices([n(0,4,'F3', tie: true)], [n(0,4,'F2', tie: true)])]},
                    {'number' =>66,
                     'treble' => semis(['Eb5','C5','B4','C5'], ['Eb5','C5','B4','C5'], ['F5','Db5','C5','Db5'], ['Eb5','C5','B4','C5']),
                     'bass' =>[voices([n(0,1,'F3'), n(1,1,'F3'), n(2,1,'F3'), n(3,1,'F3')], [n(0,4,'F2')])]},
                    {'number' =>67,
                     'treble' => semis(['Db5','Bb4','A4','Bb4'], ['Eb5','C5','B4','C5'], ['F5','Db5','C5','Db5'], ['Eb5','C5','B4','C5']),
                     'bass' =>[n(0,1,['Bb1','Bb2']), r(1,1), r(2,1), n(3,1,['F2','F3'])]},
                    {'number' =>68,
                     'treble' => semis(['Db5','Bb4','A4','Bb4'], ['Eb5','C5','B4','C5'], ['F5','Db5','C5','Db5'], ['Eb5','C5','B4','C5']),
                     'bass' =>[n(0,1,['Bb1','Bb2']), r(1,1), r(2,1), n(3,1,['F2','F3'])]},
                    {'number' =>69,
                     'treble' => semis(['Db5','Bb4','A4','Bb4'], ['Eb5','C5','B4','C5'], ['F5','Db5','C5','Db5'], ['D5','Bb4','A4','Bb4']),
                     'bass' =>[n(0,1,['Bb1','Bb2']), r(1,1), r(2,1), n(3,0.5,'Ab2', staccatissimo: true), r(3.5,0.5)]},
                    {'number' =>70,
                     'treble' =>[voices([n(0,1,'F5', slur_start: true), n(1,0.5,'Eb5', slur_end: true), r(1.5,0.5)],
                                      semis(['F5','Bb4','A4','Bb4'], ['Eb5','Bb4','A4','Bb4'], ['Eb5','Bb4','A4','Bb4'], ['Db5','Bb4','A4','Bb4']))],
                     'bass' =>[n(0,3,'Gb3', slur_start: true), n(3,0.5,'F3', staccatissimo: true, slur_end: true), r(3.5,0.5)],
                     'dynamics' =>[dyn(0,'fz')]},
                    {'number' =>71,
                     'treble' =>[voices([n(0,1,'Db5', slur_start: true), n(1,0.5,'C5', slur_end: true), r(1.5,0.5)],
                                      semis(['Db5','Bb4','A4','Bb4'], ['C5','Bb4','A4','Bb4'], ['C5','Bb4','A4','Bb4'], ['D5','Bb4','A4','Bb4']))],
                     'bass' =>[n(0,3,'Eb3', slur_start: true), n(3,0.5,'F3', staccatissimo: true, slur_end: true), r(3.5,0.5)],
                     'dynamics' =>[dyn(0,'fz')]},
                    {'number' =>72,
                     'treble' =>[voices([n(0,1,'F5', slur_start: true), n(1,0.5,'Eb5', slur_end: true), r(1.5,0.5)],
                                      semis(['F5','Bb4','A4','Bb4'], ['Eb5','Bb4','A4','Bb4'], ['Eb5','Bb4','A4','Bb4'], ['Db5','Bb4','A4','Bb4']))],
                     'bass' =>[n(0,3,'Gb3', slur_start: true), n(3,0.5,'F3', staccatissimo: true, slur_end: true), r(3.5,0.5)],
                     'dynamics' =>[dyn(0,'fz')]},
                    {'number' =>73,
                     'treble' =>[voices([n(0,1,'Db5', slur_start: true), n(1,0.5,'C5', slur_end: true), r(1.5,0.5)],
                                      semis(['Db5','Bb4','A4','Bb4'], ['C5','Bb4','A4','Bb4'], ['C5','Bb4','A4','Bb4'], ['D5','Bb4','A4','Bb4']))],
                     'bass' =>[n(0,3,'Eb3', slur_start: true), n(3,0.5,'F3', staccatissimo: true, slur_end: true), r(3.5,0.5)],
                     'dynamics' =>[dyn(0,'fz')]},
                    {'number' =>74,
                     'treble' =>[voices([n(0,1,'Db5', slur_start: true), n(1,0.5,'C5', slur_end: true), r(1.5,0.5)],
                                      semis(['Db5','Bb4','A4','Bb4'], ['C5','Bb4','A4','Bb4'], ['C5','Bb4','A4','Bb4'], ['C5','Bb4','A4','Bb4']))],
                     'bass' =>[n(0,3,'E3', slur_start: true), n(3,0.5,'E2', staccatissimo: true, slur_end: true), r(3.5,0.5)]},
                    {'number' =>75,
                     'treble' => triplet_quavers(['A4','C5','Bb4'], ['A4','Bb4','C5'], ['D5','E5','F5'], ['G5','A5','Bb5']),
                     'bass' =>[n(0,4,['F2','F3'], tie: true)]},
                    {'number' =>76,
                     'treble' => triplet_quavers(['C6','D6','E6'], ['F6','C6','A5'], ['F5','C5','A4'], ['F4','C4','A3']),
                     'bass' =>[n(0,4,['F2','F3'])]},
                    {'number' =>77,
                     'treble' => [clef('bass'), *triplet_quavers(['F3','A3','C4'], ['F4','C4','A3'], ['F3','C3','A2'], ['F2','C2','A1'])],
                     'bass' =>[r(0,4)]},
                    {'number' =>78,
                     'treble' =>[r(0,4, fermata: true)],
                     'bass' =>[n(0,4,'F1', fermata: true)]},
                ],
            },
        ],
    },
]
