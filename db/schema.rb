# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2025_10_26_092251) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pg_trgm"

  create_table "companies", force: :cascade do |t|
    t.string "name"
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "tax_id", limit: 8, null: false
    t.index [ "tax_id" ], name: "index_companies_on_tax_id", unique: true
  end

  create_table "employee_sequences", force: :cascade do |t|
    t.bigint "company_id", null: false
    t.integer "year", null: false
    t.integer "last_number", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index [ "company_id", "year" ], name: "index_employee_sequences_on_company_and_year", unique: true
    t.index [ "company_id" ], name: "index_employee_sequences_on_company_id"
  end

  create_table "employees", force: :cascade do |t|
    t.bigint "company_id", null: false
    t.string "employee_id", null: false
    t.string "name", null: false
    t.string "id_number"
    t.string "email"
    t.string "phone"
    t.date "birth_date"
    t.date "hire_date", null: false
    t.date "resign_date"
    t.string "department"
    t.string "position"
    t.decimal "base_salary", precision: 10, scale: 2, default: "0.0", null: false
    t.json "allowances", default: {}
    t.json "deductions", default: {}
    t.string "labor_insurance_group"
    t.string "health_insurance_group"
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index [ "company_id", "employee_id" ], name: "index_employees_on_company_id_and_employee_id", unique: true
    t.index [ "company_id" ], name: "index_employees_on_company_id"
    t.index [ "name" ], name: "index_employees_on_name_trgm", opclass: :gin_trgm_ops, using: :gin
  end

  create_table "insurances", force: :cascade do |t|
    t.string "insurance_type", null: false
    t.integer "grade_level", null: false
    t.decimal "salary_min", precision: 10, scale: 2, null: false
    t.decimal "salary_max", precision: 10, scale: 2
    t.decimal "premium_base", precision: 10, scale: 2, null: false
    t.decimal "rate", precision: 5, scale: 4, null: false
    t.decimal "employee_ratio", precision: 4, scale: 3, null: false
    t.decimal "employer_ratio", precision: 4, scale: 3, null: false
    t.decimal "government_ratio", precision: 4, scale: 3, default: "0.0"
    t.date "effective_date", null: false
    t.date "expiry_date"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index [ "grade_level" ], name: "index_insurances_on_grade_level"
    t.index [ "insurance_type", "effective_date", "expiry_date" ], name: "index_insurances_on_type_and_dates"
    t.index [ "insurance_type" ], name: "index_insurances_on_insurance_type"
    t.index [ "salary_min", "salary_max" ], name: "index_insurances_on_salary_range"
  end

  create_table "payroll_items", force: :cascade do |t|
    t.bigint "payroll_id", null: false
    t.bigint "employee_id", null: false
    t.decimal "base_salary", precision: 10, null: false
    t.decimal "total_allowances", precision: 10, default: "0"
    t.decimal "total_deductions", precision: 10, default: "0"
    t.decimal "total_insurance_premium", precision: 10, default: "0"
    t.decimal "gross_pay", precision: 10
    t.decimal "net_pay", precision: 10
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index [ "employee_id" ], name: "index_payroll_items_on_employee_id"
    t.index [ "payroll_id", "employee_id" ], name: "index_payroll_items_on_payroll_id_and_employee_id", unique: true
    t.index [ "payroll_id" ], name: "index_payroll_items_on_payroll_id"
  end

  create_table "payrolls", force: :cascade do |t|
    t.bigint "company_id", null: false
    t.integer "year", null: false
    t.integer "month", null: false
    t.string "status", default: "draft"
    t.decimal "total_gross_pay", precision: 12
    t.decimal "total_net_pay", precision: 12
    t.datetime "confirmed_at"
    t.datetime "paid_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index [ "company_id", "year", "month" ], name: "index_payrolls_on_company_id_and_year_and_month", unique: true
    t.index [ "company_id" ], name: "index_payrolls_on_company_id"
    t.index [ "status" ], name: "index_payrolls_on_status"
  end

  create_table "sessions", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "ip_address"
    t.string "user_agent"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index [ "user_id" ], name: "index_sessions_on_user_id"
  end

  create_table "user_companies", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "company_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index [ "company_id" ], name: "index_user_companies_on_company_id"
    t.index [ "user_id", "company_id" ], name: "index_user_companies_on_user_id_and_company_id", unique: true
    t.index [ "user_id" ], name: "index_user_companies_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email_address", null: false
    t.string "password_digest", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index [ "email_address" ], name: "index_users_on_email_address", unique: true
  end

  add_foreign_key "employee_sequences", "companies"
  add_foreign_key "employees", "companies"
  add_foreign_key "payroll_items", "employees"
  add_foreign_key "payroll_items", "payrolls"
  add_foreign_key "payrolls", "companies"
  add_foreign_key "sessions", "users"
  add_foreign_key "user_companies", "companies"
  add_foreign_key "user_companies", "users"
end
