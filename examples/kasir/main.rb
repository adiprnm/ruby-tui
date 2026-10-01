# frozen_string_literal: true
#
# Kasir entry point:
#
#   ruby examples/kasir/main.rb                    interactive
#   ruby examples/kasir/main.rb --snapshot         one frame to stdout
#   ruby examples/kasir/main.rb --snapshot --state=pay --w=100 --h=30
#
# states: (empty) | cart | pay | receipt

require 'stringio'

$LOAD_PATH.unshift(File.expand_path('../../lib', __dir__))
require 'tui'

require_relative 'app'

module Kasir
  module CLI
    USAGE = <<~TEXT
      KASIR -- a cashier till built with the TUI toolkit

        ruby examples/kasir/main.rb                    interactive
        ruby examples/kasir/main.rb --snapshot         dump one frame
        ruby examples/kasir/main.rb --snapshot --state=pay --w=100 --h=30
                                   --state=empty|cart|pay|receipt

      keys: tab focus · enter add/pay · +/- qty · d remove · f2 pay · q quit
           in the receipt: pgup/pgdn scroll · enter = new order
    TEXT

    class << self
      def run(argv)
        options = parse(argv)
        app = App.new
        options[:snapshot] ? snapshot(app, options) : interactive(app)
        app
      end

      def parse(argv)
        options = { snapshot: false, state: nil, w: nil, h: nil }
        argv.each do |arg|
          case arg
          when '--snapshot'          then options[:snapshot] = true
          when /\A--state=(\w+)\z/   then options[:state] = Regexp.last_match(1)
          when /\A--w=(\d+)\z/       then options[:w] = Regexp.last_match(1).to_i
          when /\A--h=(\d+)\z/       then options[:h] = Regexp.last_match(1).to_i
          when /\A--cash=(\S+)\z/    then options[:cash] = Regexp.last_match(1)
          when '-h', '--help'        then puts USAGE
                                        exit 0
          else
            warn "kasir: unknown option #{arg.inspect}"
            puts USAGE
            exit 1
          end
        end
        options
      end

      def snapshot(app, options)
        case options[:state]
        when 'cart'    then app.demo_cart!
        when 'pay'     then app.demo_payment!(options[:cash] || '150000')
        when 'receipt' then app.demo_receipt!
        end

        cols = options[:w] || 96
        rows = options[:h] || 30
        ui = TUI::App.new(app.root, out: StringIO.new, size: [cols, rows])
        app.attach(ui)
        print ui.render_lines.join("\n"), "\n"
        print TUI::Style::RESET
      end

      def interactive(app)
        ui = TUI::App.new(app.root)
        app.attach(ui)

        ui.on_key('q') { ui.quit }
        ui.on_key(:ctrl_c) { ui.quit }
        ui.on_key(:f2) { app.open_payment }
        ui.on_key('p') { app.open_payment }
        ui.on_key('+') { app.change_qty(1) }
        ui.on_key('=') { app.change_qty(1) }
        ui.on_key('-') { app.change_qty(-1) }
        ui.on_key('d') { app.remove_selected }
        ui.on_key(:escape) { app.cancel }
        ui.on_key(:enter) { app.confirm if app.showing_receipt? }
        ui.on_key(:page_down) { app.scroll_receipt(4) }
        ui.on_key(:page_up) { app.scroll_receipt(-4) }

        ui.every(1.0) { app.refresh_change if app.overlay_shown? }
        ui.run
      end
    end
  end
end

Kasir::CLI.run(ARGV) if $PROGRAM_NAME == __FILE__
