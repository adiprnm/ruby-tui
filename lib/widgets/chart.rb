# frozen_string_literal: true
#
# Widgets -- charts: a vertical bar chart and a sparkline.
#
# Reopens the Widgets namespace from lib/widgets.rb; the public API is
# always Widgets.<name>(frame, ...).

require_relative '../term'
require_relative '../theme'

module Widgets
  class << self
    def bars(f, x, y, w, h, values, grid: true)
      return if w < 1 || h < 1

      # faint dotted gridlines at 25 / 50 / 75 %
      if grid
        [0.25, 0.5, 0.75].each do |g|
          gy = y + h - 1 - (g * (h - 1)).round
          f.hline(x, gy, w, DOT, :grid)
        end
      end

      values = values.last(w)
      offset = w - values.length

      values.each_with_index do |v, i|
        v = v.clamp(0.0, 1.0)
        eighths = (v * h * 8).round
        next if eighths.zero?

        colour = Style.ramp(v)
        0.upto(h - 1) do |r|
          spent = r * 8
          e = eighths - spent
          next if e <= 0
          e = 8 if e > 8
          f.put(x + offset + i, y + h - 1 - r, BLOCKS[e], colour)
        end
      end
      self
    end

    # One-row sparkline of the last `w` values.
    def sparkline(f, x, y, w, values, style = :accent)
      values = values.last(w)
      offset = w - values.length
      values.each_with_index do |v, i|
        idx = (v.clamp(0.0, 1.0) * 7).round
        f.put(x + offset + i, y, BLOCKS[idx + 1], style)
      end
      self
    end
  end
end
