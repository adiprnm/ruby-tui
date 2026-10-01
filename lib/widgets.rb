# frozen_string_literal: true
#
# Widgets -- small drawing primitives that paint onto a Frame.
#
# A widget is a module function that takes the frame first and draws inside
# the rectangle it is handed. Nothing keeps state and nothing reads
# application state, which makes widgets reusable and trivial to test:
#
#   Widgets.box(frame, 0, 0, 40, 12)
#   Widgets.panel(frame, 0, 0, 40, 12, 'CPU', right: '12 cores')
#   Widgets.gauge(frame, 2, 3, 20, 0.42)
#
# The implementations live in lib/widgets/*.rb.

module Widgets
  # box drawing glyphs
  TL = '╭'; TR = '╮'; BL = '╰'; BR = '╯'
  HZ = '─'; VT = '│'
  DOT = '·'

  # eighth blocks, indexed by eighths filled: BLOCKS[0] is blank
  BLOCKS = [' ', '▁', '▂', '▃', '▄', '▅', '▆', '▇', '█'].freeze
end

require_relative 'widgets/box'
require_relative 'widgets/text'
require_relative 'widgets/meter'
require_relative 'widgets/chart'
require_relative 'widgets/table'
require_relative 'widgets/panel'
