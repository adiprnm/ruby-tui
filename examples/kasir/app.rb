# frozen_string_literal: true
#
# A cashier till, built out of the TUI toolkit: a searchable product table,
# a cart table, a totals panel and a modal payment dialog that turns into a
# receipt. Nothing here draws a cell by hand -- it is all composition, and
# the arithmetic lives in catalog.rb.
#
#   tab        move the focus
#   enter      add the highlighted product to the cart
#   + / -      more / fewer of the highlighted cart line
#   d          drop the highlighted cart line
#   f2 / p     pay
#   esc        cancel (payment) / new order (receipt)
#   q          quit

require 'tui'

require_relative 'catalog'

module Kasir
  class App
    STORE = 'TOKO RUBY'
    METHODS = %w[Tunai QRIS Kartu].freeze

    HINTS = {
      cart:    ' enter tambah · tab fokus · +/- qty · d hapus · f2 bayar · q keluar ',
      pay:     ' enter bayar · tab pindah · esc batal ',
      receipt: ' enter transaksi baru · q keluar '
    }.freeze

    TITLE = ' kasir '

    attr_reader :root, :catalog, :cart

    def initialize(catalog: Catalog.new)
      @catalog = catalog
      @cart = Cart.new
      @status = 'Siap.'
      build_ui
      refresh
    end

    # The runtime, so the app can move the focus (a modal needs it).
    def attach(ui)
      @ui = ui
      self
    end

    # ---------------------------------------------------------------- state

    def overlay_shown?
      @overlay.shown?
    end

    def showing_receipt?
      overlay_shown? && @dialogs.active == 1
    end

    def add_to_cart(sku, qty = 1)
      product = @catalog.find(sku)
      return self unless product

      @cart.add(product, qty)
      @cart_table.set_rows(cart_rows)
      @cart_table.select(index_of(sku), notify: false) if index_of(sku)
      flash("#{product.name} ×#{qty} ditambahkan")
      refresh_totals
    end

    def change_qty(delta)
      return self unless @cart_table.focused?

      line = selected_cart_line
      return self unless line

      sku = line[:sku]
      @cart.change(sku, delta)
      if (index = index_of(sku))
        @cart_table.set_rows(cart_rows)
        @cart_table.select(index, notify: false)
      else
        @cart_table.set_rows(cart_rows)
      end
      flash(@cart.empty? ? 'Keranjang kosong' : "#{line[:name]} qty #{delta.positive? ? '+' : ''}#{delta}")
      refresh_totals
    end

    def remove_selected
      return self unless @cart_table.focused?

      line = selected_cart_line
      return self unless line

      @cart.remove(line[:sku])
      @cart_table.set_rows(cart_rows)
      flash("#{line[:name]} dihapus")
      refresh_totals
    end

    # ------------------------------------------------------------- payment

    def open_payment
      return flash('Keranjang masih kosong') if @cart.empty?

      @pay_total.text = "Total  #{Money.format(@cart.total)}"
      @pay_form.fields.each { |field| field.error = nil }
      @cash_field.editor.value = ''
      @dialogs.set_active(0)
      @overlay.show
      @root.footer = HINTS[:pay]
      refresh_change
      @ui.focus(@cash_field.editor) if @ui
      self
    end

    def cancel
      if showing_receipt?
        confirm
      elsif overlay_shown?
        @overlay.hide
        refresh
        flash('Pembayaran dibatalkan')
      elsif @ui
        @ui.focus(@search)
      end
      self
    end

    def settle(values)
      paid = Money.parse(values[:cash])
      @receipt = Receipt.new(cart: @cart, paid: paid, method: values[:method], store: STORE)
      @overlay.hide
      show_receipt
      self
    end

    # Page up/down walk through a long receipt.
    def scroll_receipt(delta)
      @receipt_view.scroll_by(delta) if showing_receipt?
      self
    end

    def confirm
      @overlay.hide
      @cart.clear
      @cart_table.set_rows([])
      @receipt = nil
      refresh
      flash('Transaksi baru')
      @ui.focus(@search) if @ui
      self
    end

    # Used by --snapshot so a frame can be rendered mid-transaction.
    def demo_cart!
      %w[MKN-01 SBK-03 MNM-02 LAI-01].each { |sku| @cart.add(@catalog.find(sku)) }
      @cart.change('SBK-03', 5)          # enough for the bulk discount
      @cart_table.set_rows(cart_rows)
      refresh_totals
      self
    end

    def demo_payment!(cash = '150000')
      demo_cart!
      open_payment
      @cash_field.editor.value = cash
      refresh_change
      self
    end

    def demo_receipt!
      demo_cart!
      settle(cash: '150000', method: 'Tunai')
      self
    end

    # ------------------------------------------------------------------- ui

    def build_ui
      @root = TUI::Layout::Box.new(title: TITLE, footer: HINTS[:cart])

      cashier = TUI::Layout::Stack.new(direction: :vertical)
      cashier.add(build_search, size: TUI.fixed(1))
      cashier.add(build_lists,  size: TUI.flex(1))
      cashier.add(build_totals, size: TUI.fixed(7))

      @dialogs = TUI::Panes.new
      @dialogs.add(build_payment)
      @dialogs.add(build_receipt)

      @overlay = TUI::Layout::Overlay.new(cashier, @dialogs)
      @overlay.hide
      @root.add(@overlay)
    end

    def build_search
      row = TUI::Layout::Stack.new(direction: :horizontal, gap: 1)
      row.add(TUI::Label.new('Cari', style: :label), size: TUI.fixed(4))

      @search = TUI::Input.new(placeholder: 'nama atau kode barang…', padding: 1)
      @search.on(TUI::Events::CHANGE) { refresh_products }
      row.add(@search, size: TUI::flex(1))

      @category = TUI::RadioGroup.new(options: @catalog.categories, orientation: :horizontal)
      @category.on(TUI::Events::CHANGE) { refresh_products }
      row.add(@category, size: TUI::auto)
      row
    end

    def build_lists
      columns = TUI::Layout::Stack.new(direction: :horizontal)

      @products_box = TUI::Layout::Box.new(title: 'Produk')
      @product_table = TUI::Table.new(
        columns: [
          { key: :sku,   header: 'KODE',  width: 7 },
          { key: :name,  header: 'BARANG', width: TUI.flex(1) },
          { key: :price, header: 'HARGA', width: 11, align: :right,
            format: ->(value) { Money.format(value) } },
          { key: :category, header: 'KATEGORI', width: 9, align: :right }
        ],
        sortable: true
      )
      @product_table.on(TUI::Events::SELECT) { |row| add_to_cart(row[:sku]) }
      @products_box.add(@product_table)

      @cart_box = TUI::Layout::Box.new(title: 'Keranjang')
      @cart_table = TUI::Table.new(
        columns: [
          { key: :name,  header: 'BARANG', width: TUI.flex(1) },
          { key: :qty,   header: 'QTY',    width: 4, align: :right },
          { key: :price, header: 'HARGA',  width: 11, align: :right,
            format: ->(value) { Money.format(value) } },
          { key: :total, header: 'JUMLAH', width: 11, align: :right,
            format: ->(value) { Money.format(value) } }
        ]
      )
      @cart_box.add(@cart_table)

      columns.add(@products_box, size: TUI.percent(0.56))
      columns.add(@cart_box, size: TUI.flex(1))
      columns
    end

    def build_totals
      box = TUI::Layout::Box.new(title: 'Pembayaran', title_right: STORE)
      row = TUI::Layout::Stack.new(direction: :horizontal, gap: 1)

      left = TUI::Layout::Stack.new(direction: :vertical)
      @total_values = {}
      [['Subtotal', :subtotal], ['Diskon', :discount], ['PPN 11%', :tax]].each do |label, key|
        line = TUI::Layout::Stack.new(direction: :horizontal)
        line.add(TUI::Label.new(label, style: :label), size: TUI.fixed(12))
        value = TUI::Label.new('', style: :value, align: :right)
        @total_values[key] = value
        line.add(value, size: TUI::flex(1))
        left.add(line, size: TUI.fixed(1))
      end

      right = TUI::Layout::Stack.new(direction: :vertical)
      @grand_total = TUI::Label.new('', style: :title, align: :right)
      @status_label = TUI::Label.new(@status, style: :muted)
      @pay_button = TUI::Button.new('Bayar (F2)')
      @pay_button.on(TUI::Events::PRESS) { open_payment }
      right.add(@grand_total, size: TUI.fixed(1))
      right.add(@status_label, size: TUI.fixed(1))
      right.add(TUI::Layout::Center.new(@pay_button), size: TUI.fixed(1))

      row.add(left, size: TUI::flex(1))
      row.add(right, size: TUI::fixed(26))
      box.add(row)
      box
    end

    def build_payment
      box = TUI::Layout::Box.new(title: 'Pembayaran')
      stack = TUI::Layout::Stack.new(direction: :vertical)

      @pay_total = TUI::Label.new('', style: :title, align: :center)
      @pay_form = TUI::Form.new(label_width: 10)

      @cash_field = @pay_form.text(:cash, 'Tunai', placeholder: 'mis. 100000',
                                   required: true, width: 18,
                                   validate: method(:validate_cash))
      @cash_field.editor.on(TUI::Events::CHANGE) { refresh_change }
      @pay_form.radio(:method, 'Metode', options: METHODS, orientation: :horizontal)
      @pay_form.button('Bayar')
      @pay_form.on(TUI::Events::SUBMIT) { |values| settle(values) }

      @pay_change = TUI::Label.new('', style: :accent, align: :center)
      @pay_hint = TUI::Label.new('enter bayar · esc batal', style: :muted, align: :center)

      stack.add(@pay_total, size: TUI::fixed(1))
      stack.add(TUI::Layout::Spacer.new, size: TUI::fixed(1))
      stack.add(@pay_form, size: TUI.auto)
      stack.add(@pay_change, size: TUI.fixed(1))
      stack.add(@pay_hint, size: TUI.fixed(1))
      box.add(stack)
      box
    end

    def build_receipt
      box = TUI::Layout::Box.new(title: 'Struk', footer: 'enter = baru')
      @receipt_stack = TUI::Layout::Stack.new(direction: :vertical)
      @receipt_view = TUI::Layout::Viewport.new(@receipt_stack)
      box.add(@receipt_view)
      box
    end

    # -------------------------------------------------------------- refresh

    def refresh
      refresh_products
      refresh_cart
      refresh_totals
      @root.footer = HINTS[overlay_shown? ? :pay : :cart]
      self
    end

    def refresh_products
      rows = @catalog.search(@search.value, @category.value).map do |product|
        { sku: product.sku, name: product.name, price: product.price,
          category: product.category }
      end
      @product_table.set_rows(rows)
      @products_box.title_right = "#{rows.length} barang"
      self
    end

    def refresh_cart
      @cart_table.set_rows(cart_rows)
      @cart_box.title_right = @cart.empty? ? 'kosong' : "#{@cart.quantity} item"
      self
    end

    def refresh_totals
      @total_values[:subtotal].text = Money.format(@cart.subtotal)
      @total_values[:discount].text = "-#{Money.format(@cart.discount)}"
      @total_values[:tax].text      = Money.format(@cart.tax)
      @grand_total.text = "TOTAL  #{Money.format(@cart.total)}"
      @cart_box.title_right = @cart.empty? ? 'kosong' : "#{@cart.quantity} item"
      self
    end

    def refresh_change
      paid = Money.parse(@cash_field.editor.value)
      @pay_change.text = if paid.zero?
                           "kembalian akan dihitung"
                         elsif paid < @cart.total
                           "kurang #{Money.format(@cart.total - paid)}"
                         else
                           "kembalian #{Money.format(paid - @cart.total)}"
                         end
      self
    end

    def show_receipt
      @receipt_stack.clear_children
      @receipt.lines.each do |line|
        @receipt_stack.add(TUI::Label.new(line, style: :text), size: TUI.fixed(1))
      end
      @dialogs.set_active(1)
      @overlay.show
      @root.footer = HINTS[:receipt]
      self
    end

    def flash(message)
      @status = message
      @status_label.text = message
      self
    end

    # -------------------------------------------------------------- helpers

    def validate_cash(value)
      paid = Money.parse(value)
      return 'wajib diisi' if paid.zero?
      return "kurang #{Money.format(@cart.total - paid)}" if paid < @cart.total

      true
    end

    def cart_rows
      @cart.lines.map do |line|
        { sku: line.product.sku, name: line.product.name, qty: line.qty,
          price: line.product.price, total: line.subtotal - line.discount }
      end
    end

    def index_of(sku)
      @cart_table.rows.index { |row| row[:sku] == sku }
    end

    def selected_cart_line
      @cart_table.selected_row
    end
  end
end
