# frozen_string_literal: true
#
# TextArea -- a multi-line editor with a scrolling viewport and a cursor.

require_relative '../component'
require_relative '../text'
require_relative '../scroll'
require_relative 'text_buffer'

module TUI
  class TextArea < Component
    attr_reader :buffer, :scroll

    def initialize(value: '', rows: 5, width: 40, padding: 1, style: :field,
                   cursor_style: :cursor, **opts)
      super(**opts)
      @buffer = TextBuffer.new(value, multiline: true)
      @rows = rows
      @width = width
      @padding = padding
      @style = style
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

    def measure(max_w, max_h)
      [[@width, max_w].min, [@rows, max_h].min]
    end

    def layout(rect)
      super
      @scroll = Scroll.ensure_visible(@scroll, @buffer.row, content_rect.h)
      self
    end

    def render(canvas)
      area = content_rect
      @scrolling = @buffer.lines.length > area.h && area.w > 2
      area = area.with(w: area.w - 1) if @scrolling
      canvas.fill(area.x, area.y, area.w, area.h, ' ', @style) if focused?

      area.h.times do |i|
        line = @buffer.lines[@scroll + i]
        break if line.nil? && i > 0

        canvas.text(Rect.new(area.x, area.y + i, area.w, 1), line.to_s, @style)
      end

      draw_cursor(canvas, area) if focused?
      draw_scrollbar(canvas, area)
      self
    end

    def handle_key(key)
      if key.char
        @buffer.insert(key.char)
        after_edit
        return true
      end

      case key.name
      when :enter     then @buffer.newline; after_edit
      when :backspace then @buffer.backspace; after_edit
      when :delete    then @buffer.delete; after_edit
      when :left      then @buffer.left
      when :right     then @buffer.right
      when :up        then @buffer.up; @scroll = Scroll.ensure_visible(@scroll, @buffer.row, content_rect.h)
      when :down      then @buffer.down; @scroll = Scroll.ensure_visible(@scroll, @buffer.row, content_rect.h)
      when :page_up   then @scroll = Scroll.clamp(@scroll - content_rect.h, @buffer.lines.length, content_rect.h)
      when :page_down then @scroll = Scroll.clamp(@scroll + content_rect.h, @buffer.lines.length, content_rect.h)
      when :home      then @buffer.home
      when :end       then @buffer.end_of_line
      else return false
      end
      true
    end

    private

    def content_rect
      @padding.positive? ? @rect.inset(0, left: @padding, right: @padding) : @rect
    end

    def after_edit
      @scroll = Scroll.ensure_visible(@scroll, @buffer.row, content_rect.h)
      emit(Events::CHANGE, value)
    end

    def draw_cursor(canvas, area)
      row = @buffer.row - @scroll
      return if row.negative? || row >= area.h

      cell = @buffer.cursor_cell
      return if cell >= area.w

      char = @buffer.current_line[@buffer.col]
      canvas.put(area.x + cell, area.y + row,
                 char && !char.empty? ? char : ' ', @cursor_style)
    end

    def draw_scrollbar(canvas, area)
      return unless @scrolling

      Scroll.draw(canvas, Rect.new(content_rect.right, area.y, 1, area.h),
                  @buffer.lines.length, area.h, @scroll)
    end
  end
end
