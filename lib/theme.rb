# frozen_string_literal: true
#
# Style -- a tiny styling layer.
#
# A "style" is either a registered Symbol (:accent, :border, ...) or a raw
# SGR string (as produced by Style.fg / Style.bg), which lets widgets paint
# per-cell gradients without registering a style per colour.

module Style
  RESET = "\e[0m"

  # 256-colour palette we actually use. Kept explicit so the theme is easy
  # to re-skin.
  PALETTE = {
    bg:        234,
    border:    238,
    border_hi: 244,
    track:     236,
    text:      252,
    dim:       245,
    muted:     240,
    title:     231,
    accent:    51,
    accent2:   141,
    good:      84,
    warn:      220,
    bad:       203,
    sel_bg:    237,
    sel_fg:    231
  }.freeze

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

    # Colour from the shared ramp; t is 0.0..1.0.
    def ramp(t)
      i = (t.clamp(0.0, 1.0) * (RAMP.length - 1)).round
      fg(RAMP[i])
    end

    def define(name, opts)
      @defs ||= {}
      @cache ||= {}
      @defs[name] = opts
      @cache.delete(name)
    end

    # Turn a style value into an SGR escape string.
    def resolve(style)
      return RESET if style.nil?
      return style if style.is_a?(String)

      @cache ||= {}
      @cache[style] ||= build(style)
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

# --- the theme ------------------------------------------------------------

module Theme
  P = Style::PALETTE

  Style.define :text,      fg: P[:text]
  Style.define :dim,       fg: P[:dim]
  Style.define :muted,     fg: P[:muted]
  Style.define :hidden,    fg: P[:bg]

  Style.define :title,     fg: P[:title], bold: true
  Style.define :subtitle,  fg: P[:accent2]
  Style.define :accent,    fg: P[:accent], bold: true
  Style.define :good,      fg: P[:good]
  Style.define :warn,      fg: P[:warn]
  Style.define :bad,       fg: P[:bad]

  Style.define :border,    fg: P[:border]
  Style.define :border_hi, fg: P[:border_hi]
  Style.define :track,     fg: P[:track]
  Style.define :grid,      fg: P[:muted], dim: true

  Style.define :sel,       fg: P[:sel_fg], bg: P[:sel_bg], bold: true
  Style.define :sel_dim,   fg: P[:dim],    bg: P[:sel_bg]
  Style.define :focus,     fg: P[:accent], bold: true
end
