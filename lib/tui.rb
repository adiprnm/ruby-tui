# frozen_string_literal: true
#
# TUI -- a small, pure-Ruby terminal UI toolkit.
#
#   require 'tui'
#
#   app = TUI::App.new(TUI::Label.new('hello'))
#   app.on_key('q') { app.quit }
#   app.run
#
# Nothing here needs a gem: the terminal is io/console plus ANSI escapes and
# the renderer only writes the cells that changed.

require 'stringio'

require_relative 'tui/version'
require_relative 'tui/geometry'
require_relative 'tui/event'
require_relative 'tui/term'
require_relative 'tui/text'
require_relative 'tui/util'
require_relative 'tui/style'
require_relative 'tui/theme'
require_relative 'tui/scroll'
require_relative 'tui/canvas'
require_relative 'tui/screen'
require_relative 'tui/component'
require_relative 'tui/app'

require_relative 'tui/layout/distribute'
require_relative 'tui/layout/stack'
require_relative 'tui/layout/box'
require_relative 'tui/layout/center'
require_relative 'tui/layout/viewport'
require_relative 'tui/layout/overlay'
require_relative 'tui/layout/spacer'

require_relative 'tui/components/label'
require_relative 'tui/components/button'
require_relative 'tui/components/text_buffer'
require_relative 'tui/components/input'
require_relative 'tui/components/text_area'
require_relative 'tui/components/choice'
require_relative 'tui/components/list'
require_relative 'tui/components/table'
require_relative 'tui/components/tabs'
require_relative 'tui/components/form'
require_relative 'tui/components/progress_bar'
require_relative 'tui/components/charts'

module TUI
  # Render a component tree off-screen at a fixed size; returns the Canvas.
  # Used by tests and by frame-dumping tools.
  def self.render(root, cols: 80, rows: 24)
    app = App.new(root, out: StringIO.new, size: [cols, rows])
    app.render_frame
  end
end
