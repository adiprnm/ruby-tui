# frozen_string_literal: true
#
# SysData -- Linux system metrics straight out of /proc.
# Pure Ruby: File.read + parsing, no subprocesses.

require 'etc'

module SysData
  CLK_TCK = begin
    Etc.sysconf(Etc::SC_CLK_TCK)
  rescue StandardError
    100
  end

  PAGE_SIZE = begin
    Etc.sysconf(Etc::SC_PAGESIZE)
  rescue StandardError
    4096
  end

  module_function

  # --- CPU --------------------------------------------------------------

  # Raw jiffy counters from the aggregate `cpu` line of /proc/stat.
  def cpu_times
    File.foreach('/proc/stat') do |line|
      next unless line.start_with?('cpu ')
      return line.split[1..-1].map(&:to_i)
    end
    []
  rescue Errno::ENOENT
    []
  end

  # Busy fraction between two samples: (total_delta - idle_delta) / total_delta
  def cpu_delta(prev, cur)
    return 0.0 if prev.nil? || cur.nil? || prev.empty? || cur.empty?

    total = 0
    idle  = 0
    cur.each_index do |i|
      d = cur[i] - prev[i]
      d = 0 if d < 0
      total += d
      idle  += d if i == 3 || i == 4   # idle + iowait
    end
    return 0.0 if total <= 0
    ((total - idle).to_f / total).clamp(0.0, 1.0)
  end

  def cpu_count
    @cpu_count ||= Dir.glob('/sys/devices/system/cpu/cpu[0-9]*').length.nonzero? || 1
  end

  # --- memory -----------------------------------------------------------

  def meminfo
    info = {}
    File.foreach('/proc/meminfo') do |line|
      key, value = line.split(':', 2)
      next unless value
      info[key] = value.strip.split.first.to_i
    end
    info
  rescue Errno::ENOENT
    {}
  end

  # { total:, used:, available:, swap_total:, swap_used: } in kB
  def memory
    m = meminfo
    total = m['MemTotal'].to_i
    avail = m['MemAvailable'] || (m['MemFree'].to_i + m['Buffers'].to_i + m['Cached'].to_i)
    {
      total:       total,
      available:   avail.to_i,
      used:        total - avail.to_i,
      swap_total:  m['SwapTotal'].to_i,
      swap_used:   m['SwapTotal'].to_i - m['SwapFree'].to_i
    }
  end

  def loadavg
    File.read('/proc/loadavg').split[0, 3].map(&:to_f)
  rescue Errno::ENOENT
    [0.0, 0.0, 0.0]
  end

  def uptime
    File.read('/proc/uptime').split.first.to_f
  rescue Errno::ENOENT
    0.0
  end

  def format_uptime(seconds)
    s = seconds.to_i
    d, s = s.divmod(86_400)
    h, s = s.divmod(3_600)
    m, _  = s.divmod(60)
    d.positive? ? "#{d}d #{format('%02d:%02d', h, m)}" : format('%02d:%02d', h, m)
  end

  def format_bytes(kb)
    b = kb.to_f * 1024
    units = %w[B K M G T]
    i = 0
    while b >= 1024 && i < units.length - 1
      b /= 1024
      i += 1
    end
    b >= 100 || i.zero? ? format('%d%s', b, units[i]) : format('%.1f%s', b, units[i])
  end

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
