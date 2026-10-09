# frozen_string_literal: true
#
# List -- a vertical list of items with a cursor, scrolling and selection.
#
#   list = TUI::List.new(items: %w[one two three])
#   list.on(:change) { |item, index| ... }
#   list.on(:select) { |item, index| ... }   # Enter

require_relative '../component'
require_relative '../text'
require_relative '../scroll'
require_relative '../util'

module TUI
  class List < Component
    attr_reader :items, :selected, :scroll

    def initialize(items: [], selected: 0, format: nil, padding: 1,
                   style: :text, selected_style: :selection,
                   dim_style: :selection_dim, **opts)
      super(**opts)
      @items = items.dup
      @selected = selected
      @format = format || ->(item, _i) { item.to_s }
      @padding = padding
      @style = style
      @selected_style = selected_style
      @dim_style = dim_style
      @scroll = 0
    end

    def focusable?
      true
    end

    def set_items(items)
      @items = items.dup
      @selected = @selected.clamp(0, [@items.length - 1, 0].max)
      self
    end

    def selected_item
      @items[@selected]
    end

    def select(index, notify: true)
      return self if @items.empty?

      target = index.clamp(0, @items.length - 1)
      moved = target != @selected
      @selected = target
      @scroll = Scroll.ensure_visible(@scroll, @selected, content_rect.h)
      emit(Events::CHANGE, selected_item, @selected) if notify && moved
      self
    end

    def measure(max_w, max_h)
      width = @items.map { |item| Text.width(Util.call(@format, item, 0).to_s) }.max.to_i
      [[width + (@padding * 2), max_w].min, [@items.length, max_h].min]
    end

    def render(canvas)
      area = content_rect
      rows = area.h

      @scroll = Scroll.ensure_visible(@scroll, @selected, rows)
      @scroll = Scroll.clamp(@scroll, @items.length, rows)

      visible = [rows, @items.length - @scroll].min
      visible = 0 if visible.negative?
      visible.times do |i|
        index = @scroll + i
        item = @items[index]

        row_rect = Rect.new(area.x, area.y + i, area.w, 1)
        style = @style
        if index == @selected
          style = focused? ? @selected_style : @dim_style
          canvas.fill(row_rect.x, row_rect.y, row_rect.w, 1, ' ', style)
        end
        canvas.text(row_rect, Util.call(@format, item, index).to_s, style)
      end

      Scroll.draw(canvas, Rect.new(area.right + 1, area.y, 1, area.h),
                  @items.length, rows, @scroll) if area.right + 1 <= @rect.right
      self
    end

    def handle_key(key)
      case key.name
      when :up, 'k'   then select(@selected - 1)
      when :down, 'j' then select(@selected + 1)
      when :home      then select(0)
      when :end       then select(@items.length - 1)
      when :page_up   then select(@selected - content_rect.h)
      when :page_down then select(@selected + content_rect.h)
      when :enter     then emit(Events::SELECT, selected_item, @selected)
      else return false
      end
      true
    end

    private

    def content_rect
      @padding.positive? ? @rect.inset(0, left: @padding, right: @padding) : @rect
    end
  end
end
