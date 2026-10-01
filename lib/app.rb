# frozen_string_literal: true
#
# App -- the hub. It owns the state (sampled from /proc), the main loop, key
# handling, and it wires the UI components together. Drawing itself lives in
# lib/components/*; this file never paints a cell.

require_relative 'term'
require_relative 'theme'
require_relative 'screen'
require_relative 'widgets'
require_relative 'sysdata'
require_relative 'sampler'
require_relative 'components'

class App
  TICK = 0.1   # input/render cadence, seconds

  # ------------------------------------------------------------- state
  # Raw metrics come from the Sampler; the selection is UI state and lives
  # here. This is the whole surface the components are allowed to read.

  attr_reader :view, :focus, :proc_rows, :proc_sel, :proc_offset, :proc_sort,
              :proc_total

  def cpu;      @sampler.cpu;        end
  def cpu_hist; @sampler.history;    end
  def cpu_n;    @sampler.cpu_count;  end
  def mem;      @sampler.mem;        end
  def loadavg;  @sampler.loadavg;    end
  def boot;     @sampler.boot;       end
  def hostname; @sampler.hostname;   end

  def initialize(out)
    @screen  = Screen.new(out)
    @sampler = Sampler.new

    @view   = :dash
    @focus  = :menu
    @quit   = false

    @proc_rows   = []
    @proc_sel    = 0
    @proc_offset = 0
    @proc_sort   = :cpu
    @proc_total  = 0

    @chrome    = Components::Chrome.new(self)
    @too_small = Components::TooSmall.new(self)
    @views = {
      dash:  Components::Dashboard.new(self),
      procs: Components::Processes.new(self),
      help:  Components::Help.new(self)
    }
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

  # Sample a few times so the chart and the process table have something to
  # show. Used by --snapshot and by the tests.
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
    resampled = @sampler.tick(force: force)
    sync_processes if resampled
  end

  # Re-rank the freshly sampled process table and keep the cursor on the
  # same process: the ranking moves constantly, the selection should not.
  def refresh_processes!
    sample(force: true)
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
    when 'q', :ctrl_c, :ctrl_d then @quit = true
    when '?'                   then show(:help, :content)
    when '1'                   then select_view(0)
    when '2'                   then select_view(1)
    when '3'                   then select_view(2)
    when :tab                  then @focus = @focus == :menu ? :content : :menu
    when :escape               then leave_focused_view
    when :up, 'k'              then move(-1)
    when :down, 'j'            then move(1)
    when :page_up              then move(-12) if @focus == :content
    when :page_down            then move(12)  if @focus == :content
    when :home                 then jump_to(0)
    when :end                  then jump_to(@proc_rows.length - 1)
    when :enter                then @focus = :content if @view == :procs
    when :left, 'h'            then cycle_sort(-1)
    when :right, 'l'           then cycle_sort(1)
    when 'r'                   then refresh_processes!
    end
  end

  def select_view(index)
    item = Components::MENU[index]
    show(item[:id], :menu) if item
  end

  def set_view(view)
    show(view, :menu) if Components::MENU.any? { |m| m[:id] == view }
    self
  end

  def show(view, focus)
    @view = view
    @focus = focus
    self
  end

  def menu_index
    Components::MENU.index { |m| m[:id] == @view } || 0
  end

  def leave_focused_view
    return show(:dash, :menu) if @view == :help

    @focus = :menu
  end

  def move(delta)
    if @focus == :menu
      select_view((menu_index + delta).clamp(0, Components::MENU.length - 1))
    else
      jump_to(@proc_sel + delta)
    end
  end

  def jump_to(index)
    return unless @focus == :content

    @proc_sel = index.clamp(0, [@proc_rows.length - 1, 0].max)
    clamp_selection
  end

  def cycle_sort(direction)
    return unless @view == :procs

    order = %i[cpu mem]
    @proc_sort = order[(order.index(@proc_sort) + direction) % order.length]
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
    frame = @screen.frame
    w = @screen.w
    h = @screen.h

    if w < Components::MIN_W || h < Components::MIN_H
      @too_small.draw(frame, 0, 0, w, h)
    else
      @chrome.draw(frame, 0, 0, w, h)
      @views.fetch(@view).draw(frame, *content_rect(w, h))
    end

    frame
  end

  # -------------------------------------------------------------------- state

  def mem_ratio
    total = mem[:total]
    return 0.0 unless total.positive?

    (mem[:used].to_f / total).clamp(0.0, 1.0)
  end

  def mem_pct
    (mem_ratio * 100).round
  end

  private

  # Adopt a fresh process table.
  def sync_processes
    selected_pid = @proc_rows[@proc_sel] && @proc_rows[@proc_sel][:pid]

    @proc_rows  = sort_procs(@sampler.processes)
    @proc_total = @sampler.process_count

    follow(selected_pid) if selected_pid
    clamp_selection
  end

  # [x, y, w, h] of the area the views may use.
  def content_rect(w, h)
    [Components::CONTENT_X, 1, w - Components::CONTENT_X - 2, h - 2]
  end

  def follow(pid)
    index = @proc_rows.index { |r| r[:pid] == pid }
    @proc_sel = index if index
  end

  # Keep the selected row inside the visible window.
  def clamp_selection
    @proc_sel = @proc_sel.clamp(0, [@proc_rows.length - 1, 0].max)

    window = Components::Processes.visible_rows(@screen.h)
    if @proc_sel < @proc_offset
      @proc_offset = @proc_sel
    elsif @proc_sel >= @proc_offset + window
      @proc_offset = @proc_sel - window + 1
    end
    @proc_offset = @proc_offset.clamp(0, [@proc_rows.length - window, 0].max)
  end

end
