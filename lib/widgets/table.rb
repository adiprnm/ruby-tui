# frozen_string_literal: true
#
# Widgets -- the process table: column layout, header and rows.
#
# Reopens the Widgets namespace from lib/widgets.rb; the public API is
# always Widgets.<name>(frame, ...).

require_relative '../term'
require_relative '../theme'

module Widgets
  class << self
    # --- process table ---------------------------------------------------
    #
    # Column layout, shared by the header and the rows:
    #   x+1            PID ......... width 8
    #   x+10           COMMAND ..... width proc_name_w(w)
    #   x+11+name_w    %CPU ........ width 6
    #   x+18+name_w    MEM ......... width 7
    # Total used: name_w + 25, i.e. one spare column for the scrollbar.

    PID_W = 8

    def proc_name_w(w)
      [w - 26, 8].max
    end

    def proc_header(f, x, y, w, style = :muted)
      nw = proc_name_w(w)
      f.put(x + 1, y, 'PID'.ljust(PID_W), style)
      f.put(x + 10, y, 'COMMAND'.ljust(nw), style)
      f.put(x + 11 + nw, y, '%CPU'.rjust(6), style)
      f.put(x + 18 + nw, y, 'MEM'.rjust(7), style)
      self
    end

    # items: array of { pid:, name:, cpu:, mem: } hashes (cpu/mem pre-formatted)
    def process_list(f, x, y, w, h, items, selected, offset, focused)
      return self if items.empty?

      nw = proc_name_w(w)
      visible = items[offset, h] || []

      visible.each_with_index do |p, i|
        idx    = offset + i
        row    = y + i
        is_sel = focused && idx == selected

        if is_sel
          f.fill(x, row, w, 1, ' ', :sel)
        elsif !focused && idx == selected
          f.fill(x, row, w, 1, ' ', :sel_dim)
        end

        label_style = is_sel || (!focused && idx == selected) ? :sel : :text
        meta_style  = is_sel || (!focused && idx == selected) ? :sel_dim : :muted

        name = p[:name].to_s
        # Only pay for a width walk when the name could actually be too
        # long: for ASCII, chars == cells.
        if name.length > nw || !name.ascii_only?
          if Term.text_width(name) > nw
            name = truncate(name, nw)
          end
        end

        f.put(x + 1, row, format('%-*s', PID_W, p[:pid].to_s), meta_style)
        f.put(x + 10, row, format('%-*s', nw, name), label_style)
        f.put(x + 11 + nw, row, format('%6s', p[:cpu].to_s), cpu_style(p[:cpu], is_sel))
        f.put(x + 18 + nw, row, format('%7s', p[:mem].to_s), meta_style)
      end
      self
    end

    def cpu_style(cpu, selected)
      return :sel if selected
      v = cpu.to_s.to_f
      if v >= 50 then :bad
      elsif v >= 15 then :warn
      else :dim
      end
    end

    def scrollbar(f, x, y, h, total, visible, offset)
      return if total <= visible || h < 2

      bar_h = [(h * visible / total.to_f).round, 1].max
      max_pos = h - bar_h
      pos = total == visible ? 0 : (offset * max_pos / (total - visible).to_f).round
      f.fill(x, y, 1, h, '│', :track)
      f.fill(x, y + pos, 1, bar_h, '│', :border_hi)
      self
    end
  end
end
