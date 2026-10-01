# frozen_string_literal: true
#
# Dashboard -- the overview view: a CPU bar chart on top, memory and system
# panels under it, and a live top-process list if there is room left.
#
# Layout rule: panels are stacked from the top and every height is computed
# from the available space, so shrinking the terminal removes panels instead
# of drawing them past the bottom border.

module Components
  class Dashboard
    # Panel heights: one border row for the title, one for the bottom edge,
    # the rest is content.
    MEM_H = 5   # mem, swap, available
    SYS_H = 6   # uptime, load, procs, mem

    def initialize(state)
      @state = state
    end

    def draw(f, x, y, w, h)
      stacked = w < 56
      lower_h = stacked ? MEM_H + SYS_H : SYS_H
      # no room for both stacked panels?
      lower_h = MEM_H if stacked && h - lower_h < 5
      # no room for any of them?
      lower_h = 0 if h - lower_h < 5

      cpu_h = [(h * 0.45).round, 16].min
      cpu_h = [cpu_h, h - lower_h].min
      cpu_h = [cpu_h, 4].max

      Widgets.panel(f, x, y, w, cpu_h, 'CPU',
                    right: "#{@state.cpu_n} cores   #{Components.pct(@state.cpu)}")
      Widgets.bars(f, x + 1, y + 1, w - 2, cpu_h - 2, @state.cpu_hist)

      lower_y = y + cpu_h
      draw_lower_panels(f, x, lower_y, w, stacked, lower_h) if lower_h.positive?

      list_y = y + cpu_h + lower_h
      draw_top_processes(f, x, list_y, w, y + h - list_y)
    end

    private

    # `lower_h` is how much vertical room we were given: in the stacked
    # layout that may be enough for the memory panel only.
    def draw_lower_panels(f, x, y, w, stacked, lower_h)
      if stacked
        memory_panel(f, x, y, w, MEM_H)
        system_panel(f, x, y + MEM_H, w, SYS_H) if lower_h > MEM_H
      else
        half = (w - 1) / 2
        memory_panel(f, x, y, half, SYS_H)
        system_panel(f, x + half + 1, y, w - half - 1, SYS_H)
      end
    end

    def memory_panel(f, x, y, w, h)
      mem = @state.mem
      Widgets.panel(f, x, y, w, h, 'Memory',
                    right: "#{Components.pct(mem[:used].to_f / [mem[:total], 1].max)} full")

      gauge_w = [w - 22, 10].max
      iy = y + 1

      used  = "#{SysData.format_bytes(mem[:used])}/#{SysData.format_bytes(mem[:total])}"
      meter(f, x, iy, w, gauge_w, 'MEM', @state.mem_ratio, used)

      swap = mem[:swap_total].positive? ? mem[:swap_used].to_f / mem[:swap_total] : 0.0
      swap_text = "#{SysData.format_bytes(mem[:swap_used])}/#{SysData.format_bytes(mem[:swap_total])}"
      meter(f, x, iy + 1, w, gauge_w, 'SWP', swap, swap_text)

      return if h < MEM_H

      free = mem[:available].to_f / [mem[:total], 1].max
      f.put(x + 2, iy + 2,
            "available #{SysData.format_bytes(mem[:available])}  (#{Components.pct(free)})",
            :muted)
    end

    def meter(f, x, y, w, gauge_w, label, ratio, text)
      f.put(x + 2, y, label, :subtitle)
      Widgets.gauge(f, x + 6, y, gauge_w, ratio)
      Widgets.right(f, x + 2, y, w - 3, text, :text)
    end

    def system_panel(f, x, y, w, _h)
      load1, load5, load15 = @state.loadavg
      Widgets.panel(f, x, y, w, SYS_H, 'System', right: @state.hostname)

      rows = [
        ['uptime', SysData.format_uptime(@state.boot)],
        ['load', format('%.2f %.2f %.2f', load1, load5, load15)],
        ['procs', "#{@state.proc_total}  ·  cpu #{@state.cpu_n}x"],
        ['mem', "#{Components.pct(@state.mem_ratio)} used"]
      ]
      rows.each_with_index do |(key, value), i|
        f.put(x + 2, y + 1 + i, key, :muted)
        f.put(x + 10, y + 1 + i, value, :text)
      end
    end

    def draw_top_processes(f, x, y, w, h)
      return if h < 5

      Widgets.panel(f, x, y, w, h, 'Top processes',
                    right: @state.proc_sort == :mem ? 'by memory' : 'by cpu')
      Widgets.proc_header(f, x + 1, y + 1, w - 2)

      rows = h - 3                       # minus title and column header
      items = @state.proc_rows.first(rows).map { |r| Components.proc_row(r) }
      Widgets.process_list(f, x + 1, y + 2, w - 2, rows, items, -1, 0, false)
    end
  end
end
