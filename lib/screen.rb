# frozen_string_literal: true
#
# Screen -- presents Frames on a terminal.
#
# The whole point is doing as little as possible: a row that was not drawn
# on this tick is never composed, and a row whose composed text is identical
# to the previous frame is never written. What is left is a cursor move plus
# the changed rows, wrapped in DEC private mode 2026 (synchronized output) so
# the terminal shows the update atomically instead of tearing.

require_relative 'frame'

class Screen
  def initialize(out)
    @out = out
    @prev = []
    @w, @h = Term.size
    @frame = nil
  end

  attr_reader :w, :h

  # Returns true when the terminal was resized.
  def resize!
    w, h = Term.size
    return false if w == @w && h == @h

    @w = w
    @h = h
    @prev = []
    @frame = nil
    @out.print(Term::CLEAR)
    true
  end

  # A reused frame, wiped where the previous tick drew.
  def frame
    @frame ||= Frame.new(@w, @h)
    @frame.begin_frame!
  end

  # Paint only what changed. Rows nobody drew on this tick are left as they
  # are on screen, so both composition and I/O shrink to the delta.
  def present(frame)
    buf = +Term::SYNC_ON

    i = 0
    while i < @h
      unless frame.dirty?(i)
        i += 1
        next
      end

      line = frame.row(i)
      if @prev[i] != line
        buf << Term.move(i, 0) << line << "\e[K"
        @prev[i] = line
      end
      i += 1
    end

    buf << Term::SYNC_OFF
    @out.print(buf)
    @out.flush
    frame.presented!
    self
  end
end
