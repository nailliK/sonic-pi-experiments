# frozen_string_literal: true

use_debug false
use_cue_logging false
use_midi_logging false

set :dir_root, "/Users/killian/Sites/Live Coding/Sonic Pi/src"
set :resource_root, "/Users/killian/Documents/Music Resources"

set :global_root_note, :e2
set :global_scale, :lydian

eval_file "#{get(:dir_root)}/lib/global_clock.rb"
eval_file "#{get(:dir_root)}/lib/arrangement.rb"
eval_file "#{get(:dir_root)}/lib/midi_instruments/simpler_slices.rb"
eval_file "#{get(:dir_root)}/lib/midi_instruments/poly_chords.rb"
eval_file "#{get(:dir_root)}/lib/midi_instruments/jungle_bass.rb"
