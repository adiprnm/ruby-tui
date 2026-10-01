# frozen_string_literal: true
require_relative 'test_helper'
require 'term'

puts 'Term -- width calculation'

test 'ASCII is one cell' do
  assert_equal 1, Term.width('a')
  assert_equal 1, Term.codepoint_width('█'.ord)
  assert_equal 11, Term.text_width('hello world')
end

test 'CJK and emoji are two cells' do
  assert_equal 2, Term.width('日')
  assert_equal 2, Term.width('あ')
  assert_equal 6, Term.text_width('日本語')
end

test 'combining marks take no cell' do
  assert_equal 0, Term.codepoint_width(0x0301)   # combining acute
  assert_equal 1, Term.text_width("e\u0301")
end

test 'box drawing and block glyphs are one cell' do
  assert_equal 1, Term.width('─')
  assert_equal 1, Term.width('▄')
  assert_equal 1, Term.width('░')
end

puts 'Term -- size'

test 'size falls back to COLUMNS/LINES when not a tty' do
  with_size(101, 42) do
    assert_equal [101, 42], Term.size
  end
end

test 'size ignores nonsense values' do
  with_size(0, -5) do
    assert_equal [80, 24], Term.size
  end
end

puts 'Term -- key parsing'

test 'escape sequences map to named keys' do
  seq = Term::SEQUENCES
  assert_equal :up, seq["\e[A"]
  assert_equal :down, seq["\e[B"]
  assert_equal :right, seq["\e[C"]
  assert_equal :left, seq["\e[D"]
  assert_equal :page_down, seq["\e[6~"]
  assert_equal :backtab, seq["\e[Z"]
  assert_equal :home, seq["\e[1~"] if seq.key?("\e[1~")
end
