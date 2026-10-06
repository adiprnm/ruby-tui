# frozen_string_literal: true
#
# Table -- rows and columns with a cursor, scrolling, sorting and per-column
# formatting.
#
#   table = TUI::Table.new(
#     columns: [
#       { key: :pid,  header: 'PID',  width:  8, align: :right },
#       { key: :name, header: 'NAME', width: TUI.flex(1) },
#       { key: :cpu,  header: 'CPU',  width:  6, align: :right,
#         format: ->(v) { format('%.1f%%', v) } }
#     ],
#     rows: rows
#   )
#   table.on(:select) { |row| open(row) }
#
# Rows are anything that responds to the column keys (Hash, Struct, or any
# object with readers). Column width accepts a plain number, TUI.flex,
# TUI.percent, or nil to size to the widest cell.

require_relative '../component'
require_relative '../text'
require_relative '../scroll'
require_relative '../layout/distribute'
require_relative '../util'

module TUI
  class Table < Component
    Column = Struct.new(:key, :header, :width, :align, :format) do
      def cell(row, index)
        value = key.nil? ? nil : row[key]
        return value.to_s unless formatter

        Util.call(formatter, value, row, index).to_s
      end

      def raw(row)
        key.nil? ? nil : row[key]
      end

      def formatter
        self[:format]
      end
    end

    attr_reader :columns, :rows, :selected, :scroll, :sort_key, :sort_direction

    def initialize(columns: [], rows: [], header: true, selected: 0,
                   padding: 0, style: :text, header_style: :header,
                   selected_style: :selection, dim_style: :selection_dim,
                   sortable: false, scrollbar: true, **opts)
      super(**opts)
      @columns = columns.map { |c| build_column(c) }
      @rows = rows.dup
      @header = header
      @selected = selected
      @padding = padding
      @style = style
      @header_style = header_style
      @selected_style = selected_style
      @dim_style = dim_style
      @sortable = sortable
      @show_scrollbar = scrollbar
      @scroll = 0
      @widths = []
      @auto_widths = nil
      @sort_key = nil
      @sort_direction = :asc
    end

    def focusable?
      true
    end

    def row_count
      @rows.length
    end

    def selected_row
      @rows[@selected]
    end

    def set_columns(columns)
      @columns = columns.map { |c| build_column(c) }
      @auto_widths = nil
      self
    end

    def set_rows(rows)
      @rows = rows.dup
      @selected = @selected.clamp(0, [@rows.length - 1, 0].max)
      @auto_widths = nil          # auto widths depend on the data
      apply_sort
      self
    end

    def select(index, notify: true)
      return self if @rows.empty?

      target = index.clamp(0, @rows.length - 1)
      moved = target != @selected
      @selected = target
      @scroll = Scroll.ensure_visible(@scroll, @selected, visible_rows)
      emit(Events::CHANGE, selected_row, @selected) if notify && moved
      self
    end

    # Sort by a column key. The caller keeps ownership of the data; this
    # reorders the copy the table holds.
    def sort_by(key, direction = nil)
      column = @columns.find { |c| c.key == key }
      return self unless column

      @sort_direction = direction ||
                        (@sort_key == key && @sort_direction == :asc ? :desc : :asc)
      @sort_key = key
      apply_sort(reset_cursor: true)
      emit(:sort, key, @sort_direction)
      self
    end

    def measure(max_w, max_h)
      widths = natural_widths
      height = @rows.length + (@header ? 2 : 0)
      [[widths.sum + (@padding * 2), max_w].min, [height, max_h].min]
    end

    def layout(rect)
      super
      # The scrollbar lives in the last column, so the columns get the rest.
      @scrollbar_visible = @show_scrollbar && @rows.length > visible_rows && data_rect.w > 3
      available = data_rect.w - (@scrollbar_visible ? 1 : 0)
      @widths = column_widths(available)
      @scroll = Scroll.ensure_visible(@scroll, @selected, visible_rows)
      @scroll = Scroll.clamp(@scroll, @rows.length, visible_rows)
      self
    end

    def render(canvas)
      area = data_rect
      return self if area.empty?

      draw_header(canvas, area) if @header

      rows_area = body_rect
      visible = [visible_rows, @rows.length - @scroll].min
      visible = 0 if visible.negative?
      visible.times do |i|
        index = @scroll + i
        row = @rows[index]

        draw_row(canvas, rows_area, row, index, i)
      end

      draw_scrollbar(canvas, area)
      self
    end

    def handle_key(key)
      case key.name
      when :up        then select(@selected - 1)
      when :down      then select(@selected + 1)
      when :home      then select(0)
      when :end       then select(@rows.length - 1)
      when :page_up   then select(@selected - visible_rows)
      when :page_down then select(@selected + visible_rows)
      when :enter     then emit(Events::SELECT, selected_row, @selected)
      when 's'        then cycle_sort
      else return false
      end
      true
    end

    # Scrollable region, used by tests and by callers that draw their own
    # scrollbar.
    def visible_rows
      [body_rect.h, 1].max
    end

    private

    def build_column(spec)
      spec = { key: spec } unless spec.is_a?(Hash)
      Column.new(spec[:key], spec[:header] || spec[:key].to_s,
                 spec.fetch(:width, nil), spec.fetch(:align, :left),
                 spec[:format])
    end

    # Re-apply the current sort (after new data arrived) without moving the
    # cursor.
    def apply_sort(reset_cursor: false)
      return self unless @sort_key

      column = @columns.find { |c| c.key == @sort_key }
      return self unless column

      @rows = @rows.sort_by { |row| sort_value(column.raw(row)) }
      @rows.reverse! if @sort_direction == :desc
      if reset_cursor
        @selected = 0
        @scroll = 0
        emit(Events::CHANGE, selected_row, @selected)
      end
      self
    end

    def sort_value(value)
      case value
      when nil then [1, 0]
      when Numeric then [0, value]
      else [0, value.to_s.downcase]
      end
    end

    def cycle_sort
      return self unless @sortable
      return self if @columns.empty?

      index = @columns.index { |c| c.key == @sort_key }
      column = index ? @columns[(index + (sort_direction == :asc ? 0 : 1)) % @columns.length] : @columns.first
      sort_by(column.key, (index && column.key == @sort_key && @sort_direction == :asc) ? :desc : :asc)
    end

    def data_rect
      @padding.positive? ? @rect.inset(0, left: @padding, right: @padding) : @rect
    end

    def body_rect
      return data_rect unless @header
      return Rect.new(@rect.x, @rect.y, @rect.w, 0) if data_rect.h < 3

      _, rest = data_rect.take_top(2)
      rest
    end

    def header_rect
      data_rect.take_top(1).first
    end

    def column_widths(available)
      auto = natural_widths
      specs = @columns.map do |column|
        column.width ? [column.width, nil] : [TUI.auto, auto[column.key] || 0]
      end
      Layout::Distribute.split(specs, [available, @columns.length].max, gap: 1)
    end

    # Widest cell for every column that has no explicit width; cached per
    # data set because it walks all the rows.
    def natural_widths
      @auto_widths ||= begin
        wanted = @columns.each_with_index.reject { |column, _i| column.width }
        if wanted.empty?
          {}
        else
          wanted.each_with_object({}) do |(column, ci), widths|
            width = Text.width(column.header)
            @rows.each do |row|
              w = Text.fast_width(column.cell(row, ci))
              width = w if w > width
            end
            widths[column.key] = width
          end
        end
      end
    end

    def draw_header(canvas, area)
      return if area.h < 3

      rect = header_rect
      @columns.each_with_index do |column, i|
        style = (column.key == @sort_key && @sortable) ? :accent : @header_style
        label = column.header
        label = "#{label} #{@sort_direction == :asc ? '▲' : '▼'}" if column.key == @sort_key && @sortable
        canvas.text(Rect.new(rect.x + column_offset(i), rect.y, @widths[i], 1),
                    label, style, column.align)
      end
      canvas.hline(area.x, area.y + 1, area.w, '─', :track)
    end

    def draw_row(canvas, area, row, index, line)
      rect = Rect.new(area.x, area.y + line, area.w, 1)
      selected = index == @selected
      if selected
        style = focused? ? @selected_style : @dim_style
        canvas.fill(rect.x, rect.y, rect.w, 1, ' ', style)
      end

      @columns.each_with_index do |column, i|
        cell_rect = Rect.new(rect.x + column_offset(i), rect.y, @widths[i], 1)
        style = selected ? (focused? ? @selected_style : @dim_style) : @style
        canvas.text(cell_rect, column.cell(row, i), style, column.align)
      end
    end

    def draw_scrollbar(canvas, area)
      return unless @scrollbar_visible

      Scroll.draw(canvas, Rect.new(area.right, area.y + header_height, 1, visible_rows),
                  @rows.length, visible_rows, @scroll)
    end

    def header_height
      @header ? 2 : 0
    end

    def column_offset(index)
      @widths[0, index].sum + index    # one cell of gap between columns
    end
  end
end
