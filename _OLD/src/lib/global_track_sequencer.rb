define :set_track_enabled do |track_name, enabled|
  key = :"track_enabled_#{track_name}"
  set key, (enabled ? 1 : 0)
end

define :track_enabled? do |track_name|
  key = :"track_enabled_#{track_name}"
  val = get(key)
  val.nil? ? true : val != 0
end

define :add_track_sequence do |track_name:, bar_multiple:, sequence:|
  raise "track_name must be a Symbol" unless track_name.is_a?(Symbol)
  bm = bar_multiple.to_i
  raise "bar_multiple must be >= 1" if bm < 1

  seq = Array(sequence).map do |x|
    if x.is_a?(Numeric)
      x.to_i != 0 ? 1 : 0
    else
      x == true ? 1 : 0
    end
  end
  raise "sequence must contain at least one element" if seq.empty?

  loop_name = :"track_seq_#{track_name}"

  set_track_enabled(track_name, seq.first == 1)
  set :"#{loop_name}_idx", 0
  set :"#{loop_name}_bars", 0

  live_loop loop_name do
    sync :global_bar

    next unless get(:global_start) == 1

    bars = (get(:"#{loop_name}_bars") || 0) + 1
    set :"#{loop_name}_bars", bars

    if (bars % bm).zero?
      idx = (get(:"#{loop_name}_idx") || 0)
      idx = (idx + 1) % seq.length
      set :"#{loop_name}_idx", idx
      set :"#{loop_name}_bars", 0

      set_track_enabled(track_name, seq[idx] == 1)
    end
  end

  loop_name
end
