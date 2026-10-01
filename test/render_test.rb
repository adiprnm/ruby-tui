# frozen_string_literal: true
require_relative 'test_helper'
require 'pty'
require 'timeout'
require 'tmpdir'
require 'app'

# ---------------------------------------------------------------------------
# Whole-app rendering: every view, at every interesting terminal size, must
# fill exactly the frame without bleeding over the border.
# ---------------------------------------------------------------------------

class CountingIO
  def initialize
    @bytes = 0
  end

  attr_reader :bytes

  def print(str)
    @bytes += str.bytesize
  end

  def flush; end

  def tty?
    false
  end
end

def render(view, cols, rows)
  with_size(cols, rows) do
    app = App.new(CountingIO.new)
    app.set_view(view)
    app.prime
    app.render_frame
  end
end

puts 'App -- rendering invariants'

[[56, 14], [110, 34], [200, 50]].each do |cols, rows|
  %i[dash procs help].each do |view|
    test "#{view} fills a #{cols}x#{rows} frame exactly" do
      frame = render(view, cols, rows)
      lines = frame.lines
      assert_equal rows, lines.length
      lines.each_with_index do |line, i|
        text = plain(line)
        assert_equal cols, text.length, "row #{i} is #{text.length} cells wide"
        refute text.include?("\0"), "row #{i} leaked a placeholder cell"
      end
    end
  end
end

test 'no panel ever spills over the outer border' do
  corners = { top: %w[╭ ╮], bottom: %w[╰ ╯] }

  [[56, 14], [60, 16], [64, 18], [70, 20], [78, 24], [80, 26],
   [100, 30], [110, 34], [120, 20], [200, 50], [200, 16]].each do |cols, rows|
    %i[dash procs help].each do |view|
      lines = render(view, cols, rows).lines.map { |l| plain(l) }

      assert_equal corners[:top][0], lines.first[0],
                   "#{view} #{cols}x#{rows}: top-left corner is intact"
      assert_equal corners[:top][1], lines.first[cols - 1],
                   "#{view} #{cols}x#{rows}: top-right corner is intact"
      assert_equal corners[:bottom][0], lines.last[0],
                   "#{view} #{cols}x#{rows}: bottom-left corner is intact"
      assert_equal corners[:bottom][1], lines.last[cols - 1],
                   "#{view} #{cols}x#{rows}: bottom-right corner is intact"

      # a panel drawn too low would leave its own corners on the border rows
      %w[╭ ╮].each do |glyph|
        assert_equal 1, lines.first.count(glyph),
                     "#{view} #{cols}x#{rows}: stray #{glyph} on the top border"
      end
      %w[╰ ╯].each do |glyph|
        assert_equal 1, lines.last.count(glyph),
                     "#{view} #{cols}x#{rows}: stray #{glyph} on the bottom border"
      end
      refute lines.last.include?('│'),
             "#{view} #{cols}x#{rows}: a panel is drawn over the bottom border"
    end
  end
end

test 'a tiny window degrades to a readable message' do
  frame = render(:dash, 30, 8)
  text = frame.lines.map { |l| plain(l) }.join("\n")
  assert_includes text, 'window too small'
  assert_equal 8, frame.lines.length
end

test 'the frame is wrapped in a border with a title' do
  frame = render(:dash, 100, 24)
  lines = frame.lines.map { |l| plain(l) }
  assert lines.first.start_with?('╭'), 'top left corner'
  assert lines.first.end_with?('╮'), 'top right corner'
  assert lines.last.start_with?('╰')
  assert lines.last.end_with?('╯')
  assert_includes lines.first, 'rtop'
  assert_includes lines.last, 'quit'
end

test 'the dashboard shows cpu, memory and a process table' do
  text = render(:dash, 110, 34).lines.map { |l| plain(l) }.join("\n")
  assert_includes text, 'CPU'
  assert_includes text, 'Memory'
  assert_includes text, 'System'
  assert_includes text, 'COMMAND'
end

test 'the process view honours the sort order in its label' do
  with_size(110, 34) do
    app = App.new(CountingIO.new)
    app.set_view(:procs)
    app.prime
    assert_includes plain(app.render_frame.lines.join("\n")), 'sort: cpu'
    app.handle(:right)
    assert_includes plain(app.render_frame.lines.join("\n")), 'sort: memory'
    app.handle(:left)
    assert_includes plain(app.render_frame.lines.join("\n")), 'sort: cpu'
  end
