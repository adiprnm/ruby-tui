# frozen_string_literal: true
require_relative 'test_helper'
require_relative '../examples/kasir/app'

# A fresh till plus a runtime, rendered off-screen at a fixed size.
def till(cols = 96, rows = 28)
  app = Kasir::App.new
  ui = TUI::App.new(app.root, out: CountingIO.new, size: [cols, rows])
  app.attach(ui)
  [app, ui]
end

def screen_of(ui)
  ui.render_frame.lines.map { |line| plain(line) }
end

puts 'Kasir -- money'

test 'amounts are grouped like rupiah' do
  assert_equal 'Rp 0', Kasir::Money.format(0)
  assert_equal 'Rp 3.500', Kasir::Money.format(3_500)
  assert_equal 'Rp 1.234.567', Kasir::Money.format(1_234_567)
  assert_equal '-Rp 5.100', Kasir::Money.format(-5_100)
end

test 'user typed amounts are parsed leniently' do
  assert_equal 50_000, Kasir::Money.parse('Rp 50.000')
  assert_equal 50_000, Kasir::Money.parse('50 000')
  assert_equal 0, Kasir::Money.parse('')
  assert_equal 0, Kasir::Money.parse('abc')
end

puts 'Kasir -- catalog'

test 'search matches names and codes, optionally per category' do
  catalog = Kasir::Catalog.new
  assert_equal ['Aqua 600ml'], catalog.search('aqua').map(&:name)
  assert_equal ['Indomie Goreng'], catalog.search('mkn-01').map(&:name)
  assert catalog.search('').length > 10

  sembako = catalog.search('', 'Sembako')
  assert_equal %w[Sembako], sembako.map(&:category).uniq
  assert_equal catalog.products.length, catalog.search('', 'Semua').length
end

puts 'Kasir -- cart'

test 'adding the same product merges the line' do
  cart = Kasir::Cart.new
  mie = Kasir::Catalog.new.find('MKN-01')
  cart.add(mie).add(mie, 2)

  assert_equal 1, cart.lines.length
  assert_equal 3, cart.quantity
  assert_equal 10_500, cart.subtotal
end

test 'quantities can change and lines disappear at zero' do
  cart = Kasir::Cart.new
  cart.add(Kasir::Catalog.new.find('MNM-01'), 2)

  cart.change('MNM-01', 3)
  assert_equal 5, cart.quantity
  cart.change('MNM-01', -5)
  assert cart.empty?
end

test 'bulk lines earn a discount, small ones do not' do
  catalog = Kasir::Catalog.new
  cart = Kasir::Cart.new

  cart.add(catalog.find('MKN-01'), Kasir::BULK_QTY - 1)
  assert_equal 0, cart.discount

  cart.add(catalog.find('MKN-01'))          # now at the bulk threshold
  assert_equal (cart.subtotal * Kasir::BULK_RATE).round, cart.discount
end

test 'totals add tax on the discounted amount' do
  catalog = Kasir::Catalog.new
  cart = Kasir::Cart.new
  cart.add(catalog.find('SBK-01')).add(catalog.find('MNM-02'))

  expected_tax = ((cart.subtotal - cart.discount) * Kasir::TAX_RATE).round
  assert_equal expected_tax, cart.tax
  assert_equal cart.subtotal - cart.discount + expected_tax, cart.total
  assert_equal 10_000, cart.change_for(cart.total + 10_000)
end

puts 'Kasir -- receipt'

test 'the receipt lists the items, the totals and the change' do
  catalog = Kasir::Catalog.new
  cart = Kasir::Cart.new
  cart.add(catalog.find('MKN-01'), 6).add(catalog.find('MNM-01'))
  receipt = Kasir::Receipt.new(cart: cart, paid: 100_000, time: Time.at(0))

  text = receipt.lines.join("\n")
  assert_includes text, 'TOKO RUBY'
  assert_includes text, 'Indomie Goreng'
  assert_includes text, '6 x 3.500'
  assert_includes text, 'diskon grosir'
  assert_includes text, 'PPN 11%'
  assert_includes text, 'Kembali'
  assert_equal 100_000 - cart.total, receipt.change
  assert_equal Kasir::Receipt::WIDTH, receipt.lines.first.length + (Kasir::Receipt::WIDTH - receipt.lines.first.length)
  receipt.lines.each { |line| refute line.length > Kasir::Receipt::WIDTH, line.inspect }
end

puts 'Kasir -- the till'

test 'the empty till renders the catalog and a zero total' do
  app, ui = till
  lines = screen_of(ui)
  text = lines.join("\n")
  assert_equal 28, lines.length
  assert_includes text, 'Indomie Goreng'
  assert_includes text, 'Keranjang'
  assert_includes text, 'TOTAL  Rp 0'
end

test 'picking a product adds it to the cart' do
  app, = till
  assert app.cart.empty?

  app.add_to_cart('MKN-01', 2)
  assert_equal 2, app.cart.quantity
  assert_equal 7_000 + (7_000 * Kasir::TAX_RATE).round, app.cart.total
  assert_includes plain(app.instance_variable_get(:@grand_total).text), 'Rp 7.770'
end

test 'the qty shortcuts only work while the cart has the focus' do
  app, ui = till
  app.add_to_cart('MKN-01')

  app.change_qty(1)                     # focus is on the search field
  assert_equal 1, app.cart.quantity

  ui.focus(app.instance_variable_get(:@cart_table))
  app.change_qty(1)
  assert_equal 2, app.cart.quantity
  app.change_qty(-5)
  assert app.cart.empty?, 'qty below zero drops the line'
