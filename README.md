# rtop — a pure-Ruby TUI

A small, interactive system monitor that is also a worked example of how to
build an elegant TUI in **pure Ruby**: no `curses`, no `tty-*`, no native
extensions. Everything is `io/console` plus ANSI escape codes, and all the
numbers come from `/proc`.

```
╭  rtop  ──────────────────────────────────────────────────  Thu 01 Oct  13:03:01  ╮
│                   │╭ CPU ─────────────────────────────────── 12 cores   20.0%  ╮ │
│ VIEWS             ││                                                          │ │
│                   ││··························································│ │
│▌ ◈  Dashboard     ││                                                          │ │
│                   ││··························································│ │
│▌ ▤  Processes     ││                                                       ▂▃▅│ │
│                   ││··························································│ │
│▌ ?  Help          ││                                                       ███│ │
│                   │╰──────────────────────────────────────────────────────────╯ │
│                   │╭ Memory ─────────────── 66.8% full  ╮ ╭ System ─── laptopsiadi ╮ │
│ SYSTEM            ││ MEM [█████████░░░░░]   10.0G/15.0G │ │ uptime  15d 02:44      │ │
│ load         2.53 ││ SWP [██░░░░░░░░░░░░]    4.2G/30.0G │ │ load    2.53 2.39 2.16 │ │
│ procs         460 ││ available 5.0G  (33.2%)           │ │ procs   460  ·  cpu 12x│ │
│ uptime  15d 02:44 │╰───────────────────────────────────╯ ╰────────────────────────╯ │
│ mem           67% │╭ Top processes ────────────────────────────────── by cpu  ╮ │
│ [██████████░░░░░] ││ PID      COMMAND                          %CPU     MEM │ │
│                   ││ 2744183  postgres                          9.0    253M │ │
╰──────────────────────  ↑↓ view · 1-3 jump · ? help · q quit  ──────────────────────╯
```

## Requirements

Ruby 2.0+ on Linux (the data source is `/proc`). Developed and tested against
the stock Ruby 2.6.10 that ships with this machine; no gems are installed for
it and none are required.

## Usage

```sh
ruby rtop.rb                # interactive
ruby rtop.rb --help         # all the flags

ruby rtop.rb --snapshot                 # render one frame to stdout (no raw mode)
ruby rtop.rb --snapshot --view=procs    # dash | procs | help
ruby rtop.rb --snapshot --w=120 --h=36  # pretend terminal size
ruby rtop.rb --snapshot --frames=3      # a few frames, 0.4s apart
```

`--snapshot` needs no tty, so it works over pipes and in CI — handy for
golden-output tests and for eyeballing layout changes without a terminal.

### Keys

| key | action |
| --- | --- |
| `↑` `↓` / `j` `k` | move in the sidebar, or scroll the list when it has focus |
| `tab` | toggle focus between sidebar and content |
| `←` `→` / `h` `l` | change the process sort order (cpu% / memory) |
| `1` `2` `3` | jump to Dashboard / Processes / Help |
| `enter` | focus the content pane |
| `pgup` `pgdn` `home` `end` | move around the list |
| `r` | refresh the process table now |
| `esc` | back to the sidebar |
| `q` / `ctrl-c` | quit |

## Layout

```
lib/term.rb      terminal plumbing: ANSI sequences, size, lossless key reading
lib/theme.rb     the palette and the style registry (styles become small ints)
lib/screen.rb    Frame (off-screen cell grid) + Screen (diffed presentation)
lib/widgets.rb   box, border label, gauge, bar chart, sparkline, process table
lib/sysdata.rb   /proc parsing: cpu, memory, load, uptime, processes
lib/app.rb       state, key handling and the three views
rtop.rb          argument parsing + the raw-mode/alternate-screen session
```

## Design notes

**Cells, not strings.** A `Frame` is a grid of Unicode codepoints
(`Integer`) plus a style id (`Integer`). Writing text is one `Array#[]=` splice
for the characters and one `Array#fill` for the styles, and composing a row is
a single `Array#pack('U*')` per equal-style run — no per-character string
building. Wide characters claim two cells; the continuation cell holds a `NUL`
placeholder that is stripped when the row is packed, so CJK text stays aligned.

**Only the delta goes to the terminal.** `Screen#present` compares each row it
was asked to draw against the previous frame and emits a cursor move plus that
row (with `EL` to erase the tail) only when it actually differs. Rows nobody
drew on are skipped without being composed at all. A fully repainted 160x48
frame is ~17 KB; a steady-state tick is ~100 bytes.

**Synchronized output.** Frames are wrapped in `ESC[?2026h … ESC[?2026l`,
which tells supporting terminals to present the whole batch atomically.
Without it you get tearing; with it, updates are invisible until they are
complete.

**Font width.** `Term.codepoint_width` is a small wcwidth covering ASCII, box
drawing, blocks, CJK and emoji. Zero-width marks are ignored (the app never
draws them), so the one thing this TUI deliberately does not do is combine
marks.

**Lossless input.** `IO#getch` was a trap on Ruby 2.6: it re-toggles the
terminal mode on each call and silently swallowed roughly every other
keystroke (measured with a pty harness: 2 of 5 bytes arrived). `Term.read_key`
therefore uses `IO.select` + `read_nonblock(1)` and assembles UTF-8
continuation bytes itself. `test/render_test.rb` drives the real binary
through a pty and asserts that every key lands, as a regression test.

**Always restore the terminal.** Interactive mode prints `ESC[?1049h` (the
alternate screen) and hides the cursor, runs the app inside `$stdin.raw`, and
restores everything from an `ensure` block — including on a crash.

## Performance

Measured on this machine (Ruby 2.6.10, 160x48, dashboard with a full 512-sample
CPU history and 45 process rows):

| | |
| --- | --- |
| full frame build | ~3.6 ms (empty history) / ~8 ms (worst case) |
| steady-state tick | ~8.5 ms including sampling; **~107 bytes** written |
| process scan (460 procs) | once per second |

The render loop ticks at 10 Hz, so an idle rtop costs a few percent of one
core. The two things worth knowing if you adapt this code: keep per-cell
operations out of Ruby loops (splice and `pack` instead), and never repaint
what did not change.

## Tests

```sh
ruby test/run.rb
```

68 tests with a ~60-line homegrown harness (stdlib only): character
width, key-sequence parsing, frame drawing and clipping, wide-character
handling, the dirty-row bookkeeping, the differential writer (it asserts the
byte counts), `/proc` parsing, layout invariants for every view at several
terminal sizes, key handling, and the end-to-end pty session above.

`test/frame_equivalence_test.rb` encodes the contract that the fast frame
implementation (integer cells, packed rows, dirty rows) renders byte-for-byte
identically to a naive string-per-cell renderer. That comparison is what
caught a NUL-placeholder leaking out of rows containing wide characters.
