class CreateOrders < ActiveRecord::Migration[7.2]
  def change
    create_table :orders do |t|
      t.string :status, null: false, default: "pending"
      t.integer :total_cents, null: false, default: 0

      t.timestamps
    end
  end
end
