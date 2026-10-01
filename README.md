# TUI — a pure-Ruby terminal UI toolkit

A small toolkit for building interactive terminal applications in plain
Ruby: **no curses, no gems, no native extensions**. It ships a component
model, a layout engine, focus handling and a widget library, plus two
example applications built entirely out of the generic components: `rtop`
(a system monitor) and `kasir` (a cashier till).

`rtop`:

```
╭  rtop  ───────────────────  ↑↓ view · 1-3 jump · ? help · q quit  ───────────────────────────╮
│▌ ◈  Dashboard      ╭ CPU ────────────────────────────────────────────────── 12 cores   9.8% ╮│
│  ▤  Processes      │                                                                        ││
│  ?  Help           │                                                                        ││
│                    │········································································││
│                    │                                                                        ││
│                    │                                                                        ││
│                    │········································································││
│                    │                                                                        ││
│                    │········································································││
│                    │                                                                     ▅  ││
│                    │                                                                     █▂▁││
│                    │                                                                     ███││
│                    ╰────────────────────────────────────────────────────────────────────────╯│
│                    ╭ Memory ─────────────── 65.0% full ╮╭ System ────────────── laptopsiadi ╮│
│                    │MEM ████████████░░░░░░░ 9.8G/15.0G ││uptime  15d 04:20                  ││
│                    │SWP ██░░░░░░░░░░░░░░░░░ 3.7G/30.0G ││load    1.71 1.29 0.91             ││
│                    │available 5.3G  (35.0%)            ││procs   459  ·  cpu 12x            ││
│                    ╰───────────────────────────────────╯╰───────────────────────────────────╯│
│                    ╭ Top processes ───────────────────────────────────────────────── by cpu ╮│
│╭ System ──────────╮│     PID COMMAND                                        %CPU ▼      MEM ││
││load          1.71││────────────────────────────────────────────────────────────────────────││
││procs          459││  696824 nvim                                              3.6    75.0M│││
││uptime   15d 04:20││ 1520531 claude                                            3.6     242M│││
││mem            65%││ 1547047 claude                                            3.6     250M┃││
││████████████░░░░░░││ 3448784 chromium                                          3.6    26.1M┃││
│╰──────────────────╯╰────────────────────────────────────────────────────────────────────────╯│
╰──────────────────────────────────────────────────────────────────────────────────────────────╯
```

`kasir`, mid-payment — the dialog is a modal `Layout::Overlay`:

```
╭  kasir  ──────────────  enter bayar · tab pindah · esc batal  ───────────────────────╮
│Cari  nama atau kode…  (•) Semua  ( ) Makanan  ( ) Minuman  ( ) Sembako  ( ) Lainnya  │
│╭ Produk ─────────────────────────── 20 barang ╮╭ Keranjang ───────────────── 9 item ╮│
││KODE    BARANG                HARGA  KATEGORI ││BARANG   QTY       HARGA      JUMLAH││
││──────────────────────────────────────────────││────────────────────────────────────││
││MKN-01  Indomie Goreng     Rp 3.500   Makanan┃││Indomi…    1    Rp 3.500    Rp 3.500││
││MKN-02  Mie Sedaap Soto    Rp 3.200   Makanan┃││Gula P…    6   Rp 17.000   Rp 96.900││
││MKN-03  Biskuit Roma K…    Rp 8.500   Makanan┃││Teh Pu…    1    Rp 5.000    Rp 5.000││
││MKN-04  Chitato Sapi P…    Rp 9.000   Makanan┃││Sabun …    1    Rp 4.500    Rp 4.500││
││MKN-05  Roti Tawar ╭ Pembayaran ───────────────────────────────╮                    ││
││MNM-01  Aqua 600ml │             Total  Rp 121.989             │                    ││
││MNM-02  Teh Pucuk H│                                           │                    ││
││MNM-03  Kopi Kapal │     Tunai  150000                         │                    ││
││MNM-04  Susu UHT Co│    Metode (•) Tunai  ( ) QRIS  ( ) Kartu  │                    ││
││MNM-05  Pocari Swea│                 [ Bayar ]                 │                    ││
││SBK-01  Beras Panda│            kembalian Rp 28.011            │                    ││
││SBK-02  Minyak Gore╰───────────────────────────────────────────╯                    ││
│╰──────────────────────────────────────────────╯╰────────────────────────────────────╯│
│╭ Pembayaran ───────────────────────────────────────────────────────────── TOKO RUBY ╮│
││Subtotal                                       Rp 115.000          TOTAL  Rp 121.989││
││Diskon                                          -Rp 5.100 Siap.                     ││
││PPN 11%                                         Rp 12.089       [ Bayar (F2) ]      ││
││                                                                                    ││
││                                                                                    ││
│╰────────────────────────────────────────────────────────────────────────────────────╯│
╰──────────────────────────────────────────────────────────────────────────────────────╯
```

