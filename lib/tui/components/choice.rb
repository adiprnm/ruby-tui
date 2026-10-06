# frozen_string_literal: true
#
# Checkbox and RadioGroup -- the non-text inputs.

require_relative '../component'
require_relative '../text'

module TUI
  class Checkbox < Component
    attr_accessor :value

    def initialize(label = '', value: false, style: :text, focus_style: :accent, **opts)
      super(**opts)
      @label = label
      @value = value
      @style = style
      @focus_style = focus_style
    end

    def label=(text)
      @label = text
    end

    def focusable?
      true
    end

    def measure(_max_w, _max_h)
      [Text.width(@label) + 4, 1]
    end

    def render(canvas)
      box = @value ? '[x]' : '[ ]'
      style = focused? ? @focus_style : @style
      canvas.text(@rect, "#{box} #{@label}", style)
    end

    def handle_key(key)
      return false unless key.space? || key.name == :enter

      @value = !@value
      emit(Events::CHANGE, @value)
      true
    end
  end

  class RadioGroup < Component
    attr_reader :options, :selected

    def initialize(options: [], selected: 0, orientation: :vertical,
                   style: :text, focus_style: :accent, **opts)
      super(**opts)
      @options = options.dup
      @selected = selected
      @orientation = orientation
      @style = style
      @focus_style = focus_style
    end

    def focusable?
      true
    end

    def value
      @options[@selected]
    end

    def select(index, notify: true)
      return self if @options.empty?

      index = index.clamp(0, @options.length - 1)
      return self if index == @selected

      @selected = index
      emit(Events::CHANGE, value) if notify
      self
    end

    # One slot per option: "(x) name" plus a two cell gap.
    def slot_width(option)
      Text.width(option) + 6
    end

    def measure(max_w, max_h)
      widths = @options.map { |option| slot_width(option) }
      if @orientation == :horizontal
        [[widths.sum, max_w].min, 1]
      else
        [[widths.max.to_i - 2, max_w].min, [@options.length, max_h].min]
      end
    end

    def render(canvas)
      offset = 0
      catch(:full) do
        @options.each_with_index do |option, index|
          rect = if @orientation == :horizontal
                   slot = slot_width(option)
                   r = Rect.new(@rect.x + offset, @rect.y, slot - 2, 1)
                   offset += slot
                   r
                 else
                   Rect.new(@rect.x, @rect.y + index, @rect.w, 1)
                 end
          throw :full if rect.y > @rect.bottom || rect.right > @rect.right

          mark = index == @selected ? '(•)' : '( )'
          style = focused? && index == @selected ? @focus_style : @style
          canvas.text(rect, "#{mark} #{option}", style)
        end
      end
      self
    end

    def handle_key(key)
      case key.name
      when :up, :left    then select(@selected - 1)
      when :down, :right then select(@selected + 1)
      when :home         then select(0)
      when :end          then select(@options.length - 1)
      else return false
      end
      true
    end
  end
end
