# frozen_string_literal: true
#
# Frame equivalence: the optimised Frame (integer cells, packed rows, dirty
# rows) must render byte-for-byte identically to the obvious implementation
# (a String per cell, naive per-character loops). This is the test that
# caught a NUL placeholder leaking into rows containing wide characters.

require_relative 'test_helper'
require 'screen'
require 'widgets'

# --- a deliberately naive reference implementation ------------------------

class RefFrame
  TL = '╭'; TR = '╮'; BL = '╰'; BR = '╯'; HZ = '─'; VT = '│'

  attr_reader :w, :h

  def initialize(w, h)
    @w = w
    @h = h
    @chars  = Array.new(h) { Array.new(w, ' ') }
    @styles = Array.new(h) { Array.new(w, nil) }
  end

  def put(x, y, str, style = nil)
    return self if y < 0 || y >= @h

    col = x
    str.to_s.each_char do |ch|
      wd = Term.width(ch)

      if wd.zero?
        prev = col - 1
        @chars[y][prev] = @chars[y][prev] + ch if prev >= 0 && prev < @w
        next
      end

      if col >= 0 && col < @w
        @chars[y][col] = ch
        @styles[y][col] = style
        k = 1
        while k < wd && col + k < @w
          @chars[y][col + k] = ''
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
        xx = x
        while xx < x + w
          if xx >= 0 && xx < @w
            @chars[yy][xx] = ch
            @styles[yy][xx] = style
          end
          xx += 1
        end
      end
      yy += 1
    end
    self
  end

  def hline(x, y, w, ch = HZ, style = :border)
    fill(x, y, w, 1, ch, style)
  end

  def row(y)
    return '' if y < 0 || y >= @h

    out = +''
    cur = nil
    x = 0
    while x < @w
      st = @styles[y][x]
      if st != cur
        out << (st ? Style.resolve(st) : Style::RESET)
        cur = st
      end
      out << @chars[y][x]
      x += 1
    end
    out << Style::RESET
    out
  end

  def lines
    Array.new(@h) { |y| row(y) }
  end
end

# --- the same drawing script run against both frames ---------------------

def scripted_drawing(f)
  f.fill(0, 0, 60, 20, ' ', :text)
  Widgets.box(f, 0, 0, 60, 20)
  Widgets.border_label(f, 1, 0, 58, 'title', :title, :left)
  Widgets.border_label(f, 1, 0, 58, 'right', :dim, :right)
  f.put(2, 2, 'hello world', :text)
  f.put(2, 3, 'aksara: 日本語 ok', :subtitle)
  f.put(2, 4, 'box: ┌─┼─┐ blocks: ▁▂▃▄▅▆▇█', :accent)
  f.put(2, 5, 'clipped-here-> truncate me', :warn)
  f.put(-3, 6, 'negative x', :bad)
  f.put(55, 7, 'edge overflow', :good)
  f.hline(2, 8, 40, '─', :track)
  Widgets.gauge(f, 2, 9, 30, 0.42)
  Widgets.gauge(f, 2, 10, 30, 1.0)
  Widgets.sparkline(f, 2, 11, 30, Array.new(30) { |i| i / 30.0 })
  Widgets.bars(f, 2, 12, 30, 5, Array.new(30) { |i| (Math.sin(i / 3.0) + 1) / 2 })
  rows = [
    { pid: 1, name: 'systemd', cpu: '0.1', mem: '12.4M' },
    { pid: 4242, name: 'a-very-long-process-name-here', cpu: '99.9', mem: '1.2G' },
    { pid: 7, name: '日本語プロセス', cpu: '3.0', mem: '900K' }
  ]
  Widgets.proc_header(f, 2, 18, 56)
  Widgets.process_list(f, 2, 19, 56, 3, rows, 1, 0, true)
  f
end

puts 'Frame -- equivalence with a naive implementation'

test 'every row matches the reference renderer byte for byte' do
  fast = scripted_drawing(Frame.new(60, 20))
  ref  = scripted_drawing(RefFrame.new(60, 20))

  fast.lines.each_with_index do |line, i|
    assert_equal ref.lines[i], line, "row #{i} differs"
  end
end

test 'no placeholder cells survive in either implementation' do
  [Frame.new(60, 20), RefFrame.new(60, 20)].each do |f|
    scripted_drawing(f)
    f.lines.each_with_index do |line, i|
      refute plain(line).include?("\0"), "#{f.class} row #{i} leaked a placeholder"
    end
  end
end
