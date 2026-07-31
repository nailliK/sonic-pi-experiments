# frozen_string_literal: true

# Melody generator using a Brownian (random walk) approach over a given scale.
# Public API mirrors acid303_start to keep options and structure consistent,
# but this generator has no slides and uses a consistent note length.
#
# Options:
# - midi_port: MIDI port name or nil
# - midi_channel: Integer MIDI channel
# - loop_name: Symbol for the live_loop name
# - steps: Integer number of steps in the repeating pattern (default 16)
# - density: Integer 0..16 controlling both gate density and motion tendency (default 12)
# - scale_root: MIDI note number or 0-based scale degree root (default 60)
# - scale_name: Symbol Sonic Pi scale (e.g., :dorian)
# - regen_every_bars: nil or integer - if set, rebuilds the pattern every N bars with a fresh seed
# - seed: optional integer for deterministic generation; nil to auto-reseed on start
# - bpm_mult: float multiplier applied to step length (>1 slower, <1 faster; default 1.0)

# --- Helpers ------------------------------------------------

define :mb_rand_bit do |prob_percent|
  rand < (prob_percent.to_f / 100.0)
end

define :mb_update_mask do |mask, step, state|
  if state
    mask | (1 << step)
  else
    mask & ~(1 << step)
  end
end

define :mb_mask_on? do |mask, step|
  (mask & (1 << step)) != 0
end

# Seed control: refresh the random stream while allowing reproducible seeds.
define :mb_reseed do |seed = nil|
  if seed
    use_random_seed seed
  else
    salt = (get(:mb_entropy) || 0) + 1
    set :mb_entropy, salt
    use_random_seed ((Time.now.to_i + salt) & 0x7fffffff)
  end
end

# Build a Brownian pattern: notes + gate mask (+ optional octave up/down like acid303)
# Notes are selected by a bounded random walk over the scale degrees.
# The walk step per time is mostly +/- 1 with occasional 0, and reflects at boundaries.
# Density influences both the fraction of gates on and the tendency to move vs. stay.
define :melody_brownian_build_pattern do |steps:, density:, scale_root:, scale_name:|
  deg_per_oct = (scale scale_root, scale_name, num_octaves: 1).length
  scale_arr = (scale scale_root, scale_name, num_octaves: 6)
  max_idx = scale_arr.length - 1

  # Motion tendency: lower density -> more staying, higher density -> more movement
  dens = [[density.to_i, 0].max, 16].min
  move_prob = 0.3 + (dens / 16.0) * 0.6 # 0.3..0.9
  zero_step_prob = 1.0 - move_prob # chance to stay

  # Initialize near the middle for better exploration
  cur_idx = (max_idx / 2.0).round

  notes = Array.new(steps, 0)
  steps.times do |s|
    # Decide step: -1, 0, or +1 with reflection at edges
    r = rand
    step_delta = 0
    if r < zero_step_prob
      step_delta = 0
    else
      step_delta = rand < 0.5 ? -1 : +1
    end

    cur_idx += step_delta
    # Reflect at boundaries to keep walk within range
    if cur_idx < 0
      cur_idx = 1
    elsif cur_idx > max_idx
      cur_idx = max_idx - 1
    end

    notes[s] = cur_idx
  end

  # Gate density similar to acid303: convert density to gate probability
  on_off_density = (dens - 7).abs
  gate_prob = 10 + on_off_density * 14 # %

  gates = 0
  oct_ups = 0
  oct_dns = 0

  steps.times do |i|
    gate_on = mb_rand_bit(gate_prob)
    gates = mb_update_mask(gates, i, gate_on)

    # Keep occasional octave transpositions like acid303 for variation
    up_on = gate_on && rand < 0.06
    dn_on = gate_on && !up_on && rand < 0.06
    oct_ups = mb_update_mask(oct_ups, i, up_on)
    oct_dns = mb_update_mask(oct_dns, i, dn_on)
  end

  {
    steps: steps,
    notes: notes,
    gates: gates,
    oct_ups: oct_ups,
    oct_dns: oct_dns,
    scale_arr: scale_arr,
    deg_per_oct: deg_per_oct
  }
end

define :melody_brownian_note_for_step do |pattern, step|
  idx = pattern[:notes][step]
  idx += pattern[:deg_per_oct] if mb_mask_on?(pattern[:oct_ups], step)
  idx -= pattern[:deg_per_oct] if mb_mask_on?(pattern[:oct_dns], step)
  idx = [[idx, 0].max, pattern[:scale_arr].length - 1].min
  pattern[:scale_arr][idx]
end

# --- Public entry ------------------------------------------------
# Signature mirrors acid303_start, but with no slides and a consistent note length.
# - regen_every_bars: nil or integer
# - seed: optional integer for reproducibility; nil => new random seed
# - bpm_mult: float multiplier applied to step length (>1 slower, <1 faster; default 1.0)

define :melody_brownian_start do |midi_port, midi_channel, loop_name = :melody_brownian, steps = 16, density = 12, scale_root = 60, scale_name = :dorian, bpm_mult = 1.0, regen_every_bars = nil, seed = nil|
  # Initialize random stream
  mb_reseed seed

  pattern = melody_brownian_build_pattern(
    steps: steps,
    density: density,
    scale_root: scale_root,
    scale_name: scale_name
  )

  i = 0
  accum = 0.0

  live_loop loop_name do
    sync :global_tick

    # Optional regeneration on bar boundary with a fresh seed each time
    if regen_every_bars
      in_thread do
        sync :global_bar
        set :"#{loop_name}_bars", (get(:"#{loop_name}_bars") || 0) + 1
        if (get(:"#{loop_name}_bars") % regen_every_bars).zero?
          mb_reseed
          pattern = melody_brownian_build_pattern(
            steps: steps,
            density: density,
            scale_root: scale_root,
            scale_name: scale_name
          )
        end
      end
    end

    # Determine base timing from global lines and adjust for multiplier (multiplies step length)
    lines = get(:global_lines_per_beat) || 4.0
    base_step_len = 1.0 / lines

    safe_mult = (bpm_mult || 1.0).to_f
    safe_mult = 0.0001 if safe_mult <= 0 # avoid zero/negatives

    # Accumulate based on inverse of multiplier: >1 => slower (fewer steps), <1 => faster (more steps)
    accum += 1.0 / safe_mult

    while accum >= 1.0
      step = i % pattern[:steps]

      # Sub-step duration scales with multiplier: >1 slows down (longer), <1 speeds up (shorter)
      sub_step_len = base_step_len * safe_mult

      if track_enabled?(loop_name) && mb_mask_on?(pattern[:gates], step)
        note = melody_brownian_note_for_step(pattern, step)

        # Consistent note length, no slides or accents
        sustain = sub_step_len * 0.8
        velocity = 90

        midi_opts = { channel: midi_channel }
        midi_opts[:port] = midi_port if midi_port

        midi note, **midi_opts, sustain: sustain, velocity: velocity
      end

      i += 1
      accum -= 1.0

      # If more sub-steps remain within this global tick window, space them evenly
      if accum >= 1.0
        sleep sub_step_len
      end
    end
  end

  loop_name
end
