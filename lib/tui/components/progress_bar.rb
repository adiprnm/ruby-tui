# frozen_string_literal: true
#
# ProgressBar -- a horizontal meter for a 0.0..1.0 value. The filled part is
# painted with the shared colour ramp, so low is teal and high is red.

require_relative '../component'
require_relative '../style'
require_relative '../text'

module TUI
  class ProgressBar < Component
    attr_accessor :value, :label

    def initialize(value: 0.0, width: 20, label: nil, percent: true,
                   show_value: nil, right: nil, track: :track, ramp: true,
                   filled: '█', empty: '░', value_style: :text, **opts)
      super(**opts)
      @value = value
      @width = width
      @label = label
      @percent = percent
      @show_value = show_value
      @right = right
      @track = track
      @ramp = ramp
      @filled = filled
      @empty = empty
      @value_style = value_style
    end

    def ratio
      (@value || 0.0).clamp(0.0, 1.0)
    end

    def measure(_max_w, _max_h)
      width = @width
      width += Text.width(@label) + 1 if @label
      width += 6 if text_right
      [width, 1]
    end

    def render(canvas)
      text = text_right
      x = @rect.x
      if @label
        canvas.text(Rect.new(x, @rect.y, Text.width(@label), 1), @label, :label)
        x += Text.width(@label) + 1
      end

      bar_w = [@rect.right - x + 1 - (text ? Text.width(text) + 2 : 0), 1].max
      filled = (bar_w * ratio).round

      bar_w.times do |i|
        if i < filled
          style = @ramp ? Style.ramp(i.to_f / [bar_w - 1, 1].max) : :accent
          canvas.put(x + i, @rect.y, @filled, style)
        else
          canvas.put(x + i, @rect.y, @empty, @track)
        end
      end

      if text
        canvas.text(Rect.new(@rect.right - Text.width(text), @rect.y,
                             Text.width(text), 1), text, @value_style, :right)
      end
      self
    end

    private

    def text_right
      return @right.is_a?(Proc) ? @right.call : @right if @right
      return format('%.1f%%', ratio * 100) if @percent
      return @show_value.call(@value) if @show_value

      nil
    end
  end
end
