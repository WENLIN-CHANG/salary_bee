class FixDecimalScaleForPayrolls < ActiveRecord::Migration[8.0]
  def change
    # Fix payrolls table
    change_column :payrolls, :total_gross_pay, :decimal, precision: 12, scale: 0
    change_column :payrolls, :total_net_pay, :decimal, precision: 12, scale: 0

    # Fix payroll_items table
    change_column :payroll_items, :base_salary, :decimal, precision: 10, scale: 0, null: false
    change_column :payroll_items, :total_allowances, :decimal, precision: 10, scale: 0, default: 0
    change_column :payroll_items, :total_deductions, :decimal, precision: 10, scale: 0, default: 0
    change_column :payroll_items, :total_insurance_premium, :decimal, precision: 10, scale: 0, default: 0
    change_column :payroll_items, :gross_pay, :decimal, precision: 10, scale: 0
    change_column :payroll_items, :net_pay, :decimal, precision: 10, scale: 0
  end
end
