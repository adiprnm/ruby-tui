# frozen_string_literal: true
require_relative 'test_helper'
require 'screen'
require 'widgets'

puts 'Frame -- drawing'

test 'put writes characters at the right cells' do
  f = Frame.new(20, 3)
  f.put(2, 1, 'hello', :text)
  assert_equal '  hello             ', plain(f.row(1))
end

test 'put clips at the right edge' do
  f = Frame.new(10, 2)
  f.put(7, 0, 'abcdefgh', :text)
  assert_equal '       abc', plain(f.row(0))
end

test 'put clips negative x without shifting' do
  f = Frame.new(10, 2)
  f.put(-3, 0, 'abcdefgh', :text)
  assert_equal 'defgh     ', plain(f.row(0))
end

test 'put ignores out-of-range rows' do
  f = Frame.new(10, 2)
  f.put(0, -1, 'x', :text)
  f.put(0, 5, 'x', :text)
  assert_equal ['          ', '          '], f.lines.map { |l| plain(l) }
end

test 'fill paints a rectangle' do
  f = Frame.new(10, 3)
  f.fill(2, 1, 4, 1, '#', :text)
  assert_equal '  ####    ', plain(f.row(1))
end

test 'fill clamps to the frame' do
  f = Frame.new(6, 2)
  f.fill(-2, -2, 100, 100, '.', :text)
  assert_equal ['......', '......'], f.lines.map { |l| plain(l) }
end

test 'styles are emitted per run and reset at the end' do
  f = Frame.new(10, 1)
  f.put(0, 0, 'aa', :good)
  f.put(2, 0, 'bb', :bad)
  row = f.row(0)
  assert_includes row, Style.sgr(Style.id(:good))
  assert_includes row, Style.sgr(Style.id(:bad))
  assert row.end_with?(Style::RESET)
  assert_equal 'aabb      ', plain(row)
end

test 'wide characters occupy two cells and render as one glyph' do
  f = Frame.new(12, 1)
  f.put(0, 0, '日本', :text)
  assert_equal '日本        ', plain(f.row(0))
  assert_equal 12, Term.text_width(plain(f.row(0))), 'row stays aligned to the frame width'
end

test 'wide characters survive a mixed-style row' do
  f = Frame.new(12, 1)
  f.put(0, 0, 'a', :good)
  f.put(1, 0, '日', :bad)
  f.put(3, 0, 'b', :good)
  assert_equal 'a日b        ', plain(f.row(0))
end

test 'wide characters are clipped instead of overflowing' do
  f = Frame.new(4, 1)
  f.put(3, 0, '日', :text)
  refute plain(f.row(0)).include?("\0")
  assert_equal 4, plain(f.row(0)).length
end

puts 'Frame -- bookkeeping'

test 'a fresh frame reports every row dirty' do
  f = Frame.new(4, 3)
  assert [0, 1, 2].all? { |y| f.dirty?(y) }
end

test 'only drawn rows are dirty after begin_frame!' do
  f = Frame.new(4, 3)
  f.presented!          # pretend the empty frame is on screen
  f.begin_frame!
  f.put(0, 1, 'x', :text)
  assert f.dirty?(1)
  refute f.dirty?(0)
  refute f.dirty?(2)
end

test 'begin_frame! wipes rows drawn during the previous tick' do
  f = Frame.new(6, 2)
  f.put(0, 1, 'xx', :text)
  f.presented!
  f.begin_frame!
  assert_equal ['      ', '      '], f.lines.map { |l| plain(l) }
  assert f.dirty?(1), 'wiped row must still be presented (so the terminal clears it)'
  refute f.dirty?(0), 'untouched row stays clean'
end

test 'a partly written row is conservatively marked mixed' do
  f = Frame.new(6, 1)
  f.put(0, 0, 'a', :good)
  # the rest of the row is untouched style-0 space, so the row is mixed
  assert_equal(-1, f.instance_variable_get(:@flat)[0])
end

test 'mixing styles in a uniform row marks it mixed' do
  f = Frame.new(6, 1)
  f.fill(0, 0, 6, 1, ' ', :good)          # claims the whole row
  assert_equal Style.id(:good), f.instance_variable_get(:@flat)[0]
  f.put(1, 0, 'b', :bad)
  assert_equal(-1, f.instance_variable_get(:@flat)[0])
end

test 'a full-width fill may claim the row flat, a partial one may not' do
  f = Frame.new(6, 2)
  f.fill(0, 0, 6, 1, ' ', :sel)
  assert_equal Style.id(:sel), f.instance_variable_get(:@flat)[0]

  f.put(0, 1, 'a', :sel)
  assert_equal(-1, f.instance_variable_get(:@flat)[1])
end

puts 'Widgets -- drawing stays inside its box'

test 'box draws rounded corners' do
  f = Frame.new(8, 3)
  Widgets.box(f, 0, 0, 8, 3)
  assert_equal ['╭──────╮', '│      │', '╰──────╯'], f.lines.map { |l| plain(l) }
end

test 'gauge fills proportionally and never overflows' do
  f = Frame.new(12, 1)
  Widgets.gauge(f, 0, 0, 12, 0.5)
  row = plain(f.row(0))
  assert_equal 12, row.length
  assert_equal '[█████░░░░░]', row
end

test 'gauge clamps out-of-range ratios' do
  f = Frame.new(12, 1)
  Widgets.gauge(f, 0, 0, 12, 5.0)
  assert_equal '[██████████]', plain(f.row(0))
end

test 'bars stay within width and height' do
  f = Frame.new(20, 6)
  Widgets.bars(f, 0, 0, 20, 6, Array.new(40) { |i| (i % 10) / 10.0 })
  assert_equal 6, f.lines.length
  f.lines.each { |l| assert_equal 20, plain(l).length }
end

test 'bars with all-zero values draw nothing' do
  f = Frame.new(10, 4)
  Widgets.bars(f, 0, 0, 10, 4, [0.0, 0.0], grid: false)
  assert_equal ['          '] * 4, f.lines.map { |l| plain(l) }
end

test 'sparkline right-aligns the newest sample' do
  f = Frame.new(5, 1)
  Widgets.sparkline(f, 0, 0, 5, [0.0, 1.0])
  assert_equal '   ▁█', plain(f.row(0))
end

test 'truncate cuts on cell width, not char count' do
  assert_equal 'abc', Widgets.truncate('abc', 5)
  assert_equal 'ab…', Widgets.truncate('abcdef', 3)
  assert_equal '日…', Widgets.truncate('日本語', 3)
end
