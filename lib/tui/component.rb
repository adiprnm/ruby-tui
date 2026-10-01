# frozen_string_literal: true
#
# Component -- the base class every widget and container shares.
#
# A component is a node in a tree. It is handed a rect by its parent
# (#layout), it paints itself into that rect (#render), and it may consume
# keys while focused (#handle_key). Nothing else is required of it.
#
#   class Clock < TUI::Component
#     def measure(w, h) = [12, 1]        # preferred size
#     def render(canvas)                 # paint inside #rect
#       canvas.text(rect, Time.now.strftime('%H:%M'), :accent)
#     end
#   end

require_relative 'geometry'
require_relative 'event'

module TUI
  class Component
    attr_reader :parent, :children, :rect
    attr_accessor :visible

    def initialize(visible: true)
      @parent = nil
      @children = []
      @visible = visible
      @rect = Rect.new(0, 0, 0, 0)
      @handlers = {}
      @app = nil
    end

    # --- tree -------------------------------------------------------------

    def add(child, *_args)
      child.attach(self)
      @children << child
      child
    end

    def remove(child)
      child.detach
      @children.delete(child)
    end

    def attach(parent)
      @parent = parent
      mount(parent.app) if parent.app
      self
    end

    def detach
      unmount
      @parent = nil
      self
    end

    def app
      @app || (@parent && @parent.app)
    end

    def mount(app)
      @app = app
      @children.each { |child| child.mount(app) }
      emit(Events::MOUNT, app)
      self
    end

    def unmount
      @children.each(&:unmount)
      @app = nil
      self
    end

    def root
      @parent ? @parent.root : self
    end

    def visible?
      return false unless @visible
      @parent ? @parent.visible? : true
    end

    # --- geometry ---------------------------------------------------------

    # Preferred size inside the given constraints. Containers use it for
    # TUI.auto children; leaves should override it.
    def measure(max_w, max_h)
      [max_w, max_h]
    end

    # Place this component: assign the rect, then place the children.
    def layout(rect)
      @rect = rect
      self
    end

    def contains?(px, py)
      @rect.contains?(px, py)
    end

    # --- rendering --------------------------------------------------------

    def render(canvas)
      render_children(canvas)
    end

    def render_children(canvas)
      clip = clipped_children?
      @children.each do |child|
        next unless child.visible?
        if clip
          canvas.clip(child.rect) { child.render(canvas) }
        else
          child.render(canvas)
        end
      end
      self
    end

    # Containers that must not let a child bleed out set this to true.
    def clipped_children?
      false
    end

    # --- focus ------------------------------------------------------------

    def focusable?
      false
    end

    def focus!
      app.focus(self) if app
      self
    end

    def blur!
      app.focus(nil) if app && focused?
      self
    end

    def focused?
      !app.nil? && app.focused.equal?(self)
    end

    # True when this component or one of its descendants has the focus;
    # used by containers to light up a border around the focused child.
    def contains_focus?
      return true if focused?

      @children.any? { |child| child.visible? && child.contains_focus? }
    end

    # Depth-first list of focusable components, in tab order.
    def focusables(list = [])
      list << self if visible? && focusable?
      @children.each { |child| child.focusables(list) }
      list
    end

    # --- events -----------------------------------------------------------

    def on(event, &block)
      (@handlers[event] ||= []) << block
      self
    end

    def off(event)
      @handlers.delete(event)
      self
    end

    def emit(event, *args)
      handlers = @handlers[event]
      handlers.each { |handler| handler.call(*args) } if handlers
      self
    end

    def handle_key(_key)
      false
    end
  end
end
