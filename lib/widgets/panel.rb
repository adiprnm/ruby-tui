# frozen_string_literal: true
#
# Widgets -- panels: the layout unit every view is built from.
#
# Reopens the Widgets namespace from lib/widgets.rb; the public API is
# always Widgets.<name>(frame, ...).

require_relative '../term'
require_relative '../theme'

module Widgets
  class << self
# A panel is a box with a title in its top border; panel heights are
    # therefore always (content rows + 2): one border row for the title and
    # one for the bottom edge. `right` is drawn right-aligned in that row.
    def panel(f, x, y, w, h, title, right: nil)
      box(f, x, y, w, h, :border)
      border_label(f, x + 1, y, w - 2, title, :title, :left)
      border_label(f, x + 1, y, w - 2, "#{right} ", :dim, :right) if right
      self
    end
  end
end
