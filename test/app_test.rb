# frozen_string_literal: true
require_relative 'test_helper'
require 'pty'
require 'timeout'

puts 'App -- focus'

def focus_demo
  stack = TUI::Layout::Stack.new(direction: :vertical)
  labels = %w[one two three].map { |name| NamedLabel.new(name) }
  labels.each { |label| stack.add(label, size: TUI.fixed(1)) }
  [stack, labels]
end

test 'the first focusable component gets the focus' do
  stack, labels = focus_demo
  app = TUI::App.new(stack, out: CountingIO.new, size: [20, 5])
  assert app.focused.equal?(labels.first)
end

test 'tab cycles forward and shift-tab backwards' do
  stack, labels = focus_demo
  app = TUI::App.new(stack, out: CountingIO.new, size: [20, 5])

  app.send(:dispatch, TUI::Key.new(:tab))
  assert app.focused.equal?(labels[1])
  app.send(:dispatch, TUI::Key.new(:tab))
  assert app.focused.equal?(labels[2])
  app.send(:dispatch, TUI::Key.new(:tab))
  assert app.focused.equal?(labels[0]), 'tab wraps around'
  app.send(:dispatch, TUI::Key.new(:backtab))
  assert app.focused.equal?(labels[2])
end

test 'only the focused component draws the focus marker' do
  stack, = focus_demo
  app = TUI::App.new(stack, out: CountingIO.new, size: [20, 5])
  lines = app.render_frame.lines.map { |line| plain(line) }
  assert_equal 'one*', lines[0].strip
  assert_equal 'two', lines[1].strip
end

test 'focus and blur events fire' do
  stack, labels = focus_demo
  app = TUI::App.new(stack, out: CountingIO.new, size: [20, 5])
  events = []
  labels[0].on(TUI::Events::BLUR) { events << :blur }
  labels[1].on(TUI::Events::FOCUS) { events << :focus }
  app.focus(labels[1])
  assert_equal %i[blur focus], events
end

test 'a component that is hidden loses the focus on the next key' do
  one = NamedLabel.new('one')
  two = NamedLabel.new('two')
  panes = TUI::Panes.new
  panes.add(one)
  panes.add(two)
  tabs = TUI::Layout::Stack.new(direction: :vertical)
  bar = TUI::TabBar.new(items: %w[a b])
  bar.on(TUI::Events::CHANGE) { |_label, i| panes.set_active(i) }
  tabs.add(bar, size: TUI.fixed(1))
  tabs.add(panes, size: TUI.flex(1))

  app = TUI::App.new(tabs, out: CountingIO.new, size: [20, 5])
  app.focus(one)
  bar.select(1)
  app.send(:dispatch, TUI::Key.new(:down))
  refute app.focused.equal?(one), 'a hidden component must not keep the focus'
end

puts 'App -- keys and timers'

test 'global bindings fire for keys nothing else wants' do
  stack, = focus_demo
  app = TUI::App.new(stack, out: CountingIO.new, size: [20, 5])
  seen = []
  app.on_key('q') { seen << :quit }
  app.on_key(:escape) { seen << :escape }

  app.send(:dispatch, TUI::Key.printable('q'))
  app.send(:dispatch, TUI::Key.new(:escape))
  assert_equal %i[quit escape], seen
end

test 'a focused component can swallow a key' do
  stack, labels = focus_demo
  app = TUI::App.new(stack, out: CountingIO.new, size: [20, 5])
  handled = []
  app.on_key('x') { handled << :global }

  app.send(:dispatch, TUI::Key.printable('x'))
  assert_equal %i[global], handled

  labels.first.define_singleton_method(:handle_key) do |_key|
    true
  end
  app.send(:dispatch, TUI::Key.printable('x'))
  assert_equal %i[global], handled, 'the global handler did not run again'
end

test 'timers fire once immediately and then respect their interval' do
  stack, = focus_demo
  app = TUI::App.new(stack, out: CountingIO.new, size: [20, 5])
  ticks = 0
  app.every(0.01) { ticks += 1 }

  app.send(:run_timers)
  assert_equal 1, ticks, 'the first tick is immediate so the app has data'
  app.send(:run_timers)
  assert_equal 1, ticks, 'not due again in the same instant'
  sleep 0.02
  app.send(:run_timers)
  assert_equal 2, ticks
end

test 'quit stops the loop' do
  stack, = focus_demo
  app = TUI::App.new(stack, out: CountingIO.new, size: [20, 5])
  refute app.quit?
  app.quit
  assert app.quit?
end

test 'render_lines builds a frame without a terminal' do
  stack, = focus_demo
  app = TUI::App.new(stack, out: CountingIO.new, size: [10, 3])
  assert_equal 3, app.render_lines.length
  assert_equal 10, plain(app.render_lines.first).length
end

puts 'App -- layout at any size'

def kitchen_sink
  table = TUI::Table.new(
    columns: [{ key: :a, header: 'A', width: TUI.flex(1) },
              { key: :b, header: 'B', width: 6, align: :right }],
    rows: (1..40).map { |i| { a: "row #{i}", b: i } },
    sortable: true
  )
  form = TUI::Form.new
  form.text(:one, 'One')
  form.text(:two, 'Two')
  form.button('Go')
  list = TUI::List.new(items: (1..20).map { |i| "item #{i}" })

  tabs = TUI::Tabs.new(orientation: :vertical)
  tabs.add_tab('Table', table)
  tabs.add_tab('Form', form)
  tabs.add_tab('List', list)

  root = TUI::Layout::Box.new(title: ' kitchen ', footer: ' tab focus ')
  root.add(tabs)
  root
end

[[60, 16], [80, 24], [120, 34], [200, 50], [56, 14]].each do |cols, rows|
  test "every widget fits in a #{cols}x#{rows} frame" do
    lines = render_lines(kitchen_sink, cols, rows)
    assert_equal rows, lines.length
    lines.each_with_index do |line, i|
      assert_equal cols, line.length, "row #{i} is #{line.length} cells: #{line.inspect}"
      refute line.include?("\0"), "row #{i} leaked a placeholder cell"
    end
    assert_equal 1, lines.first.count('╭'), 'no panel escapes the root box'
    assert_equal 1, lines.last.count('╰')
  end
end

test 'a very small frame degrades without crashing' do
  lines = render_lines(kitchen_sink, 24, 6)
  assert_equal 6, lines.length
  lines.each { |line| assert_equal 24, line.length }
end
