FactoryBot.define do
  factory :order do
    status { "pending" }
    total_cents { 0 }
  end
end
