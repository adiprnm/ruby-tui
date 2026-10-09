# frozen_string_literal: true
require_relative 'test_helper'

def key(name, char = nil)
  TUI::Key.new(name, char)
end

def press(component, name, char = nil)
  component.handle_key(key(name, char))
end

puts 'Label'

test 'label measures to its text' do
  assert_equal [5, 1], TUI::Label.new('hello').measure(40, 10)
  assert_equal [8, 1], TUI::Label.new('a much longer line').measure(8, 10)
end

test 'label aligns and truncates inside its rect' do
  label = TUI::Label.new('abcdefghij', align: :right)
  lines = render_lines(label, 6, 1)
  assert_equal 'abcde…', lines.first
end

test 'wrapped labels report their line count' do
  label = TUI::Label.new('one two three', wrap: true)
  assert_equal [7, 2], label.measure(8, 10)
  assert_equal ['one two', 'three'], render_lines(label, 8, 2).map(&:strip)
end

puts 'Button'

test 'button renders with brackets and emits press' do
  button = TUI::Button.new('Save')
  pressed = 0
  button.on(TUI::Events::PRESS) { pressed += 1 }
  assert_equal 8, button.measure(20, 1).first
  assert_equal '[ Save ]', render_lines(button, 8, 1).first
  assert press(button, :enter)
  assert press(button, ' ')
  assert_equal 2, pressed
  refute press(button, :down)
end

puts 'TextBuffer'

test 'text buffer edits like a single line' do
  b = TUI::TextBuffer.new('hello')
  b.home
  b.insert('>> ')
  b.end_of_line
  b.insert('!')
  assert_equal '>> hello!', b.value
  b.backspace
  assert_equal '>> hello', b.value
end

test 'text buffer does not take newlines unless multiline' do
  b = TUI::TextBuffer.new('')
  b.insert("a\nb")
  assert_equal 'ab', b.value
end

test 'multiline buffer joins and splits lines' do
  b = TUI::TextBuffer.new("one\ntwo", multiline: true)
  b.document_end
  b.newline
  b.insert('three')
  assert_equal ['one', 'two', 'three'], b.lines
  b.document_home
  b.delete                     # forward delete
  assert_equal ['ne', 'two', 'three'], b.lines
  b.document_end
  b.backspace
  assert_equal ['ne', 'two', 'thre'], b.lines
end

test 'cursor moves between lines' do
  b = TUI::TextBuffer.new("ab\ncdef", multiline: true)
  b.document_home
  b.right
  b.right
  b.right          # wrap to the next line
  assert_equal [1, 0], [b.row, b.col]
  b.down
  assert_equal 1, b.row
  b.up
  assert_equal 0, b.row
end

puts 'Input'

test 'input edits text and reports changes' do
  field = TUI::Input.new
  seen = []
  field.on(TUI::Events::CHANGE) { |value| seen << value }
  press(field, 'h', 'h')
  press(field, 'i', 'i')
  assert_equal 'hi', field.value
  assert_equal %w[h hi], seen
  press(field, :backspace)
  assert_equal 'h', field.value
end

test 'input emits submit on enter and moves the cursor' do
  field = TUI::Input.new(value: 'abc')
  submitted = nil
  field.on(TUI::Events::SUBMIT) { |value| submitted = value }
  press(field, :enter)
  assert_equal 'abc', submitted
  press(field, :left)          # cursor between b and c
  press(field, :backspace)     # removes b
  assert_equal 'ac', field.value
  press(field, :home)
  press(field, :delete)        # removes a
  assert_equal 'c', field.value
end

test 'input shows a placeholder, focused or not' do
  field = TUI::Input.new(placeholder: 'name', padding: 0)
  stack = TUI::Layout::Stack.new(direction: :vertical)
  button = TUI::Button.new('focus me')
  stack.add(button, size: TUI.fixed(1))
  stack.add(field, size: TUI.fixed(1))

  lines = render_lines(stack, 20, 2)
  assert_includes lines[1], 'name', 'unfocused field shows the placeholder'

  app = TUI::App.new(stack, out: CountingIO.new, size: [20, 2])
  app.focus(field)
  canvas = app.render_frame
  assert_includes plain(canvas.row(1)), 'name',
                  'the placeholder stays readable under the caret'
  assert_includes canvas.row(1), TUI::Style.resolve(:cursor_placeholder),
                  'the caret over a hint is an underline'
  refute canvas.row(1).include?('48;5;'), 'nothing is painted over the placeholder'
  refute canvas.row(1).include?(TUI::Style.resolve(:cursor)),
         'no block cursor while the hint is showing'
