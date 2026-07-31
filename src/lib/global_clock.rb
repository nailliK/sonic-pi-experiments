# frozen_string_literal: true

# Globals
set :global_bpm, :link
set :global_lines_per_beat, 4.0 if get(:global_lines_per_beat).nil?
set :global_look, 0 if get(:global_look).nil?
set :global_start, 0 if get(:global_start).nil?
set :global_seed, 666 if get(:global_seed).nil?

# Enable Ableton Link and follow its BPM
use_bpm get(:global_bpm)
use_cue_logging false

link_sync
set :global_start, 1

# Listen to Link start/stop directly
live_loop :transport_start do
  use_real_time
  sync "/link/start"
  set :global_start, 1
  set :global_look, 0
  cue :global_started
  puts "Global transport: START"
end

live_loop :transport_stop do
  use_real_time
  sync "/link/stop"
  set :global_start, 0
  cue :global_stopped
  puts "Global transport: STOP"
end

# Global clock: ticks only when running (beat-based sleeps, aligned to Link BPM)
live_loop :global_clock, auto_cue: false do
  use_bpm get(:global_bpm)
  lines = (get(:global_lines_per_beat) || 4).to_i

  if get(:global_start) == 1
    set :global_look, (get(:global_look) || 0) + 1
    cue :global_tick

    # Optional: bar cue every 4 beats (4 * lines subdivisions)
    total_subdiv_per_bar = lines * 4
    if (get(:global_look) % total_subdiv_per_bar).zero?
      cue :global_bar
    end

    # Sleep in beats to stay phase-locked to Link tempo
    sleep 1.0 / lines
  else
    # Idle while stopped (light polling)
    sleep 0.125
  end
end

live_loop :randomization, auto_cue: false do
  set :global_seed, rand_i(441000)

  # new seed after bar
  sleep 1.0 * get(:global_lines_per_beat)
end
