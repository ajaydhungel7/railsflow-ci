require 'rails_helper'

RSpec.describe "Api::V1::Products", type: :request do
  describe "GET /api/v1/products" do
    it "returns all products" do
      create_list(:product, 3)
      get "/api/v1/products"
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body).length).to eq(3)
    end
  end

  describe "GET /api/v1/products/:id" do
    it "returns the product" do
      product = create(:product)
      get "/api/v1/products/#{product.id}"
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)["id"]).to eq(product.id)
    end
  end

  describe "POST /api/v1/products" do
    let(:valid_params) { { product: { name: "Widget", price_cents: 999, stock_count: 10 } } }

    it "creates a product" do
      post "/api/v1/products", params: valid_params
      expect(response).to have_http_status(:created)
      expect(JSON.parse(response.body)["name"]).to eq("Widget")
    end

    it "returns errors for invalid params" do
      post "/api/v1/products", params: { product: { name: "" } }
      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)).to have_key("errors")
    end
  end

  describe "PATCH /api/v1/products/:id" do
    it "updates the product" do
      product = create(:product)
      patch "/api/v1/products/#{product.id}", params: { product: { stock_count: 99 } }
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)["stock_count"]).to eq(99)
    end
  end
end
