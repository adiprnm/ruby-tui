# frozen_string_literal: true
#
# Layout::Box -- a bordered (or plain) frame with a title, a footer and
# padding, wrapping exactly one child. This is the panel/tab/frame building
# block: the border lights up while the child has the focus.

require_relative '../component'

module TUI
  module Layout
    class Box < Component
      attr_accessor :title, :title_right, :footer, :padding, :border, :highlight
      attr_reader :border_style, :title_style, :footer_style

      def initialize(title: nil, title_right: nil, footer: nil, padding: 0,
                     border: true, border_style: :border, focus_style: :border_focus,
                     title_style: :title, title_right_style: :dim,
                     footer_style: :hint, highlight: true, **opts)
        super(**opts)
        @title = title
        @title_right = title_right
        @title_right_style = title_right_style
        @footer = footer
        @padding = padding
        @border = border
        @border_style = border_style
        @focus_style = focus_style
        @title_style = title_style
        @footer_style = footer_style
        @highlight = highlight
      end

      def add(child, *)
        raise ArgumentError, 'a Box holds one child; use a Stack' unless @children.empty?

        super
      end

      def child
        @children.first
      end

      # Area available to the child.
      def inner_rect
        base = @border ? @rect.inset(1) : @rect
        @padding.positive? ? base.inset(@padding) : base
      end

      def measure(max_w, max_h)
        inset = (@border ? 2 : 0) + (@padding * 2)
        return [max_w, max_h] unless child

        mw, mh = child.measure([max_w - inset, 0].max, [max_h - inset, 0].max)
        [[mw + inset, max_w].min, [mh + inset, max_h].min]
      end

      def layout(rect)
        @rect = rect
        child.layout(inner_rect) if child
        self
      end

      def render(canvas)
        if @border
          canvas.box(@rect, border_color, title: @title, title_style: @title_style,
                                       title_right: @title_right,
                                       title_right_style: @title_right_style,
                                       footer: @footer, footer_style: @footer_style)
        end
        render_children(canvas)
      end

      def clipped_children?
        true
      end

      private

      def border_color
        highlighted? ? @focus_style : @border_style
      end

      def highlighted?
        @highlight && contains_focus?
      end
    end
  end
end
