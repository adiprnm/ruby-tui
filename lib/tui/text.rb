# frozen_string_literal: true
#
# Text -- string helpers that think in terminal cells, not characters:
# CJK and emoji take two cells, combining marks take none.

require_relative 'term'

module TUI
  module Text
    ELLIPSIS = '…'

    class << self
      def width(str)
        Term.text_width(str.to_s)
      end

      # Width without walking the string when it is plain ASCII, which is
      # the case for almost every cell in a table.
      def fast_width(str)
        str = str.to_s
        str.ascii_only? ? str.length : width(str)
      end

      # Cut to `width` cells, adding an ellipsis when something was removed.
      def truncate(str, width)
        str = str.to_s
        return str if width <= 0
        return str if width(str) <= width

        out = +''
        used = 0
        str.each_char do |ch|
          w = Term.width(ch)
          break if used + w > width - 1
          out << ch
          used += w
        end
        out << ELLIPSIS
      end

      # Pad to `width` cells (never truncates -- see truncate).
      def pad(str, width, align = :left)
        str = str.to_s
        fill = width - width(str)
        return str if fill <= 0

        case align
        when :right then (' ' * fill) + str
        when :center
          left = fill / 2
          (' ' * left) + str + (' ' * (fill - left))
        else str + (' ' * fill)
        end
      end

      # Greedy word wrap into an array of lines.
      def wrap(str, width)
        return [str.to_s] if width <= 1

        lines = []
        str.to_s.split("\n", -1).each do |paragraph|
          current = +''
          paragraph.split(/\s+/).each do |word|
            candidate = current.empty? ? word : "#{current} #{word}"
            if self.width(candidate) <= width
              current = candidate
            else
              lines << current unless current.empty?
              current = word
            end
          end
          lines << current
        end
        lines
      end
    end
  end
end
