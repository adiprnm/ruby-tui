# frozen_string_literal: true
#
# Chrome -- everything around the views: the outer border with the app name
# and clock, the key hints in the bottom border, and the sidebar with the
# view list and the mini system readout.

module Components
  class Chrome
    def initialize(state)
      @state = state
    end

    def draw(f, x, y, w, h)
      Widgets.box(f, x, y, w, h, :border)
      Widgets.border_label(f, x + 1, y, w - 2, ' rtop ', :accent, :left)

      clock = " #{Time.now.strftime('%a %d %b  %H:%M:%S')} "
      Widgets.border_label(f, x + 1, y, w - 2, clock, :dim, :right)

      Widgets.border_label(f, x + 1, y + h - 1, w - 2, hints, :muted, :center)

      separator(f, h)
      sidebar(f, h)
    end

    private

    def hints
      case @state.view
      when :procs then ' ↑↓ move · tab sidebar · ←→ sort · r refresh · ? help · q quit '
      when :help  then ' q quit · esc back '
      else             ' ↑↓ view · 1-3 jump · ? help · q quit '
      end
    end

    # A lit separator tells you where the keyboard is pointed.
    def separator(f, h)
      style = @state.focus == :menu ? :border_hi : :border
      1.upto(h - 2) { |y| f.put(SIDEBAR_W, y, Widgets::VT, style) }
    end

    def sidebar(f, h)
      f.put(2, 2, 'VIEWS', :muted)

      MENU.each_with_index do |item, i|
        draw_item(f, item, 4 + i * 2)
      end

      draw_stats(f, h)
    end

    def draw_item(f, item, y)
      active  = item[:id] == @state.view
      focused = active && @state.focus == :menu

      if focused
        f.fill(1, y, SIDEBAR_W - 1, 1, ' ', :sel)
        f.put(1, y, '▌', :focus)
        f.put(3, y, "#{item[:glyph]}  #{item[:label]}", :sel)
        Widgets.right(f, 1, y, SIDEBAR_W - 2, "#{item[:key]} ", :sel_dim)
      else
        f.put(1, y, '▌', active ? :focus : :border)
        f.put(3, y, "#{item[:glyph]}  #{item[:label]}", active ? :accent : :dim)
        Widgets.right(f, 1, y, SIDEBAR_W - 2, "#{item[:key]} ", :muted)
      end
    end

    # Mini readout pinned to the bottom of the sidebar.
    def draw_stats(f, h)
      y = h - 8
      return if y < 4 + MENU.length * 2

      f.put(2, y, 'SYSTEM', :muted)
      stat(f, y + 1, 'load', format('%.2f', @state.loadavg[0]))
      stat(f, y + 2, 'procs', @state.proc_total.to_s)
      stat(f, y + 3, 'uptime', SysData.format_uptime(@state.boot))

      f.put(2, y + 5, 'mem', :dim)
      Widgets.right(f, 2, y + 5, SIDEBAR_W - 3, "#{@state.mem_pct}%", :text)
      Widgets.gauge(f, 2, y + 6, SIDEBAR_W - 3, @state.mem_ratio, :track)
    end

    def stat(f, y, label, value)
      f.put(2, y, label, :dim)
      Widgets.right(f, 2, y, SIDEBAR_W - 3, value, :text)
    end
  end
end
