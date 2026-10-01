# frozen_string_literal: true
#
# rtop entry point:
#
#   ruby examples/rtop/main.rb                 interactive
#   ruby examples/rtop/main.rb --snapshot      one frame to stdout
#   ruby examples/rtop/main.rb --snapshot --view=procs --w=120 --h=34

require 'stringio'

# Running from a checkout: put lib/ on the load path before requiring the
# toolkit (an installed gem would not need this).
$LOAD_PATH.unshift(File.expand_path('../../lib', __dir__))
require 'tui'

require_relative 'app'

module Rtop
  module CLI
    VIEWS = { 'dash' => 0, 'procs' => 1, 'help' => 2 }.freeze

    USAGE = <<~TEXT
      rtop -- a system monitor built with the TUI toolkit

        ruby examples/rtop/main.rb                 interactive
        ruby examples/rtop/main.rb --snapshot      dump one frame to stdout
        ruby examples/rtop/main.rb --theme=plain   no colours at all (see Theme)
        ruby examples/rtop/main.rb --snapshot --view=procs --w=120 --h=34
                                   --frames=N --delay=SECONDS

      keys: arrows move (or sort) · tab focus · 1-3 views · r refresh · q quit
    TEXT

    class << self
      def run(argv)
        options = parse(argv)
        TUI::Theme.install(options[:theme]) if options[:theme]
        app = App.new
        options[:snapshot] ? snapshot(app, options) : interactive(app)
        app
      end

      def parse(argv)
        options = { snapshot: false, view: nil, w: nil, h: nil, frames: 1, delay: 0.4 }
        argv.each do |arg|
          case arg
          when '--snapshot'         then options[:snapshot] = true
          when /\A--theme=(\w+)\z/   then options[:theme] = Regexp.last_match(1)
          when /\A--view=(\w+)\z/   then options[:view] = Regexp.last_match(1)
          when /\A--w=(\d+)\z/      then options[:w] = Regexp.last_match(1).to_i
          when /\A--h=(\d+)\z/      then options[:h] = Regexp.last_match(1).to_i
          when /\A--frames=(\d+)\z/ then options[:frames] = Regexp.last_match(1).to_i
          when /\A--delay=([\d.]+)\z/ then options[:delay] = Regexp.last_match(1).to_f
          when '-h', '--help'       then puts USAGE
                                       exit 0
          else
            warn "rtop: unknown option #{arg.inspect}"
            puts USAGE
            exit 1
          end
        end
        options
      end

      # Non-interactive: render into an off-screen canvas and print it. No
      # raw mode, no alternate screen, works over a pipe.
      def snapshot(app, options)
        cols = options[:w] || 100
        rows = options[:h] || 30
        view = VIEWS[options[:view]]
        app.select_tab(view) if view

        tui = TUI::App.new(app.root, out: StringIO.new, size: [cols, rows])

        frames = [options[:frames], 1].max
        frames.times do |i|
          # sample a few times so the chart and the process table have real
          # numbers: cpu% is a delta between two snapshots
          3.times { app.refresh!; sleep 0.25 }
          print tui.render_lines.join("\n")
          print "\n"
          next unless i < frames - 1

          print('─' * cols, "\n")
          sleep options[:delay]
        end
        print TUI::Style::RESET
      end

      def interactive(app)
        tui = TUI::App.new(app.root)

        tui.on_key('q') { tui.quit }
        tui.on_key(:ctrl_c) { tui.quit }
        VIEWS.each_value { |view| tui.on_key((view + 1).to_s) { app.select_tab(view) } }
        tui.on_key(:left)  { app.sort(-1) }
        tui.on_key(:right) { app.sort(1) }
        tui.on_key('r')    { app.refresh! }

        tui.every(App::SAMPLE_PERIOD) { app.tick }
        tui.run
      end
    end
  end
end

Rtop::CLI.run(ARGV) if $PROGRAM_NAME == __FILE__
