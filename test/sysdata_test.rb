# frozen_string_literal: true
require_relative 'test_helper'
require 'sysdata'

puts 'SysData -- /proc parsing'

test 'cpu_times returns jiffy counters' do
  times = SysData.cpu_times
  assert times.length >= 4, "expected at least user/nice/system/idle, got #{times.inspect}"
  assert times.all? { |t| t.is_a?(Integer) && t >= 0 }
end

test 'cpu_delta computes the busy fraction' do
  idle   = [0, 0, 0, 0, 0]
  loaded = [200, 0, 0, 600, 0]   # 200 busy of 800 jiffies -> 25 %
  assert_equal 0.25, SysData.cpu_delta(idle, loaded)
end

test 'cpu_delta is safe with missing samples' do
  assert_equal 0.0, SysData.cpu_delta(nil, [1, 2, 3, 4])
  assert_equal 0.0, SysData.cpu_delta([1, 2, 3, 4], [])
  assert_equal 0.0, SysData.cpu_delta([5, 5, 5, 5], [5, 5, 5, 5])
end

test 'memory reports sane totals' do
  mem = SysData.memory
  assert mem[:total].positive?, 'MemTotal should be positive'
  assert mem[:used] >= 0
  assert mem[:used] <= mem[:total]
  assert mem[:swap_total] >= 0
end

test 'loadavg returns three floats' do
  load = SysData.loadavg
  assert_equal 3, load.length
  assert load.all? { |v| v.is_a?(Float) }
end

test 'uptime is a positive number of seconds' do
  assert SysData.uptime.positive?
end

test 'format_uptime renders hh:mm and days' do
  assert_equal '00:00', SysData.format_uptime(0)
  assert_equal '01:30', SysData.format_uptime(90 * 60)
  assert_equal '1d 01:00', SysData.format_uptime(25 * 3600)
end

test 'format_bytes picks a readable unit' do
  assert_equal '512B', SysData.format_bytes(0.5)
  assert_equal '1.0K', SysData.format_bytes(1)
  assert_equal '1.5M', SysData.format_bytes(1536)
  assert_equal '2.0G', SysData.format_bytes(2 * 1024 * 1024)
end

puts 'SysData -- processes'

test 'process_snapshot lists the current process' do
  procs = SysData.process_snapshot
  assert procs.length > 1, "expected several processes, got #{procs.length}"
  assert procs.any? { |p| p[:pid] == Process.pid }, 'should include this process'
  assert procs.all? { |p| p[:pid].positive? && p[:rss_kb] >= 0 }
end

test 'process_rows computes cpu percentage from tick deltas' do
  before = [{ pid: 1, name: 'a', ticks: 100, rss_kb: 10 }, { pid: 2, name: 'b', ticks: 100, rss_kb: 10 }]
  after  = [{ pid: 1, name: 'a', ticks: 200, rss_kb: 10 }, { pid: 2, name: 'b', ticks: 100, rss_kb: 10 }]

  rows = SysData.process_rows(before, after, 100)
  a = rows.find { |r| r[:pid] == 1 }
  b = rows.find { |r| r[:pid] == 2 }

  expected = 100 * 100.0 / SysData::CLK_TCK
  assert_equal expected, a[:cpu]
  assert_equal 0.0, b[:cpu]
end

test 'process_rows tolerates processes that appeared mid-flight' do
  after = [{ pid: 9, name: 'new', ticks: 500, rss_kb: 2048 }]
  rows = SysData.process_rows([], after, 1024)
  assert_equal 1, rows.length
  assert_equal 0.0, rows.first[:cpu]
  assert_equal 200.0, rows.first[:mem]
end
