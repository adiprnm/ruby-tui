# frozen_string_literal: true
#
# ruby-tui -- a small, pure-Ruby terminal UI toolkit.
#
#   require 'ruby-tui'
#
#   app = TUI::App.new(TUI::Label.new('hello'))
#   app.on_key('q') { app.quit }
#   app.run
#
# The library lives under the TUI:: module; this file only exists so that
# `require 'ruby-tui'` (the gem name, hyphens and all) loads it. Bundler's
# `Bundler.require` picks the same file up automatically.
require_relative 'tui'
