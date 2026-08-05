# frozen_string_literal: true

set :chords_port, "iac_driver_bus_1"
set :chords_channel, 4
set :chords_bars, 8
set :chords_size, 8
set :chords_degrees, [2, 5, 7, 11].shuffle.ring
set :chords_fill_sustain, 2.0

def chords_play (degree, sustain)
  chord_degree(degree, get(:global_root_note), get(:global_scale), rand_i(3) + 3).each do |note|
    midi note, sustain: sustain, port: get(:chords_port), channel: get(:chords_channel)
  end
end

live_loop :chords do
  sync :global_tick

  look = get(:global_look)
  every = get(:global_bar_ticks) * get(:chords_bars)

  next unless (look % get(:global_bar_ticks)).zero?
  next unless arrangement_playing? :chords, look

  if get(:global_start) == 1
    if (look % every).zero?
      chords_play get(:chords_degrees)[look / every], every / get(:global_pulse)
    elsif arrangement_fill?(look)
      chords_play get(:chords_degrees)[(look / every) + 1], get(:chords_fill_sustain)
    end
  end
end
