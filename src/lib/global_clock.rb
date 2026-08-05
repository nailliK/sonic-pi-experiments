# frozen_string_literal: true

set :global_bpm, :link
set :global_pulse, 4.0
set :global_bar_ticks, 16

link
use_bpm get(:global_bpm)

set :global_look, 0

live_loop :transport_watch do
  set :global_start, (@link_api.link_is_playing? ? 1 : 0)

  sleep 4
end

live_loop :transport_start do
  use_real_time
  sync "/link/start"

  set :global_start, 1

  puts "START"
  cue :global_start_queue
end

live_loop :transport_stop do
  use_real_time
  sync "/link/stop"

  set :global_start, 0

  puts "STOP"
  cue :global_stop_queue
end

live_loop :global_clock do
  use_real_time

  if get(:global_start) == 1
    cue :global_tick
    set :global_look, get(:global_look) + 1
  end

  sleep 1.0 / get(:global_pulse)
end
