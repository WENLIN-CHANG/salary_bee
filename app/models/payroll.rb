class Payroll < ApplicationRecord
  include AASM

  # Associations
  belongs_to :company
  has_many :payroll_items, dependent: :destroy
  has_many :employees, through: :payroll_items

  # Validations
  validates :year, presence: true,
                   numericality: { only_integer: true, greater_than: 2000 }
  validates :month, presence: true,
                    numericality: { only_integer: true, greater_than_or_equal_to: 1, less_than_or_equal_to: 12 }
  validates :month, uniqueness: { scope: [ :company_id, :year ], message: "該公司在此年月已有薪資記錄" }

  validates :total_gross_pay, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :total_net_pay, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

  # Custom validations
  validate :period_cannot_be_future

  # State machine
  aasm column: :status do
    state :draft, initial: true
    state :confirmed
    state :paid

    event :confirm do
      transitions from: :draft, to: :confirmed, guard: :can_confirm?

      after do
        update_column(:confirmed_at, Time.current)
      end
    end

    event :mark_as_paid do
      transitions from: :confirmed, to: :paid

      after do
        update_column(:paid_at, Time.current)
      end
    end
  end

  # Scopes
  scope :by_company, ->(company) { where(company: company) }
  scope :by_period, ->(year, month) { where(year: year, month: month) }
  scope :by_year, ->(year) { where(year: year) }
  scope :in_status, ->(status) { where(status: status) }
  scope :recent, -> { order(created_at: :desc) }

  # Instance methods
  def period_text
    "#{year}年#{format('%02d', month)}月"
  end

  def can_edit?
    draft?
  end

  def calculate_totals
    self.total_gross_pay = payroll_items.sum(:gross_pay) || 0
    self.total_net_pay = payroll_items.sum(:net_pay) || 0
  end

  def employees_count
    payroll_items.count
  end

  private

  def period_cannot_be_future
    return if year.blank? || month.blank?

    begin
      period_date = Date.new(year, month, 1)
      current_month_start = Date.current.beginning_of_month

      if period_date > current_month_start
        errors.add(:base, "薪資期間不可設定為未來")
      end
    rescue Date::Error, ArgumentError
      # Invalid date (e.g., month = 13), skip this validation
      # Let numericality validation handle the error
    end
  end

  def can_confirm?
    return false if payroll_items.empty?
    return false if payroll_items.where(net_pay: nil).exists?

    true
  end
end
