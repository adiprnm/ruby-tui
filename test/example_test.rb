# frozen_string_literal: true
require_relative 'test_helper'
require 'pty'
require 'timeout'

require_relative '../examples/rtop/app'

puts 'Example -- rtop built on the toolkit'

def rtop_app
  app = Rtop::App.new
  app.refresh!          # first snapshot
  sleep 0.1
  app.refresh!          # and one with a real delta behind it
  app
end

test 'the dashboard renders its panels' do
  app = rtop_app
  text = TUI::App.new(app.root, out: CountingIO.new, size: [100, 30]).render_lines
             .map { |line| plain(line) }.join("\n")
  assert_includes text, 'CPU'
  assert_includes text, 'Memory'
  assert_includes text, 'System'
  assert_includes text, 'Top processes'
  assert_includes text, 'COMMAND'
end

test 'the views are reachable through the tab bar' do
  app = rtop_app
  render = lambda do
    TUI::App.new(app.root, out: CountingIO.new, size: [100, 30]).render_lines
               .map { |line| plain(line) }.join("\n")
  end

  assert_includes render.call, 'Top processes'
  app.select_tab(1)
  assert_includes render.call, 'COMMAND'
  app.select_tab(2)
  assert_includes render.call, 'system monitor built with the TUI toolkit'
end

test 'the process table sorts by cpu and by memory' do
  app = rtop_app
  app.select_tab(1)
  proc_box = app.instance_variable_get(:@proc_box)
  assert_equal 'by cpu', proc_box.title_right.split('·').last.strip

  app.sort(1)
  assert_equal 'by memory', proc_box.title_right.split('·').last.strip
  app.sort(-1)
  assert_includes proc_box.title_right, 'by cpu'
end

test 'every view fits every size' do
  app = rtop_app
  [[56, 14], [80, 24], [120, 34], [200, 50]].each do |cols, rows|
    3.times do |view|
      app.select_tab(view)
      lines = TUI::App.new(app.root, out: CountingIO.new, size: [cols, rows]).render_lines
      assert_equal rows, lines.length, "#{view} at #{cols}x#{rows}"
      lines.each do |line|
        assert_equal cols, plain(line).length
      end
    end
  end
end

test 'a resample keeps the rows and the sort order' do
  app = rtop_app
  app.select_tab(1)
  table = app.instance_variable_get(:@proc_table)
  assert table.rows.length.positive?

  app.refresh!
  assert table.rows.length.positive?
  assert_equal :cpu, table.sort_key, 'the sort survives new data'
  assert_equal :desc, table.sort_direction
end

puts 'Example -- end to end in a pty'

test 'bin/rtop runs, takes keys and restores the terminal' do
  out = +''
  status = nil
  root = File.expand_path('..', __dir__)

  PTY.spawn('ruby', File.join(root, 'bin', 'rtop')) do |reader, writer, pid|
    drain = Thread.new do
      loop { out << reader.readpartial(65_536) }
    rescue EOFError, Errno::EIO
    end

    sleep 1.2
    ['2', "\t", 'j', 'j', "\e[D", "\e[6~", '3', '1', 'q'].each do |key|
      writer.print(key)
      writer.flush
      sleep 0.3
    end

    begin
      Timeout.timeout(10) { _, status = Process.wait2(pid) }
    rescue Timeout::Error
      Process.kill('KILL', pid)
      status = nil
    end
    drain.join(1)
  end

  text = plain(out)

  assert status && status.success?, "rtop must exit cleanly (got #{status.inspect})"
  assert_includes out, TUI::Term::ALT_ON
  assert_includes out, TUI::Term::ALT_OFF
  assert_includes out, TUI::Term::HIDE_CURSOR
  assert_includes out, TUI::Term::SHOW_CURSOR
  assert_includes text, 'COMMAND', 'the processes view was reached'
  assert_includes text, 'by memory', 'the sort changed with the left arrow'
  assert_includes text, 'Dashboard', 'the help view was reached and left again'
  refute text.include?('jjjj'), 'keys are not echoed'
end

puts 'Example -- hello'

test 'the hello example renders a form' do
  out = `ruby #{File.expand_path('../examples/hello.rb', __dir__)} --snapshot 2>&1`
  text = plain(out)
  assert_includes text, 'Name'
  assert_includes text, 'Secret'
  assert_includes text, '[ Save ]'
  assert_includes text, 'hello'   # the title bar
end