end

test 'the block cursor appears once there is text' do
  field = TUI::Input.new(value: 'abc', padding: 0)
  app = TUI::App.new(field, out: CountingIO.new, size: [10, 1])
  app.focus(field)
  assert_includes app.render_frame.row(0), TUI::Style.resolve(:cursor)
end

test 'the cursor is neutral: reverse video, not a coloured block' do
  cursor = TUI::Style.resolve(:cursor)
  assert cursor.include?('7'), "reverse video expected in #{cursor.inspect}"
  refute cursor.include?('48;5;'), "no background colour in #{cursor.inspect}"
end

test 'input scrolls long values so the cursor stays visible' do
  field = TUI::Input.new(value: 'x' * 60, width: 20, padding: 0)
  app = TUI::App.new(field, out: CountingIO.new, size: [20, 1])
  app.focus(field)
  press(field, 'y', 'y')                      # an edit scrolls the cursor into view

  assert_equal 20, render_lines(field, 20, 1).first.length
  assert_includes TUI.render(field, cols: 20, rows: 1).row(0), TUI::Style.resolve(:cursor)
  assert field.instance_variable_get(:@scroll).positive?, 'the field scrolled'
end

test 'password input masks the value' do
  field = TUI::Input.new(value: 'secret', password: true, padding: 0)
  assert_includes render_lines(field, 20, 1).first, '******'
end

puts 'TextArea'

test 'text area edits multiple lines and scrolls' do
  area = TUI::TextArea.new(value: "one\ntwo", rows: 2, padding: 0)
  press(area, :enter)
  press(area, 'x', 'x')
  assert_equal "one\ntwo\nx", area.value

  lines = render_lines(area, 12, 2)
  assert lines[0].start_with?('two'), lines[0].inspect
  assert lines[1].start_with?('x'), lines[1].inspect
  assert_includes lines.join, '┃', 'a scrollbar appears next to the text'
  assert_equal 1, area.scroll
end

puts 'Checkbox and RadioGroup'

test 'checkbox toggles and emits change' do
  box = TUI::Checkbox.new('Agree', value: false)
  changes = []
  box.on(TUI::Events::CHANGE) { |v| changes << v }
  assert press(box, ' ')
  assert box.value
  assert_equal '[x] Agree', render_lines(box, 12, 1).first.rstrip
  press(box, ' ')
  refute box.value
  assert_equal [true, false], changes
end

test 'radio group selects with arrows' do
  group = TUI::RadioGroup.new(options: %w[low high], orientation: :horizontal)
  seen = []
  group.on(TUI::Events::CHANGE) { |v| seen << v }
  assert press(group, :right)
  assert_equal 'high', group.value
  refute press(group, :right) == true && group.value == 'low'
  assert_equal ['high'], seen
  assert_includes render_lines(group, 20, 1).first, '(•) high'
end

puts 'List'

test 'list navigates and emits change and select' do
  list = TUI::List.new(items: %w[a b c], padding: 0)
  changed = []
  selected = []
  list.on(TUI::Events::CHANGE) { |item, i| changed << [item, i] }
  list.on(TUI::Events::SELECT) { |item, i| selected << [item, i] }

  press(list, :down)
  assert_equal 'b', list.selected_item
  press(list, :end)
  assert_equal 'c', list.selected_item
  press(list, :down)
  assert_equal 'c', list.selected_item, 'the end of the list is a hard stop'
  press(list, :enter)
  assert_equal [['b', 1], ['c', 2]], changed
  assert_equal [['c', 2]], selected
end

test 'list navigates with j and k too' do
  list = TUI::List.new(items: %w[a b c], padding: 0)
  press(list, 'j', 'j')
  assert_equal 'b', list.selected_item, 'j moves down one row'
  press(list, 'k', 'k')
  assert_equal 'a', list.selected_item, 'k moves back up'
  press(list, 'k', 'k')
  assert_equal 'a', list.selected_item, 'the top of the list is a hard stop'
end

