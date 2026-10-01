# frozen_string_literal: true
#
# SysData::Processes -- a snapshot of every readable /proc/<pid>/stat, and
# the arithmetic that turns two snapshots into a cpu% per process.

module SysData
  module_function

  # --- processes --------------------------------------------------------

  # Snapshot of every readable process.
  #   { pid:, name:, ticks:, rss_kb: }
  def process_snapshot
    out = []
    Dir.glob('/proc/[0-9]*').each do |dir|
      pid = File.basename(dir).to_i
      begin
        raw = File.read("#{dir}/stat")
      rescue Errno::ENOENT, Errno::EACCES, Errno::ESRCH
        next
      end

      # comm is wrapped in parens and may itself contain spaces or parens.
      open_paren = raw.index('(')
      close_paren = raw.rindex(')')
      next unless open_paren && close_paren

      name = raw[(open_paren + 1)...close_paren]
      rest = raw[(close_paren + 2)..-1].to_s.split
      next if rest.length < 22

      utime = rest[11].to_i
      stime = rest[12].to_i
      rss   = rest[21].to_i

      out << {
        pid:    pid,
        name:   name,
        ticks:  utime + stime,
        rss_kb: rss * PAGE_SIZE / 1024
      }
    end
    out
  end

  # Turn two snapshots into rows with cpu% / mem% over the sample window.
  # Left unsorted: the caller decides how to rank them.
  def process_rows(before, after, mem_total_kb)
    prev = {}
    before.each { |p| prev[p[:pid]] = p[:ticks] } if before

    after.map do |p|
      delta = p[:ticks] - (prev[p[:pid]] || p[:ticks])
      delta = 0 if delta.negative?
      cpu = delta * 100.0 / CLK_TCK        # % of one core over the window
      {
        pid:   p[:pid],
        name:  p[:name],
        cpu:   cpu,
        rss:   p[:rss_kb],
        mem:   mem_total_kb.positive? ? p[:rss_kb] * 100.0 / mem_total_kb : 0.0,
        ticks: p[:ticks]
      }
    end
  end
end
