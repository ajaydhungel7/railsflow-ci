puts "Seeding products..."

products = [
  { name: "Wireless Headphones", price_cents: 7999, description: "Noise-cancelling over-ear headphones", stock_count: 50 },
  { name: "Mechanical Keyboard", price_cents: 12999, description: "Tenkeyless RGB mechanical keyboard", stock_count: 30 },
  { name: "USB-C Hub", price_cents: 3499, description: "7-in-1 USB-C hub with HDMI and PD charging", stock_count: 100 },
  { name: "Webcam 1080p", price_cents: 5999, description: "Full HD webcam with built-in microphone", stock_count: 75 },
  { name: "Desk Mat", price_cents: 1999, description: "Large extended mouse pad, 90x40cm", stock_count: 200 }
]

products.each { |attrs| Product.find_or_create_by!(name: attrs[:name]).update!(attrs) }

puts "Seeding orders..."

order1 = Order.create!(status: "confirmed")
order1.order_items.create!(product: Product.find_by!(name: "Wireless Headphones"), quantity: 1, unit_price_cents: 7999)
order1.order_items.create!(product: Product.find_by!(name: "USB-C Hub"), quantity: 2, unit_price_cents: 3499)
order1.recalculate_total!

order2 = Order.create!(status: "pending")
order2.order_items.create!(product: Product.find_by!(name: "Mechanical Keyboard"), quantity: 1, unit_price_cents: 12999)
order2.recalculate_total!

puts "Done! #{Product.count} products, #{Order.count} orders."
