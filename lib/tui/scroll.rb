# frozen_string_literal: true
#
# Scroll -- the arithmetic every scrolling widget needs, plus the scrollbar
# drawing. Kept in one place so List, Table and TextArea behave identically.

require_relative 'geometry'
require_relative 'text'

module TUI
  module Scroll
    class << self
      def limit(total, visible)
        [total - visible, 0].max
      end

      def clamp(offset, total, visible)
        offset.clamp(0, limit(total, visible))
      end

      # Smallest offset that keeps `index` inside a window of `visible` rows.
      def ensure_visible(offset, index, visible)
        return 0 if visible <= 0
        return index if index < offset
        return index - visible + 1 if index >= offset + visible

        offset
      end

      # A one-column scrollbar drawn into `rect`, or nothing when the whole
      # content fits.
      def draw(canvas, rect, total, visible, offset, track: :track, thumb: :thumb)
        return if total <= visible || rect.h < 1 || rect.w < 1

        x = rect.x
        top = rect.y
        height = rect.h
        bar = [(height * visible / total.to_f).round, 1].max
        span = limit(total, visible)
        pos = span.zero? ? 0 : (offset * (height - bar) / span.to_f).round

        canvas.vline(x, top, height, '│', track)
        canvas.vline(x, top + pos, bar, '┃', thumb)
      end
    end
  end
end
