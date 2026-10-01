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
      # Kept for re-skins; the default theme does not use them (see below).
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
      subtitle:      { fg: PALETTE[:dim], bold: true },

      # The accent is deliberately hueless: it inherits whatever foreground
      # the terminal is using and only goes bold, so the chrome never fights
      # the colour scheme you are running. Put a colour back with
      #   TUI::Theme.style(:accent, fg: TUI::Theme::PALETTE[:accent], bold: true)
      accent:        { bold: true },
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
      cursor:        { reverse: true },

      tab_active:    { bold: true },
      tab_inactive:  { fg: PALETTE[:dim] },
      header:        { fg: PALETTE[:muted] },

      # Text fields carry no colour of their own: the value uses the
      # terminal's default foreground, the placeholder only goes faint and
      # the cursor only reverses. Nothing inside a text field can fight
      # whatever colours the terminal (or its theme) is running.
      field:         {},
      placeholder:   { dim: true }
    }.freeze

    # A completely hueless variant: no colour codes at all, only attributes
    # (bold / dim / reverse). Use it when the terminal's own theme should
    # decide every colour:
    #
    #   TUI::Theme.install(:plain)
    #
    # Status colours stay, because there the colour is information.
    PLAIN = {
      text: {}, value: {}, field: {},
      title: { bold: true }, subtitle: { bold: true }, accent: { bold: true },
      tab_active: { bold: true }, border_focus: { bold: true },
      thumb: { bold: true },
      muted: { dim: true }, dim: { dim: true }, hint: { dim: true },
      label: { dim: true }, header: { dim: true }, tab_inactive: { dim: true },
      placeholder: { dim: true }, border: { dim: true }, track: { dim: true },
      grid: { dim: true }, selection_dim: { reverse: true },
      selection: { reverse: true }, cursor: { reverse: true },
      success: DARK[:success], warning: DARK[:warning],
      danger: DARK[:danger], error: DARK[:error]
    }.freeze

    class << self
      THEMES = { dark: DARK, plain: PLAIN }.freeze

      # Install a theme. :dark is the default, :plain uses no colours at all.
      def install(name = :dark)
        name = name.to_sym if name.respond_to?(:to_sym)
        styles = THEMES[name]
        raise ArgumentError, "unknown theme #{name.inspect} (have: #{THEMES.keys.join(', ')})" unless styles

        styles.each { |style_name, opts| Style.define(style_name, opts) }
        self
      end

      def themes
        THEMES.keys
      end

      # Override a single style, e.g. Theme.style(:accent, fg: 170).
      def style(name, **opts)
        Style.define(name, opts)
      end
    end
  end
end

TUI::Theme.install(:dark)
