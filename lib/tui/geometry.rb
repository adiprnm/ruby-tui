# frozen_string_literal: true

module TUI
  # A rectangle in cell coordinates. Rects are immutable: layout code builds
  # new ones instead of mutating, which keeps containers honest.
  class Rect
    attr_reader :x, :y, :w, :h

    def initialize(x, y, w, h)
      @x = x
      @y = y
      @w = w.negative? ? 0 : w
      @h = h.negative? ? 0 : h
    end

    def right
      @x + @w - 1
    end

    def bottom
      @y + @h - 1
    end

    def empty?
      @w.zero? || @h.zero?
    end

    def area
      @w * @h
    end

    def contains?(px, py)
      px >= @x && px <= right && py >= @y && py <= bottom
    end

    # Shrink on all sides by `n` (or by a per-side hash).
    def inset(n = 1, top: n, right: n, bottom: n, left: n)
      Rect.new(@x + left, @y + top,
               @w - left - right, @h - top - bottom)
    end

    def offset(dx, dy)
      Rect.new(@x + dx, @y + dy, @w, @h)
    end

    def with(x: @x, y: @y, w: @w, h: @h)
      Rect.new(x, y, w, h)
    end

    # Cut a band off the top: returns [band, rest].
    def take_top(n)
      n = [[n, @h].min, 0].max
      [Rect.new(@x, @y, @w, n), Rect.new(@x, @y + n, @w, @h - n)]
    end

    def take_bottom(n)
      n = [[n, @h].min, 0].max
      [Rect.new(@x, @y + @h - n, @w, n), Rect.new(@x, @y, @w, @h - n)]
    end

    def take_left(n)
      n = [[n, @w].min, 0].max
      [Rect.new(@x, @y, n, @h), Rect.new(@x + n, @y, @w - n, @h)]
    end

    def take_right(n)
      n = [[n, @w].min, 0].max
      [Rect.new(@x + @w - n, @y, n, @h), Rect.new(@x, @y, @w - n, @h)]
    end

    # Split into two columns at a fraction (0..1) of the width.
    def split(ratio, gap = 0)
      left_w = ((@w - gap) * ratio).round
      left, right = take_left(left_w + gap)
      [left, right]
    end

    def to_a
      [@x, @y, @w, @h]
    end

    def ==(other)
      other.is_a?(Rect) && to_a == other.to_a
    end

    def inspect
      "#<TUI::Rect #{@w}x#{@h}+#{@x}+#{@y}>"
    end
  end

  # Sizing specs handed to a layout container.
  module Units
    Fixed = Struct.new(:value)
    Flex  = Struct.new(:weight)
    Ratio = Struct.new(:ratio)
    AUTO  = :auto
  end

  class << self
    def fixed(n)
      Units::Fixed.new(n)
    end

    def flex(weight = 1)
      Units::Flex.new(weight)
    end

    def percent(ratio)
      Units::Ratio.new(ratio)
    end

    def auto
      Units::AUTO
    end
  end
end
