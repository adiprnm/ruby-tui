# frozen_string_literal: true
#
# TooSmall -- the fallback when the terminal cannot fit the layout.

module Components
  class TooSmall
    def initialize(_state); end

    def draw(frame, x, y, w, h)
      Widgets.box(frame, x, y, w, h, :border)
      return if w < 16 || h < 5

      Widgets.border_label(frame, x + 1, y, w - 2, 'rtop', :accent, :left)
      Widgets.center(frame, x + 1, y + (h / 2) - 1, w - 2, 'window too small', :warn)
      Widgets.center(frame, x + 1, y + (h / 2), w - 2,
                     "#{w}x#{h}, need #{MIN_W}x#{MIN_H}", :dim)
    end
  end
end
