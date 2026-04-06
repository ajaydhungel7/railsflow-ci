FactoryBot.define do
  factory :product do
    name { Faker::Commerce.product_name }
    price_cents { Faker::Number.between(from: 100, to: 99999) }
    description { Faker::Lorem.sentence }
    stock_count { Faker::Number.between(from: 0, to: 500) }
  end
end
