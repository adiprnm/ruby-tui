# frozen_string_literal: true
#
# Label -- static text, optionally wrapped and aligned.

require_relative '../component'
require_relative '../text'

module TUI
  class Label < Component
    attr_accessor :text, :style

    def initialize(text = '', align: :left, style: :text, wrap: false, **opts)
      super(**opts)
      @text = text
      @align = align
      @style = style
      @wrap = wrap
    end

    def measure(max_w, max_h)
      unless @wrap
        return [[Text.width(@text), max_w].min, [1, max_h].min]
      end

      lines = Text.wrap(@text, max_w)
      [lines.map { |l| Text.width(l) }.max.to_i.clamp(0, max_w),
       [lines.length, max_h].min]
    end

    def render(canvas)
      if @wrap
        lines = Text.wrap(@text, @rect.w)
        lines.first(@rect.h).each_with_index do |line, i|
          canvas.text(@rect.with(y: @rect.y + i, h: 1), line, @style, @align)
        end
      else
        canvas.text(@rect, @text, @style, @align)
      end
      self
    end
  end
end
