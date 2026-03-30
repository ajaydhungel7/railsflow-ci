require 'rails_helper'

RSpec.describe "Api::V1::Orders", type: :request do
  describe "GET /api/v1/orders" do
    it "returns all orders" do
      create_list(:order, 2)
      get "/api/v1/orders"
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body).length).to eq(2)
    end
  end

  describe "GET /api/v1/orders/:id" do
    it "returns the order with items" do
      order = create(:order)
      create(:order_item, order: order)
      get "/api/v1/orders/#{order.id}"
      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["id"]).to eq(order.id)
    end
  end

  describe "POST /api/v1/orders" do
    it "creates an order with items and calculates total" do
      product = create(:product, price_cents: 2000)
      post "/api/v1/orders", params: {
        order_items: [{ product_id: product.id, quantity: 2 }]
      }
      expect(response).to have_http_status(:created)
      body = JSON.parse(response.body)
      expect(body["total_cents"]).to eq(4000)
      expect(body["order_items"].length).to eq(1)
    end

    it "returns 404 for unknown product" do
      post "/api/v1/orders", params: {
        order_items: [{ product_id: 99999, quantity: 1 }]
      }
      expect(response).to have_http_status(:not_found)
    end
  end
end
