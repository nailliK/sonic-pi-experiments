# frozen_string_literal: true

set :bass_port, "iac_driver_bus_1"
set :sub_channel, 5
set :reese_channel, 6
set :sub_octave, -12
set :reese_octave, 0
set :bass_sustain, 0.9
set :bass_degrees, [1, 4, 5, 3, 6, 7, 9, 3].ring
set :bass_cell, [3, 4, 1]
set :bass_fill_cell, [1, 1, 2]

def bass_note (bar, octave)
  chord_degree(get(:bass_degrees)[bar], get(:global_root_note), get(:global_scale), 1)[0] + octave
end

def sub_play (note, span)
  beats = span / get(:global_pulse)

  midi note, sustain: beats * get(:bass_sustain), port: get(:bass_port), channel: get(:sub_channel)
end

def reese_play (note, cell, span)
  (span / cell.sum).times do
    cell.each do |length|
      beats = length / get(:global_pulse)

      midi note, sustain: beats * get(:bass_sustain), port: get(:bass_port), channel: get(:reese_channel)
      sleep beats
    end
  end
end

live_loop :sub do
  sync :global_tick

  look = get(:global_look)
  span = get(:global_bar_ticks)

  next unless (look % span).zero?
  next unless get(:global_start) == 1
  next unless arrangement_playing? :sub, look

  sub_play bass_note(arrangement_bar(look), get(:sub_octave)), span
end

live_loop :reese do
  sync :global_tick

  look = get(:global_look)
  span = get(:global_bar_ticks)

  next unless (look % span).zero?
  next unless get(:global_start) == 1
  next unless arrangement_playing? :reese, look

  cell = arrangement_fill?(look) ? get(:bass_fill_cell) : get(:bass_cell)

  reese_play bass_note(arrangement_bar(look), get(:reese_octave)), cell, span
end
