# frozen_string_literal: true
#
# Form -- labelled fields, validation and a submit callback.
#
#   form = TUI::Form.new
#   form.text(:name,  'Name',  required: true)
#   form.text(:email, 'Email', validate: ->(v) { v.include?('@') || 'invalid address' })
#   form.toggle(:news, 'Newsletter')
#   form.button('Save')
#   form.on(:submit) { |values| ... }
#   form.on(:invalid) { |errors| ... }
#
# The editors (Input, Checkbox, ...) are ordinary children, so Tab moves
# between them; Enter in a text field submits, and invalid fields show the
# error under the label.

require_relative '../component'
require_relative '../text'
require_relative 'input'
require_relative 'choice'
require_relative 'button'

module TUI
  class Form < Component
    class Field
      attr_reader :name, :label, :editor
      attr_accessor :error, :label_rect, :error_rect

      def initialize(name, label, editor, required: false, validate: nil)
        @name = name
        @label = label
        @editor = editor
        @required = required
        @validate = validate
        @error = nil
      end

      def button?
        @label.nil? || @label.to_s.empty?
      end

      def value
        @editor.respond_to?(:value) ? @editor.value : nil
      end

      # nil when valid, otherwise the message to show.
      def validate!
        value = self.value
        if @required && (value.nil? || (value.respond_to?(:empty?) && value.empty?))
          return 'required'
        end
        return nil unless @validate

        result = @validate.call(value)
        return nil if result.nil? || result == true

        result == false ? 'invalid' : result.to_s
      end
    end

    attr_reader :fields

    def initialize(label_width: 14, gap: 0, error_rows: true, **opts)
      super(**opts)
      @fields = []
      @label_width = label_width
      @gap = gap
      @error_rows = error_rows
      @submit_on_enter = true
    end

    def add_field(name, label, editor, **opts)
      field = Field.new(name, label, editor, **opts)
      @fields << field
      add(editor)
      wire_submit(field)
      field
    end

    # Keyword arguments that configure the field rather than its editor.
    FIELD_OPTS = %i[required validate].freeze

    def text(name, label, **opts)
      field_opts, editor_opts = split_opts(opts)
      add_field(name, label, Input.new(**editor_opts), **field_opts)
    end

    def password(name, label, **opts)
      field_opts, editor_opts = split_opts(opts)
      add_field(name, label, Input.new(password: true, **editor_opts), **field_opts)
    end

    # The field label carries the text, so the box itself stays empty.
    def toggle(name, label, **opts)
      field_opts, editor_opts = split_opts(opts)
      add_field(name, label, Checkbox.new('', **editor_opts), **field_opts)
    end

    def radio(name, label, options: [], **opts)
      field_opts, editor_opts = split_opts(opts)
      add_field(name, label, RadioGroup.new(options: options, **editor_opts), **field_opts)
    end

    def area(name, label, **opts)
      field_opts, editor_opts = split_opts(opts)
      add_field(name, label, TextArea.new(**editor_opts), **field_opts)
    end

    def button(label, **opts)
      field_opts, editor_opts = split_opts(opts)
      add_field(nil, nil, Button.new(label, **editor_opts), **field_opts)
    end

    def values
      @fields.each_with_object({}) do |field, hash|
        hash[field.name] = field.value if field.name
      end
    end

    def errors
      @fields.each_with_object({}) do |field, hash|
        hash[field.name] = field.error if field.error && field.name
      end
    end

    def validate!
      @fields.each { |field| field.error = field.validate! }
      @fields.none?(&:error)
    end

    def submit
      if validate!
        emit(Events::SUBMIT, values)
      else
        emit(:invalid, errors)
        first = @fields.find(&:error)
        first.editor.focus! if first && first.editor.respond_to?(:focus!)
      end
      self
    end

    def focus_first_field
      field = @fields.first
      field.editor.focus! if field
      self
    end

    def measure(max_w, max_h)
      height = @fields.sum { |field| rows_for(field) } +
               (@gap * [@fields.length - 1, 0].max)
      width = @fields.reject(&:button?).map do |field|
        @label_width + 1 + [field.editor.measure(max_w, 1).first, 0].max
      end.max.to_i
      [[width, max_w].min, [height, max_h].min]
    end

    def layout(rect)
      @rect = rect
      y = rect.y

      @fields.each do |field|
        break if y > rect.bottom

        editor_rect = if field.button?
                        Rect.new(rect.x, y, rect.w, 1)
                      else
                        Rect.new(rect.x + @label_width + 1, y,
                                 [rect.w - @label_width - 1, 1].max, 1)
                      end
        field.editor.layout(editor_rect)
        field.label_rect = Rect.new(rect.x, y, @label_width, 1) unless field.button?
        field.error_rect = Rect.new(editor_rect.x, y + 1, editor_rect.w, 1) if field.error

        y += rows_for(field) + @gap
      end
      self
    end

    def render(canvas)
      @fields.each do |field|
        canvas.text(field.label_rect, field.label, :label, :right) if field.label_rect
        if field.error && field.error_rect
          canvas.text(field.error_rect, field.error, :error)
        end
      end
      render_children(canvas)
    end

    def clipped_children?
      true
    end

    private

    def split_opts(opts)
      field = opts.select { |key, _value| FIELD_OPTS.include?(key) }
      [field, opts.reject { |key, _value| FIELD_OPTS.include?(key) }]
    end

    def rows_for(field)
      return 1 if field.button?
      return 1 unless @error_rows

      field.error ? 2 : 1
    end

    def wire_submit(field)
      editor = field.editor
      if editor.is_a?(Button)
        editor.on(Events::PRESS) { submit }
      elsif @submit_on_enter && editor.respond_to?(:on)
        editor.on(Events::SUBMIT) { submit }
        editor.on(Events::CHANGE) { field.error = nil }
      end
    end
  end
end
