# frozen_string_literal: true

module TUI
  # A single keypress.
  #
  #   key.name  # :up, :enter, :escape, :ctrl_c, ... or "q" for printables
  #   key.char  # the printable character, or nil
  #
  # Printable keys are their own name, so bindings read naturally:
  #
  #   app.on_key("q") { app.quit }
  #   app.on_key(:page_down) { ... }
  class Key
    SPECIAL = {
      up: "\e[A", down: "\e[B", right: "\e[C", left: "\e[D",
      home: "\e[H", end: "\e[F",
      insert: "\e[2~", delete: "\e[3~",
      page_up: "\e[5~", page_down: "\e[6~",
      backtab: "\e[Z",
      enter: "\r", tab: "\t", backspace: "\u007F", escape: "\e"
    }.freeze

    attr_reader :name

    def initialize(name, char = nil)
      @name = name
      @char = char
    end

    def self.printable(char)
      new(char, char)
    end

    def char
      @char
    end

    def printable?
      !@char.nil?
    end

    # A space press (printable, so it arrives as its own name).
    def space?
      @name == ' ' || @char == ' '
    end

    def ctrl?(letter)
      @name == :"ctrl_#{letter.to_s.downcase}"
    end

    def eql?(other)
      other.is_a?(Key) && other.name == @name
    end
    alias == eql?

    def hash
      @name.hash
    end

    def to_s
      printable? ? @name : @name.to_s
    end

    def inspect
      "#<TUI::Key #{to_s.inspect}>"
    end
  end

  # Events components can subscribe to with Component#on.
  module Events
    CHANGE  = :change
    SELECT  = :select
    SUBMIT  = :submit
    PRESS   = :press
    FOCUS   = :focus
    BLUR    = :blur
    CANCEL  = :cancel
    MOUNT   = :mount
    RESIZE  = :resize
  end
end
