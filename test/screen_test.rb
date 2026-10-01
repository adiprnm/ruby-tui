# frozen_string_literal: true
require_relative 'test_helper'

puts 'Screen -- differential painting'

def screen(io, cols, rows)
  TUI::Screen.new(io, size: [cols, rows])
end

test 'the first frame paints every row in one write' do
  io = CountingIO.new
  s = screen(io, 40, 10)
  canvas = s.frame
  canvas.put(0, 0, 'hello', :text)
  s.present(canvas)

  assert_equal 1, io.writes
  assert io.bytes > 40 * 10, "expected a full first paint, wrote #{io.bytes} bytes"
end

test 'an unchanged frame costs only the sync markers' do
  io = CountingIO.new
  s = screen(io, 40, 10)
  draw = lambda do
    canvas = s.frame
    canvas.box(TUI::Rect.new(0, 0, 40, 10), :border, title: 'static')
    s.present(canvas)
  end

  draw.call
  io.reset
  draw.call
  assert io.bytes < 40, "expected a cheap repaint, wrote #{io.bytes} bytes"
end

test 'only the rows that changed are written' do
  io = CountingIO.new
  s = screen(io, 40, 10)

  first = s.frame
  first.put(2, 1, 'one', :text)
  first.put(2, 5, 'five', :text)
  s.present(first)

  io.reset
  second = s.frame
  second.put(2, 1, 'one', :text)
  second.put(2, 5, 'FIVE', :text)
  s.present(second)

  assert io.bytes.positive?
  assert io.bytes < 40 * 3, "expected a single row update, wrote #{io.bytes} bytes"
end

test 'rows that stop being drawn are cleared' do
  io = CountingIO.new
  s = screen(io, 40, 10)

  first = s.frame
  first.put(2, 1, 'temporary', :text)
  s.present(first)

  second = s.frame
  second.put(2, 2, 'other', :text)
  s.present(second)

  assert_equal ' ' * 40, plain(s.instance_variable_get(:@prev)[1])
end

test 'resize clears the cached rows and reports the change' do
  io = CountingIO.new
  s = screen(io, 40, 10)
  s.present(s.frame)

  s.instance_variable_set(:@fixed_size, [50, 12])
  assert s.resize!
  assert_equal [], s.instance_variable_get(:@prev)
  assert_equal [50, 12], s.to_size
end

test 'the canvas is pooled between frames' do
  io = CountingIO.new
  s = screen(io, 20, 5)
  first = s.frame
  s.present(first)
  assert first.equal?(s.frame)
end
