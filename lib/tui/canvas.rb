# frozen_string_literal: true
#
# Canvas -- an off-screen cell grid plus the drawing primitives.
#
# Cells are codepoints (Integer) and style ids (Integer), so drawing is pure
# array assignment and a row is composed with a single Array#pack per
# equal-style run. The canvas also tracks which rows were drawn on and which
# were drawn on last tick, which is what lets TUI::Screen send only the diff
# to the terminal.
#
# Everything is clipped: a component cannot paint outside its rect if the
# caller wraps it in #clip.

require_relative 'geometry'
require_relative 'term'
require_relative 'style'
require_relative 'text'

module TUI
  class Canvas
    SPACE = 32
    NUL   = 0     # placeholder cell after a double-width character

    attr_reader :w, :h

    def initialize(w, h)
      @w = w
      @h = h
      @chars   = Array.new(h) { Array.new(w, SPACE) }
      @styles  = Array.new(h) { Array.new(w, 0) }
      @wide    = Array.new(h, false)
      @dirty   = Array.new(h, true)
      @touched = Array.new(h, false)
      @flat    = Array.new(h, 0)
      @clip      = Rect.new(0, 0, w, h)
      @clip_full = true
    end

    # --- clipping -------------------------------------------------------

    # Restrict drawing to `rect` for the duration of the block.
    def clip(rect = nil, &block)
      return yield if rect.nil? || rect == @clip

      previous = @clip
      previous_full = @clip_full
      begin
        @clip = intersect(previous, rect)
        @clip_full = @clip == Rect.new(0, 0, @w, @h)
        yield
      ensure
        @clip = previous
        @clip_full = previous_full
      end
    end

    # Note: the reader is not called #clip -- that name is the method that
    # sets the clipping region.
    def clip_rect
      @clip
    end

    # --- drawing --------------------------------------------------------

    # Write a string at (x, y). Out-of-range coordinates clip instead of
    # wrapping, so components can draw carelessly.
    def put(x, y, str, style = nil)
      return self if y < @clip.y || y > @clip.bottom

      str = str.to_s
      return self if str.empty?

      @dirty[y] = true
      @touched[y] = true
      sid = Style.id(style)
      mark_style(y, sid, false)
      row = @chars[y]
      stl = @styles[y]

      if str.length == 1
        cp = str.ord
        wd = Term.codepoint_width(cp)
        if wd == 1 && x >= @clip.x && x <= @clip.right
          row[x] = cp
          stl[x] = sid
          return self
        end
      elsif str.ascii_only? && x >= @clip.x && x + str.length <= @clip.right + 1
        n = str.length
        row[x, n] = str.bytes
        stl.fill(sid, x, n)
        return self
      end

      put_character_by_character(x, y, str, sid)
    end

    def fill(x, y, w, h, ch = ' ', style = nil)
      region = intersect(Rect.new(x, y, w, h), @clip)
      return self if region.empty?

      cp  = blank?(ch) ? SPACE : ch.to_s.ord
      sid = Style.id(style)

      region.y.upto(region.bottom) do |row_y|
        @chars[row_y].fill(cp, region.x, region.w)
        @styles[row_y].fill(sid, region.x, region.w)
        @dirty[row_y] = true
        @touched[row_y] = true
        mark_style(row_y, sid, region.x.zero? && region.w == @w)
        @wide[row_y] = false if region.x.zero? && region.w == @w
      end
      self
    end

    def fill_rect(rect, ch = ' ', style = nil)
      fill(rect.x, rect.y, rect.w, rect.h, ch, style)
    end

    def clear(style = nil)
      fill(0, 0, @w, @h, ' ', style)
    end

    def hline(x, y, w, ch = '─', style = :border)
      fill(x, y, w, 1, ch, style)
    end

    def vline(x, y, h, ch = '│', style = :border)
      fill(x, y, 1, h, ch, style)
    end

    # Text helpers that stay inside `rect`.
    def text(rect, str, style = :text, align = :left)
      str = Text.truncate(str, rect.w) if Text.width(str) > rect.w
      x = case align
          when :center then rect.x + ((rect.w - Text.width(str)) / 2)
          when :right  then rect.x + rect.w - Text.width(str)
          else rect.x
          end
      put([x, rect.x].max, rect.y, str, style)
    end

    # A rounded box; title and footer are written into the border rows.
    def box(rect, style = :border, title: nil, title_style: :title,
            title_right: nil, title_right_style: :dim,
            footer: nil, footer_style: :hint, footer_align: :center)
      return self if rect.w < 2 || rect.h < 2

      hline(rect.x + 1, rect.y, rect.w - 2, '─', style)
      hline(rect.x + 1, rect.bottom, rect.w - 2, '─', style)
      vline(rect.x, rect.y + 1, rect.h - 2, '│', style)
      vline(rect.right, rect.y + 1, rect.h - 2, '│', style)
      put(rect.x, rect.y, '╭', style)
      put(rect.right, rect.y, '╮', style)
      put(rect.x, rect.bottom, '╰', style)
      put(rect.right, rect.bottom, '╯', style)

      # Titles win over the footer: a centred hint must not run into them.
      title_w = 0
      if title
        border_label(rect, title, title_style, :left)
        title_w = Text.width(title) + 2
      end

      right_w = 0
      if title_right
        tw = Text.width(title_right) + 2
        if rect.w - 2 - tw >= title_w + 2
          border_label(rect, title_right, title_right_style, :right)
          right_w = tw
        end
      end

      if footer
        fw = Text.width(footer) + 2
        left_edge = rect.x + 2 + title_w
        right_edge = rect.right - right_w - 1
        fx = case footer_align
             when :center then rect.x + ((rect.w - fw) / 2)
             when :right  then rect.right - fw
             else rect.x + 1
             end
        border_label(rect, footer, footer_style, footer_align) if fx >= left_edge && fx + fw <= right_edge
      end
      self
    end

    def border_label(rect, text, style, align = :left)
      text = " #{text} "
      tw = Text.width(text)
      return self if tw > rect.w - 2

      x = case align
          when :center then rect.x + ((rect.w - tw) / 2)
          when :right  then rect.right - tw
          else rect.x + 1
          end
      put(x, rect.y, text, style)
      self
    end

    # --- row composition ------------------------------------------------

    def row(y)
      return '' if y < 0 || y >= @h

      chars = @chars[y]
      out = +''

      # The common case: one style across the whole row -> one pack call.
      if @flat[y] >= 0
        out << Style.sgr(@flat[y]) << chars.pack('U*') << Style::RESET
        out.delete!(NUL.chr) if @wide[y]
        return out
      end

      styles = @styles[y]
      x = 0
      cur = -1
      while x < @w
        sid = styles[x]
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

    # --- frame lifecycle (used by Screen) -------------------------------

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

    def presented!
      @dirty.fill(false)
      self
    end

    def dirty?(y)
      @dirty[y] == true
    end

    private

    def blank?(ch)
      ch.nil? || ch.to_s.empty?
    end

    def intersect(a, b)
      x = [a.x, b.x].max
      y = [a.y, b.y].max
      right  = [a.right, b.right].min
      bottom = [a.bottom, b.bottom].min
      Rect.new(x, y, right - x + 1, bottom - y + 1)
    end

    # Remember whether a row keeps one style, so row() can skip the scan.
    def mark_style(y, sid, full)
      cur = @flat[y]
      return if cur < 0 || cur == sid

      @flat[y] = (cur.zero? && full) ? sid : -1
    end

    def put_character_by_character(x, y, str, sid)
      row = @chars[y]
      stl = @styles[y]
      col = x

      str.each_char do |ch|
        wd = Term.codepoint_width(ch.ord)
        next if wd.zero?
        break if col > @clip.right

        if col >= @clip.x && col + wd - 1 <= @clip.right
          row[col] = ch.ord
          stl[col] = sid
          if wd == 2
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
end
