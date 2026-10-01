# frozen_string_literal: true
#
# Widgets -- meters: the horizontal gauge.
#
# Reopens the Widgets namespace from lib/widgets.rb; the public API is
# always Widgets.<name>(frame, ...).

require_relative '../term'
require_relative '../theme'

module Widgets
  class << self
    def gauge(f, x, y, w, ratio, track = :track)
      return if w < 2

      ratio = ratio.clamp(0.0, 1.0)
      inner = w - 2
      filled = (inner * ratio).round

      inner.times do |i|
        if i < filled
          t = inner <= 1 ? ratio : i.to_f / (inner - 1)
          f.put(x + 1 + i, y, '█', Style.ramp(t))
        else
          f.put(x + 1 + i, y, '░', track)
        end
      end
      f.put(x, y, '[', :dim)
      f.put(x + w - 1, y, ']', :dim)
      self
    end

    # Vertical bar chart, w columns x h rows, values 0.0..1.0.
    # Drawn bottom-up with eighth blocks, tinted by height.
  end
end