end

test 'paying is refused while the cart is empty' do
  app, = till
  app.open_payment
  refute app.overlay_shown?
  assert_includes plain(app.instance_variable_get(:@status_label).text), 'kosong'
end

test 'the payment dialog only accepts enough cash' do
  app, ui = till
  app.add_to_cart('SBK-02')             # Rp 38.000 + PPN
  app.open_payment

  assert app.overlay_shown?
  assert_equal 0, app.instance_variable_get(:@dialogs).active, 'the payment pane is active'

  cash = app.instance_variable_get(:@cash_field)
  cash.editor.value = '10.000'
  assert_includes app.validate_cash('10.000'), 'kurang'
  assert_includes plain(app.instance_variable_get(:@pay_change).text), 'kurang'

  cash.editor.value = '50.000'
  assert_equal true, app.validate_cash('50.000')
  assert_includes plain(app.instance_variable_get(:@pay_change).text), 'kembalian'
end

test 'a modal keeps the focus inside itself' do
  app, ui = till
  app.add_to_cart('MKN-01')
  app.open_payment

  reachable = ui.focusables
  assert reachable.length.positive?
  assert reachable.all? { |component| component.respond_to?(:rect) }
  refute reachable.include?(app.instance_variable_get(:@search)),
         'the search field is behind the modal'
end

test 'settling shows the receipt and confirming starts a new order' do
  app, ui = till
  app.add_to_cart('MKN-01', 2)
  total = app.cart.total

  app.open_payment
  app.settle(cash: '100.000', method: 'Tunai')

  assert app.overlay_shown?
  assert app.showing_receipt?
  receipt_lines = app.instance_variable_get(:@receipt_stack).children.map { |l| plain(l.text) }
  assert_includes receipt_lines.join("\n"), 'Indomie Goreng'
  assert_includes receipt_lines.join("\n"), 'Kembali'
  assert_equal 100_000 - total, app.instance_variable_get(:@receipt).change

  app.confirm
  refute app.overlay_shown?
  assert app.cart.empty?
end

test 'esc cancels a payment without touching the cart' do
  app, = till
  app.add_to_cart('MKN-01')
  app.open_payment
  app.cancel

  refute app.overlay_shown?
  assert_equal 1, app.cart.quantity
end

test 'a long receipt scrolls' do
  app, ui = till(96, 20)
  app.demo_receipt!
  ui.render_frame                     # lay out, so the viewport knows its content
  view = app.instance_variable_get(:@receipt_view)
  assert_equal 0, view.offset_y
  app.scroll_receipt(4)
  assert_equal 4, view.offset_y
  app.scroll_receipt(-40)
  assert_equal 0, view.offset_y
end

puts 'Kasir -- rendering'

test 'every state fits every size' do
  [[72, 20], [96, 28], [140, 40]].each do |cols, rows|
    %i[empty cart pay receipt].each do |state|
      app = Kasir::App.new
      app.demo_cart!     if %i[cart pay receipt].include?(state)
      app.demo_payment!  if state == :pay
      app.demo_receipt!  if state == :receipt

      ui = TUI::App.new(app.root, out: CountingIO.new, size: [cols, rows])
      lines = screen_of(ui)
      assert_equal rows, lines.length, "#{state} at #{cols}x#{rows}"
      lines.each_with_index do |line, i|
        assert_equal cols, line.length, "#{state} row #{i} at #{cols}x#{rows}: #{line.inspect}"
      end
    end
  end
end

test 'bin/kasir --snapshot works without a terminal' do
  root = File.expand_path('..', __dir__)
  out = `ruby #{File.join(root, 'bin', 'kasir')} --snapshot --state=cart --w=100 --h=26 2>&1`
  text = plain(out)
  assert_includes text, 'kasir'
  assert_includes text, 'Keranjang'
  assert_includes text, 'TOTAL'
end

puts 'Kasir -- end to end in a pty'

test 'a whole sale can be typed through in a real terminal' do
  out = +''
  status = nil
  root = File.expand_path('..', __dir__)

  PTY.spawn('ruby', File.join(root, 'bin', 'kasir')) do |reader, writer, pid|
    drain = Thread.new do
      loop { out << reader.readpartial(65_536) }
    rescue EOFError, Errno::EIO
    end

    sleep 1.2
    keys = ['m', 'k', 'n',                  # search for "mkn"
            "\t", "\t", "\r",               # to the products, add the first hit
            "\t", "\t", "\r",               # to the pay button, open the dialog
            '1', '5', '0', '0', '0', '0',   # count the cash
            "\r",                           # pay -> receipt
            "\r",                           # start a new order
            "\u0003"]                       # ctrl-c quits from anywhere
    keys.each do |key|
      writer.print(key)
      writer.flush
      sleep 0.25
    end

    begin
      Timeout.timeout(10) { _, status = Process.wait2(pid) }
    rescue Timeout::Error
      Process.kill('KILL', pid)
      status = nil
    end
    drain.join(1)
  end

  text = plain(out)

  assert status && status.success?, "kasir must exit cleanly (got #{status.inspect})"
  assert_includes out, TUI::Term::ALT_ON
  assert_includes out, TUI::Term::ALT_OFF
  assert_includes text, 'Indomie G', 'the search filtered the catalog and the item went in'
  assert_includes text, 'Total  Rp', 'the payment dialog opened'
  assert_includes text, 'Kembali', 'the receipt shows the change'
  refute text.include?('1500000000'), 'keys are not echoed'
end
