# frozen_string_literal: true

set :arrangement_section_bars, 8

def arrangement_parts
  {
    slice: [1, 1, 1, 0],
    sub: [0, 1, 1, 1],
    reese: [0, 0, 1, 1],
    chords: [1, 0, 1, 1]
  }
end

def arrangement_bar (look)
  look / get(:global_bar_ticks)
end

def arrangement_section (look)
  arrangement_bar(look) / get(:arrangement_section_bars)
end

def arrangement_playing? (part, look)
  arrangement_parts[part].ring[arrangement_section(look)] == 1
end

def arrangement_halftime? (look)
  [0, 1, 0, 0].ring[arrangement_section(look)] == 1
end

def arrangement_fill? (look)
  arrangement_bar(look) % get(:arrangement_section_bars) == get(:arrangement_section_bars) - 1
end
