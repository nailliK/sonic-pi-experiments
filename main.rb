# frozen_string_literal: true
set :dir_root, "/Users/killian/Sites/Live Coding/Sonic Pi Experiments/src"
set :resource_root, "/Users/killian/Documents/Music Resources/"
eval_file "#{get(:dir_root)}/lib/global_clock.rb"

set :base_slice_note, 36
set :break_slice_length, 32
set :playable_slices, 16
set :pitch_bend_range, 12
set :midi_port, "iac_driver_bus_1"

use_midi_defaults port: get(:midi_port), channel: 1

def retrig(note_val, step, retrig_num, gate)
  with_bpm current_bpm do
    time_warp 0 do
      retrig_num.times do
        midi note_val, sustain: step * gate / retrig_num
        sleep step.to_f / retrig_num
      end
    end
  end
end

def reverse(note_val, step, gate)
  base = get(:base_slice_note)
  slice = note_val - base
  midi (base + get(:break_slice_length) - 1 - slice), sustain: step * gate, channel: 2
end

def pitch_retrig(note_val, step, retrig_num, gate, semitones)
  bend_range = get(:pitch_bend_range)

  with_bpm current_bpm do
    time_warp 0 do
      retrig_num.times do |n|
        shift = retrig_num > 1 ? semitones * n / (retrig_num - 1.0) : 0
        midi_pitch_bend 0.5 + (shift / (2.0 * bend_range))
        midi note_val, sustain: step * gate / retrig_num
        sleep step.to_f / retrig_num
      end
      midi_pitch_bend 0.5
    end
  end
end

def random_note(note_val, step, gate, range)
  base = get(:base_slice_note)
  slice = (note_val - base + rrand_i(-range, range)).min(0).max(get(:playable_slices) - 1)

  midi base + slice, sustain: step * gate
end

def execute_fx(note_val, step, gate = 1)
  case dice(4)
  when 1
    retrig note_val, step, choose([2, 3, 4]), gate
  when 2
    reverse note_val, step, gate
  when 3
    pitch_retrig note_val, step, choose([2, 3, 4]), gate, choose([-12, -7, 5, 7, 12])
  when 4
    random_note note_val, step, gate, choose([2, 3, 5])
  else
    # No-op
  end
end

live_loop :slices do
  step = 0.5
  steps = 8
  fx_chance = 0.50

  if get(:global_start) == 1
    use_random_seed get(:global_seed)

    steps.times do |i|
      slices = (ring 0, 1, choose([2, 7]), 0, 1, choose([2, 7]), 1, 2)
      note_val = get(:base_slice_note) + slices[i]
      gate = choose([0.75, 0.85])

      if rrand(0, 1) < fx_chance
        execute_fx note_val, step, gate
      else
        midi note_val, sustain: step * gate
      end

      sleep step
    end
  else
    sleep step
  end
end

define :gen_acid do |seed, opts = {}|
  o = { steps: 16, root: 48, density: 0.65, acc: 0.25, slide: 0.3 }.merge(opts)
  use_random_seed seed

  tones = scale(o[:root], :chromatic).to_a.drop(1)
  pool = [o[:root]] * 7 + # root dominates
         [o[:root] + 12] * 3 + # octave jumps
         [o[:root] + 1] + # b2, the acid flavor
         tones + tones.map { |n| n + 12 }

  pat = o[:steps].times.map { |i| (i.zero? || rand < o[:density]) ? pool.choose : nil }
  acc = pat.map { |n| (n && rand < o[:acc]) ? 1 : 0 }
  sld = pat.each_cons(2).map { |a, b| (a && b && rand < o[:slide]) ? 1 : 0 } + [0]

  [pat.ring, acc.ring, sld.ring]
end

set :seed, 555
live_loop :acid do
  # stop
  pat, acc, sld = gen_acid(get(:seed))

  pat.length.times do |i|
    if get(:global_start) == 1
      n = pat[i]
      midi n,
           vel: (acc[i] == 1 ? 120 : 70),
           channel: 3,
           sustain: (sld[i] == 1 ? 0.28 : 0.20) unless n.nil?
    end

    sleep 1.0 / get(:global_lines_per_beat)
  end
end

live_loop :cutoff, sync: :acid do
  midi_cc 74, (0 + 127 * (Math.sin(vt / 8.0) ** 2)).to_i, channel: 3
  sleep 1.0 / get(:global_lines_per_beat)
end
