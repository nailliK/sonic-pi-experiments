# frozen_string_literal: true

set :global_bpm, :link
set :global_quantum, 4
set :global_lines_per_beat, 4.0
set :global_start, 0 if get(:global_start).nil?
set :global_seed, 666 if get(:global_seed).nil?

eval_file "#{get(:dir_root)}/lib/log.rb"

use_cue_logging false

link_sync get(:global_quantum)
set :global_start, 1

define :global_look do
  (beat * get(:global_lines_per_beat)).floor
end

define :link_cycle do |cycle_beats|
  global_look / (cycle_beats * get(:global_lines_per_beat)).to_i
end

define :link_bar do
  link_cycle(get(:global_quantum))
end

define :await_start do
  next unless get(:global_start) == 0

  sync :global_started
  link get(:global_quantum)
end

set :song_origin_bar, link_bar

live_loop :transport_start do
  use_real_time
  sync "/link/start"
  set :global_start, 1
  set :song_origin_bar, link_bar
  cue :global_started
  emit :start, bpm: current_bpm.round(2), bar: link_bar
end

live_loop :transport_stop do
  use_real_time
  sync "/link/stop"
  set :global_start, 0
  cue :global_stopped
  emit :stop, bar: link_bar
end

live_loop :heartbeat, auto_cue: false do
  emit :tick,
       look: global_look,
       bar: link_bar,
       beat: beat.round(3),
       bpm: current_bpm.round(2),
       start: get(:global_start)
  sleep 1.0 / get(:global_lines_per_beat)
end

live_loop :randomization, auto_cue: false do
  set :global_seed, rand_i(441000)

  # new seed after bar
  sleep 1.0 / get(:global_lines_per_beat)
end
