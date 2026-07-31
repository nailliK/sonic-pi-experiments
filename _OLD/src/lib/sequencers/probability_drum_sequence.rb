# frozen_string_literal: true

KEY_TO_NOTE = {
  BD: 36, SD: 38, RS: 37, CP: 39,
  CH: 42, OH: 46, CY: 49, CB: 56,
  HT: 50, MT: 47, LT: 45,
}.freeze

KEY_TO_CHANNEL = {
  BD: 1, SD: 2, RS: 3, CP: 4,
  CH: 5, OH: 6, CY: 7, HT: 8,
  MT: 9, LT: 10, CB: 11,
}.freeze

# Reads JSON and normalizes into an array of pattern hashes with symbol keys.
define :probability_drum_load_patterns do |path|
  data = JSON.parse(File.read(path))
  arr =
    if data.is_a?(Hash) && data.key?("pattern")
      data["pattern"]
    elsif data.is_a?(Array)
      data
    else
      raise "Unsupported JSON structure (expected Hash with 'pattern' key or Array): #{path}"
    end

  arr.map { |pattern| pattern.transform_keys { |k| k.to_sym } }
end

# Converts N patterns into probability per step per instrument.
define :probability_drum_build_probability do |patterns|
  out = {}

  patterns.each do |pattern|
    pattern.each do |key, steps|
      steps = Array(steps)
      out[key.to_sym] ||= Array.new(steps.length, 0.0)
      steps.each_with_index { |v, idx| out[key.to_sym][idx] += v.to_f }
    end
  end

  denom = patterns.length.nonzero? || 1
  out.transform_values { |vals| vals.map { |x| x / denom } }
end

# Public entry: loads JSON, builds probabilities, and runs the live loop on the global clock.
# json_path: String path to the JSON file
# midi_port: MIDI output port name
# loop_name: Symbol live_loop name (default :probability_drum_loop)
define :probability_drum_start do |json_path, midi_port, loop_name = :probability_drum_loop|
  patterns = probability_drum_load_patterns(json_path)
  prob_seq = probability_drum_build_probability(patterns)

  # Step index captured by the live_loop closure
  i = 0

  live_loop loop_name do
    # Advance only when the global clock ticks
    sync :global_tick

    # Honor global track enable/disable
    if track_enabled?(loop_name)
      prob_seq.each do |key, probs|
        next if probs.nil? || probs.empty?

        idx = i % probs.length
        if rand < probs[idx]
          note = KEY_TO_NOTE[key.to_sym]
          chan = KEY_TO_CHANNEL[key.to_sym]
          midi note, port: midi_port, channel: chan, sustain: 0.125 if note && chan
        end
      end
    end

    i += 1
  end

  loop_name
end
