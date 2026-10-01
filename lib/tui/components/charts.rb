# frozen_string_literal: true
#
# Sparkline and BarChart -- the two ways of drawing a series of 0.0..1.0
# values. Both fill their rect and both are happy with an empty series.

require_relative '../component'
require_relative '../style'

module TUI
  BLOCKS = [' ', '▁', '▂', '▃', '▄', '▅', '▆', '▇', '█'].freeze

  class Sparkline < Component
    attr_accessor :values

    def initialize(values: [], style: :accent, **opts)
      super(**opts)
      @values = values
      @style = style
    end

    def measure(max_w, _max_h)
      [max_w, 1]
    end

    def render(canvas)
      values = @values.last(@rect.w)
      offset = @rect.w - values.length
      values.each_with_index do |value, i|
        step = (value.to_f.clamp(0.0, 1.0) * 8).round
        canvas.put(@rect.x + offset + i, @rect.y, BLOCKS[step], @style)
      end
      self
    end
  end

  # Vertical bars, bottom-up, with optional dotted grid lines.
  class BarChart < Component
    attr_accessor :values, :max

    def initialize(values: [], max: nil, grid: true, ramp: true,
                   style: :accent, **opts)
      super(**opts)
      @values = values
      @max = max
      @grid = grid
      @ramp = ramp
      @style = style
    end

    def render(canvas)
      return self if @rect.w < 1 || @rect.h < 1

      draw_grid(canvas) if @grid

      values = @values.last(@rect.w)
      offset = @rect.w - values.length
      values.each_with_index do |raw, i|
        value = scale(raw)
        eighths = (value * @rect.h * 8).round
        next if eighths.zero?

        colour = @ramp ? Style.ramp(value) : @style
        0.upto(@rect.h - 1) do |row|
          filled = eighths - (row * 8)
          next if filled <= 0

          filled = 8 if filled > 8
          canvas.put(@rect.x + offset + i, @rect.bottom - row, BLOCKS[filled], colour)
        end
      end
      self
    end

    def push(value)
      @values << value
      @values.shift while @values.length > 4096
      self
    end

    private

    def scale(value)
      v = value.to_f
      v /= @max.to_f if @max && @max.positive?
      v.clamp(0.0, 1.0)
    end

    def draw_grid(canvas)
      [0.25, 0.5, 0.75].each do |fraction|
        y = @rect.bottom - (fraction * (@rect.h - 1)).round
        canvas.hline(@rect.x, y, @rect.w, '·', :grid)
      end
    end
  end
end
