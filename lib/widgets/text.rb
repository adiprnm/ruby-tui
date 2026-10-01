# frozen_string_literal: true
#
# Widgets -- text: placement helpers and truncation.
#
# Reopens the Widgets namespace from lib/widgets.rb; the public API is
# always Widgets.<name>(frame, ...).

require_relative '../term'
require_relative '../theme'

module Widgets
  class << self
    # --- text -----------------------------------------------------------

    def text(f, x, y, str, style = :text)
      f.put(x, y, str, style)
      self
    end

    def center(f, x, y, w, str, style = :text)
      tw = Term.text_width(str)
      f.put(x + [(w - tw) / 2, 0].max, y, str, style)
      self
    end

    def right(f, x, y, w, str, style = :text)
      tw = Term.text_width(str)
      f.put(x + [w - tw, 0].max, y, str, style)
      self
    end

    def truncate(str, width)
      return str if width <= 0 || Term.text_width(str) <= width

      out = +''
      used = 0
      str.each_char do |ch|
        w = Term.width(ch)
        break if used + w > width - 1
        out << ch
        used += w
      end
      out << '…'
    end
  end
end
