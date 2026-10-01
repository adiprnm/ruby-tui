# frozen_string_literal: true
#
# Frame  -- an off-screen character grid (chars + per-cell style).
# Screen -- diffs consecutive frames and only writes the rows that changed.

require_relative 'term'
require_relative 'theme'

class Frame
  attr_reader :w, :h

  def initialize(w, h)
    @w = w
    @h = h
    @chars  = Array.new(h) { Array.new(w, ' ') }
    @styles = Array.new(h) { Array.new(w, nil) }
    @dirty  = Array.new(h, true)
  end

  # Wipe and reuse this frame instead of allocating a new one every tick.
  def reset!
    @chars.each { |row| row.fill(' ') }
    @styles.each { |row| row.fill(nil) }
    @dirty.fill(true)
    self
  end

  # True when anything was drawn on this row since the last reset.
  # Screen uses it to skip re-composing untouched rows entirely.
  def dirty?(y)
    @dirty[y] == true
  end

  # Write a string at (x, y). Style may be a Symbol or an SGR string.
  # Wide characters claim two cells; combining marks attach to the previous.
  def put(x, y, str, style = nil)
    return self if y < 0 || y >= @h

    @dirty[y] = true
    col = x
    str.to_s.each_char do |ch|
      wd = Term.width(ch)

      if wd.zero?
        prev = col - 1
        if prev >= 0 && prev < @w && @chars[y][prev]
          @chars[y][prev] = @chars[y][prev] + ch
        end
        next
      end

      if col >= 0 && col < @w
        @chars[y][col]  = ch
        @styles[y][col] = style
        k = 1
        while k < wd && col + k < @w
          @chars[y][col + k]  = ''   # continuation cell
          @styles[y][col + k] = style
          k += 1
        end
      end

      col += wd
      break if col >= @w
    end
    self
  end

  def fill(x, y, w, h, ch = ' ', style = nil)
    yy = y
    while yy < y + h
      if yy >= 0 && yy < @h
        @dirty[yy] = true
        xx = x
        while xx < x + w
          if xx >= 0 && xx < @w
            @chars[yy][xx]  = ch
            @styles[yy][xx] = style
          end
          xx += 1
        end
      end
      yy += 1
    end
    self
  end

  def hline(x, y, w, ch = '─', style = :border)
    fill(x, y, w, 1, ch, style)
  end

  # Compose a row into a single ANSI string, emitting an SGR code only when
  # the style actually changes (keeps the byte count low).
  def row(y)
    return '' if y < 0 || y >= @h

    out  = +''
    cur  = nil
    chars = @chars[y]
    styles = @styles[y]

    x = 0
    while x < @w
      st = styles[x]
      if st != cur
        out << Style.resolve(st)
        cur = st
      end
      out << chars[x]
      x += 1
    end
    out << Style::RESET
    out
  end

  def lines
    Array.new(@h) { |y| row(y) }
  end
end

class Screen
  def initialize(out)
    @out  = out
    @prev = []
    @w, @h = Term.size
    @frame = nil
  end

  attr_reader :w, :h

  # Returns true when the terminal was resized.
  def resize!
    w, h = Term.size
    return false if w == @w && h == @h

    @w = w
    @h = h
    @prev = []
    @frame = nil
    @out.print(Term.CLEAR)
    true
  end

  # A reused, already-wiped frame.
  def frame
    @frame ||= Frame.new(@w, @h)
    @frame.reset!
  end

  # Paint only what changed: rows nobody drew on are compared against the
  # previous frame and skip composition altogether.
  def present(frame)
    buf = +Term::SYNC_ON

    i = 0
    while i < @h
      unless frame.dirty?(i)
        i += 1
        next
      end

      line = frame.row(i)
      if @prev[i] != line
        buf << Term.move(i, 0) << line << "\e[K"
        @prev[i] = line
      end
      i += 1
    end

    buf << Term::SYNC_OFF
    @out.print(buf)
    @out.flush
    self
  end
end
