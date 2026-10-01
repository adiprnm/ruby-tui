# frozen_string_literal: true
require_relative 'test_helper'

puts 'Rect'

test 'right/bottom are inclusive edges' do
  r = TUI::Rect.new(2, 3, 10, 4)
  assert_equal 11, r.right
  assert_equal 6, r.bottom
  assert r.contains?(2, 3)
  assert r.contains?(11, 6)
  refute r.contains?(12, 6)
end

test 'inset shrinks on every side' do
  r = TUI::Rect.new(0, 0, 10, 6).inset(1)
  assert_equal [1, 1, 8, 4], r.to_a
  assert_equal [2, 1, 7, 4], TUI::Rect.new(0, 0, 10, 6).inset(1, left: 2).to_a
end

test 'inset never goes negative' do
  r = TUI::Rect.new(0, 0, 2, 2).inset(5)
  assert r.empty?
  assert_equal 0, r.w
  assert_equal 0, r.h
  refute r.contains?(0, 0)
end

test 'take_top/take_left return the band and the rest' do
  r = TUI::Rect.new(0, 0, 10, 5)
  head, rest = r.take_top(2)
  assert_equal [0, 0, 10, 2], head.to_a
  assert_equal [0, 2, 10, 3], rest.to_a

  left, right = r.take_left(3)
  assert_equal [0, 0, 3, 5], left.to_a
  assert_equal [3, 0, 7, 5], right.to_a
end

test 'take clamps to the available size' do
  r = TUI::Rect.new(0, 0, 4, 2)
  head, rest = r.take_top(10)
  assert_equal 4, head.w
  assert_equal 2, head.h
  assert_equal 0, rest.h
end

puts 'Units and Distribute'

test 'fixed specs get their exact size' do
  sizes = TUI::Layout::Distribute.split([[TUI.fixed(3), nil], [TUI.fixed(4), nil]], 20)
  assert_equal [3, 4], sizes
end

test 'a bare number is a fixed size' do
  assert_equal [5, 2], TUI::Layout::Distribute.split([[5, nil], [2, nil]], 20)
end

test 'flex shares the leftover space by weight' do
  sizes = TUI::Layout::Distribute.split(
    [[TUI.fixed(4), nil], [TUI.flex(1), nil], [TUI.flex(3), nil]], 24
  )
  assert_equal 4, sizes[0]
  assert_equal 5, sizes[1]
  assert_equal 15, sizes[2]
  assert_equal 24, sizes.sum
end

test 'percent is a share of the available space' do
  assert_equal [5, 15], TUI::Layout::Distribute.split([[TUI.percent(0.25), nil], [TUI.flex(1), nil]], 20)
end

test 'auto uses the measured size' do
  assert_equal [7, 3], TUI::Layout::Distribute.split([[TUI.auto, 7], [TUI.auto, 3]], 20)
end

test 'specs never overflow the space available' do
  sizes = TUI::Layout::Distribute.split([[TUI.fixed(30), nil], [TUI.fixed(30), nil]], 10)
  assert_equal [10, 0], sizes
end

test 'a later spec gets whatever the earlier ones left' do
  sizes = TUI::Layout::Distribute.split([[TUI.fixed(8), nil], [TUI.auto, 5]], 10)
  assert_equal [8, 2], sizes
end

test 'rounding leftovers do not leave a gap' do
  sizes = TUI::Layout::Distribute.split([[TUI.flex(1), nil], [TUI.flex(1), nil], [TUI.flex(1), nil]], 10)
  assert_equal 10, sizes.sum
end

test 'gaps are taken out of the total' do
  sizes = TUI::Layout::Distribute.split([[TUI.flex(1), nil], [TUI.flex(1), nil]], 10, gap: 2)
  assert_equal 8, sizes.sum
end