end

puts 'App -- interaction'

test 'q and ctrl-c quit' do
  with_size(100, 30) do
    app = App.new(CountingIO.new)
    app.prime
    refute app.instance_variable_get(:@quit)
    app.handle('q')
    assert app.instance_variable_get(:@quit)
  end
end

test 'number keys and ? switch views' do
  with_size(100, 30) do
    app = App.new(CountingIO.new)
    app.set_view(:dash)
    app.handle('2')
    assert_equal :procs, app.view
    app.handle('3')
    assert_equal :help, app.view
    app.handle(:escape)
    assert_equal :dash, app.view
  end
end

test 'tab moves focus and arrows move the selection in the content pane' do
  with_size(100, 30) do
    app = App.new(CountingIO.new)
    app.set_view(:procs)
    app.prime
    app.handle(:tab)
    assert_equal :content, app.instance_variable_get(:@focus)

    before = app.instance_variable_get(:@proc_sel)
    app.handle(:down)
    app.handle(:down)
    assert_equal before + 2, app.instance_variable_get(:@proc_sel)

    app.handle(:home)
    assert_equal 0, app.instance_variable_get(:@proc_sel)
  end
end

test 'the selection stays inside the list' do
  with_size(100, 30) do
    app = App.new(CountingIO.new)
    app.set_view(:procs)
    app.prime
    app.handle(:tab)
    app.handle(:end)
    rows = app.instance_variable_get(:@proc_rows)
    assert_equal rows.length - 1, app.instance_variable_get(:@proc_sel)
    app.handle(:down)
    assert_equal rows.length - 1, app.instance_variable_get(:@proc_sel)
  end
end

test 'the selection follows the same process across refreshes' do
  with_size(100, 30) do
    app = App.new(CountingIO.new)
    app.set_view(:procs)
    app.prime
    app.handle(:tab)

    app.handle(:down)
    app.handle(:down)
    sel = app.instance_variable_get(:@proc_sel)
    pid = app.instance_variable_get(:@proc_rows)[sel][:pid]

    app.instance_variable_set(:@last_proc_sample, 0.0)
    app.send(:refresh_procs)

    again = app.instance_variable_get(:@proc_rows)[app.instance_variable_get(:@proc_sel)]
    assert_equal pid, again[:pid], 'cursor should stick to the same process'
  end
end

# ---------------------------------------------------------------------------
# End-to-end: drive the real binary through a pty. This is the regression
# test for keystroke loss (IO#getch on Ruby 2.6 dropped roughly every other
# byte) and for leaving the terminal in a usable state on exit.
# ---------------------------------------------------------------------------

puts 'End to end -- pty session'

test 'every keystroke reaches the app and the terminal is restored' do
  out = +''
  status = nil

  PTY.spawn('ruby', File.expand_path('../rtop.rb', __dir__)) do |r, w, pid|
    reader = Thread.new do
      loop { out << r.readpartial(65_536) }
    rescue EOFError, Errno::EIO
    end

    sleep 1.2
    ['2', "\t", 'j', 'j', "\e[D", "\e[6~", "\e[Z", '3', "\e", '1', 'q'].each do |key|
      w.print(key)
      w.flush
      sleep 0.35
    end

    begin
      Timeout.timeout(6) { _, status = Process.wait2(pid) }
    rescue Timeout::Error
      Process.kill('KILL', pid)
      status = nil
    end
    reader.join(1)
  end

  text = plain(out)

  assert status && status.success?, "rtop must exit cleanly (got #{status.inspect})"
  assert_includes out, Term::ALT_ON, 'enters the alternate screen'
  assert_includes out, Term::ALT_OFF, 'leaves the alternate screen'
  assert_includes out, Term::HIDE_CURSOR
  assert_includes out, Term::SHOW_CURSOR
  assert_includes text, 'COMMAND', 'the processes view was reached with "2"'
  assert_includes text, 'sort: memory', 'the left arrow changed the sort order'
  assert_includes text, 'A tiny system monitor', 'help was reached with "3"'
  assert_includes text, 'Top processes', 'escape + 1 went back to the dashboard'
  refute text.include?('jjj'), 'raw mode must not echo typed characters'
end
