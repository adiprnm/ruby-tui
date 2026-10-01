# frozen_string_literal: true
#
# SysData::System -- CPU, memory, load and uptime, read straight out of
# /proc. Pure Ruby: File.read plus parsing, no subprocesses.

module SysData
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
end
