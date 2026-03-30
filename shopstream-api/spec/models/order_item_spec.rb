require 'rails_helper'

RSpec.describe OrderItem, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:order) }
    it { is_expected.to belong_to(:product) }
  end

  describe "validations" do
    it { is_expected.to validate_numericality_of(:quantity).is_greater_than(0) }
    it { is_expected.to validate_numericality_of(:unit_price_cents).is_greater_than_or_equal_to(0) }
  end
end
