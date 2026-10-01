# frozen_string_literal: true
#
# Processes -- the full, scrollable process table.

module Components
  class Processes
    # Rows a caller needs for its own scroll arithmetic: the panel loses two
    # rows to the border and two to the column header/separator.
    def self.visible_rows(screen_h)
      screen_h - 6
    end

    def initialize(state)
      @state = state
    end

    def draw(f, x, y, w, h)
      sort = @state.proc_sort == :mem ? 'memory' : 'cpu'
      Widgets.panel(f, x, y, w, h, 'Processes',
                    right: "sort: #{sort}   #{@state.proc_rows.length} shown   #{@state.proc_total} total")

      # one border row + column header + separator
      header_y = y + 1
      list_y   = header_y + 2
      list_h   = h - 2 - 2

      Widgets.proc_header(f, x + 1, header_y, w - 2)
      f.hline(x + 1, header_y + 1, w - 2, '─', :track)
      return if list_h < 1

      items = @state.proc_rows.map { |r| Components.proc_row(r) }
      Widgets.process_list(f, x + 1, list_y, w - 2, list_h,
                           items, @state.proc_sel, @state.proc_offset,
                           @state.focus == :content)
      Widgets.scrollbar(f, x + w - 2, list_y, list_h, items.length, list_h, @state.proc_offset)
    end
  end
end
