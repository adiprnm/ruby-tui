# frozen_string_literal: true
#
# App -- the rtop dashboard. Holds all state, samples /proc, and paints
# frames onto a Screen.

require_relative 'term'
require_relative 'theme'
require_relative 'screen'
require_relative 'widgets'
require_relative 'sysdata'

class App
  SIDEBAR_W   = 20
  CONTENT_X   = SIDEBAR_W + 1
  TICK        = 0.1        # input/render cadence
  CPU_PERIOD  = 0.2        # push a CPU sample into the history every 0.2s
  PROC_PERIOD = 1.0        # refresh the process table once a second
  HISTORY     = 512

  MENU = [
    { id: :dash,  key: '1', glyph: '◈', label: 'Dashboard', hint: 'overview' },
    { id: :procs, key: '2', glyph: '▤', label: 'Processes', hint: 'top' },
    { id: :help,  key: '3', glyph: '?', label: 'Help',      hint: 'keys' }
  ].freeze

  attr_reader :view

  def initialize(out)
    @out        = out
    @screen     = Screen.new(out)
    @view       = :dash
    @focus      = :menu
    @quit       = false

    @cpu_hist   = []
    @cpu        = 0.0
    @cpu_prev   = nil
    @cpu_n      = SysData.cpu_count

    @mem        = SysData.memory
    @proc_rows  = []
    @proc_snap  = nil
    @proc_sel   = 0
    @proc_offset = 0
    @proc_sort  = :cpu
    @proc_total = 0

    @last_cpu_sample  = 0.0
    @last_proc_sample = 0.0
    @started          = Time.now
    @boot             = SysData.uptime
  end

  # ---------------------------------------------------------------- main loop

  def run
    loop do
      break if @quit
      sample
      draw
      key = Term.read_key(TICK)
      handle(key) if key
    end
  end

  # One non-interactive frame (used by --snapshot and tests).
  def prime
    2.times do
      sample(force: true)
      sleep 0.25
    end
    sample(force: true)
    self
  end

  def quit!
    @quit = true
  end

  # ----------------------------------------------------------------- sampling

  def sample(force: false)
    now = Process.clock_gettime(Process::CLOCK_MONOTONIC)

    if force || now - @last_cpu_sample >= CPU_PERIOD
      @last_cpu_sample = now
      cur = SysData.cpu_times
      unless cur.empty?
        if @cpu_prev
          @cpu = SysData.cpu_delta(@cpu_prev, cur)
          @cpu_hist << @cpu
          @cpu_hist.shift while @cpu_hist.length > HISTORY
        end
        @cpu_prev = cur
      end
      @mem = SysData.memory
      @boot = SysData.uptime
    end

    refresh_procs if force || now - @last_proc_sample >= PROC_PERIOD
  end

  def refresh_procs
    now = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    return if @proc_snap && now - @last_proc_sample < 0.05

    sel_pid = @proc_rows[@proc_sel] && @proc_rows[@proc_sel][:pid]

    snap = SysData.process_snapshot
    @proc_total = snap.length
    rows = SysData.process_rows(@proc_snap, snap, @mem[:total])
    @proc_snap = snap
    @proc_rows = sort_procs(rows)

    @last_proc_sample = now

    # keep the cursor on the same process even as the ranking shifts
    if sel_pid
      idx = @proc_rows.index { |r| r[:pid] == sel_pid }
      @proc_sel = idx if idx
    end
    clamp_selection
  end

  def sort_procs(rows)
    if @proc_sort == :mem
      rows.sort_by { |r| [-r[:rss], r[:name]] }
    else
      rows.sort_by { |r| [-r[:cpu], -r[:rss]] }
    end
  end

  # -------------------------------------------------------------------- input

  def handle(key)
    case key
    when 'q', :ctrl_c, :ctrl_d
      @quit = true
    when '?'
      @view = :help
      @focus = :content
    when '1' then select_view(0)
    when '2' then select_view(1)
    when '3' then select_view(2)
    when :tab
      @focus = @focus == :menu ? :content : :menu
    when :escape
      if @view == :help
        @view = :dash
        @focus = :menu
      else
        @focus = :menu
      end
    when :up, 'k'   then move(-1)
    when :down, 'j' then move(1)
    when :page_up   then move(-12) if @focus == :content
    when :page_down then move(12)  if @focus == :content
    when :home      then jump_to(0)
    when :end       then jump_to(@proc_rows.length - 1)
    when :enter
      @focus = :content if @view == :procs
    when :left, 'h'  then cycle_sort(-1)
    when :right, 'l' then cycle_sort(1)
    when 'r' then refresh_procs
    end
  end

  def select_view(index)
    item = MENU[index]
    return unless item

    @view = item[:id]
    @focus = :menu
  end

  def menu_index
    MENU.index { |m| m[:id] == @view } || 0
  end

  def move(delta)
    if @focus == :menu
      idx = (menu_index + delta).clamp(0, MENU.length - 1)
      select_view(idx)
    else
      @proc_sel = (@proc_sel + delta).clamp(0, [@proc_rows.length - 1, 0].max)
      clamp_selection
    end
  end

  def jump_to(index)
    return unless @focus == :content

    @proc_sel = index.clamp(0, [@proc_rows.length - 1, 0].max)
    clamp_selection
  end

  def cycle_sort(dir)
    return unless @view == :procs

    order = %i[cpu mem]
    @proc_sort = order[(order.index(@proc_sort) + dir) % order.length]
    @proc_rows = sort_procs(@proc_rows)
    @proc_sel = 0
    @proc_offset = 0
  end

  # -------------------------------------------------------------------- paint

  def draw
    @screen.present(render_frame)
  end

  # Build a complete frame without touching the terminal.
  def render_frame
    @screen.resize!
    f = @screen.frame
    w = @screen.w
    h = @screen.h

    chrome(f, w, h)

    if w < 56 || h < 14
      Widgets.center(f, 0, h / 2, w, "terminal too small: #{w}x#{h} (need 56x14)", :warn)
    else
      case @view
      when :dash  then draw_dashboard(f, w, h)
      when :procs then draw_processes(f, w, h)
      when :help  then draw_help(f, w, h)
      end
    end

    f
  end

  def set_view(view)
    @view = view if MENU.any? { |m| m[:id] == view }
    self
  end

  def chrome(f, w, h)
    Widgets.box(f, 0, 0, w, h, :border)

    # top border: app name left, clock right
    left = ' rtop '
    Widgets.border_label(f, 1, 0, w - 2, left, :accent, :left)

    right = " #{Time.now.strftime('%a %d %b  %H:%M:%S')} "
    Widgets.border_label(f, 1, 0, w - 2, right, :dim, :right)

    # bottom border: contextual key hints
    Widgets.border_label(f, 1, h - 1, w - 2, hints, :muted, :center)

    # sidebar separator
    sep = @focus == :menu ? :border_hi : :border
    (1).upto(h - 2) { |y| f.put(SIDEBAR_W, y, Widgets::VT, sep) }

    draw_sidebar(f, h)
  end

  def hints
    case @view
    when :procs
      ' ↑↓ move · tab sidebar · ←→ sort · r refresh · ? help · q quit '
    when :help
      ' q quit · esc back '
    else
      ' ↑↓ view · 1-3 jump · ? help · q quit '
    end
  end

  def draw_sidebar(f, h)
    f.put(2, 2, 'VIEWS', :muted)

    MENU.each_with_index do |item, i|
      y = 4 + i * 2
      active = item[:id] == @view
      focused = active && @focus == :menu

      if focused
        f.fill(1, y, SIDEBAR_W - 1, 1, ' ', :sel)
        f.put(1, y, '▌', :focus)
        f.put(3, y, "#{item[:glyph]}  #{item[:label]}", :sel)
      else
        f.put(1, y, '▌', active ? :focus : :border)
        f.put(3, y, "#{item[:glyph]}  #{item[:label]}", active ? :accent : :dim)
      end
    end

    # mini stats pinned to the bottom of the sidebar
    y = h - 8
    return if y < 4 + MENU.length * 2

    f.put(2, y, 'SYSTEM', :muted)
    f.put(2, y + 1, 'load', :dim)
    Widgets.right(f, 2, y + 1, SIDEBAR_W - 3, format('%.2f', SysData.loadavg[0]), :text)
    f.put(2, y + 2, 'procs', :dim)
    Widgets.right(f, 2, y + 2, SIDEBAR_W - 3, @proc_total.to_s, :text)
    f.put(2, y + 3, 'uptime', :dim)
    Widgets.right(f, 2, y + 3, SIDEBAR_W - 3, SysData.format_uptime(@boot), :text)
    f.put(2, y + 5, 'mem', :dim)
    Widgets.right(f, 2, y + 5, SIDEBAR_W - 3, "#{mem_pct}%", :text)
    Widgets.gauge(f, 2, y + 6, SIDEBAR_W - 3, mem_ratio, :track)
  end

  # --- dashboard --------------------------------------------------------

  def draw_dashboard(f, w, h)
    cx = CONTENT_X
    cw = w - CONTENT_X - 2
    cy = 1
    ch = h - 2

    cpu_h = [(ch * 0.45).round, 16].min
    cpu_h = [cpu_h, ch - 6].min
    cpu_h = [cpu_h, 5].max

    panel(f, cx, cy, cw, cpu_h, 'CPU',
          right: "#{@cpu_n} cores   #{pct(@cpu)}")
    Widgets.bars(f, cx + 1, cy + 1, cw - 2, cpu_h - 2, @cpu_hist)

    lower_y = cy + cpu_h

    if cw >= 56
      half = (cw - 1) / 2
      draw_memory_panel(f, cx, lower_y, half, 6)
      draw_system_panel(f, cx + half + 1, lower_y, cw - half - 1, 6)
    else
      draw_memory_panel(f, cx, lower_y, cw, 5)
      draw_system_panel(f, cx, lower_y + 5, cw, 5)
    end

    list_y = lower_y + (cw >= 56 ? 6 : 10)
    list_h = h - 2 - list_y
    return if list_h < 5

    panel(f, cx, list_y, cw, list_h, 'Top processes',
          right: @proc_sort == :mem ? 'by memory' : 'by cpu')
    Widgets.proc_header(f, cx + 1, list_y + 1, cw - 2)
    rows = list_h - 3
    items = @proc_rows.first(rows).map { |r| format_proc(r) }
    Widgets.process_list(f, cx + 1, list_y + 2, cw - 2, rows, items, -1, 0, false)
  end

  def draw_memory_panel(f, x, y, w, h)
    panel(f, x, y, w, h, 'Memory', right: "#{pct(@mem[:used].to_f / [@mem[:total], 1].max)} full")

    gauge_w = [w - 22, 10].max
    iy = y + 1
    f.put(x + 2, iy, 'MEM', :subtitle)
    Widgets.gauge(f, x + 6, iy, gauge_w, mem_ratio)
    Widgets.right(f, x + 2, iy, w - 3, "#{SysData.format_bytes(@mem[:used])}/#{SysData.format_bytes(@mem[:total])}", :text)

    swap_ratio = @mem[:swap_total].positive? ? @mem[:swap_used].to_f / @mem[:swap_total] : 0.0
    f.put(x + 2, iy + 1, 'SWP', :subtitle)
    Widgets.gauge(f, x + 6, iy + 1, gauge_w, swap_ratio)
    Widgets.right(f, x + 2, iy + 1, w - 3,
                  "#{SysData.format_bytes(@mem[:swap_used])}/#{SysData.format_bytes(@mem[:swap_total])}", :text)

    return if h < 5

    avail = @mem[:available].to_f / [@mem[:total], 1].max
    f.put(x + 2, iy + 2, "available #{SysData.format_bytes(@mem[:available])}  (#{pct(avail)})", :muted)
  end

  def draw_system_panel(f, x, y, w, h)
    load1, load5, load15 = SysData.loadavg
    panel(f, x, y, w, h, 'System', right: hostname)

    rows = [
      ['uptime', SysData.format_uptime(@boot)],
      ['load', format('%.2f %.2f %.2f', load1, load5, load15)],
      ['procs', "#{@proc_total}  ·  cpu #{@cpu_n}x"],
      ['mem', "#{pct(mem_ratio)} used"]
    ]
    rows.each_with_index do |(k, v), i|
      f.put(x + 2, y + 1 + i, k, :muted)
      f.put(x + 10, y + 1 + i, v, :text)
    end
  end

  # --- processes --------------------------------------------------------

  def draw_processes(f, w, h)
    cx = CONTENT_X
    cw = w - CONTENT_X - 2
    cy = 1
    ch = h - 2

    sort_label = @proc_sort == :mem ? 'memory' : 'cpu'
    panel(f, cx, cy, cw, ch, 'Processes',
          right: "sort: #{sort_label}   #{@proc_rows.length} shown   #{@proc_total} total")

    ix = cx + 1
    iy = cy + 1
    iw = cw - 2
    ih = ch - 2

    Widgets.proc_header(f, ix, iy, iw)
    f.hline(ix, iy + 1, iw, '─', :track)

    list_y = iy + 2
    list_h = ih - 2
    return if list_h < 1

    items = @proc_rows.map { |r| format_proc(r) }
    Widgets.process_list(f, ix, list_y, iw, list_h, items, @proc_sel, @proc_offset, @focus == :content)
    Widgets.scrollbar(f, ix + iw - 1, list_y, list_h, items.length, list_h, @proc_offset)
  end

  # --- help -------------------------------------------------------------

  KEYS = [
    ['↑ ↓ / j k', 'move in the sidebar, or scroll the list when it has focus'],
    ['tab',       'toggle focus between sidebar and content'],
    ['← → / h l', 'change process sort order (cpu% / memory)'],
    ['1 2 3',     'jump straight to Dashboard / Processes / Help'],
    ['enter',     'focus the content pane'],
    ['pgup/pgdn', 'move a page at a time'],
    ['home/end',  'jump to the top / bottom of the list'],
    ['r',         'refresh the process table now'],
    ['esc',       'back to the sidebar'],
    ['?',         'this help'],
    ['q / ctrl-c', 'quit']
  ].freeze

  def draw_help(f, w, h)
    cx = CONTENT_X
    cw = w - CONTENT_X - 2
    cy = 1
    ch = h - 2

    panel(f, cx, cy, cw, ch, 'Help', right: 'rtop')

    text = [
      [:title,  'A tiny system monitor written in pure Ruby.'],
      [:dim,    ''],
      [:muted,  'Everything here is io/console + ANSI escape codes: no curses,'],
      [:muted,  'no gems, no native extensions.'],
      [:dim,    ''],
      [:subtitle, 'KEYS'],
    ]

    y = cy + 2
    text.each do |style, line|
      f.put(cx + 3, y, line, style)
      y += 1
    end
    y += 1

    last = cy + ch - 2
    KEYS.each do |keys, desc|
      break if y > last - 1
      f.put(cx + 3, y, format('%-14s', keys), :accent)
      f.put(cx + 18, y, truncate(desc, cw - 20), :text)
      y += 1
    end

    f.put(cx + 3, last, 'Data source: /proc (stat, meminfo, loadavg, uptime).', :muted)
  end

  def truncate(str, width)
    return str if width <= 0 || Term.text_width(str) <= width

    out = +''
    str.each_char do |ch|
      break if Term.text_width(out) + Term.width(ch) > width - 1
      out << ch
    end
    out << '…'
  end

  # ----------------------------------------------------------------- helpers

  def panel(f, x, y, w, h, title, right: nil)
    Widgets.box(f, x, y, w, h, :border)
    Widgets.border_label(f, x + 1, y, w - 2, title, :title, :left)
    Widgets.border_label(f, x + 1, y, w - 2, "#{right} ", :dim, :right) if right
  end

  def format_proc(row)
    {
      pid:  row[:pid],
      name: row[:name],
      cpu:  format('%.1f', row[:cpu]),
      mem:  SysData.format_bytes(row[:rss])
    }
  end

  def mem_ratio
    return 0.0 unless @mem[:total].positive?
    (@mem[:used].to_f / @mem[:total]).clamp(0.0, 1.0)
  end

  def mem_pct
    (mem_ratio * 100).round
  end

  def pct(ratio)
    format('%.1f%%', ratio * 100)
  end

  def hostname
    @hostname ||= begin
      File.read('/proc/sys/kernel/hostname').strip
    rescue StandardError
      'localhost'
    end
  end

  # keep the selected row inside the visible window
  def clamp_selection
    max = [@proc_rows.length - 1, 0].max
    @proc_sel = @proc_sel.clamp(0, max)

    rows = visible_rows
    if @proc_sel < @proc_offset
      @proc_offset = @proc_sel
    elsif @proc_sel >= @proc_offset + rows
      @proc_offset = @proc_sel - rows + 1
    end
    @proc_offset = @proc_offset.clamp(0, [@proc_rows.length - rows, 0].max)
  end

  def visible_rows
    @screen.h - 6
  end
end
