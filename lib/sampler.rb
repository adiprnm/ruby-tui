# frozen_string_literal: true
#
# Sampler -- the data acquisition half of App.
#
# It reads /proc on a schedule, keeps the last value of every metric, and
# hands over plain data. It knows nothing about the UI, keys or rendering,
# which is why it can be exercised from a script or a test without a
# terminal.

require_relative 'sysdata'

class Sampler
  CPU_PERIOD  = 0.2   # push a CPU sample into the history every 0.2s
  PROC_PERIOD = 1.0   # rescan /proc for processes once a second
  HISTORY     = 512   # CPU samples kept for the chart

  attr_reader :cpu, :cpu_count, :mem, :loadavg, :boot, :hostname,
              :history, :processes, :process_count

  def initialize
    @cpu         = 0.0
    @history     = []
    @cpu_prev    = nil
    @cpu_count   = SysData.cpu_count

    @mem         = SysData.memory
    @loadavg     = SysData.loadavg
    @boot        = SysData.uptime
    @hostname    = read_hostname

    @processes     = []
    @process_count = 0
    @snapshot      = nil

    @last_cpu   = 0.0
    @last_procs = 0.0
  end

  # Refresh whatever is due. Returns true when the process table was
  # resampled, so the caller can re-rank it and keep its cursor in place.
  def tick(force: false)
    sample_cpu if force || due?(@last_cpu, CPU_PERIOD)
    return false unless force || due?(@last_procs, PROC_PERIOD)

    sample_processes
    true
  end

  private

  def due?(last, period)
    clock - last >= period
  end

  def clock
    Process.clock_gettime(Process::CLOCK_MONOTONIC)
  end

  def sample_cpu
    @last_cpu = clock

    current = SysData.cpu_times
    unless current.empty?
      if @cpu_prev
        @cpu = SysData.cpu_delta(@cpu_prev, current)
        @history << @cpu
        @history.shift while @history.length > HISTORY
      end
      @cpu_prev = current
    end

    @mem     = SysData.memory
    @loadavg = SysData.loadavg
    @boot    = SysData.uptime
  end

  def sample_processes
    @last_procs = clock

    snapshot = SysData.process_snapshot
    @processes     = SysData.process_rows(@snapshot, snapshot, @mem[:total])
    @process_count = snapshot.length
    @snapshot      = snapshot
  end

  def read_hostname
    File.read('/proc/sys/kernel/hostname').strip
  rescue StandardError
    'localhost'
  end
end
