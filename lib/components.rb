# frozen_string_literal: true
#
# Components -- the application-specific UI, as opposed to the generic
# widgets in lib/widgets.
#
# Contract: a component is constructed with the application state (the App
# instance, duck-typed: it only reads from it) and draws itself into a
# rectangle:
#
#   component.draw(frame, x, y, w, h)
#
# Components never mutate state and never touch the terminal, so they can be
# rendered into a frame at any size and compared in tests.

module Components
  # The chrome owns the sidebar; views get everything to its right, with one
  # blank column so two borders never touch.
  SIDEBAR_W = 20
  CONTENT_X = SIDEBAR_W + 1

  # Below this there is no point pretending: show the size hint instead.
  MIN_W = 56
  MIN_H = 14

  # The view list is shared by the sidebar (draws it) and App (maps keys and
  # the number shortcuts onto it).
  MENU = [
    { id: :dash,  key: '1', glyph: '◈', label: 'Dashboard' },
    { id: :procs, key: '2', glyph: '▤', label: 'Processes' },
    { id: :help,  key: '3', glyph: '?', label: 'Help' }
  ].freeze

  class << self
    # "12.3%" -- ratios are always 0.0..1.0 inside rtop and always shown
    # with one decimal.
    def pct(ratio)
      format('%.1f%%', ratio * 100)
    end

    # A /proc process row -> what the table widget expects to draw.
    def proc_row(row)
      {
        pid:  row[:pid],
        name: row[:name],
        cpu:  format('%.1f', row[:cpu]),
        mem:  SysData.format_bytes(row[:rss])
      }
    end
  end
end

require_relative 'components/too_small'
require_relative 'components/chrome'
require_relative 'components/dashboard'
require_relative 'components/processes'
require_relative 'components/help'
