class CreatePayrolls < ActiveRecord::Migration[8.0]
  def change
    create_table :payrolls do |t|
      t.references :company, null: false, foreign_key: true
      t.integer :year, null: false
      t.integer :month, null: false
      t.string :status, default: 'draft'
      t.decimal :total_gross_pay, precision: 12, scale: 0
      t.decimal :total_net_pay, precision: 12, scale: 0
      t.datetime :confirmed_at
      t.datetime :paid_at

      t.timestamps
    end

    add_index :payrolls, [:company_id, :year, :month], unique: true
    add_index :payrolls, :status
  end
end
