# frozen_string_literal: true
#
# Layout::Viewport -- a scrollable window over content that may be larger
# than the space available. The child is laid out at its preferred size and
# clipped to the viewport; scrolling moves it under the window.
#
#   viewport = TUI::Layout::Viewport.new(form)
#   viewport.scroll_by(1)

require_relative '../component'

module TUI
  module Layout
    class Viewport < Component
      # A stand-in for "as much as you need" when measuring content.
      MAX = 1 << 16

      attr_reader :offset_x, :offset_y

      def initialize(child = nil, **opts)
        super(**opts)
        @offset_x = 0
        @offset_y = 0
        @content_size = [0, 0]
        add(child) if child
      end

      def content
        @children.first
      end

      def scroll_by(dy, dx = 0)
        @offset_y += dy
        @offset_x += dx
        clamp! if @content_size[0].positive? || @content_size[1].positive?
        self
      end

      def scroll_to(offset_y)
        @offset_y = offset_y
        self
      end

      def measure(max_w, max_h)
        return [max_w, max_h] unless content

        mw, mh = content.measure(max_w, 1 << 16)
        [[mw, max_w].min, [mh, max_h].min]
      end

      def layout(rect)
        @rect = rect
        return self unless content

        mw, mh = content.measure(rect.w, MAX)
        w = [mw, rect.w].max
        h = [mh, rect.h].max
        @content_size = [w, h]
        clamp!

        content.layout(Rect.new(rect.x - @offset_x, rect.y - @offset_y, w, h))
        self
      end

      def render(canvas)
        content ? canvas.clip(@rect) { content.render(canvas) } : nil
        self
      end

      def clipped_children?
        true
      end

      private

      def clamp!
        @offset_y = @offset_y.clamp(0, [@content_size[1] - @rect.h, 0].max)
        @offset_x = @offset_x.clamp(0, [@content_size[0] - @rect.w, 0].max)
      end
    end
  end
end
