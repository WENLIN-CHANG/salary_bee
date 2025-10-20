class CreatePayrollItems < ActiveRecord::Migration[8.0]
  def change
    create_table :payroll_items do |t|
      t.references :payroll, null: false, foreign_key: true
      t.references :employee, null: false, foreign_key: true
      t.decimal :base_salary, precision: 10, scale: 0, null: false
      t.decimal :total_allowances, precision: 10, scale: 0, default: 0
      t.decimal :total_deductions, precision: 10, scale: 0, default: 0
      t.decimal :total_insurance_premium, precision: 10, scale: 0, default: 0
      t.decimal :gross_pay, precision: 10, scale: 0
      t.decimal :net_pay, precision: 10, scale: 0

      t.timestamps
    end

    add_index :payroll_items, [ :payroll_id, :employee_id ], unique: true
  end
end