```
╭  rtop  ───────────────────  ↑↓ view · 1-3 jump · ? help · q quit  ───────────────────────────╮
│▌ ◈  Dashboard      ╭ CPU ────────────────────────────────────────────────── 12 cores   9.8% ╮│
│  ▤  Processes      │                                                                        ││
│  ?  Help           │                                                                        ││
│                    │········································································││
│                    │                                                                        ││
│                    │                                                                        ││
│                    │········································································││
│                    │                                                                        ││
│                    │········································································││
│                    │                                                                     ▅  ││
│                    │                                                                     █▂▁││
│                    │                                                                     ███││
│                    ╰────────────────────────────────────────────────────────────────────────╯│
│                    ╭ Memory ─────────────── 65.0% full ╮╭ System ────────────── laptopsiadi ╮│
│                    │MEM ████████████░░░░░░░ 9.8G/15.0G ││uptime  15d 04:20                  ││
│                    │SWP ██░░░░░░░░░░░░░░░░░ 3.7G/30.0G ││load    1.71 1.29 0.91             ││
│                    │available 5.3G  (35.0%)            ││procs   459  ·  cpu 12x            ││
│                    ╰───────────────────────────────────╯╰───────────────────────────────────╯│
│                    ╭ Top processes ───────────────────────────────────────────────── by cpu ╮│
│╭ System ──────────╮│     PID COMMAND                                        %CPU ▼      MEM ││
││load          1.71││────────────────────────────────────────────────────────────────────────││
││procs          459││  696824 nvim                                              3.6    75.0M│││
││uptime   15d 04:20││ 1520531 claude                                            3.6     242M│││
││mem            65%││ 1547047 claude                                            3.6     250M┃││
││████████████░░░░░░││ 3448784 chromium                                          3.6    26.1M┃││
│╰──────────────────╯╰────────────────────────────────────────────────────────────────────────╯│
╰──────────────────────────────────────────────────────────────────────────────────────────────╯
```

## Quick start

```ruby
$LOAD_PATH.unshift 'lib'
require 'tui'

label = TUI::Label.new('hello, world', align: :center)
app = TUI::App.new(label)
app.on_key('q') { app.quit }
app.run   # alternate screen + raw mode, restored on exit
```

```sh
ruby examples/hello.rb          # a form with validation
ruby bin/rtop                   # the example application
ruby test/run.rb                # the test suite, no gems required
```

Requires Ruby 2.0+ (developed against the stock Ruby 2.6.10 on Linux).

## The component model

Everything on screen is a `TUI::Component`: a node in a tree that is handed
a rectangle, paints itself into it and may consume keys while focused.

```ruby
class Clock < TUI::Component
  def measure(max_w, max_h)                 # what it would like to be
    [12, 1]
  end

  def render(canvas)                        # paint inside #rect
    canvas.text(rect, Time.now.strftime('%H:%M:%S'), :accent, :center)
  end

  def handle_key(key)                       # only while focused
    return false unless key.name == :enter
    emit(:press)
    true                                    # consumed: do not bubble
  end
end
```

| method | purpose |
| --- | --- |
| `measure(max_w, max_h)` | preferred size, used for `TUI.auto` sizing |
| `layout(rect)` | receive a rect and place the children (containers) |
| `render(canvas)` | draw; the canvas is clipped to the rect by the parent |
| `handle_key(key)` | return true to consume the key |
| `focusable?` | whether `tab` can reach it |
| `on(event) { }` / `emit(event)` | `:change`, `:select`, `:submit`, `:press`, `:focus`, `:blur`, ... |
| `focused?` / `contains_focus?` | focus state, for highlighting |

Components never talk to the terminal and never mutate each other's state,
which is why any subtree can be rendered off-screen at any size:

```ruby
canvas = TUI.render(root, cols: 100, rows: 30)
canvas.lines     # one ANSI string per row
```

## Layout

Layout is composition: containers are components too.

```ruby
root = TUI::Layout::Box.new(title: ' my app ', footer: ' q quit ')
columns = TUI::Layout::Stack.new(direction: :horizontal)
sidebar = TUI::Layout::Stack.new(direction: :vertical)
inner = TUI::Layout::Stack.new(direction: :vertical)

sidebar.add(menu, size: TUI.flex(1))
sidebar.add(stats, size: TUI.fixed(7))
inner.add(header, size: TUI.auto)
inner.add(table,  size: TUI.flex(1))

columns.add(sidebar, size: TUI.fixed(20))
columns.add(inner,   size: TUI.flex(1))
root.add(columns)
```

