# frozen_string_literal: true
#
# Layout::Spacer -- empty space with a preferred size, for pushing siblings
# apart in an auto-sized stack. A Divider is the visible version.

require_relative '../component'

module TUI
  module Layout
    class Spacer < Component
      def initialize(size = 0, **opts)
        super(**opts)
        @size = size
      end

      def measure(_max_w, _max_h)
        [@size, @size]
      end
    end

    class Divider < Component
      attr_reader :orientation

      def initialize(orientation: :horizontal, char: nil, style: :border, **opts)
        super(**opts)
        @orientation = orientation
        @char = char || (orientation == :horizontal ? '─' : '│')
        @style = style
      end

      def measure(_max_w, _max_h)
        @orientation == :horizontal ? [0, 1] : [1, 0]
      end

      def render(canvas)
        if @orientation == :horizontal
          canvas.hline(@rect.x, @rect.y, @rect.w, @char, @style)
        else
          canvas.vline(@rect.x, @rect.y, @rect.h, @char, @style)
        end
      end
    end
  end
end
