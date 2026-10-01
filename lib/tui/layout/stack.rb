# frozen_string_literal: true
#
# Layout::Stack -- children laid out in a row or a column.
#
# Each child gets a size spec:
#
#   stack.add(table,     size: TUI.flex(1))     # share the leftover space
#   stack.add(header,    size: TUI.fixed(1))    # exactly one row
#   stack.add(sidebar,   size: TUI.percent(0.3))# 30% of the main axis
#   stack.add(label,     size: TUI.auto)        # whatever it measures

require_relative '../component'
require_relative 'distribute'

module TUI
  module Layout
    class Stack < Component
      attr_reader :direction, :gap

      def initialize(direction: :vertical, gap: 0, **opts)
        super(**opts)
        @direction = direction
        @gap = gap
        @specs = {}
      end

      def add(child, size: TUI.auto)
        @specs[child] = size
        super(child)
      end

      def horizontal?
        @direction == :horizontal
      end

      def measure(max_w, max_h)
        entries = @children.map { |c| [c, spec_for(c)] }
        return [0, 0] if entries.empty?

        main = 0
        cross = 0
        entries.each do |child, spec|
          mw, mh = measure_child(child, spec, max_w, max_h)
          if horizontal?
            main += mw
            cross = [cross, mh].max
          else
            main += mh
            cross = [cross, mw].max
          end
        end
        main += @gap * (entries.length - 1)
        horizontal? ? [[main, max_w].min, [cross, max_h].min]
                    : [[cross, max_w].min, [main, max_h].min]
      end

      def layout(rect)
        @rect = rect
        sizes = distribute(rect)
        cursor = 0

        @children.each_with_index do |child, i|
          child.layout(child_rect(rect, cursor, sizes[i]))
          cursor += sizes[i] + @gap
        end
        self
      end

      def clipped_children?
        true
      end

      private

      def spec_for(child)
        @specs[child] || TUI.auto
      end

      # The main-axis spec overrides whatever the child would ask for; the
      # cross axis always comes from the child.
      def measure_child(child, _spec, max_w, max_h)
        child.measure(max_w, max_h)
      end

      def child_rect(rect, cursor, size)
        if horizontal?
          Rect.new(rect.x + cursor, rect.y, size, rect.h)
        else
          Rect.new(rect.x, rect.y + cursor, rect.w, size)
        end
      end

      # Resolve every spec into a number of cells along the main axis.
      def distribute(rect)
        return [] if @children.empty?

        main  = horizontal? ? rect.w : rect.h
        cross = horizontal? ? rect.h : rect.w
        avail = [main - (@gap * (@children.length - 1)), 0].max

        specs = @children.map do |child|
          spec = spec_for(child)
          measured = if spec == Units::AUTO || spec == TUI.auto
                       mw, mh = child.measure(cross, avail)
                       horizontal? ? mw : mh
                     end
          [spec, measured]
        end

        Distribute.split(specs, main, gap: @gap)
      end
    end
  end
end
