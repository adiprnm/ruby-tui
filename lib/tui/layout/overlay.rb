# frozen_string_literal: true
#
# Layout::Overlay -- a base component that fills the space, plus a modal
# component drawn on top of it in the centre.
#
#   overlay = TUI::Layout::Overlay.new(cashier_view, payment_dialog)
#   overlay.show(payment_dialog)
#   overlay.hide
#
# While something is shown, only the overlay's components can take the
# focus, which is what makes it modal: the App notices that the focused
# component is no longer reachable and re-homes the focus.

require_relative '../component'

module TUI
  module Layout
    class Overlay < Component
      attr_reader :base, :modal

      def initialize(base = nil, modal = nil, shown: false, backdrop: nil, **opts)
        super(**opts)
        @base = base
        @modal = modal
        @shown = shown
        @backdrop = backdrop   # style used to blank the area under the modal
        register(base) if base
        register(modal) if modal
      end

      def add(child)
        # First child is the base, everything else becomes the modal layer.
        @base ||= child
        @modal = child unless @base.equal?(child)
        register(child)
        child
      end

      def show(component = nil)
        @modal = component if component
        @shown = true
        sync_visibility
        emit(:show)
        self
      end

      def hide
        @shown = false
        sync_visibility
        emit(:hide)
        self
      end

      def shown?
        @shown && !@modal.nil?
      end

      def measure(max_w, max_h)
        @base ? @base.measure(max_w, max_h) : [max_w, max_h]
      end

      def layout(rect)
        @rect = rect
        @base.layout(rect) if @base
        place_modal(rect) if @modal
        self
      end

      def render(canvas)
        @base.render(canvas) if @base
        if shown?
          # paint over the base so the dialog is readable
          canvas.fill_rect(@modal.rect, ' ', @backdrop) unless @modal.rect.empty?
          @modal.render(canvas)
        end
        self
      end

      # Only the modal layer is reachable while it is up.
      def focusables(list = [])
        return list unless visible?

        if shown?
          @modal.focusables(list)
        elsif @base
          @base.focusables(list)
        end
        list
      end

      def clipped_children?
        true
      end

      private

      # An Overlay is built by hand, not by the usual add-walking.
      def register(child)
        child.attach(self)
        @children << child unless @children.include?(child)
        child
      end

      def place_modal(rect)
        mw, mh = @modal.measure([rect.w - 4, 0].max, [rect.h - 2, 0].max)
        w = [[mw, 20].max, rect.w - 2].min
        h = [mh, rect.h].min
        @modal.layout(Rect.new(rect.x + ((rect.w - w) / 2),
                               rect.y + ((rect.h - h) / 2), w, h))
      end

      # The modal layer is only rendered while it is shown, but the base
      # stays visible so it keeps its layout.
      def sync_visibility
        @modal.visible = @shown if @modal
      end
    end
  end
end