| container | what it does |
| --- | --- |
| `Layout::Stack` | row or column; children get a size spec |
| `Layout::Box` | border + title + footer + padding around one child; the border lights up while the child has focus |
| `Layout::Center` | child at its preferred size, centred |
| `Layout::Viewport` | scrollable window over larger content (`scroll_by`) |
| `Layout::Overlay` | a base component plus a centred modal; while it is up only the modal can take focus |
| `Layout::Spacer` / `Divider` | empty space / a rule |

Size specs are `TUI.fixed(n)`, `TUI.flex(weight)`, `TUI.percent(0.42)`,
`TUI.auto` (measured) or a bare number (fixed). Distribution always respects
the space actually available, so a tree never has to care how big the
terminal is:

```ruby
stack.add(chart, size: TUI.percent(0.5))   # half the height...
stack.add(panel, size: TUI.fixed(6))       # ...then a fixed panel...
stack.add(table, size: TUI.flex(1))        # ...and the table takes the rest
```

## Components

| component | notes |
| --- | --- |
| `Label` | text, alignment, optional word wrap |
| `Button` | focusable, emits `:press` on enter/space |
| `Input` | single-line editor: cursor, horizontal scroll, placeholder, password mode |
| `TextArea` | multi-line editor with its own viewport |
| `Checkbox`, `RadioGroup` | toggle and single-choice inputs |
| `List` | scrollable list with a cursor, `:change` / `:select` |
| `Table` | columns, alignment, per-column formatters, sorting, scrolling, cursor |
| `TabBar`, `Panes`, `Tabs` | tab strip, one-of-N container, and the two wired together |
| `Form` | labelled fields, validation, `:submit` / `:invalid` |
| `ProgressBar` | 0..1 meter painted from the shared colour ramp |
| `Sparkline`, `BarChart` | one-row and block charts for a series of values |

```ruby
table = TUI::Table.new(
  columns: [
    { key: :pid,  header: 'PID',  width: 8, align: :right },
    { key: :name, header: 'NAME', width: TUI.flex(1) },
    { key: :cpu,  header: 'CPU',  width: 7, align: :right,
      format: ->(value) { format('%.1f', value) } }   # 1-arg formatters work
  ],
  rows: rows, sortable: true
)
table.on(:select) { |row| open(row) }
table.sort_by(:cpu, :desc)      # the sort survives set_rows
```

```ruby
form = TUI::Form.new(label_width: 12)
form.text(:name, 'Name', required: true)
form.text(:mail, 'Email', validate: ->(v) { v.include?('@') || 'need an @' })
form.toggle(:news, 'Newsletter')
form.button('Save')
form.on(:submit)  { |values| ... }
form.on(:invalid) { |errors| ... }
```

## The runtime

`TUI::App` owns the loop, the focus ring, global bindings and timers:

```ruby
app = TUI::App.new(root)
app.on_key('q') { app.quit }        # printable keys
app.on_key(:ctrl_c) { app.quit }
app.on_key(:left) { sort(-1) }      # unhandled keys bubble up to here
app.every(0.2) { refresh }          # the first run is immediate
app.on_resize { |cols, rows| ... }
app.run
```

* `tab` / `shift-tab` move the focus through the visible focusable
  components — unless the focused component consumes them (a form, say).
* A component that becomes invisible (a switched pane) cannot keep the
  focus: the next key re-homes it.
* `App#render_frame` / `#render_lines` render without touching the terminal,
  which is what the tests and the `--snapshot` modes use.

Behind it sit `TUI::Term` (raw mode, alternate screen, key reading) and
`TUI::Screen` (the diffed renderer).

## Theming

Components ask for semantic style names, never for colours:

```ruby
TUI::Theme.style(:accent, fg: 170, bold: true)
TUI::Style.define(:mine, fg: 250, bg: 236)
canvas.put(x, y, '!', :mine)
```

The default theme is **hueless on purpose**: the chrome uses the terminal's
own grey ramp, the cursor is reverse video and `:accent` is just bold (so it
inherits whatever foreground you are running), which means the UI never
fights the terminal's colour scheme. Only the semantic statuses
(`:success`, `:warning`, `:danger`, `:error`) and the value ramp used by
gauges and charts carry a colour, because there the colour is information.
A test walks every defined style and fails if anything else has a non-grey
colour.

`Style.ramp(t)` maps 0.0..1.0 onto the shared teal→green→amber→red ramp,
which is what gauges and charts use. Named styles are turned into small
integers once and stored per cell, so re-skinning costs nothing at render
time.

