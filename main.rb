# frozen_string_literal: true

set :dir_root, "/Users/killian/Sites/Live Coding/Sonic Pi/src"
set :resource_root, "/Users/killian/Documents/Music Resources/"
eval_file "#{get(:dir_root)}/lib/global_clock.rb"
eval_file "#{get(:dir_root)}/lib/arrangement.rb"

set :base_slice_note, 36
set :break_slice_length, 32
set :playable_slices, 16
set :pitch_bend_range, 12

set :midi_port, "iac_driver_bus_1"
set :root_note, :e3
set :root_scale, :lydian

set :slice_channel, 1
set :slice_reverse_channel, 2
set :acid_channel, 3
set :chord_channel, 4

set :fx_primary, [:retrig, :reverse, :pitch_retrig, :random_note]
set :fx_secondary, [:retrig, :pitch_retrig]
set :fx_chance, 0.15

register_track :slices,
               ".###.###.###.###"
register_track :acid,
               "..####....####.."
register_track :chords,
               "################"

use_midi_defaults port: get(:midi_port), channel: 1

def retrig(note_val, step, retrig_num, gate, channel:)
  with_bpm current_bpm do
    time_warp 0 do
      retrig_num.times do
        midi note_val, sustain: gate / step.to_f / retrig_num, channel: channel
        sleep 1.0 / step.to_f / retrig_num
      end
    end
  end
end

def reverse(note_val, step, gate, channel: get(:slice_reverse_channel))
  base = get(:base_slice_note)
  slice = note_val - base
  midi (base + get(:break_slice_length) - 1 - slice), sustain: 1 / step * gate, channel: channel
end

def pitch_retrig(note_val, step, retrig_num, gate, semitones, channel:)
  bend_range = get(:pitch_bend_range)

  with_bpm current_bpm do
    time_warp 0 do
      retrig_num.times do |n|
        shift = retrig_num > 1 ? semitones * n / (retrig_num - 1.0) : 0
        midi_pitch_bend 0.5 + (shift / (2.0 * bend_range)), channel: channel
        midi note_val, sustain: gate / step.to_f / retrig_num, channel: channel
        sleep 1.0 / step.to_f / retrig_num
      end
      midi_pitch_bend 0.5, channel: channel
    end
  end
end

def random_note(note_val, step, gate, range, channel:)
  base = get(:base_slice_note)
  slice = (note_val - base + rrand_i(-range, range)).min(0).max(get(:playable_slices) - 1)

  midi base + slice, sustain: step * gate, channel: channel
end

def execute_fx(note_val, step, gate = 1, channel:, pool:)
  retrig_range = [2, 3, 4, 6, 8]
  kind = choose(pool)

  case kind
  when :retrig
    n = choose(retrig_range)
    emit kind, note: note_val, ch: channel, n: n, gate: gate
    retrig note_val, step, n, gate, channel: channel
  when :reverse
    emit kind, note: note_val, ch: get(:slice_reverse_channel), gate: gate
    reverse note_val, step, gate
  when :pitch_retrig
    n = choose(retrig_range)
    semitones = choose([-12, -7, 5, 7, 12])
    emit kind, note: note_val, ch: channel, n: n, bend: semitones, gate: gate
    pitch_retrig note_val, step, n, gate, semitones, channel: channel
  when :random_note
    amount = choose([2, 3, 5])
    emit kind, note: note_val, ch: channel, amount: amount, gate: gate
    random_note note_val, step, gate, amount, channel: channel
  else
    # No-op
  end
end

live_loop :slices do
  steps = 8
  cycle = steps / get(:global_lines_per_beat)

  await_start

  use_random_seed get(:global_seed)

  steps.times do |i|
    slices = (ring 0, 1, choose([2, 7, 7, 7]), 0, 1, choose([2, 7, 7, 7]), 1, 2)
    note_val = get(:base_slice_note) + slices[i]
    gate = choose([0.75, 0.85])
    fire_fx = rrand(0, 1) < get(:fx_chance)

    if playing?(:slices)
      if fire_fx
        execute_fx note_val, get(:global_lines_per_beat), gate, channel: get(:slice_channel), pool: get(:fx_primary)
      else
        midi note_val, sustain: get(:global_lines_per_beat) * gate
      end
    end

    sleep 1.0 / get(:global_lines_per_beat)
  end
end

define :gen_acid do |seed, opts = {}|
  o = { steps: 16, density: 0.65, acc: 0.25, slide: 0.3,
        root: note(get(:root_note)), scale: get(:root_scale) }.merge(opts)

  use_random_seed seed

  tones = scale(o[:root], o[:scale]).to_a.drop(1)

  pool = [o[:root]] * 7 + # root dominates
         [o[:root] + 12] * 3 + # octave jumps
         [o[:root] + 1] + # acid flavor
         tones + tones.map { |n| n + 12 }

  pat = o[:steps].times.map { |i| (i.zero? || rand < o[:density]) ? pool.choose : nil }
  acc = pat.map { |n| (n && rand < o[:acc]) ? 1 : 0 }
  sld = pat.each_cons(2).map { |a, b| (a && b && rand < o[:slide]) ? 1 : 0 } + [0]

  [pat.ring, acc.ring, sld.ring]
end

live_loop :acid do
  steps = 16
  cycle = steps / get(:global_lines_per_beat)

  await_start

  seed = (ring 555, 555, 555, 777)[link_cycle(cycle)]
  pat, acc, sld = gen_acid(seed, steps: steps)

  pat.length.times do |i|
    n = pat[i]

    if playing?(:acid) && !n.nil?
      gate = sld[i] == 1 ? 0.66 : 0.33

      if rrand(0, 1) < get(:fx_chance)
        execute_fx n, get(:global_lines_per_beat), gate, channel: get(:acid_channel), pool: get(:fx_secondary)
      else
        midi n, vel: (acc[i] == 1 ? 120 : 70), channel: get(:acid_channel), sustain: gate
      end
    end

    sleep 1.0 / get(:global_lines_per_beat)
  end
end

live_loop :cutoff, sync: :acid do
  if playing?(:acid)
    midi_cc 74, (0 + 127 * (Math.sin(vt / 16.0) ** 2)).to_i, channel: get(:acid_channel)
  end
  sleep 1.0 / get(:global_lines_per_beat)
end

root = note(get(:root_note))
prog = (ring [root, :major7], [root + 5, :minor7], [root + 7, :major7], [root + 9, :minor7])

live_loop :chords do
  cycle = 16

  await_start

  root, qual = prog[link_cycle(cycle)]
  note_vals = [0, 3, 5, 7]
  notes = chord_invert(chord(root, qual), note_vals.choose)
  offset = 0.02
  stagger = notes.length * offset

  notes.each do |n|
    fire_fx = rrand(0, 1) < get(:fx_chance)
    vel = rrand_i(56, 76)

    if playing?(:chords)
      if fire_fx
        execute_fx n, get(:global_lines_per_beat), 0.8, channel: get(:chord_channel), pool: get(:fx_secondary)
      else
        midi n, vel: vel, sustain: 8, channel: get(:chord_channel)
      end
    end

    sleep offset
  end

  sleep cycle - stagger
end
