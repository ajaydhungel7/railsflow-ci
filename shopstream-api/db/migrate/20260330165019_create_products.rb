class CreateProducts < ActiveRecord::Migration[7.2]
  def change
    create_table :products do |t|
      t.string :name, null: false
      t.integer :price_cents, null: false, default: 0
      t.text :description
      t.integer :stock_count, null: false, default: 0

      t.timestamps
    end
  end
end
