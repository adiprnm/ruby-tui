# frozen_string_literal: true

require_relative 'lib/tui/version'

Gem::Specification.new do |spec|
  spec.name        = 'ruby-tui'
  spec.version     = TUI::VERSION
  spec.authors     = ['Adi Purnama']
  spec.email       = ['adiprnm2014@gmail.com']

  spec.summary     = 'A small, pure-Ruby terminal UI toolkit.'
  spec.description = 'Build interactive terminal applications in plain Ruby: ' \
                     'a component model, a layout engine, focus handling and a ' \
                     'widget library. No curses, no gems, no native extensions.'
  spec.homepage    = 'https://github.com/adiprnm/ruby-tui'
  spec.license     = 'MIT'

  spec.required_ruby_version = '>= 2.0'

  spec.metadata = {
    'homepage_uri'    => spec.homepage,
    'source_code_uri' => spec.homepage,
    'rubygems_mfa_required' => 'true'
  }

  # The gem itself lives under lib/tui/ and is loaded by lib/ruby-tui.rb,
  # the entry point `require 'ruby-tui'` picks up. The module stays TUI::.
  spec.files         = Dir['lib/**/*.rb'] + %w[README.md LICENSE.txt]
  spec.require_paths = ['lib']

  # The examples (bin/kasir, bin/rtop) are development tools, not gem
  # executables, so they are shipped as plain files and not installed.
end
