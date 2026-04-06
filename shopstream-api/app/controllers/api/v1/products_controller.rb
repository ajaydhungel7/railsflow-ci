module Api
  module V1
    class ProductsController < ApplicationController
      def index
        render json: Product.all
      end

      def show
        render json: product
      end

      def create
        product = Product.new(product_params)
        if product.save
          render json: product, status: :created
        else
          render json: { errors: product.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def update
        if product.update(product_params)
          render json: product
        else
          render json: { errors: product.errors.full_messages }, status: :unprocessable_entity
        end
      end

      private

      def product
        @product ||= Product.find(params[:id])
      end

      def product_params
        params.require(:product).permit(:name, :price_cents, :description, :stock_count)
      end
    end
  end
end
