# frozen_string_literal: true

set :arrangement_step_bars, 8
set :arrangement_offset, 0

define :register_track do |name, pattern|
  set :"track_#{name}", pattern.delete(" ").chars.ring
  set :track_names, ((get(:track_names) || []) + [name]).uniq
end

define :arrangement_step do
  elapsed = link_bar - get(:song_origin_bar).to_i
  elapsed / get(:arrangement_step_bars) + get(:arrangement_offset).to_i
end

define :playing? do |name|
  next false unless get(:global_start) == 1

  row = get(:"track_#{name}")
  row.nil? || row[arrangement_step] == "#"
end

live_loop :arrangement, auto_cue: false do
  tracks = (get(:track_names) || []).map { |n| "#{n}=#{playing?(n)}" }.join(" ")
  emit :step, step: arrangement_step, tracks: tracks
  sleep get(:global_quantum)
end
