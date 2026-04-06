class Order < ApplicationRecord
  STATUSES = %w[pending confirmed shipped cancelled].freeze

  has_many :order_items, dependent: :destroy
  has_many :products, through: :order_items

  validates :status, inclusion: { in: STATUSES }

  def recalculate_total!
    update!(total_cents: order_items.sum { |item| item.quantity * item.unit_price_cents })
  end
end