test 'list scrolls to keep the cursor visible' do
  list = TUI::List.new(items: (1..20).map(&:to_s), padding: 0)
  render_lines(list, 10, 4)
  press(list, :end)
  lines = render_lines(list, 10, 4)
  assert_equal %w[20], lines.last.strip.split
  assert_equal 16, list.scroll
end

test 'list uses the format proc' do
  list = TUI::List.new(items: [1, 2], format: ->(item) { "##{item}" }, padding: 0)
  assert_equal ['#1', '#2'], render_lines(list, 6, 2).map(&:strip)
end

puts 'Table'

def sample_table(**opts)
  TUI::Table.new(
    columns: [
      { key: :name, header: 'NAME', width: TUI.flex(1) },
      { key: :size, header: 'SIZE', width: 6, align: :right,
        format: ->(v) { "#{v}K" } }
    ],
    rows: [{ name: 'alpha', size: 1 }, { name: 'beta', size: 2 }],
    **opts
  )
end

test 'table draws a header and the rows' do
  table = sample_table
  lines = render_lines(table, 20, 4)
  assert_includes lines[0], 'NAME'
  assert_includes lines[0], 'SIZE'
  assert_includes lines[2], 'alpha'
  assert_includes lines[3], 'beta'
end

test 'table formats and aligns columns' do
  table = sample_table
  lines = render_lines(table, 20, 4)
  assert_equal 'alpha', lines[2].strip.split.first
  assert lines[2].rstrip.end_with?('1K'), "size is right-aligned: #{lines[2].inspect}"
end

test 'table keeps the cursor in range' do
  table = sample_table
  press(table, :down)
  assert_equal 1, table.selected
  press(table, :down)
  assert_equal 1, table.selected
  press(table, :home)
  assert_equal 0, table.selected
end

test 'table navigates with j and k too' do
  table = sample_table
  press(table, 'j', 'j')
  assert_equal 1, table.selected, 'j moves down one row'
  press(table, 'j', 'j')
  assert_equal 1, table.selected, 'the last row is a hard stop'
  press(table, 'k', 'k')
  assert_equal 0, table.selected, 'k moves back up'
end

test 'table emits select and change' do
  table = sample_table
  selected = nil
  table.on(TUI::Events::SELECT) { |row| selected = row }
  press(table, :enter)
  assert_equal({ name: 'alpha', size: 1 }, selected)
end

test 'table sorts by a column and toggles direction' do
  table = sample_table
  table.sort_by(:size, :asc)
  assert_equal [1, 2], table.rows.map { |r| r[:size] }
  table.sort_by(:size)
  assert_equal [2, 1], table.rows.map { |r| r[:size] }
  assert_equal :desc, table.sort_direction
end

test 'table re-applies the sort when new rows arrive' do
  table = sample_table
  table.sort_by(:size, :desc)
  table.set_rows([{ name: 'x', size: 1 }, { name: 'y', size: 9 }])
  assert_equal [9, 1], table.rows.map { |r| r[:size] }
end

test 'table sizes auto columns from the widest cell' do
  table = TUI::Table.new(columns: [{ key: :a, header: 'A' }, { key: :b, header: 'B' }],
                         rows: [{ a: 'longest', b: 1 }])
  lines = render_lines(table, 40, 3)
  assert_includes lines[0], 'A'
  assert_includes lines[2], 'longest'
end

test 'table scrolls a long list' do
  rows = (1..30).map { |i| { name: "row #{i}" } }
  table = TUI::Table.new(columns: [{ key: :name, header: 'NAME', width: TUI.flex(1) }],
                         rows: rows)
  render_lines(table, 20, 6)
  press(table, :end)
  lines = render_lines(table, 20, 6)
  assert_includes lines.last, 'row 30'
end

puts 'Tabs'

test 'tab bar changes tabs with the arrow matching its axis' do
  bar = TUI::TabBar.new(items: %w[one two three])
  seen = []
  bar.on(TUI::Events::CHANGE) { |_item, i| seen << i }
  assert press(bar, :right)
  assert_equal 1, bar.active
  refute press(bar, :down), 'a horizontal bar ignores up/down'
  assert_equal [1], seen
end

test 'vertical tab bar uses up/down only' do
  bar = TUI::TabBar.new(items: %w[a b], orientation: :vertical)
  assert press(bar, :down)
  assert_equal 1, bar.active
  refute press(bar, :right)
end

