# frozen_string_literal: true
#
# Theme -- the semantic style names components ask for.
#
# Components never hardcode a colour; they use names like :border, :selection
# or :danger. Swap the whole look by installing a different theme, or tweak
# single styles:
#
#   TUI::Theme.style(:accent, fg: 170, bold: true)

require_relative 'style'

module TUI
  module Theme
    PALETTE = {
      bg:        234,
      border:    238,
      border_hi: 244,
      track:     236,
      thumb:     245,
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

    # name => style opts
    DARK = {
      text:          { fg: PALETTE[:text] },
      muted:         { fg: PALETTE[:muted] },
      dim:           { fg: PALETTE[:dim] },
      title:         { fg: PALETTE[:title], bold: true },
      subtitle:      { fg: PALETTE[:accent2] },
      accent:        { fg: PALETTE[:accent], bold: true },
      label:         { fg: PALETTE[:muted] },
      value:         { fg: PALETTE[:text] },
      success:       { fg: PALETTE[:good] },
      warning:       { fg: PALETTE[:warn] },
      danger:        { fg: PALETTE[:bad] },
      error:         { fg: PALETTE[:bad], bold: true },
      hint:          { fg: PALETTE[:muted] },

      border:        { fg: PALETTE[:border] },
      border_focus:  { fg: PALETTE[:border_hi] },
      track:         { fg: PALETTE[:track] },
      grid:          { fg: PALETTE[:muted], dim: true },
      thumb:         { fg: PALETTE[:thumb] },

      selection:     { fg: PALETTE[:sel_fg], bg: PALETTE[:sel_bg], bold: true },
      selection_dim: { fg: PALETTE[:dim], bg: PALETTE[:sel_bg] },
      # A cursor is a "here" marker, not a highlight: reverse video stays
      # neutral on any palette (and never fights the accent colour).
      cursor:        { reverse: true, bold: true },

      tab_active:    { fg: PALETTE[:accent], bold: true },
      tab_inactive:  { fg: PALETTE[:dim] },
      header:        { fg: PALETTE[:muted] },
      field:         { fg: PALETTE[:text] },
      placeholder:   { fg: PALETTE[:muted], dim: true }
    }.freeze

    class << self
      # Install a theme (only :dark ships with the library).
      def install(name = :dark)
        styles = case name
                 when :dark then DARK
                 else raise ArgumentError, "unknown theme #{name.inspect}"
                 end
        styles.each { |style_name, opts| Style.define(style_name, opts) }
        self
      end

      # Override a single style, e.g. Theme.style(:accent, fg: 170).
      def style(name, **opts)
        Style.define(name, opts)
      end
    end
  end
end

TUI::Theme.install(:dark)
