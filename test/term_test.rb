# frozen_string_literal: true
require_relative 'test_helper'

puts 'Term -- width and keys'

test 'cell widths cover ASCII, CJK, emoji and marks' do
  assert_equal 1, TUI::Term.width('a')
  assert_equal 1, TUI::Term.width('─')
  assert_equal 2, TUI::Term.width('日')
  assert_equal 2, TUI::Term.width('😀')
  assert_equal 0, TUI::Term.codepoint_width(0x0301)
end

test 'escape sequences map to key names' do
  sequences = TUI::Term::SEQUENCES
  assert_equal :up, sequences["\e[A"]
  assert_equal :down, sequences["\e[B"]
  assert_equal :page_down, sequences["\e[6~"]
  assert_equal :backtab, sequences["\e[Z"]
  assert_equal :delete, sequences["\e[3~"]
end

test 'function keys are understood in both usual encodings' do
  sequences = TUI::Term::SEQUENCES
  assert_equal :f1, sequences["\eOP"]
  assert_equal :f2, sequences["\eOQ"]
  assert_equal :f2, sequences["\e[12~"]
  assert_equal :f12, sequences["\e[24~"]
end

test 'key objects know about printable characters and modifiers' do
  space = TUI::Key.printable(' ')
  assert space.space?
  assert space.printable?
  assert_equal ' ', space.name

  ctrl = TUI::Key.new(:ctrl_c)
  refute ctrl.printable?
  assert ctrl.ctrl?('c')
  refute ctrl.ctrl?('d')
  assert_equal :ctrl_c, ctrl.name
end

test 'keys compare by name so bindings are hashable' do
  assert_equal TUI::Key.new(:enter), TUI::Key.new(:enter)
  assert_equal TUI::Key.printable('q').hash, TUI::Key.printable('q').hash
end

test 'the terminal size falls back to COLUMNS and LINES' do
  old = [ENV['COLUMNS'], ENV['LINES']]
  ENV['COLUMNS'] = '123'
  ENV['LINES'] = '45'
  assert_equal [123, 45], TUI::Term.size

  ENV['COLUMNS'] = '0'
  ENV['LINES'] = '-3'
  assert_equal [80, 24], TUI::Term.size
ensure
  ENV['COLUMNS'], ENV['LINES'] = old
end

puts 'Theme -- neutral by default'

test 'the accent carries no colour of its own' do
  accent = TUI::Style.resolve(:accent)
  refute accent.include?('38;5;'), "accent should inherit the terminal foreground: #{accent.inspect}"
  refute accent.include?('48;5;'), 'accents never paint a background'
end

test 'text fields carry no colour at all' do
  %i[field placeholder cursor cursor_placeholder].each do |name|
    sgr = TUI::Style.resolve(name)
    refute sgr.include?('38;5;'), "#{name} should inherit the terminal foreground: #{sgr.inspect}"
    refute sgr.include?('48;5;'), "#{name} should not paint a background: #{sgr.inspect}"
  end
end

test 'the plain theme keeps the whole chrome colourless' do
  chrome = %i[text value field title subtitle accent tab_active tab_inactive
              muted dim hint label header placeholder border border_focus
              track grid thumb selection selection_dim cursor
              cursor_placeholder]

  TUI::Theme.install(:plain)
  chrome.each do |name|
    sgr = TUI::Style.resolve(name)
    refute sgr.include?('38;5;'), "#{name} sets a foreground in the plain theme: #{sgr.inspect}"
    refute sgr.include?('48;5;'), "#{name} sets a background in the plain theme: #{sgr.inspect}"
  end
ensure
  TUI::Theme.install(:dark)
end

test 'the cursor is hueless too' do
  cursor = TUI::Style.resolve(:cursor)
  refute cursor.include?('38;5;')
  refute cursor.include?('48;5;')
end

# xterm-256: 232..255 is the grey ramp, and inside the colour cube (16..231)
# the grey axis is the one where r == g == b (16 = black, 231 = white).
def neutral?(index)
  return true if index >= 232
  return false if index < 16

  n = index - 16
  r = n / 36
  g = (n % 36) / 6
  b = n % 6
  r == g && g == b
end

test 'only status and data styles carry a hue' do
  hued = TUI::Style.names.select do |name|
    sgr = TUI::Style.resolve(name)
    sgr.scan(/(?:38|48);5;(\d+)/).flatten.map(&:to_i).any? { |c| !neutral?(c) }
  end.sort

  assert_equal %i[danger error success warning], hued,
               "only semantic status styles should be coloured, got #{hued.inspect}"
end

