class CreateEmployeeSequences < ActiveRecord::Migration[8.0]
  def change
    create_table :employee_sequences do |t|
      t.references :company, null: false, foreign_key: true, index: true
      t.integer :year, null: false
      t.integer :last_number, null: false, default: 0

      t.timestamps
    end

    # Unique index to prevent duplicate sequences for the same company and year
    add_index :employee_sequences, [:company_id, :year], unique: true, name: 'index_employee_sequences_on_company_and_year'
  end
end
