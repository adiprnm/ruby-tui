#!/usr/bin/env ruby
# frozen_string_literal: true
#
# A two-minute tour of the toolkit: a form, validation, a button and a
# label that reacts. Run it with `ruby examples/hello.rb`, or dump a frame
# with `ruby examples/hello.rb --snapshot`.

$LOAD_PATH.unshift(File.expand_path('../lib', __dir__))
require 'tui'

# 1. widgets ------------------------------------------------------------
form = TUI::Form.new(label_width: 10)
form.text(:name, 'Name', value: 'Ruby', required: true)
form.password(:secret, 'Secret')
form.toggle(:news, 'Newsletter', value: true)
form.button('Save')

status = TUI::Label.new('fill it in and press Save', style: :muted)

# 2. events -------------------------------------------------------------
form.on(:submit) { |values| status.text = "hello #{values[:name]}!" }
form.on(:invalid) { |errors| status.text = "check: #{errors.keys.join(', ')}" }

# 3. layout -------------------------------------------------------------
content = TUI::Layout::Stack.new(direction: :vertical, gap: 1)
content.add(form, size: TUI.auto)
content.add(status, size: TUI.fixed(1))

root = TUI::Layout::Box.new(title: ' hello ',
                            footer: ' tab focus · enter save · q quit ')
root.add(content)

# 4. run ----------------------------------------------------------------
if ARGV.include?('--snapshot')
  cols = ARGV.grep(/\A--w=/).first.to_s.split('=').last.to_i
  rows = ARGV.grep(/\A--h=/).first.to_s.split('=').last.to_i
  cols = 60 if cols.zero?
  rows = 14 if rows.zero?
  print TUI.render(root, cols: cols, rows: rows).lines.join("\n"), "\n"
else
  app = TUI::App.new(root)
  app.on_key('q') { app.quit }
  app.run
end