test 'panes show and focus only the active child' do
  one = NamedLabel.new('one')
  two = NamedLabel.new('two')
  panes = TUI::Panes.new
  panes.add(one)
  panes.add(two)
  panes.set_active(1)

  assert_equal [two], panes.focusables
  lines = render_lines(panes, 10, 1)
  assert_includes lines.first, 'two'
  refute lines.first.include?('one')
end

test 'tabs wire a bar to panes' do
  tabs = TUI::Tabs.new
  tabs.add_tab('first', NamedLabel.new('first pane'))
  tabs.add_tab('second', NamedLabel.new('second pane'))
  assert_equal 0, tabs.active
  assert_includes render_text(tabs, 30, 4), 'first pane'

  tabs.tab_bar.select(1)
  assert_equal 1, tabs.panes.active
  assert_includes render_text(tabs, 30, 4), 'second pane'
end

puts 'Form'

def sample_form
  form = TUI::Form.new(label_width: 8)
  form.text(:name, 'Name', required: true)
  form.text(:email, 'Email', validate: ->(v) { v.include?('@') || 'needs an @' })
  form.toggle(:news, 'News')
  form.button('Save')
  form
end

test 'form lays out labels and editors' do
  form = sample_form
  text = render_text(form, 40, 8)
  assert_includes text, 'Name'
  assert_includes text, 'Email'
  assert_includes text, '[ Save ]'
end

test 'form reports required and custom validation errors' do
  form = sample_form
  invalid = nil
  form.on(:invalid) { |errors| invalid = errors }
  form.submit
  assert_equal({ name: 'required', email: 'needs an @' }, invalid)

  form.fields[0].editor.value = 'Ruby'
  form.fields[1].editor.value = 'ruby@example.com'
  assert form.validate!
  assert_equal({}, form.errors)
end

test 'form submits its values' do
  form = sample_form
  values = nil
  form.on(TUI::Events::SUBMIT) { |v| values = v }
  form.fields[0].editor.value = 'Ruby'
  form.fields[1].editor.value = 'ruby@example.com'
  form.submit
  assert_equal({ name: 'Ruby', email: 'ruby@example.com', news: false }, values)
end

test 'typing in a field submits the form on enter' do
  form = sample_form
  submitted = false
  form.on(TUI::Events::SUBMIT) { submitted = true }
  form.fields[0].editor.value = 'x'
  form.fields[1].editor.value = 'x@y'
  press(form.fields[0].editor, :enter)
  assert submitted
end

test 'form shows the error under the field' do
  form = sample_form
  form.submit
  assert_includes render_text(form, 40, 8), 'required'
end

test 'radio fields are focusable editors' do
  form = TUI::Form.new
  form.radio(:plan, 'Plan', options: %w[a b])
  assert_equal 1, form.focusables.length
  press(form.fields.first.editor, :down)
  assert_equal 'b', form.values[:plan]
end

puts 'Progress bars and charts'

test 'progress bar clamps its value and shows a percentage' do
  bar = TUI::ProgressBar.new(value: 0.5, width: 10, track: :track)
  text = render_lines(bar, 20, 1).first
  assert_includes text, '50.0%'
  bar.value = 5.0
  assert_equal 1.0, bar.ratio
  bar.value = -1
  assert_equal 0.0, bar.ratio
end

test 'progress bar accepts arbitrary right-hand text' do
  bar = TUI::ProgressBar.new(label: 'MEM', width: 6, percent: false, right: '1/2')
  text = render_lines(bar, 20, 1).first
  assert_includes text, 'MEM'
  assert_includes text, '1/2'
end

test 'sparkline draws the last values' do
  spark = TUI::Sparkline.new(values: [0.0, 0.5, 1.0])
  assert_equal ' ▄█', render_lines(spark, 3, 1).first
end

test 'bar chart fills from the bottom' do
  chart = TUI::BarChart.new(values: [1.0], grid: false)
  lines = render_lines(chart, 1, 3)
  assert_equal %w[█ █ █], lines
end

test 'bar chart scales by max when given one' do
  chart = TUI::BarChart.new(values: [50], max: 100, grid: false)
  assert_equal [' ', ' ', '█', '█'], render_lines(chart, 1, 4)
end

test 'bar chart push keeps the series bounded' do
  chart = TUI::BarChart.new(values: [])
  10.times { |i| chart.push(i / 10.0) }
  assert_equal 10, chart.values.length
end
