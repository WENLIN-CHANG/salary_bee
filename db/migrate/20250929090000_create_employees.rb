class CreateEmployees < ActiveRecord::Migration[8.0]
  def change
    create_table :employees do |t|
      t.references :company, null: false, foreign_key: true
      t.string :employee_id, null: false
      t.string :name, null: false
      t.string :id_number
      t.string :email
      t.string :phone
      t.date :birth_date
      t.date :hire_date, null: false
      t.date :resign_date
      t.string :department
      t.string :position
      t.decimal :base_salary, precision: 10, scale: 2, default: 0, null: false
      t.json :allowances, default: {}
      t.json :deductions, default: {}
      t.string :labor_insurance_group
      t.string :health_insurance_group
      t.boolean :active, default: true, null: false

      t.timestamps
    end

    add_index :employees, [ :company_id, :employee_id ], unique: true
  end
end
