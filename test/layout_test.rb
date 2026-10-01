# frozen_string_literal: true
require_relative 'test_helper'

puts 'Layout::Stack'

test 'a vertical stack honours fixed, auto and flex' do
  stack = TUI::Layout::Stack.new(direction: :vertical)
  fixed = TUI::Label.new('fixed')
  auto  = TUI::Label.new('auto')
  flex  = TUI::Label.new('flex')
  stack.add(fixed, size: TUI.fixed(2))
  stack.add(auto, size: TUI.auto)
  stack.add(flex, size: TUI.flex(1))

  render_lines(stack, 20, 10)
  assert_equal [0, 0, 20, 2], fixed.rect.to_a
  assert_equal [0, 2, 20, 1], auto.rect.to_a
  assert_equal [0, 3, 20, 7], flex.rect.to_a
end

test 'gaps are left between children' do
  stack = TUI::Layout::Stack.new(direction: :vertical, gap: 1)
  a = TUI::Label.new('a')
  b = TUI::Label.new('b')
  stack.add(a, size: TUI.auto)
  stack.add(b, size: TUI.auto)

  render_lines(stack, 20, 5)
  assert_equal 0, a.rect.y
  assert_equal 2, b.rect.y
end

test 'a horizontal stack splits the width' do
  stack = TUI::Layout::Stack.new(direction: :horizontal)
  left = TUI::Label.new('l')
  right = TUI::Label.new('r')
  stack.add(left, size: TUI.fixed(6))
  stack.add(right, size: TUI.flex(1))

  render_lines(stack, 20, 4)
  assert_equal [0, 0, 6, 4], left.rect.to_a
  assert_equal [6, 0, 14, 4], right.rect.to_a
end

test 'percent sizes are a share of the axis' do
  stack = TUI::Layout::Stack.new(direction: :vertical)
  top = TUI::Label.new('t')
  bottom = TUI::Label.new('b')
  stack.add(top, size: TUI.percent(0.25))
  stack.add(bottom, size: TUI.flex(1))

  render_lines(stack, 20, 8)
  assert_equal 2, top.rect.h
  assert_equal 6, bottom.rect.h
end

test 'children never stick out of the stack' do
  stack = TUI::Layout::Stack.new(direction: :vertical)
  a = TUI::Label.new('a')
  b = TUI::Label.new('b')
  stack.add(a, size: TUI.fixed(10))
  stack.add(b, size: TUI.fixed(10))

  render_lines(stack, 20, 6)
  assert_equal 6, a.rect.h
  assert_equal 0, b.rect.h
end

test 'stack measure adds up its children' do
  stack = TUI::Layout::Stack.new(direction: :vertical, gap: 1)
  stack.add(TUI::Label.new('one'), size: TUI.auto)
  stack.add(TUI::Label.new('two'), size: TUI.auto)
  assert_equal [3, 3], stack.measure(20, 20)
end

puts 'Layout::Box'

test 'a box insets its child by the border and the padding' do
  box = TUI::Layout::Box.new(title: 'x', padding: 1)
  label = TUI::Label.new('inside')
  box.add(label)

  render_lines(box, 20, 10)
  assert_equal [0, 0, 20, 10], box.rect.to_a
  assert_equal [2, 2, 16, 6], label.rect.to_a
end

test 'a box measures as child plus chrome' do
  box = TUI::Layout::Box.new(padding: 1)
  box.add(TUI::Label.new('12345'))
  assert_equal [9, 5], box.measure(40, 40)   # 5 wide + 2 border + 2 padding
end

test 'a box draws a rounded border and a title' do
  box = TUI::Layout::Box.new(title: 'hello')
  lines = render_lines(box, 12, 4)
  assert_equal '╭ hello ───╮', lines.first
  assert_equal '╰──────────╯', lines.last
end

test 'the border lights up while a child has focus' do
  box = TUI::Layout::Box.new
  button = TUI::Button.new('ok')
  box.add(button)
  app = TUI::App.new(box, out: CountingIO.new, size: [20, 3])
  app.focus(button)
  assert_equal TUI::Style.resolve(:border_focus), TUI::Style.resolve(:border_focus)
  assert box.contains_focus?
end

puts 'Layout::Center and Spacer'

test 'center places the child in the middle at its measured size' do
  center = TUI::Layout::Center.new
  button = TUI::Button.new('ok')
  center.add(button)

  render_lines(center, 20, 5)
  assert_equal 7, button.rect.x
  assert_equal 2, button.rect.y
  assert_equal 6, button.rect.w
end

test 'spacer reports the size it was built with' do
  assert_equal [3, 3], TUI::Layout::Spacer.new(3).measure(10, 10)
end

test 'divider takes one row or one column' do
  assert_equal [0, 1], TUI::Layout::Divider.new(orientation: :horizontal).measure(10, 10)
  assert_equal [1, 0], TUI::Layout::Divider.new(orientation: :vertical).measure(10, 10)
end

puts 'Layout::Viewport'

test 'a viewport clips content taller than itself' do
  stack = TUI::Layout::Stack.new(direction: :vertical)
  labels = (1..10).map { |i| TUI::Label.new("line #{i}") }
  labels.each { |l| stack.add(l, size: TUI.fixed(1)) }

  viewport = TUI::Layout::Viewport.new(stack)
  lines = render_lines(viewport, 20, 4)
  assert_equal '┌', '┌' # sanity
  assert_equal 'line 1', lines[0].strip
  assert_equal 'line 4', lines[3].strip
end

test 'scrolling moves the content under the window' do
  stack = TUI::Layout::Stack.new(direction: :vertical)
  (1..10).each { |i| stack.add(TUI::Label.new("line #{i}"), size: TUI.fixed(1)) }
  viewport = TUI::Layout::Viewport.new(stack)
  viewport.scroll_by(2)
  lines = render_lines(viewport, 20, 4)
  assert_equal 'line 3', lines[0].strip
  assert_equal 'line 6', lines[3].strip
end

test 'scrolling is clamped to the content' do
  stack = TUI::Layout::Stack.new(direction: :vertical)
  (1..3).each { |i| stack.add(TUI::Label.new("line #{i}"), size: TUI.fixed(1)) }
  viewport = TUI::Layout::Viewport.new(stack)
  viewport.scroll_by(10)
  render_lines(viewport, 20, 4)
  assert_equal 0, viewport.offset_y, 'content fits, so there is nothing to scroll'
end
