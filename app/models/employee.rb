class Employee < ApplicationRecord
  belongs_to :company

  # Validations
  validates :employee_id, presence: true,
                         uniqueness: { scope: :company_id }
  validates :name, presence: true
  validates :hire_date, presence: true
  validates :base_salary, presence: true,
                         numericality: { greater_than: 0 }

  # Taiwan ID number format validation (optional field)
  validates :id_number, format: {
    with: /\A[A-Z]\d{9}\z/,
    message: "格式錯誤（應為 1 個英文字母 + 9 個數字）"
  }, allow_blank: true

  # Email format validation (optional field)
  validates :email, format: {
    with: URI::MailTo::EMAIL_REGEXP
  }, allow_blank: true

  # Date validations
  validate :hire_date_cannot_be_future
  validate :resign_date_cannot_be_before_hire_date

  # Scopes
  scope :active, -> { where(active: true) }
  scope :by_department, ->(dept) { where(department: dept) }

  # Instance methods
  def total_allowances
    return 0 if allowances.nil? || allowances.empty?
    allowances.values.sum
  end

  def total_deductions
    return 0 if deductions.nil? || deductions.empty?
    deductions.values.sum
  end

  def gross_salary
    base_salary + total_allowances
  end

  def full_name_with_id
    "#{name} (#{employee_id})"
  end

  private

  def hire_date_cannot_be_future
    return if hire_date.blank?

    if hire_date > Date.current
      errors.add(:hire_date, "不能是未來日期")
    end
  end

  def resign_date_cannot_be_before_hire_date
    return if resign_date.blank? || hire_date.blank?

    if resign_date < hire_date
      errors.add(:resign_date, "不能早於到職日期")
    end
  end
end
