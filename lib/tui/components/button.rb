# frozen_string_literal: true
#
# Button -- a focusable label that emits :press on Enter or Space.

require_relative '../component'
require_relative '../text'

module TUI
  class Button < Component
    attr_accessor :label

    def initialize(label = '', style: :text, focus_style: :selection,
                   brackets: true, **opts)
      super(**opts)
      @label = label
      @style = style
      @focus_style = focus_style
      @brackets = brackets
    end

    def focusable?
      true
    end

    def measure(_max_w, _max_h)
      [Text.width(display_text), 1]
    end

    def render(canvas)
      canvas.text(@rect, display_text, focused? ? @focus_style : @style, :center)
    end

    def handle_key(key)
      return false unless key.name == :enter || key.space?

      emit(Events::PRESS)
      emit(Events::SUBMIT)   # a button is usually the form's submit
      true
    end

    private

    def display_text
      @brackets ? "[ #{@label} ]" : @label
    end
  end
end
