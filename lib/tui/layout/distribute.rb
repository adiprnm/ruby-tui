# frozen_string_literal: true
#
# Distribute -- resolve width/height specs against the space available.
# Shared by Layout::Stack (one axis) and Table (column widths).

module TUI
  module Layout
    module Distribute
      class << self
        # specs: [[spec, measured_size], ...] where measured_size is only
        # used for TUI.auto entries. Returns integers that are always >= 0
        # and never add up to more than `total`.
        def split(specs, total, gap: 0)
          count = specs.length
          return [] if count.zero?

          avail = [total - (gap * (count - 1)), 0].max
          sizes = Array.new(count)
          flex_weight = 0

          specs.each_with_index do |(spec, measured), i|
            sizes[i] =
              case spec
              when Units::Fixed then spec.value
              when Integer      then spec           # a bare number is fixed
              when Units::Ratio then (avail * spec.ratio).round
              when Units::Flex  then flex_weight += spec.weight; nil
              else measured || 0
              end
          end

          # Fixed/ratio/auto sizes share the space: whatever comes later
          # gets what is left, so the sum can never exceed the total.
          used = 0
          sizes.each_index do |i|
            next if sizes[i].nil?

            sizes[i] = [[sizes[i], 0].max, [avail - used, 0].max].min
            used += sizes[i]
          end

          remaining = [avail - used, 0].max
          if flex_weight.positive?
            given = 0
            last = nil
            specs.each_with_index do |(spec, _measured), i|
              next unless sizes[i].nil?

              share = (remaining * spec.weight / flex_weight.to_f).floor
              sizes[i] = share
              given += share
              last = i
            end
            # rounding leftovers go to the last flexible slot
            sizes[last] += remaining - given if last
          end

          sizes.map { |size| [[size || 0, 0].max, avail].min }
        end
      end
    end
  end
end