## How rendering works

* A `Canvas` is a grid of codepoints (`Integer`) plus style ids (`Integer`).
  Writing text is one `Array#[]=` splice for the characters and one
  `Array#fill` for the styles; a row is composed with a single
  `Array#pack('U*')` per equal-style run.
* `Screen#present` compares every row it was asked to draw with the previous
  frame and writes only what changed, wrapped in DEC mode 2026
  (synchronized output) so a terminal shows updates atomically.
* Wide characters (CJK, emoji) claim two cells, so columns stay aligned.
* Clipping is part of the canvas: a component cannot paint outside its rect,
  which is what makes viewports and nested layouts safe.
* `Term.read_key` uses `IO.select` + `read_nonblock`, deliberately not
  `IO#getch`: on Ruby 2.6 `getch` re-toggles the terminal mode on every call
  and drops roughly every other keystroke (there is a pty regression test).

## Examples

### `kasir` — a cashier till

`examples/kasir/` is a second application, and the quickest way to see the
toolkit used for something that is not a dashboard: a searchable product
`Table`, a cart `Table`, a totals panel, and a modal payment dialog that
turns into a receipt.

```sh
ruby bin/kasir                                    # interactive
ruby bin/kasir --snapshot --state=pay --w=96 --h=28
```

Its arithmetic lives in `examples/kasir/catalog.rb` with no TUI in sight
(products, cart, bulk discount, PPN, receipts), so it is tested directly —
the layout and the money are separate concerns.

Keys: `tab` moves the focus, `enter` adds the highlighted product to the
cart, `+`/`-` change the quantity of the highlighted cart line, `d` drops
it, `f2` (or `p`) opens the payment dialog, `esc` cancels (payment) or
starts a new order (receipt), and `q` (or `ctrl-c`, which works even while
typing) quits.

### `rtop` — a system monitor

`examples/rtop/` reads `/proc` directly and draws nothing by hand: the
dashboard is a `BarChart` and two `ProgressBar`s, the process view is a
sortable `Table`, the sidebar is a vertical `TabBar` next to a `Panes`
container, and everything is wrapped in a `Box`.

```sh
ruby bin/rtop                                    # interactive
ruby bin/rtop --snapshot --w=120 --h=34          # one frame to stdout
ruby bin/rtop --snapshot --view=procs            # dash | procs | help
```

`--snapshot` needs no tty, so it works over pipes and in CI.

## Performance

Measured on this machine (Ruby 2.6.10), rendering the rtop dashboard at
160x48 with a table of ~450 rows:

| | |
| --- | --- |
| build a full frame | ~5 ms |
| steady-state tick | ~170 **bytes** written per frame |
| process scan (450 procs) | once per second |

Two rules keep it fast: keep per-cell work out of Ruby loops (splice and
`pack` instead), and never repaint what did not change.

## Repository layout

```
lib/tui.rb                  requires everything, installs the theme
lib/tui/
  geometry.rb               Rect + size specs
  event.rb                  Key + event names
  term.rb                   ANSI, size, raw mode, key reading
  text.rb                   cell-aware string helpers (width, truncate, wrap)
  style.rb                  style mechanism (SGR strings -> ids)
  theme.rb                  the semantic style names components use
  canvas.rb                 the cell grid, drawing primitives, clipping
  screen.rb                 the diffed presenter
  component.rb              the component base class
  app.rb                    the runtime (loop, focus, keys, timers)
  scroll.rb                 scrolling arithmetic shared by List/Table/TextArea
  layout/                   Stack, Box, Center, Viewport, Spacer, Divider
  components/               Label, Button, Input, TextArea, Checkbox,
                            RadioGroup, List, Table, TabBar, Panes, Tabs,
                            Form, ProgressBar, Sparkline, BarChart
examples/hello.rb           a form in 40 lines
examples/kasir/             the cashier till (catalog, app, main)
examples/rtop/              the system monitor (sysdata, sampler, app)
bin/kasir  bin/rtop         run the examples without a load-path dance
test/                       the test suite
```

## Tests

```sh
ruby test/run.rb
```

155 tests run on a ~90-line homegrown harness (stdlib only): geometry and
size distribution, canvas drawing/clipping/wide characters/row composition,
the differential writer (asserting byte counts), every container (including
modals), every component, focus traversal and key dispatch, key parsing,
layout invariants at several terminal sizes, the cashier's cart arithmetic
and receipt formatting, and two end-to-end pty sessions (`bin/rtop` and a
complete sale typed through `bin/kasir`) that assert the terminal is
restored.
