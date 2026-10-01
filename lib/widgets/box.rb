# frozen_string_literal: true
#
# Widgets -- boxes: rounded frames and border labels.
#
# Reopens the Widgets namespace from lib/widgets.rb; the public API is
# always Widgets.<name>(frame, ...).

require_relative '../term'
require_relative '../theme'

module Widgets
  class << self
    # --- boxes ----------------------------------------------------------

    # Rounded box of w x h cells with the top-left corner at (x, y).
    def box(f, x, y, w, h, style = :border)
      return if w < 2 || h < 2

      f.hline(x + 1, y, w - 2, HZ, style)
      f.hline(x + 1, y + h - 1, w - 2, HZ, style)
      (y + 1).upto(y + h - 2) do |yy|
        f.put(x, yy, VT, style)
        f.put(x + w - 1, yy, VT, style)
      end
      f.put(x, y, TL, style)
      f.put(x + w - 1, y, TR, style)
      f.put(x, y + h - 1, BL, style)
      f.put(x + w - 1, y + h - 1, BR, style)
      self
    end

    # Draw a label into a horizontal border line, masking the border char.
    # align: :left, :center or :right.
    def border_label(f, x, y, w, text, style = :title, align = :left)
      text = " #{text} "
      tw = Term.text_width(text)
      return if tw > w

      case align
      when :center then tx = x + ((w - tw) / 2)
      when :right  then tx = x + w - tw
      else              tx = x
      end
      f.put(tx, y, text, style)
      self
    end
  end
end
