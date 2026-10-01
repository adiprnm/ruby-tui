# frozen_string_literal: true
#
# Widgets -- small drawing primitives on top of a Frame.
# Everything is plain Ruby string/drawing math; no state, no widgets objects.

module Widgets
  TL = '╭'; TR = '╮'; BL = '╰'; BR = '╯'
  HZ = '─'; VT = '│'
  BLOCKS = [' ', '▁', '▂', '▃', '▄', '▅', '▆', '▇', '█'].freeze
  DOT = '·'

  class << self
    # --- boxes ----------------------------------------------------------

    # Rounded box of w x h cells with the top-left corner at (x, y).
    def box(f, x, y, w, h, style = :border)
      return if w < 2 || h < 2

      f.hline(x + 1, y, w - 2, HZ, style)
      f.hline(x + 1, y + h - 1, w - 2, HZ, style)
      (y + 1).upto(y + h - 2) do |yy|
        f.put(x, yy, VT, style)
        f.put(x + w - 1, yy, VT, style)
      end
      f.put(x, y, TL, style)
      f.put(x + w - 1, y, TR, style)
      f.put(x, y + h - 1, BL, style)
      f.put(x + w - 1, y + h - 1, BR, style)
      self
    end

    # Draw a label into a horizontal border line, masking the border char.
    # align: :left, :center or :right.
    def border_label(f, x, y, w, text, style = :title, align = :left)
      text = " #{text} "
      tw = Term.text_width(text)
      return if tw > w

      case align
      when :center then tx = x + ((w - tw) / 2)
      when :right  then tx = x + w - tw
      else              tx = x
      end
      f.put(tx, y, text, style)
      self
    end

    # --- text -----------------------------------------------------------

    def text(f, x, y, str, style = :text)
      f.put(x, y, str, style)
      self
    end

    def center(f, x, y, w, str, style = :text)
      tw = Term.text_width(str)
      f.put(x + [(w - tw) / 2, 0].max, y, str, style)
      self
    end

    def right(f, x, y, w, str, style = :text)
      tw = Term.text_width(str)
      f.put(x + [w - tw, 0].max, y, str, style)
      self
    end

    # --- meters ---------------------------------------------------------

    # Horizontal gauge: [██████░░░░░░]. The filled part is painted with the
    # shared colour ramp so every bar in the app reads the same way.
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
    def bars(f, x, y, w, h, values, grid: true)
      return if w < 1 || h < 1

      # faint dotted gridlines at 25 / 50 / 75 %
      if grid
        [0.25, 0.5, 0.75].each do |g|
          gy = y + h - 1 - (g * (h - 1)).round
          f.hline(x, gy, w, DOT, :grid)
        end
      end

      values = values.last(w)
      offset = w - values.length

      values.each_with_index do |v, i|
        v = v.clamp(0.0, 1.0)
        eighths = (v * h * 8).round
        next if eighths.zero?

        colour = Style.ramp(v)
        0.upto(h - 1) do |r|
          spent = r * 8
          e = eighths - spent
          next if e <= 0
          e = 8 if e > 8
          f.put(x + offset + i, y + h - 1 - r, BLOCKS[e], colour)
        end
      end
      self
    end

    # One-row sparkline of the last `w` values.
    def sparkline(f, x, y, w, values, style = :accent)
      values = values.last(w)
      offset = w - values.length
      values.each_with_index do |v, i|
        idx = (v.clamp(0.0, 1.0) * 7).round
        f.put(x + offset + i, y, BLOCKS[idx + 1], style)
      end
      self
    end

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

    # --- misc -----------------------------------------------------------

    # Cut a string down to `width` cells, ending with an ellipsis.
    def truncate(str, width)
      return str if width <= 0 || Term.text_width(str) <= width

      out = +''
      used = 0
      str.each_char do |ch|
        w = Term.width(ch)
        break if used + w > width - 1
        out << ch
        used += w
      end
      out << '…'
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
