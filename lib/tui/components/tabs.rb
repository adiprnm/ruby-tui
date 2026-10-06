# frozen_string_literal: true
#
# Tabs -- a focusable tab bar (TabBar), a container that shows one child at
# a time (Panes), and the two wired together (Tabs).
#
#   tabs = TUI::Tabs.new(
#     orientation: :vertical,
#     items: [['Dashboard', dashboard], ['Processes', processes]]
#   )
#
# or compose them yourself when the chrome needs to go around one of them:

require_relative '../component'
require_relative '../layout/stack'
require_relative '../text'

module TUI
  # A row (or column) of tab titles. Moving the cursor emits :change.
  class TabBar < Component
    attr_reader :items, :active

    def initialize(items: [], active: 0, orientation: :horizontal, gap: 1,
                   style: :tab_inactive, active_style: :tab_active,
                   focus_style: :selection, marker: '▌', **opts)
      super(**opts)
      @items = items.dup
      @active = active
      @orientation = orientation
      @gap = gap
      @style = style
      @active_style = active_style
      @focus_style = focus_style
      @marker = marker
    end

    def horizontal?
      @orientation == :horizontal
    end

    def focusable?
      true
    end

    def set_items(items)
      @items = items.dup
      @active = @active.clamp(0, [@items.length - 1, 0].max)
      self
    end

    def select(index, notify: true)
      return self if @items.empty?

      changed = index.clamp(0, @items.length - 1) != @active
      @active = index.clamp(0, @items.length - 1)
      emit(Events::CHANGE, @items[@active], @active) if notify && changed
      self
    end

    def measure(max_w, max_h)
      if horizontal?
        width = @items.map { |i| Text.width(i) + 2 }.sum +
                (@gap * [@items.length - 1, 0].max)
        [[width, max_w].min, 1]
      else
        width = @items.map { |i| Text.width(i) + 3 }.max.to_i
        [[width, max_w].min, [@items.length, max_h].min]
      end
    end

    def render(canvas)
      offset = 0
      catch(:full) do
        @items.each_with_index do |item, index|
          active = index == @active
          rect = if horizontal?
                   Rect.new(@rect.x + offset, @rect.y, Text.width(item) + 2, 1)
                 else
                   Rect.new(@rect.x, @rect.y + index, @rect.w, 1)
                 end
          throw :full if rect.y > @rect.bottom || rect.x > @rect.right

          draw_item(canvas, rect, item, active)
          offset += rect.w + @gap if horizontal?
        end
      end
      self
    end

    def handle_key(key)
      # Only the axis this bar runs along; the other one stays available to
      # the application (a vertical tab bar must not eat left/right).
      case key.name
      when :up
        return false if horizontal?
        select(@active - 1)
      when :down
        return false if horizontal?
        select(@active + 1)
      when :left
        return false unless horizontal?
        select(@active - 1)
      when :right
        return false unless horizontal?
        select(@active + 1)
      when :home  then select(0)
      when :end   then select(@items.length - 1)
      when :enter then emit(Events::SELECT, @items[@active], @active)
      else return false
      end
      true
    end

    private

    def draw_item(canvas, rect, text, active)
      style = active ? @active_style : @style
      if active && focused?
        canvas.fill(rect.x, rect.y, rect.w, 1, ' ', @focus_style)
        style = @focus_style
      end

      if horizontal?
        canvas.text(rect, text, style)
      else
        # vertical bars get a marker in the leftmost cell, text next to it
        canvas.put(rect.x, rect.y, @marker, style) if active
        canvas.text(Rect.new(rect.x + 2, rect.y, [rect.w - 2, 0].max, 1), text, style)
      end
    end
  end

  # Shows exactly one child; the others are hidden (and not focusable).
  class Panes < Component
    attr_reader :active

    def initialize(active: 0, **opts)
      super(**opts)
      @active = active
    end

    def active_child
      @children[@active]
    end

    def set_active(index)
      return self if @children.empty?

      @active = index.clamp(0, @children.length - 1)
      sync_visibility
      self
    end

    def add(child, *)
      super
      sync_visibility
    end

    def measure(max_w, max_h)
      active_child ? active_child.measure(max_w, max_h) : [max_w, max_h]
    end

    def layout(rect)
      @rect = rect
      active_child.layout(rect) if active_child
      self
    end

    def render(canvas)
      render_children(canvas)
    end

    private

    def sync_visibility
      @children.each_with_index { |child, i| child.visible = (i == @active) }
    end
  end

  # TabBar + Panes, layed out side by side or stacked.
  class Tabs < Layout::Stack
    attr_reader :tab_bar, :panes

    def initialize(items: [], orientation: :horizontal, active: 0,
                   bar_size: nil, gap: 1, **opts)
      super(direction: orientation == :vertical ? :horizontal : :vertical,
            gap: 0, **opts)
      @tab_bar = TabBar.new(active: active, orientation: orientation, gap: gap)
      @panes = Panes.new(active: active)

      size = bar_size || (orientation == :vertical ? TUI.fixed(20) : TUI.fixed(1))
      add(@tab_bar, size: orientation == :vertical ? size : TUI.auto)
      add(@panes, size: TUI.flex(1))

      @tab_bar.on(Events::CHANGE) { |_item, index| @panes.set_active(index) }
      items.each { |label, pane| add_tab(label, pane) }
    end

    def add_tab(label, pane)
      @tab_bar.set_items(@tab_bar.items + [label])
      @panes.add(pane)
      self
    end

    def active
      @tab_bar.active
    end

    private
  end
end
