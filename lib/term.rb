# frozen_string_literal: true
#
# Term -- low-level terminal control for pure-Ruby TUIs.
#
# Responsibilities:
#   * ANSI escape sequences (alt screen, cursor, synchronized output)
#   * terminal size
#   * non-blocking key reading with escape-sequence parsing
#
# No dependencies beyond io/console (stdlib).

require 'io/console'

module Term
  ESC  = "\e"
  CSI  = "\e["

  CLEAR       = "#{CSI}2J"
  HOME        = "#{CSI}H"
  HIDE_CURSOR = "#{CSI}?25l"
  SHOW_CURSOR = "#{CSI}?25h"
  ALT_ON      = "#{CSI}?1049h"
  ALT_OFF     = "#{CSI}?1049l"
  # Synchronized output: terminals that support it present the whole
  # batch of writes as a single frame -> no tearing, no flicker.
  SYNC_ON     = "#{CSI}?2026h"
  SYNC_OFF    = "#{CSI}?2026l"

  # --- character widths -------------------------------------------------
  # Minimal wcwidth: enough for box drawing, blocks and CJK/emoji text.
  ZERO_WIDTH = [
    0x0300..0x036F, 0x200B..0x200F, 0xFE00..0xFE0F, 0xFEFF..0xFEFF
  ].freeze

  WIDE = [
    0x1100..0x115F, 0x2E80..0x303E, 0x3041..0x33FF, 0x3400..0x4DBF,
    0x4E00..0x9FFF, 0xA000..0xA4CF, 0xAC00..0xD7A3, 0xF900..0xFAFF,
    0xFE30..0xFE6F, 0xFF00..0xFF60, 0xFFE0..0xFFE6,
    0x1F300..0x1F64F, 0x1F900..0x1F9FF, 0x20000..0x3FFFD
  ].freeze

  WIDTH_CACHE = {}

  class << self
    # Display width of a single character: 0, 1 or 2 cells.
    def width(ch)
      WIDTH_CACHE[ch] ||= begin
        cp = ch.ord
        if ZERO_WIDTH.any? { |r| r.cover?(cp) } then 0
        elsif WIDE.any? { |r| r.cover?(cp) }   then 2
        else 1
        end
      end
    end

    # Display width of a whole string.
    def text_width(str)
      str.to_s.each_char.inject(0) { |acc, ch| acc + width(ch) }
    end

    # Screen size as [columns, rows]. Falls back to $COLUMNS/$LINES, 80x24.
    def size
      rows, cols = begin
        $stdout.tty? ? $stdout.winsize : nil
      rescue SystemCallError, IOError
        nil
      end
      cols = (ENV['COLUMNS'] || 80).to_i if !cols || cols <= 0
      rows = (ENV['LINES'] || 24).to_i  if !rows || rows <= 0
      [cols, rows]
    end

    # --- input ----------------------------------------------------------

    SEQUENCES = {
      "#{CSI}A" => :up,    "#{CSI}B" => :down,
      "#{CSI}C" => :right, "#{CSI}D" => :left,
      "#{CSI}H" => :home,  "#{CSI}F" => :end,
      "#{CSI}Z" => :backtab,
      "#{CSI}5~" => :page_up, "#{CSI}6~" => :page_down,
      "#{CSI}1~" => :home,    "#{CSI}4~" => :end,
      "OA" => :up,   "OB" => :down, "OC" => :right, "OD" => :left,
      "OH" => :home, "OF" => :end
    }.freeze

    # Read one key. Returns nil when `timeout` seconds pass with no input.
    # Named keys come back as symbols (:up, :enter, :tab, :escape, ...),
    # printable keys as their one-character String.
    #
    # NOTE: deliberately not IO#getch -- on Ruby 2.6 getch re-toggles the
    # terminal mode on every call and silently drops bytes that arrive in
    # between (measured: ~50% of keystrokes lost). read_nonblock is
    # lossless and cheaper.
    def read_key(timeout = 0.0)
      return nil unless IO.select([$stdin], nil, nil, timeout)

      ch = read_char
      return nil if ch.nil?

      case ch
      when ESC             then read_escape
      when "\r", "\n"      then :enter
      when "\t"            then :tab
      when "\u007F", "\b"  then :backspace
      when "\u0003"        then :ctrl_c
      when "\u0004"        then :ctrl_d
      when "\u001A"        then :ctrl_z
      else ch
      end
    rescue Interrupt
      :ctrl_c
    end

    # One byte, plus any continuation bytes if it starts a UTF-8 sequence.
    def read_char
      first = $stdin.read_nonblock(1)
      return nil if first.nil?

      bytes = first.dup.force_encoding(Encoding::BINARY)
      lead = bytes.getbyte(0)
      if lead && lead >= 0xC0
        need = lead < 0xE0 ? 1 : (lead < 0xF0 ? 2 : 3)
        need.times do
          break unless IO.select([$stdin], nil, nil, 0.01)
          more = $stdin.read_nonblock(1)
          break if more.nil?
          bytes << more.force_encoding(Encoding::BINARY)
        end
      end

      utf8 = bytes.dup.force_encoding(Encoding::UTF_8)
      utf8.valid_encoding? ? utf8 : bytes
    rescue IO::WaitReadable, Errno::EAGAIN, Errno::EINTR, EOFError, IOError
      nil
    end

    def read_escape
      buf = +ESC
      deadline = 0.03
      while buf.bytesize < 8 && IO.select([$stdin], nil, nil, deadline)
        c = read_char
        break if c.nil? || c.empty?
        buf << c
        break if buf.bytesize > 2 && c =~ /[A-Za-z~]/
        deadline = 0.005
      end
      return :escape if buf.bytesize == 1
      SEQUENCES[buf] || :unknown
    end

    # --- output helpers -------------------------------------------------

    def move(row, col)
      "#{CSI}#{row + 1};#{col + 1}H"
    end

    def sgr(codes)
      "\e[#{codes}m"
    end

    def reset
      "\e[0m"
    end
  end
end
