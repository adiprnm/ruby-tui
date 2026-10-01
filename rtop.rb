#!/usr/bin/env ruby
# frozen_string_literal: true
#
# rtop -- a small system monitor TUI in pure Ruby.
#
#   ruby rtop.rb                 interactive
#   ruby rtop.rb --snapshot      print one frame and exit (no raw mode)
#   ruby rtop.rb --snapshot --view=procs --w=120 --h=36
#
# Nothing here needs a gem: terminal handling is io/console + ANSI escapes,
# the metrics come from /proc.

$LOAD_PATH.unshift(File.expand_path('lib', __dir__))

require 'term'
require 'theme'
require 'screen'
require 'widgets'
require 'sysdata'
require 'app'

module Rtop
  module_function

  def parse_args(argv)
    opts = { snapshot: false, view: nil, w: nil, h: nil, frames: 1 }

    argv.each do |arg|
      case arg
      when '--snapshot'          then opts[:snapshot] = true
      when /\A--view=(\w+)\z/    then opts[:view] = Regexp.last_match(1).to_sym
      when /\A--w=(\d+)\z/       then opts[:w] = Regexp.last_match(1).to_i
      when /\A--h=(\d+)\z/       then opts[:h] = Regexp.last_match(1).to_i
      when /\A--frames=(\d+)\z/  then opts[:frames] = Regexp.last_match(1).to_i
      when '-h', '--help'
        puts usage
        exit 0
      else
        warn "rtop: unknown option #{arg.inspect}"
        puts usage
        exit 1
      end
    end
    opts
  end

  def usage
    <<~TEXT
      rtop -- pure-Ruby system monitor

        ruby rtop.rb                             interactive TUI
        ruby rtop.rb --snapshot                  dump one frame to stdout
        ruby rtop.rb --snapshot --view=procs     dump the process view
                                --w=120 --h=36   pretend terminal size
                                --frames=3       dump N frames

      keys: ↑↓/jk move · tab focus · ←→/hl sort · 1-3 views · r refresh · q quit
    TEXT
  end

  # Non-interactive: render straight to stdout so it works under pipes,
  # CI, or `less -R`.
  def snapshot(opts)
    ENV['COLUMNS'] = opts[:w].to_s if opts[:w]
    ENV['LINES']   = opts[:h].to_s if opts[:h]

    app = App.new($stdout)
    app.set_view(opts[:view]) if opts[:view]
    app.prime

    frames = [opts[:frames], 1].max
    frames.times do |i|
      app.sample(force: true)
      $stdout.print(app.render_frame.lines.join("\n"), "\n")
      if i < frames - 1
        $stdout.print(('─' * Term.size[0]), "\n")
        sleep 0.4
      end
    end
    $stdout.print(Style::RESET)
  end

  # Interactive: alternate screen + raw mode, always restored.
  def interactive
    unless $stdin.tty? && $stdout.tty?
      warn 'rtop: not a tty. Use --snapshot to render a frame to stdout.'
      exit 1
    end

    app = App.new($stdout)

    $stdout.print(Term::ALT_ON + Term::HIDE_CURSOR + Term::CLEAR)
    $stdout.flush

    $stdin.raw do
      app.run
    end
  rescue Interrupt
    # ctrl-c arrives as a byte in raw mode; this is just belt and braces
  ensure
    $stdout.print(Term::SHOW_CURSOR + Term::ALT_OFF + Style::RESET)
    $stdout.flush
  end
end

if $PROGRAM_NAME == __FILE__
  opts = Rtop.parse_args(ARGV)
  opts[:snapshot] ? Rtop.snapshot(opts) : Rtop.interactive
end
