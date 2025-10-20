class PayrollItem < ApplicationRecord
  # Associations
  belongs_to :payroll
  belongs_to :employee

  # Validations
  validates :base_salary, presence: true,
                          numericality: { greater_than_or_equal_to: 0 }

  validates :total_allowances, numericality: { greater_than_or_equal_to: 0 }
  validates :total_deductions, numericality: { greater_than_or_equal_to: 0 }
  validates :total_insurance_premium, numericality: { greater_than_or_equal_to: 0 }

  validates :gross_pay, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :net_pay, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

  validates :employee_id, uniqueness: { scope: :payroll_id, message: "該員工在此薪資批次中已存在" }
end
