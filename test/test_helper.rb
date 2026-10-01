# frozen_string_literal: true
#
# Minimal test harness -- stdlib only, so `ruby test/run.rb` works anywhere
# Ruby does. No minitest, no gems.

$LOAD_PATH.unshift(File.expand_path('../lib', __dir__))
require 'tui'
require 'stringio'

module Harness
  class Failure < StandardError; end

  @passed = 0
  @failures = []
  @cases = 0

  class << self
    attr_reader :passed, :failures

    def test(name)
      @cases ||= 0
      @cases += 1
      yield
      @passed += 1
      puts "  \e[32m✓\e[0m #{name}"
    rescue Failure => e
      @failures << [name, e]
      puts "  \e[31m✗\e[0m #{name}\n      #{e.message}"
    rescue StandardError => e
      @failures << [name, e]
      puts "  \e[31m✗\e[0m #{name}\n      #{e.class}: #{e.message}"
      puts e.backtrace.first(5).map { |l| "        #{l}" }.join("\n")
    end

    def report!
      puts
      if @failures.empty?
        puts "\e[32m#{@passed}/#{@cases} tests passed\e[0m"
      else
        puts "\e[31m#{@failures.length} of #{@cases} tests failed\e[0m"
      end
    end

    def failed?
      !(@failures || []).empty?
    end
  end
end

def test(name, &block)
  Harness.test(name, &block)
end

def assert(condition, message = 'expected condition to be true')
  raise Harness::Failure, message unless condition
end

def assert_equal(expected, actual, message = nil)
  return if expected == actual

  raise Harness::Failure, message || "expected #{expected.inspect}, got #{actual.inspect}"
end

def assert_includes(haystack, needle, message = nil)
  return if haystack.include?(needle)

  raise Harness::Failure, message || "expected #{haystack.inspect} to include #{needle.inspect}"
end

def refute(condition, message = 'expected condition to be false')
  raise Harness::Failure, message if condition
end

# Strip SGR escapes so tests can assert on the text of a render.
def plain(str)
  str.gsub(/\e\[[0-9;?]*[a-zA-Z]/, '')
end

# Render a tree to an array of plain-text rows at a fixed size.
def render_lines(root, cols = 80, rows = 24)
  TUI.render(root, cols: cols, rows: rows).lines.map { |line| plain(line) }
end

def render_text(root, cols = 80, rows = 24)
  render_lines(root, cols, rows).join("\n")
end

# A sink that counts what was written, for renderer tests.
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

# A component focusing helper: every focusable gets a name so tests can
# assert on the tab order.
class NamedLabel < TUI::Label
  attr_accessor :name

  def initialize(name, **opts)
    super(name, **opts)
    @name = name
  end

  def focusable?
    true
  end

  def render(canvas)
    canvas.text(rect, "#{@name}#{focused? ? '*' : ''}", :text)
  end
end

at_exit do
  Harness.report!
  exit(1) if Harness.failed?
end
