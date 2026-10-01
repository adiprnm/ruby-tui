# frozen_string_literal: true
#
# TextBuffer -- the editing model behind Input and TextArea.
#
# Lines, a cursor position in characters, and the usual editing operations.
# It knows nothing about rendering; the widgets ask it for a cursor position
# and scroll it into view themselves.

require_relative '../text'

module TUI
  class TextBuffer
    attr_reader :lines, :row, :col

    def initialize(text = '', multiline: false)
      @multiline = multiline
      @lines = text.to_s.split("\n", -1)
      @lines = [''] if @lines.empty?
      @row = @lines.length - 1
      @col = @lines[@row].length
    end

    def multiline?
      @multiline
    end

    def value
      @lines.join("\n")
    end
    alias to_s value

    def empty?
      @lines.length == 1 && @lines.first.empty?
    end

    def current_line
      @lines[@row]
    end

    def insert(str, silent: false)
      str = str.to_s
      str = str.tr("\n", '') unless @multiline
      return self if str.empty?

      line = @lines[@row]
      @lines[@row] = line[0, @col].to_s + str + line[@col..-1].to_s
      @col += str.length
      changed unless silent
      self
    end

    def newline
      return self unless @multiline

      line = @lines[@row]
      before = line[0, @col].to_s
      after = line[@col..-1].to_s
      @lines[@row] = before
      @lines.insert(@row + 1, after)
      @row += 1
      @col = 0
      changed
      self
    end

    def backspace
      if @col.positive?
        line = current_line
        @lines[@row] = line[0, @col - 1].to_s + line[@col..-1].to_s
        @col -= 1
      elsif @multiline && @row.positive?
        line = @lines.delete_at(@row)
        @row -= 1
        @col = current_line.length
        @lines[@row] += line
      else
        return self
      end
      changed
      self
    end

    def delete
      line = current_line
      if @col < line.length
        @lines[@row] = line[0, @col].to_s + line[@col + 1..-1].to_s
      elsif @multiline && @row < @lines.length - 1
        @lines[@row] = line + @lines.delete_at(@row + 1)
      else
        return self
      end
      changed
      self
    end

    def clear
      @lines = ['']
      @row = 0
      @col = 0
      changed
      self
    end

    def left
      if @col.positive?
        @col -= 1
      elsif @multiline && @row.positive?
        @row -= 1
        @col = current_line.length
      end
      self
    end

    def right
      if @col < current_line.length
        @col += 1
      elsif @multiline && @row < @lines.length - 1
        @row += 1
        @col = 0
      end
      self
    end

    def up
      return self unless @multiline && @row.positive?

      @row -= 1
      @col = @col.clamp(0, current_line.length)
      self
    end

    def down
      return self unless @multiline && @row < @lines.length - 1

      @row += 1
      @col = @col.clamp(0, current_line.length)
      self
    end

    def home
      @col = 0
      self
    end

    def end_of_line
      @col = current_line.length
      self
    end

    def document_home
      @row = 0
      @col = 0
      self
    end

    def document_end
      @row = @lines.length - 1
      @col = current_line.length
      self
    end

    def set(text)
      fresh = TextBuffer.new(text, multiline: @multiline)
      @lines = fresh.lines
      @row = fresh.row
      @col = fresh.col
      changed
      self
    end

    # Cell offset of the cursor inside its line.
    def cursor_cell
      Text.width(current_line[0, @col].to_s)
    end

    # Cell width of the whole line.
    def line_cell_width(index = @row)
      Text.width(@lines[index])
    end

    private

    def changed
      @changed = true
    end
  end
end
