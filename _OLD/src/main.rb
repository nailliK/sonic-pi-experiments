# frozen_string_literal: true

set :dir_root, "/Users/killian/Sites/Sonic Pi Experiments/src/"
set :resource_root, "/Users/killian/Documents/Music Resources/"

# Import global clock; synced by Ableton Link
eval_file "#{get(:dir_root)}/lib/global_clock.rb"
eval_file "#{get(:dir_root)}/lib/global_track_sequencer.rb"
eval_file "#{get(:dir_root)}/lib/sequencers/probability_drum_sequence.rb"
eval_file "#{get(:dir_root)}/lib/sequencers/303.rb"
eval_file "#{get(:dir_root)}/lib/sequencers/melody_brownian.rb"

# Define drums and melodies
probability_drum_start(
  # "#{get(:resource_root)}/MIDI/Packs/SLIME/Breaks/Tritonic Groover.json",
  "#{get(:resource_root)}/MIDI/Packs/SLIME/Breaks/Drum&Bass Groove 2.json",
  "iac_driver_bus_1",
  :pd_1
)

acid303_start(
  "iac_driver_bus_2", 1, :ac_1, 16, 8, 12, :phrygian
)

melody_brownian_start(
  "iac_driver_bus_2", 2, :mb_1, 16, 12, 24, :phrygian, 16, nil, nil
)

melody_brownian_start(
  "iac_driver_bus_2", 3, :mb_12, 16, 16, 24, :phrygian, 64, nil, nil
)

# Define track sequences

tracks = {
  pd_1: [1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0],
  mb_1: [0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0],
  mb_2: [0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0],
  ac_1: [0, 0, 0, 0, 1, 1, 1, 1, 0, 0, 0, 0, 1, 1, 1, 1, 0],
}

add_track_sequence(
  track_name: :pd_1,
  bar_multiple: 16,
  sequence: tracks[:pd_1]
)

add_track_sequence(
  track_name: :ac_1,
  bar_multiple: 16,
  sequence: tracks[:ac_1]
)

add_track_sequence(
  track_name: :mb_1,
  bar_multiple: 16,
  sequence: tracks[:mb_1]
)

add_track_sequence(
  track_name: :mb_2,
  bar_multiple: 16,
  sequence: tracks[:mb_2]
)
