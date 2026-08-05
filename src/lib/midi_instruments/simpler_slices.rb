# frozen_string_literal: true

set :slice_port, "iac_driver_bus_1"
set :slice_channel, 10
set :slice_root, 36
set :slice_total, 32
set :slice_effect_chance, 0.15
set :slice_fill_chance, 0.75
set :slice_retrigs, [2, 3, 4, 6, 8]
set :slice_fill_retrigs, [6, 8, 12, 16]
set :slice_sustain, 2.0 / get(:global_pulse)
set :slice_ghost_chance, 0.25
set :slice_ghost_velocity, 0.25

def slice_retrig (slice, num_retrigs, sustain, channel)
  step = sustain / num_retrigs

  num_retrigs.times do
    midi get(:slice_root) + slice, sustain: step, port: get(:slice_port), channel: channel
    sleep step
  end
end

def slice_bend (slice, num_retrigs, sustain, channel, direction)
  step = sustain / num_retrigs

  num_retrigs.times do |i|
    midi_pitch_bend 0.5 + (direction * 0.5 * i / (num_retrigs - 1)), port: get(:slice_port), channel: channel
    midi get(:slice_root) + slice, sustain: step, port: get(:slice_port), channel: channel
    sleep step
  end

  midi_pitch_bend 0.5, port: get(:slice_port), channel: channel
end

def slice_velocity (slice, num_retrigs, sustain, channel, direction)
  step = sustain / num_retrigs

  num_retrigs.times do |i|
    midi get(:slice_root) + slice, sustain: step, vel_f: 0.5 + (direction * 0.5 * i / (num_retrigs - 1)), port: get(:slice_port), channel: channel
    sleep step
  end
end

def slice_pattern
  [0, 1, [2, 7].choose, 0, 1, [2, 7].choose, 1, 2].ring
end

def slice_ghost (slice)
  midi get(:slice_root) + slice, sustain: get(:slice_sustain) / 2, vel_f: get(:slice_ghost_velocity), port: get(:slice_port), channel: get(:slice_channel)
end

def slice_reverse (slice, sustain, channel)
  midi get(:slice_root) + get(:slice_total) - slice, sustain: sustain, port: get(:slice_port), channel: channel
end

def slice_effect (slice, sustain)
  index = dice(6)

  slice_reverse slice, sustain, get(:slice_channel) + 1 if index == 1
  slice_retrig slice, get(:slice_retrigs).choose, sustain, get(:slice_channel) if index == 2
  slice_bend slice, get(:slice_retrigs).choose, sustain, get(:slice_channel), 1 if index == 3
  slice_bend slice, get(:slice_retrigs).choose, sustain, get(:slice_channel), -1 if index == 4
  slice_velocity slice, get(:slice_retrigs).choose, sustain, get(:slice_channel), 1 if index == 5
  slice_velocity slice, get(:slice_retrigs).choose, sustain, get(:slice_channel), -1 if index == 6
end

def slice_fill (slice, sustain)
  index = dice(3)

  slice_retrig slice, get(:slice_fill_retrigs).choose, sustain, get(:slice_channel) if index == 1
  slice_bend slice, get(:slice_fill_retrigs).choose, sustain, get(:slice_channel), -1 if index == 2
  slice_velocity slice, get(:slice_fill_retrigs).choose, sustain, get(:slice_channel), 1 if index == 3
end

live_loop :slice do
  sync :global_tick

  look = get(:global_look)
  next unless get(:global_start) == 1
  next unless arrangement_playing? :slice, look

  step = arrangement_halftime?(look) ? 4 : 2
  slice = slice_pattern[look / step]

  if look.odd?
    slice_ghost slice if rrand(0, 1) < get(:slice_ghost_chance)
    next
  end

  next unless (look % step).zero?

  sustain = get(:slice_sustain) * step / 2
  fill = arrangement_fill? look
  chance = fill ? get(:slice_fill_chance) : get(:slice_effect_chance)

  if rrand(0, 1) < chance
    fill ? slice_fill(slice, sustain) : slice_effect(slice, sustain)
  else
    midi get(:slice_root) + slice, sustain: sustain, port: get(:slice_port), channel: get(:slice_channel)
  end
end
