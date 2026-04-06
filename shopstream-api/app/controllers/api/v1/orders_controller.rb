module Api
  module V1
    class OrdersController < ApplicationController
      def index
        render json: Order.includes(:order_items).all
      end

      def show
        render json: order, include: { order_items: { include: :product } }
      end

      def create
        order = Order.new(status: "pending")

        ActiveRecord::Base.transaction do
          order.save!
          (params[:order_items] || []).each do |item_params|
            product = Product.find(item_params[:product_id])
            order.order_items.create!(
              product: product,
              quantity: item_params[:quantity],
              unit_price_cents: product.price_cents
            )
          end
          order.recalculate_total!
        end

        render json: order, include: :order_items, status: :created
      rescue ActiveRecord::RecordNotFound => e
        render json: { error: e.message }, status: :not_found
      rescue ActiveRecord::RecordInvalid => e
        render json: { errors: e.record.errors.full_messages }, status: :unprocessable_entity
      end

      private

      def order
        @order ||= Order.includes(:order_items).find(params[:id])
      end
    end
  end
end
