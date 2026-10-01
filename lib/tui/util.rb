# frozen_string_literal: true

module TUI
  # Small helpers used across components.
  module Util
    class << self
      # Call a user-supplied proc with as many arguments as it accepts, so
      # formatters can be written as ->(v) { } or ->(v, row) { } and both
      # keep working.
      def call(callable, *args)
        return nil if callable.nil?

        arity = callable.arity
        return callable.call(*args) if arity.negative? || arity.zero?

        callable.call(*args[0, arity])
      end
    end
  end
end
