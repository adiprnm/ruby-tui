# frozen_string_literal: true
#
# SysData -- everything rtop knows about the machine, read from /proc.
# Parsing lives in sysdata/*.rb; this file owns the namespace and the two
# kernel constants the parsers need.

require 'etc'

module SysData
  # Jiffies per second (usually 100) and bytes per page -- needed to turn
  # raw counters from /proc into percentages and sizes.
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
end

require_relative 'sysdata/system'
require_relative 'sysdata/processes'
