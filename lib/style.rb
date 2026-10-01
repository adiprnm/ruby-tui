# frozen_string_literal: true
#
# Style -- the styling mechanism.
#
# A "style" is either a registered Symbol (:accent, :border, ...) or a raw
# SGR string (as produced by Style.fg / Style.bg), which lets widgets paint
# per-cell gradients without registering a style per colour.
#
# Frames never store the escape strings themselves: Style.id turns any style
# value into a small Integer, and Style.sgr turns that back into the escape
# when a row is composed. Palette-independent on purpose -- see theme.rb for
# the colours this app actually uses.

module Style
  RESET = "\e[0m"

  # Colour ramp used for gauges and bar charts: teal -> green -> amber -> red.
  RAMP = [51, 50, 49, 48, 47, 46, 82, 118, 154, 190, 226, 220, 214, 208, 202, 196].freeze

  class << self
    # Raw SGR escapes -- usable directly as a style value.
    def fg(n)
      "\e[38;5;#{n}m"
    end

    def bg(n)
      "\e[48;5;#{n}m"
    end

    # Colour from the shared ramp; t is 0.0..1.0. The returned escape is
    # memoised so that repeated calls hand out the *same* String object
    # (Style.id can then hit its cache by identity).
    def ramp(t)
      i = (t.clamp(0.0, 1.0) * (RAMP.length - 1)).round
      @ramp ||= Array.new(RAMP.length) { |k| fg(RAMP[k]) }
      @ramp[i]
    end

    def define(name, opts)
      @defs ||= {}
      @cache ||= {}
      @defs[name] = opts
      @cache.delete(name)
      @ids = {}
      @last_style = nil
    end

    # Turn a style value into an SGR escape string.
    def resolve(style)
      return RESET if style.nil?
      return style if style.is_a?(String)

      @cache ||= {}
      @cache[style] ||= build(style)
    end

    # Frames store styles as small integers so per-cell writes and compares
    # stay cheap. 0 is "no style" (RESET).
    #
    # The last lookup is memoised by object identity: widgets that paint a
    # run of cells with the same style (bar charts, gauges) hit this every
    # time and skip the hash entirely.
    def id(style)
      return 0 if style.nil?
      return @last_id if style.equal?(@last_style)

      @ids ||= {}
      @sgr ||= [RESET]
      cached = @ids[style]
      unless cached
        @sgr << resolve(style)
        cached = @sgr.length - 1
        @ids[style] = cached
      end
      @last_style = style
      @last_id = cached
    end

    def sgr(id)
      @sgr ||= [RESET]
      @sgr[id] || RESET
    end

    private

    def build(name)
      @defs ||= {}
      opts = @defs[name]
      raise ArgumentError, "unknown style #{name.inspect}" unless opts

      codes = []
      codes << '1' if opts[:bold]
      codes << '2' if opts[:dim]
      codes << '3' if opts[:italic]
      codes << '4' if opts[:underline]
      codes << '7' if opts[:reverse]
      codes << "38;5;#{opts[:fg]}" if opts[:fg]
      codes << "48;5;#{opts[:bg]}" if opts[:bg]
      codes.empty? ? RESET : "\e[#{codes.join(';')}m"
    end
  end
end
