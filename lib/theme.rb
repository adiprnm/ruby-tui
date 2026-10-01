# frozen_string_literal: true
#
# Theme -- the colours and named styles this app uses. Style is the
# mechanism; this file is the policy. Re-skin rtop by editing this file.

require_relative 'style'

module Theme
  # 256-colour palette. Kept explicit so a re-skin is a one-file change.
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

  P = PALETTE

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
