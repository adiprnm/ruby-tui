# frozen_string_literal: true
#
# rtop -- a system monitor built out of the generic TUI toolkit.
#
# The whole UI is composition: a bordered Box at the root, a vertical TabBar
# plus a stats panel in the sidebar column, and three panes (a dashboard of
# ProgressBars and a BarChart, a sortable Table, and a stack of Labels).
# Nothing here draws a cell by hand.

require 'tui'

require_relative 'sampler'

module Rtop
  class App
    SAMPLE_PERIOD = 0.2
    TOP_ROWS = 8

    attr_reader :root

    def initialize
      @sampler = Sampler.new
      @sampler.tick(force: true)
      build_ui
      @tables.each { |table| table.sort_by(:cpu, :desc) }
      @top_box.title_right = sort_label
      @proc_box.title_right = sort_label
      sync!
    end

    # --- construction -----------------------------------------------------

    def build_ui
      @tab_bar = TUI::TabBar.new(
        items: ['◈  Dashboard', '▤  Processes', '?  Help'],
        orientation: :vertical, marker: '▌'
      )
      @tab_bar.on(TUI::Events::CHANGE) { |_label, index| select_tab(index) }

      @panes = TUI::Panes.new
      @panes.add(build_dashboard)
      @panes.add(build_processes)
      @panes.add(build_help)

      @root = TUI::Layout::Box.new(title: ' rtop ', footer: hints)
      sidebar = TUI::Layout::Stack.new(direction: :vertical)
      sidebar.add(@tab_bar, size: TUI::flex(1))
      sidebar.add(build_stats, size: TUI::fixed(7))

      columns = TUI::Layout::Stack.new(direction: :horizontal)
      columns.add(sidebar, size: TUI::fixed(20))
      columns.add(@panes, size: TUI::flex(1))
      @root.add(columns)
    end

    def build_dashboard
      @cpu_box = TUI::Layout::Box.new(title: 'CPU')
      @chart = TUI::BarChart.new(values: @sampler.history)
      @cpu_box.add(@chart)

      @mem_box = TUI::Layout::Box.new(title: 'Memory')
      @mem_bar = TUI::ProgressBar.new(label: 'MEM', show_value: nil,
                                      right: -> { memory_text },
                                      percent: false, width: 16)
      @swap_bar = TUI::ProgressBar.new(label: 'SWP', percent: false,
                                       right: -> { swap_text }, width: 16)
      @mem_note = TUI::Label.new('', style: :muted)
      memory = TUI::Layout::Stack.new(direction: :vertical)
      memory.add(@mem_bar, size: TUI::fixed(1))
      memory.add(@swap_bar, size: TUI::fixed(1))
      memory.add(@mem_note, size: TUI::fixed(1))
      @mem_box.add(memory)

      @sys_box = TUI::Layout::Box.new(title: 'System', title_right: @sampler.hostname)
      system = TUI::Layout::Stack.new(direction: :vertical)
      @system_values = {}
      %w[uptime load procs mem].each do |key|
        row = TUI::Layout::Stack.new(direction: :horizontal)
        row.add(TUI::Label.new(key, style: :label), size: TUI::fixed(8))
        value = TUI::Label.new('', style: :value)
        @system_values[key] = value
        row.add(value, size: TUI::flex(1))
        system.add(row, size: TUI::fixed(1))
      end
      @sys_box.add(system)

      @top_box = TUI::Layout::Box.new(title: 'Top processes')
      @top_table = build_table
      @top_box.add(@top_table)

      middle = TUI::Layout::Stack.new(direction: :horizontal)
      middle.add(@mem_box, size: TUI::flex(1))
      middle.add(@sys_box, size: TUI::flex(1))

      dashboard = TUI::Layout::Stack.new(direction: :vertical)
      dashboard.add(@cpu_box, size: TUI::percent(0.5))
      dashboard.add(middle, size: TUI::fixed(5))
      dashboard.add(@top_box, size: TUI::flex(1))
      dashboard
    end

    def build_processes
      @proc_box = TUI::Layout::Box.new(title: 'Processes')
      @proc_table = build_table
      @proc_box.add(@proc_table)
      @proc_box
    end

    def build_table
      table = TUI::Table.new(
        columns: [
          { key: :pid,  header: 'PID',     width: 8, align: :right },
          { key: :name, header: 'COMMAND', width: TUI.flex(1) },
          { key: :cpu,  header: '%CPU',    width: 7, align: :right,
            format: ->(value) { format('%.1f', value) } },
          { key: :rss,  header: 'MEM',     width: 8, align: :right,
            format: ->(value) { SysData.format_bytes(value) } }
        ],
        rows: [], sortable: true
      )
      @tables ||= []
      @tables << table
      table
    end

    def build_stats
      box = TUI::Layout::Box.new(title: 'System')
      stack = TUI::Layout::Stack.new(direction: :vertical)
      @stats = {}
      ['load', 'procs', 'uptime', 'mem'].each do |key|
        row = TUI::Layout::Stack.new(direction: :horizontal)
        row.add(TUI::Label.new(key, style: :label), size: TUI::fixed(7))
        value = TUI::Label.new('', style: :value, align: :right)
        @stats[key] = value
        row.add(value, size: TUI::flex(1))
        stack.add(row, size: TUI::fixed(1))
      end
      stack.add(TUI::Layout::Spacer.new, size: TUI::flex(1))
      @stats_meter = TUI::ProgressBar.new(width: 14, percent: false)
      stack.add(@stats_meter, size: TUI::fixed(1))
      box.add(stack)
      box
    end

    def build_help
      box = TUI::Layout::Box.new(title: 'Help')
      stack = TUI::Layout::Stack.new(direction: :vertical, gap: 0)

      stack.add(TUI::Label.new('rtop -- a system monitor built with the TUI toolkit.',
                               style: :title), size: TUI::fixed(1))
      stack.add(TUI::Label.new('Every widget here is generic: Box, Stack, TabBar,',
                               style: :muted), size: TUI::fixed(1))
      stack.add(TUI::Label.new('Panes, Table, ProgressBar, BarChart, Label.',
                               style: :muted), size: TUI::fixed(1))
      stack.add(TUI::Layout::Spacer.new, size: TUI::fixed(1))

      KEYS.each do |keys, description|
        row = TUI::Layout::Stack.new(direction: :horizontal)
        row.add(TUI::Label.new(keys, style: :accent), size: TUI::fixed(14))
        row.add(TUI::Label.new(description, style: :text, wrap: false), size: TUI::flex(1))
        stack.add(row, size: TUI::fixed(1))
      end
      box.add(stack)
      box
    end

    KEYS = [
      ['↑ ↓ / j k', 'move in the sidebar, or scroll the focused table'],
      ['tab', 'move the focus between widgets'],
      ['← → / h l', 'change the process sort order (cpu% / memory)'],
      ['1 2 3', 'jump straight to Dashboard / Processes / Help'],
      ['enter', 'activate the focused row or button'],
      ['pgup/pgdn home/end', 'jump around the list'],
      ['s', 'cycle the table sort (when the table has focus)'],
      ['r', 'resample processes now'],
      ['q / ctrl-c', 'quit']
    ].freeze

    # --- behaviour --------------------------------------------------------

    def select_tab(index)
      @tab_bar.select(index)
      @panes.set_active(index)
      @root.footer = hints
    end

    def sort(direction)
      keys = %i[cpu rss]
      current = @proc_table.sort_key
      index = current ? keys.index(current) : nil
      next_key = index ? keys[(index + direction) % keys.length] : keys.first
      @tables.each { |table| table.sort_by(next_key) }
      @top_box.title_right = sort_label
      @proc_box.title_right = sort_label
    end

    def sort_label
      @proc_table.sort_key == :rss ? 'by memory' : 'by cpu'
    end

    def hints
      case @tab_bar.active
      when 1 then ' ↑↓ move · enter select · ←→ sort · tab focus · r quit '
      when 2 then ' q quit · 1-3 views '
      else        ' ↑↓ view · 1-3 jump · ? help · q quit '
      end
    end

    def refresh!
      @sampler.tick(force: true)
      sync!
    end

    # --- data -> widgets --------------------------------------------------

    # Called on every tick: cheap updates (chart, bars, labels) and the
    # process tables only when the sampler actually rescanned /proc.
    def tick
      resampled = @sampler.tick
      sync!(processes: resampled)
    end

    def sync!(processes: true)
      @cpu_box.title_right = "#{@sampler.cpu_count} cores   #{pct(@sampler.cpu)}"
      update_tables if processes
      update_meters
    end

    def update_meters
      mem = @sampler.mem
      ratio = @sampler.mem_ratio
      @mem_bar.value = ratio
      @swap_bar.value = @sampler.swap_ratio
      @mem_box.title_right = "#{pct(ratio)} full"
      @mem_note.text = "available #{SysData.format_bytes(mem[:available])}  " \
                       "(#{pct(mem[:available].to_f / [mem[:total], 1].max)})"

      @system_values['uptime'].text = SysData.format_uptime(@sampler.boot)
      @system_values['load'].text = format('%.2f %.2f %.2f', *@sampler.loadavg)
      @system_values['procs'].text = "#{@sampler.process_count}  ·  cpu #{@sampler.cpu_count}x"
      @system_values['mem'].text = "#{pct(ratio)} used"

      @stats['load'].text = format('%.2f', @sampler.loadavg[0])
      @stats['procs'].text = @sampler.process_count.to_s
      @stats['uptime'].text = SysData.format_uptime(@sampler.boot)
      @stats['mem'].text = "#{(ratio * 100).round}%"
      @stats_meter.value = ratio
    end

    def update_tables
      rows = process_rows
      @tables.each do |table|
        keep = table.selected_row && table.selected_row[:pid]
        table.set_rows(rows)
        next unless keep

        index = table.rows.index { |row| row[:pid] == keep }
        table.select(index, notify: false) if index
      end
      # The dashboard list is the head of the (already sorted) process table.
      @top_table.set_rows(@proc_table.rows.first(TOP_ROWS)) if @top_table
      @proc_box.title_right = "#{rows.length} shown · #{@sampler.process_count} total  ·  #{sort_label}"
    end

    def process_rows
      @sampler.processes.map do |row|
        { pid: row[:pid], name: row[:name], cpu: row[:cpu], rss: row[:rss] }
      end
    end

    def memory_text
      mem = @sampler.mem
      "#{SysData.format_bytes(mem[:used])}/#{SysData.format_bytes(mem[:total])}"
    end

    def swap_text
      mem = @sampler.mem
      "#{SysData.format_bytes(mem[:swap_used])}/#{SysData.format_bytes(mem[:swap_total])}"
    end

    def pct(ratio)
      format('%.1f%%', ratio * 100)
    end
  end
end
