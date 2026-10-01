# frozen_string_literal: true
#
# Layout::Center -- places its child at the child's preferred size, centred
# in the available space (a progress bar, a button row, a small form).

require_relative '../component'

module TUI
  module Layout
    class Center < Component
      def initialize(child = nil, **opts)
        super(**opts)
        add(child) if child
      end

      def child
        @children.first
      end

      def measure(max_w, max_h)
        child ? child.measure(max_w, max_h) : [max_w, max_h]
      end

      def layout(rect)
        @rect = rect
        return self unless child

        mw, mh = child.measure(rect.w, rect.h)
        w = [mw, rect.w].min
        h = [mh, rect.h].min
        child.layout(Rect.new(rect.x + ((rect.w - w) / 2),
                              rect.y + ((rect.h - h) / 2), w, h))
        self
      end

      def clipped_children?
        true
      end
    end
  end
end
