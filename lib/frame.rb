# frozen_string_literal: true
#
# Frame -- an off-screen cell grid.
#
# Cells are Unicode codepoints (Integer) plus a style id (Integer), which
# makes drawing pure array assignment and row composition a single
# Array#pack call. Writing text is a splice for the characters and an
# Array#fill for the styles; reading a row back is one pack per equal-style
# run.
#
# The frame also carries the bookkeeping Screen needs to paint only what
# changed: which rows were drawn this tick, which ones must be wiped before
# the next one, and whether a row kept a single style throughout.

require_relative 'term'
require_relative 'theme'

class Frame
  SPACE = 32  # codepoint of ' '
  NUL   = 0   # placeholder cell following a double-width character

  attr_reader :w, :h

  def initialize(w, h)
    @w = w
    @h = h
    @chars  = Array.new(h) { Array.new(w, SPACE) }
    @styles = Array.new(h) { Array.new(w, 0) }
    @wide    = Array.new(h, false)   # row contains a wide char (needs cleanup)
    @dirty   = Array.new(h, true)    # rows that must be (re)presented
    @touched = Array.new(h, false)   # rows drawn since begin_frame!
    @flat    = Array.new(h, 0)       # row's style id, or -1 when mixed
  end

  # Wipe and reuse this frame instead of allocating a new one every tick.
  def reset!
    @chars.each  { |row| row.fill(SPACE) }
    @styles.each { |row| row.fill(0) }
    @wide.fill(false)
    @dirty.fill(true)
    @touched.fill(false)
    @flat.fill(0)
    self
  end

  # Start a tick: blank out whatever was drawn during the previous one. Those
  # rows stay marked dirty so Screen can also clear them on the terminal when
  # nothing draws on them any more.
  def begin_frame!
    y = 0
    while y < @h
      if @touched[y]
        @chars[y].fill(SPACE)
        @styles[y].fill(0)
        @wide[y] = false
        @dirty[y] = true
        @flat[y] = 0
      end
      y += 1
    end
    @touched.fill(false)
    self
  end

  # Called by Screen once the frame is on screen: everything is in sync now.
  def presented!
    @dirty.fill(false)
    self
  end

  def dirty?(y)
    @dirty[y] == true
  end

  # Write a string at (x, y). Style may be a Symbol or an SGR string.
  def put(x, y, str, style = nil)
    return self if y < 0 || y >= @h || x >= @w

    str = str.to_s
    return self if str.empty?

    @dirty[y] = true
    @touched[y] = true
    sid = Style.id(style)
    row = @chars[y]
    stl = @styles[y]
    # a single put never covers a whole row, so it cannot claim a flat style
    mark_style(y, sid, false)

    # fast path: single-cell characters are drawn directly
    if str.length == 1
      cp = str.ord
      wd = Term.codepoint_width(cp)
      if wd == 1 && x >= 0 && x < @w
        row[x] = cp
        stl[x] = sid
      elsif wd.positive? && x >= 0 && x + wd <= @w
        row[x] = cp
        stl[x] = sid
        if wd == 2
          row[x + 1] = NUL
          stl[x + 1] = sid
          @wide[y] = true
        end
      else
        put_slow(row, stl, x, y, [cp], sid)
      end
      return self
    end

    # fast path: ASCII text that fits -- one C-level splice for the cells
    # and one Array#fill for the styles.
    n = str.length
    if str.ascii_only? && x >= 0 && x + n <= @w
      row[x, n] = str.bytes
      stl.fill(sid, x, n)
      return self
    end

    put_slow(row, stl, x, y, str.codepoints, sid)
  end

  # Remember whether the whole row keeps a single style; when it does, row()
  # can skip the per-cell style scan entirely.
  #
  # `full` says the write covered every cell of the row. A blank row is
  # "style 0 everywhere", so a partial write in another style really does
  # make it mixed -- but a full-width write replaces it wholesale.
  def mark_style(y, sid, full)
    cur = @flat[y]
    return if cur < 0 || cur == sid

    @flat[y] = (cur.zero? && full) ? sid : -1
  end

  def fill(x, y, w, h, ch = ' ', style = nil)
    return self if w <= 0 || h <= 0

    cp  = ch.to_s.empty? ? SPACE : ch.to_s.ord
    sid = Style.id(style)

    yy = y
    while yy < y + h
      if yy >= 0 && yy < @h
        x0 = x < 0 ? 0 : x
        x1 = x + w
        x1 = @w if x1 > @w
        if x1 > x0
          @chars[yy].fill(cp, x0, x1 - x0)
          @styles[yy].fill(sid, x0, x1 - x0)
          full = x0.zero? && x1 == @w
          mark_style(yy, sid, full)
          @wide[yy] = false if full
        end
        @dirty[yy] = true
        @touched[yy] = true
      end
      yy += 1
    end
    self
  end

  def hline(x, y, w, ch = '─', style = :border)
    fill(x, y, w, 1, ch, style)
  end

  # Compose a row into a single ANSI string. Equal-style runs are emitted
  # with one SGR code and one pack call.
  def row(y)
    return '' if y < 0 || y >= @h

    chars  = @chars[y]
    out    = +''

    # common case: the row uses one style throughout (borders, text, list
    # rows) -- no per-cell scan, just one pack call.
    if @flat[y] >= 0
      out << Style.sgr(@flat[y])
      out << chars.pack('U*')
      out << Style::RESET
      out.delete!(NUL.chr) if @wide[y]
      return out
    end

    styles = @styles[y]
    x      = 0
    cur    = -1

    while x < @w
      sid   = styles[x]
      start = x
      x += 1
      x += 1 while x < @w && styles[x] == sid

      out << Style.sgr(sid) if sid != cur
      cur = sid
      out << chars[start, x - start].pack('U*')
    end

    out << Style::RESET
    out.delete!(NUL.chr) if @wide[y]
    out
  end

  def lines
    Array.new(@h) { |y| row(y) }
  end

  private

  # Char-by-char path for multi-character strings and clipping.
  def put_slow(row, stl, x, y, codepoints, sid)
    col = x
    codepoints.each do |cp|
      wd = Term.codepoint_width(cp)
      next if wd.zero?
      break if col >= @w

      if col >= 0
        row[col] = cp
        stl[col] = sid
        if wd == 2 && col + 1 < @w
          row[col + 1] = NUL
          stl[col + 1] = sid
          @wide[y] = true
        end
      end
      col += wd
    end
    self
  end
end
