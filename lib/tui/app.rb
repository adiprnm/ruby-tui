# frozen_string_literal: true
#
# App -- the runtime. It owns the loop, the focus, the global key bindings
# and the timers, and it drives the diffed renderer. Everything else in the
# library is a component plugged into it:
#
#   app = TUI::App.new(root)
#   app.on_key('q') { app.quit }
#   app.every(1.0) { refresh }
#   app.run

require_relative 'geometry'
require_relative 'term'
require_relative 'canvas'
require_relative 'screen'
require_relative 'component'

module TUI
  class App
    DEFAULT_TICK = 0.1

    attr_reader :root, :focused, :canvas

    def initialize(root, out: $stdout, size: nil, tick: DEFAULT_TICK)
      @root  = root
      @out   = out
      @tick  = tick
      @size  = size

      @screen = Screen.new(out, size: size)
      @keys   = {}
      @timers = []
      @resize_handlers = []
      @quit = false
      @focused = nil

      @root.mount(self)
      @last_size = @screen.to_size
      focus_first
    end

    # --- global key bindings ----------------------------------------------

    # binding: a printable character ("q", "1") or a key name (:escape, :enter)
    def on_key(binding, &block)
      @keys[normalize(binding)] = block
      self
    end

    # Run a block every `seconds` (used for sampling, animation, clocks).
    # The first run happens on the first loop, so timers can prime state.
    def every(seconds, &block)
      @timers << { interval: seconds, at: 0.0, block: block }
      self
    end

    def on_resize(&block)
      @resize_handlers << block
      self
    end

    # --- focus ------------------------------------------------------------

    def focusables
      @root.focusables
    end

    def focus(component)
      return self if component.equal?(@focused)
      return self if component && !component.focusable?

      previous = @focused
      @focused = component
      previous.emit(Events::BLUR) if previous
      component.emit(Events::FOCUS) if component
      self
    end

    def focus_first
      focus(focusables.first)
    end

    def focus_next(direction = 1)
      list = focusables
      return self if list.empty?

      if @focused.nil?
        focus(list.first)
      else
        index = list.index(@focused) || 0
        focus(list[(index + direction) % list.length])
      end
    end

    def focus_previous
      focus_next(-1)
    end

    # --- run loop ---------------------------------------------------------

    def quit
      @quit = true
    end

    def quit?
      @quit
    end

    def run
      Term.session(@out) do
        until @quit
          run_timers
          render
          key = Term.read_key(@tick)
          dispatch(key) if key
        end
      end
    end

    # Lay out and paint one frame; returns the canvas. Public so tests and
    # --snapshot style tools can render without a terminal.
    def render_frame
      reflow
      @canvas = @screen.frame
      @root.layout(Rect.new(0, 0, @screen.w, @screen.h))
      @root.render(@canvas)
      @canvas
    end

    def render
      @screen.present(render_frame)
    end

    def render_lines
      render_frame.lines
    end

    def size
      @screen.to_size
    end

    # --- internals --------------------------------------------------------

    def clock
      Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end

    private

    def reflow
      return unless @screen.resize!

      current = @screen.to_size
      @last_size = current
      @resize_handlers.each { |handler| handler.call(*current) }
    end

    def dispatch(key)
      # a component that got hidden (a switched pane, say) must not keep
      # swallowing keys
      focus_first if @focused && !@focused.visible?

      target = @focused
      return if target && target.handle_key(key)

      case key.name
      when :tab    then focus_next
      when :backtab then focus_previous
      else
        handler = @keys[normalize(key.name)]
        handler.call(key) if handler
      end
    end

    def run_timers
      now = clock
      @timers.each do |timer|
        next if now - timer[:at] < timer[:interval]

        timer[:at] = now
        timer[:block].call
      end
    end

    def normalize(binding)
      binding.is_a?(String) ? binding : binding.to_sym
    end
  end
end
