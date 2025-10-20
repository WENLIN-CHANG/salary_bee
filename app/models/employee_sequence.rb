# EmployeeSequence manages employee ID generation per company and year
# Uses database locking to prevent race conditions when generating IDs
#
# Usage:
#   number = EmployeeSequence.next_for(company, 2024)
#   employee_id = "EMP#{2024}#{number.to_s.rjust(4, '0')}"
#   # => "EMP20240001", "EMP20240002", etc.
#
class EmployeeSequence < ApplicationRecord
  belongs_to :company

  validates :year, presence: true, numericality: { only_integer: true, greater_than: 1900 }
  validates :last_number, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :company_id, uniqueness: { scope: :year, message: "已有該年度的序號" }

  # Get the next employee number for a company in a given year
  # Uses database locking to prevent race conditions
  #
  # @param company [Company] 公司
  # @param year [Integer] 年份
  # @return [Integer] 下一個員工編號
  #
  # Example:
  #   EmployeeSequence.next_for(company, 2024) # => 1
  #   EmployeeSequence.next_for(company, 2024) # => 2
  #
  def self.next_for(company, year)
    transaction do
      # Find or create sequence with database lock
      # This prevents race conditions when multiple requests try to create employees simultaneously
      sequence = lock.find_or_create_by!(company: company, year: year)

      # Increment the counter
      sequence.increment!(:last_number)

      # Return the new number
      sequence.last_number
    end
  end

  # Reset the sequence for a company and year
  # Useful for testing or starting fresh
  #
  # @param company [Company] 公司
  # @param year [Integer] 年份
  # @return [Boolean] 成功回傳 true
  #
  def self.reset_for(company, year)
    transaction do
      sequence = lock.find_by(company: company, year: year)
      return true unless sequence

      sequence.update!(last_number: 0)
    end
  end
end
