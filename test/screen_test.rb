# frozen_string_literal: true
require_relative 'test_helper'
require 'screen'
require 'widgets'

# An output sink that just counts what it is asked to print.
class CountingIO
  attr_reader :bytes, :writes

  def initialize
    @bytes = 0
    @writes = 0
  end

  def print(str)
    @bytes += str.bytesize
    @writes += 1
  end

  def flush; end

  def tty?
    false
  end

  def reset
    @bytes = 0
    @writes = 0
  end
end

puts 'Screen -- differential painting'

with_size(40, 10) do
  test 'the first frame paints every row' do
    io = CountingIO.new
    screen = Screen.new(io)
    f = screen.frame
    f.put(0, 0, 'hello', :text)
    screen.present(f)

    # one write, sync markers plus a full frame of rows
    assert_equal 1, io.writes
    assert io.bytes > 40 * 10, "expected a full first paint, wrote #{io.bytes} bytes"
  end

  test 'an unchanged frame costs almost nothing' do
    io = CountingIO.new
    screen = Screen.new(io)
    draw = lambda do
      f = screen.frame
      Widgets.box(f, 0, 0, 40, 10)
      f.put(2, 1, 'static', :text)
      screen.present(f)
    end

    draw.call
    io.reset
    draw.call
    # only the two synchronised-output markers
    assert io.bytes < 40, "expected a cheap repaint, wrote #{io.bytes} bytes"
  end

  test 'only rows that changed are sent to the terminal' do
    io = CountingIO.new
    screen = Screen.new(io)

    a = screen.frame
    a.put(2, 1, 'one', :text)
    a.put(2, 3, 'three', :text)
    screen.present(a)

    io.reset
    b = screen.frame
    b.put(2, 1, 'one', :text)
    b.put(2, 3, 'THREE', :text)   # only this row differs
    screen.present(b)

    # the emitted payload must be far smaller than a full 10-row frame
    assert io.bytes.positive?
    assert io.bytes < 40 * 3, "expected a single-row update, wrote #{io.bytes} bytes"
  end

  test 'rows that stop being drawn are cleared on the terminal' do
    io = CountingIO.new
    screen = Screen.new(io)

    a = screen.frame
    a.put(2, 1, 'temporary', :text)
    screen.present(a)

    b = screen.frame
    b.put(2, 2, 'other', :text)
    screen.present(b)

    prev = screen.instance_variable_get(:@prev)
    assert_equal ' ' * 40, plain(prev[1]), 'stale row is blanked, not left behind'
  end

  test 'resize! drops cached rows and clears the screen' do
    io = CountingIO.new
    screen = Screen.new(io)
    f = screen.frame
    f.put(0, 0, 'x', :text)
    screen.present(f)

    with_size(50, 12) do
      assert screen.resize!
    end
    assert_equal [], screen.instance_variable_get(:@prev)
    assert_equal 50, screen.w
    assert_equal 12, screen.h
  end

  test 'frame reuses one buffer across ticks' do
    io = CountingIO.new
    screen = Screen.new(io)
    first = screen.frame
    screen.present(first)
    assert first.equal?(screen.frame), 'frame buffer should be pooled'
  end
end
