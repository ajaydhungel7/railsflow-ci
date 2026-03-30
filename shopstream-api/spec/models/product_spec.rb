require 'rails_helper'

RSpec.describe Product, type: :model do
  describe "associations" do
    it { is_expected.to have_many(:order_items).dependent(:destroy) }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_numericality_of(:price_cents).is_greater_than_or_equal_to(0) }
    it { is_expected.to validate_numericality_of(:stock_count).is_greater_than_or_equal_to(0) }
  end

  describe "factory" do
    it "creates a valid product" do
      expect(build(:product)).to be_valid
    end
  end
end
