# frozen_string_literal: true
#
# The cashier's books: products, the cart and the receipt. Plain Ruby --
# no TUI in here, so all of it can be tested (and re-used) on its own.

module Kasir
  TAX_RATE   = 0.11   # PPN
  BULK_QTY   = 6      # buying this many of one item earns...
  BULK_RATE  = 0.05   # ...a 5% discount on that line

  # Indonesian rupiah: no cents, "." as the thousands separator.
  module Money
    class << self
      def format(amount)
        number = amount.to_i
        return "-Rp #{separate(-number)}" if number.negative?

        "Rp #{separate(number)}"
      end

      def separate(amount)
        number = amount.to_i
        sign = number.negative? ? '-' : ''
        digits = number.abs.to_s
        grouped = digits.reverse.scan(/\d{1,3}/).join('.').reverse
        sign + grouped
      end

      # "Rp 50.000" / "50000" / "50 000" -> 50000
      def parse(text)
        text.to_s.gsub(/[^0-9]/, '').to_i
      end
    end
  end

  Product = Struct.new(:sku, :name, :price, :category) do
    def to_s
      name
    end
  end

  class Catalog
    PRODUCTS = [
      Product.new('MKN-01', 'Indomie Goreng',    3_500, 'Makanan'),
      Product.new('MKN-02', 'Mie Sedaap Soto',   3_200, 'Makanan'),
      Product.new('MKN-03', 'Biskuit Roma Kelapa', 8_500, 'Makanan'),
      Product.new('MKN-04', 'Chitato Sapi Panggang', 9_000, 'Makanan'),
      Product.new('MKN-05', 'Roti Tawar Gandum', 15_000, 'Makanan'),
      Product.new('MNM-01', 'Aqua 600ml',        4_000, 'Minuman'),
      Product.new('MNM-02', 'Teh Pucuk Harum',   5_000, 'Minuman'),
      Product.new('MNM-03', 'Kopi Kapal Api',    2_500, 'Minuman'),
      Product.new('MNM-04', 'Susu UHT Cokelat', 21_000, 'Minuman'),
      Product.new('MNM-05', 'Pocari Sweat 500ml', 9_000, 'Minuman'),
      Product.new('SBK-01', 'Beras Pandan 5kg', 68_000, 'Sembako'),
      Product.new('SBK-02', 'Minyak Goreng 2L', 38_000, 'Sembako'),
      Product.new('SBK-03', 'Gula Pasir 1kg',   17_000, 'Sembako'),
      Product.new('SBK-04', 'Telur Ayam 1kg',   29_000, 'Sembako'),
      Product.new('SBK-05', 'Kecap Manis 520ml', 12_000, 'Sembako'),
      Product.new('SBK-06', 'Terigu Serbaguna 1kg', 14_000, 'Sembako'),
      Product.new('LAI-01', 'Sabun Mandi',       4_500, 'Lainnya'),
      Product.new('LAI-02', 'Shampo Sachet',     1_000, 'Lainnya'),
      Product.new('LAI-03', 'Pasta Gigi 120g',  14_000, 'Lainnya'),
      Product.new('LAI-04', 'Tisu Wajah 250s',  16_000, 'Lainnya')
    ].freeze

    attr_reader :products

    def initialize(products = PRODUCTS)
      @products = products
    end

    def categories
      ['Semua'] + @products.map(&:category).uniq
    end

    def find(sku)
      @products.find { |product| product.sku == sku }
    end

    # Free-text search over name and code, optionally within a category.
    def search(query = '', category = nil)
      list = @products
      list = list.select { |p| p.category == category } if category && category != 'Semua'
      text = query.to_s.strip.downcase
      return list if text.empty?

      list.select do |product|
        product.name.downcase.include?(text) || product.sku.downcase.include?(text)
      end
    end
  end

  class Cart
    class Line
      attr_reader :product
      attr_accessor :qty

      def initialize(product, qty = 1)
        @product = product
        @qty = qty
      end

      def subtotal
        @product.price * @qty
      end

      # Buying in bulk earns a discount on that line only.
      def discount
        return 0 if @qty < BULK_QTY

        (subtotal * BULK_RATE).round
      end
    end

    attr_reader :lines

    def initialize
      @lines = []
    end

    def empty?
      @lines.empty?
    end

    def find(sku)
      @lines.find { |line| line.product.sku == sku }
    end

    def add(product, qty = 1)
      line = find(product.sku)
      if line
        line.qty += qty
      else
        @lines << Line.new(product, qty)
      end
      self
    end

    # qty + delta, dropping the line when it runs out.
    def change(sku, delta)
      line = find(sku)
      return self unless line

      line.qty += delta
      @lines.delete(line) if line.qty <= 0
      self
    end

    def remove(sku)
      line = find(sku)
      @lines.delete(line) if line
      self
    end

    def clear
      @lines.clear
      self
    end

    def quantity
      @lines.sum(&:qty)
    end

    def subtotal
      @lines.sum(&:subtotal)
    end

    def discount
      @lines.sum(&:discount)
    end

    def taxable
      subtotal - discount
    end

    def tax
      (taxable * TAX_RATE).round
    end

    def total
      taxable + tax
    end

    def change_for(paid)
      paid.to_i - total
    end
  end

  # A fixed-width receipt, ready to be printed line by line.
  class Receipt
    WIDTH = 40

    attr_reader :lines, :paid, :method

    def initialize(cart:, paid:, method: 'Tunai', store: 'TOKO RUBY',
                   time: Time.now, cashier: 'RUBY-01')
      @cart = cart
      @paid = paid.to_i
      @method = method
      @store = store
      @time = time
      @cashier = cashier
      @lines = build
    end

    def change
      @cart.change_for(@paid)
    end

    def total
      @cart.total
    end

    private

    def build
      out = []
      out << center(@store)
      out << center('Jl. Merdeka No. 1, Jakarta')
      out << center(@time.strftime('%d/%m/%Y %H:%M:%S'))
      out << center("Kasir: #{@cashier}")
      out << divider

      @cart.lines.each do |line|
        out << line.product.name[0, WIDTH].to_s
        out << pair("#{line.qty} x #{Money.separate(line.product.price)}",
                    Money.separate(line.subtotal))
        if line.discount.positive?
          out << pair("  diskon grosir #{line.qty} pcs",
                      "-#{Money.separate(line.discount)}")
        end
      end

      out << divider
      out << pair('Subtotal', Money.separate(@cart.subtotal))
      if @cart.discount.positive?
        out << pair('Diskon', "-#{Money.separate(@cart.discount)}")
      end
      out << pair("PPN #{(TAX_RATE * 100).round}%", Money.separate(@cart.tax))
      out << pair('TOTAL', Money.separate(total))
      out << pair(@method, Money.separate(@paid))
      out << pair('Kembali', Money.separate(change))
      out << divider
      out << center('Terima kasih, selamat belanja!')
      out << center('Barang yang sudah dibeli tidak dapat ditukar')
      out
    end

    def divider
      '-' * WIDTH
    end

    def center(text)
      text.to_s[0, WIDTH].center(WIDTH).rstrip
    end

    # A label on the left, an amount right-aligned to the receipt edge.
    def pair(left, right)
      right = right.to_s
      left = left.to_s[0, [WIDTH - right.length - 1, 0].max]
      gap = [WIDTH - left.length - right.length, 1].max
      "#{left}#{' ' * gap}#{right}"
    end
  end
end
