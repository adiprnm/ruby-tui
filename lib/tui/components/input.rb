# frozen_string_literal: true
#
# Input -- a single-line text field.
#
#   field = TUI::Input.new(placeholder: 'name')
#   field.on(:change) { |value| ... }
#   field.on(:submit) { |value| ... }     # Enter

require_relative '../component'
require_relative '../text'
require_relative 'text_buffer'

module TUI
  class Input < Component
    attr_accessor :placeholder, :style
    attr_reader :buffer

    def initialize(value: '', placeholder: nil, password: false,
                   width: 24, padding: 1, style: :field,
                   placeholder_style: :placeholder, cursor_style: :cursor,
                   **opts)
      super(**opts)
      @buffer = TextBuffer.new(value)
      @placeholder = placeholder
      @password = password
      @width = width
      @padding = padding
      @style = style
      @placeholder_style = placeholder_style
      @cursor_style = cursor_style
      @scroll = 0
    end

    def focusable?
      true
    end

    def value
      @buffer.value
    end

    def value=(text)
      @buffer.set(text)
      emit(Events::CHANGE, value)
    end

    def measure(max_w, _max_h)
      [[@width, max_w].min, 1]
    end

    def render(canvas)
      area = content_rect
      canvas.fill(area.x, area.y, area.w, area.h, ' ', @style) if focused?

      text = display_text
      if text.empty? && @placeholder
        canvas.text(area, @placeholder, @placeholder_style)
      else
        # Canvas#text would add an ellipsis; a scrolled field shows the
        # window it has scrolled to instead.
        canvas.put(area.x, area.y, text[@scroll..-1].to_s, @style)
      end

      draw_cursor(canvas, area) if focused?
      self
    end

    def handle_key(key)
      if key.char && !key.ctrl?('c')
        @buffer.insert(key.char)
        changed
        return true
      end

      case key.name
      when :backspace then @buffer.backspace; changed
      when :delete    then @buffer.delete; changed
      when :left      then @buffer.left
      when :right     then @buffer.right
      when :home      then @buffer.home
      when :end       then @buffer.end_of_line
      when :enter     then emit(Events::SUBMIT, value)
      else return false
      end
      true
    end

    private

    def changed
      scroll_into_view
      emit(Events::CHANGE, value)
    end

    def content_rect
      @padding.positive? ? @rect.inset(0, left: @padding, right: @padding) : @rect
    end

    def display_text
      @password ? '*' * @buffer.value.length : @buffer.value
    end

    def cursor_cell
      @password ? @buffer.col : @buffer.cursor_cell
    end

    def scroll_into_view
      area = content_rect
      cell = cursor_cell
      @scroll = cell - area.w + 1 if cell - @scroll >= area.w
      @scroll = cell if cell < @scroll
      @scroll = 0 if @scroll.negative?
    end

    def draw_cursor(canvas, area)
      cell = cursor_cell - @scroll
      return if cell.negative? || cell >= area.w

      char = @password ? '*' : @buffer.current_line[@buffer.col]
      canvas.put(area.x + cell, area.y, char && !char.empty? ? char : ' ', @cursor_style)
    end
  end
end
