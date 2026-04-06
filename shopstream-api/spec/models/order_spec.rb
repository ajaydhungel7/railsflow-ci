require 'rails_helper'

RSpec.describe Order, type: :model do
  describe "associations" do
    it { is_expected.to have_many(:order_items).dependent(:destroy) }
    it { is_expected.to have_many(:products).through(:order_items) }
  end

  describe "validations" do
    it { is_expected.to validate_inclusion_of(:status).in_array(Order::STATUSES) }
  end

  describe "#recalculate_total!" do
    it "sets total_cents based on order items" do
      order = create(:order)
      product = create(:product, price_cents: 1000)
      create(:order_item, order: order, product: product, quantity: 3, unit_price_cents: 1000)

      order.recalculate_total!

      expect(order.reload.total_cents).to eq(3000)
    end
  end
end
