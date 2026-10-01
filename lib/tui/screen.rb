# frozen_string_literal: true
#
# Screen -- presents canvases on the terminal, one diff at a time.
#
# Rows nobody drew on are never composed, and rows whose text did not change
# are never written. What is left is a cursor move plus the changed rows,
# wrapped in DEC mode 2026 so the terminal shows the update atomically.

require_relative 'term'
require_relative 'canvas'

module TUI
  class Screen
    def initialize(out, size: nil)
      @out = out
      @fixed_size = size
      @prev = []
      @w, @h = resolve_size
      @canvas = nil
    end

    attr_reader :w, :h

    def to_size
      [@w, @h]
    end

    # Returns true when the terminal changed size (the caller should re-layout).
    def resize!
      w, h = resolve_size
      return false if w == @w && h == @h

      @w = w
      @h = h
      @prev = []
      @canvas = nil
      @out.print(Term::CLEAR)
      true
    end

    # A pooled canvas, wiped where the previous tick drew.
    def frame
      @canvas ||= Canvas.new(@w, @h)
      @canvas.begin_frame!
    end

    def present(canvas)
      buf = +Term::SYNC_ON

      i = 0
      while i < @h
        unless canvas.dirty?(i)
          i += 1
          next
        end

        line = canvas.row(i)
        if @prev[i] != line
          buf << Term.move(i, 0) << line << "\e[K"
          @prev[i] = line
        end
        i += 1
      end

      buf << Term::SYNC_OFF
      @out.print(buf)
      @out.flush
      canvas.presented!
      self
    end

    private

    def resolve_size
      @fixed_size || Term.size
    end
  end
end
