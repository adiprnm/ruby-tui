# frozen_string_literal: true
#
# Help -- the key reference, generated from one table so the documentation
# cannot drift away from App#handle.

module Components
  class Help
    KEYS = [
      ['↑ ↓ / j k',  'move in the sidebar, or scroll the list when it has focus'],
      ['tab',        'toggle focus between sidebar and content'],
      ['← → / h l',  'change process sort order (cpu% / memory)'],
      ['1 2 3',      'jump straight to Dashboard / Processes / Help'],
      ['enter',      'focus the content pane'],
      ['pgup/pgdn',  'move a page at a time'],
      ['home/end',   'jump to the top / bottom of the list'],
      ['r',          'refresh the process table now'],
      ['esc',        'back to the sidebar'],
      ['?',          'this help'],
      ['q / ctrl-c', 'quit']
    ].freeze

    INTRO = [
      [:title,    'A tiny system monitor written in pure Ruby.'],
      [:dim,      ''],
      [:muted,    'Everything here is io/console + ANSI escape codes: no curses,'],
      [:muted,    'no gems, no native extensions.'],
      [:dim,      ''],
      [:subtitle, 'KEYS']
    ].freeze

    SOURCE = 'Data source: /proc (stat, meminfo, loadavg, uptime).'

    def initialize(_state); end

    def draw(f, x, y, w, h)
      Widgets.panel(f, x, y, w, h, 'Help', right: 'rtop')
      return if h < 6

      cursor = y + 2
      cursor = draw_intro(f, x, cursor)

      last = y + h - 2                     # last row inside the border
      draw_keys(f, x, cursor, w, last)
      f.put(x + 3, last, SOURCE, :muted)
    end

    private

    def draw_intro(f, x, cursor)
      INTRO.each do |style, line|
        f.put(x + 3, cursor, line, style)
        cursor += 1
      end
      cursor + 1
    end

    def draw_keys(f, x, cursor, w, last)
      KEYS.each do |keys, description|
        break if cursor > last - 1         # keep the last row for the footnote
        f.put(x + 3, cursor, format('%-14s', keys), :accent)
        f.put(x + 18, cursor, Widgets.truncate(description, w - 20), :text)
        cursor += 1
      end
    end
  end
end
