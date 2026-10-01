# frozen_string_literal: true
require_relative 'test_helper'

puts 'Canvas -- drawing'

def canvas(w = 20, h = 3)
  TUI::Canvas.new(w, h)
end

test 'put writes at the right cells' do
  c = canvas
  c.put(2, 1, 'hello', :text)
  assert_equal '  hello             ', plain(c.row(1))
end

test 'put clips at the right edge' do
  c = canvas(10, 2)
  c.put(7, 0, 'abcdefgh', :text)
  assert_equal '       abc', plain(c.row(0))
end

test 'put clips a negative x without shifting' do
  c = canvas(10, 2)
  c.put(-3, 0, 'abcdefgh', :text)
  assert_equal 'defgh     ', plain(c.row(0))
end

test 'put ignores rows outside the canvas' do
  c = canvas(10, 2)
  c.put(0, -1, 'x', :text)
  c.put(0, 9, 'x', :text)
  assert_equal ['          ', '          '], c.lines.map { |l| plain(l) }
end

test 'fill paints a rectangle and clamps' do
  c = canvas(6, 2)
  c.fill(-2, -2, 100, 100, '.', :text)
  assert_equal ['......', '......'], c.lines.map { |l| plain(l) }
end

test 'wide characters take two cells and render as one glyph' do
  c = canvas(12, 1)
  c.put(0, 0, '日本', :text)
  assert_equal '日本        ', plain(c.row(0))
  assert_equal 12, TUI::Text.width(plain(c.row(0)))
  refute plain(c.row(0)).include?("\0")
end

test 'wide characters are dropped rather than overflow' do
  c = canvas(4, 1)
  c.put(3, 0, '日', :text)
  assert_equal 4, TUI::Text.width(plain(c.row(0)))
end

test 'styles are emitted per run and the row ends reset' do
  c = canvas(10, 1)
  c.put(0, 0, 'aa', :success)
  c.put(2, 0, 'bb', :danger)
  row = c.row(0)
  assert_includes row, TUI::Style.sgr(TUI::Style.id(:success))
  assert_includes row, TUI::Style.sgr(TUI::Style.id(:danger))
  assert row.end_with?(TUI::Style::RESET)
  assert_equal 'aabb      ', plain(row)
end

puts 'Canvas -- clipping'

test 'clip confines drawing to the rect' do
  c = canvas(20, 3)
  c.clip(TUI::Rect.new(5, 0, 10, 3)) { c.put(0, 1, 'x' * 20, :text) }
  assert_equal '     xxxxxxxxxx     ', plain(c.row(1))
end

test 'clip affects fill too' do
  c = canvas(10, 2)
  c.clip(TUI::Rect.new(0, 0, 4, 1)) { c.fill(0, 0, 10, 2, '#', :text) }
  assert_equal ['####      ', '          '], c.lines.map { |l| plain(l) }
end

test 'clip nests, intersects and restores the previous region' do
  c = canvas(10, 1)
  c.put(0, 0, '..........', :text)

  c.clip(TUI::Rect.new(0, 0, 8, 1)) do
    # an inner clip may only shrink: this one is 4..7
    c.clip(TUI::Rect.new(4, 0, 4, 1)) { c.put(0, 0, 'X' * 10, :text) }
    c.put(0, 0, 'YY', :text)
  end

  # both clips are gone now
  c.put(8, 0, 'ZZ', :text)
  assert_equal 'YY..XXXXZZ', plain(c.row(0))
end

puts 'Canvas -- primitives'

test 'box draws corners, edges and a title' do
  c = canvas(12, 4)
  c.box(TUI::Rect.new(0, 0, 12, 4), :border, title: 'hi')
  assert_equal ['╭ hi ──────╮', '│          │', '│          │',
                '╰──────────╯'], c.lines.map { |l| plain(l) }
end

test 'box puts a right title in the same border row' do
  c = canvas(20, 3)
  c.box(TUI::Rect.new(0, 0, 20, 3), :border, title: 'left', title_right: 'right')
  assert_equal '╭ left ───── right ╮', plain(c.row(0))
end

test 'text helpers align inside a rect' do
  c = canvas(20, 3)
  rect = TUI::Rect.new(0, 0, 20, 3)
  c.text(rect, 'left', :text, :left)
  c.text(rect.with(y: 1), 'mid', :text, :center)
  c.text(rect.with(y: 2), 'right', :text, :right)
  assert_equal ['left', 'mid', 'right'],
               [plain(c.row(0)).strip, plain(c.row(1)).strip, plain(c.row(2)).strip]
end

test 'text truncates instead of overflowing its rect' do
  c = canvas(6, 1)
  c.text(TUI::Rect.new(0, 0, 6, 1), 'abcdefghij', :text)
  assert_equal 'abcde…', plain(c.row(0))
end

puts 'Canvas -- frame bookkeeping'

test 'a fresh canvas has every row dirty' do
  c = canvas(4, 3)
  assert [0, 1, 2].all? { |y| c.dirty?(y) }
end

test 'only drawn rows are dirty between frames' do
  c = canvas(4, 3)
  c.presented!
  c.begin_frame!
  c.put(0, 1, 'x', :text)
  assert c.dirty?(1)
  refute c.dirty?(0)
  refute c.dirty?(2)
end

test 'begin_frame! wipes the previous frame and keeps rows dirty' do
  c = canvas(6, 2)
  c.put(0, 1, 'xx', :text)
  c.presented!
  c.begin_frame!
  assert_equal ['      ', '      '], c.lines.map { |l| plain(l) }
  assert c.dirty?(1), 'wiped rows still need presenting (to clear the screen)'
  refute c.dirty?(0)
end

puts 'Text'

test 'width counts cells, not characters' do
  assert_equal 1, TUI::Text.width('a')
  assert_equal 2, TUI::Text.width('日')
  assert_equal 6, TUI::Text.width('日本語')
  assert_equal 0, TUI::Text.width("\u0301")
end

test 'truncate cuts on cells and adds an ellipsis' do
  assert_equal 'abc', TUI::Text.truncate('abc', 5)
  assert_equal 'ab…', TUI::Text.truncate('abcdef', 3)
  assert_equal '日…', TUI::Text.truncate('日本語', 3)
end

test 'pad fills to a cell width' do
  assert_equal 'a  ', TUI::Text.pad('a', 3)
  assert_equal '  a', TUI::Text.pad('a', 3, :right)
  assert_equal ' a ', TUI::Text.pad('a', 3, :center)
  assert_equal 'abc', TUI::Text.pad('abc', 2)
end

test 'wrap breaks on words' do
  assert_equal ['one two', 'three'], TUI::Text.wrap('one two three', 8)
  assert_equal ['a', '', 'b'], TUI::Text.wrap("a\n\nb", 10)
end
