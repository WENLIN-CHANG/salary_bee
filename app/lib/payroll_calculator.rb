# Pure Functions for Payroll Calculation
# All methods are pure: same input always produces same output, no side effects
module PayrollCalculator
  # 計算應發薪資
  # @param base_salary [Integer] 底薪
  # @param total_allowances [Integer] 津貼總額
  # @return [Integer] 應發薪資
  def self.calculate_gross_pay(base_salary:, total_allowances:)
    base_salary + total_allowances
  end

  # 計算員工負擔的保險費總和
  # @param base_salary [Integer] 底薪（用於計算保險級距）
  # @return [Integer] 保險費總額
  def self.calculate_insurance_premium(base_salary)
    return 0 if base_salary <= 0

    # 計算四種保險的員工負擔
    labor = Insurance.calculate_premium('勞保', base_salary)
    health = Insurance.calculate_premium('健保', base_salary)
    pension = Insurance.calculate_premium('勞退', base_salary)
    occupational = Insurance.calculate_premium('職災險', base_salary)

    # 加總員工負擔部分（處理 nil 的情況）
    total = [
      labor&.dig(:employee) || 0,
      health&.dig(:employee) || 0,
      pension&.dig(:employee) || 0,
      occupational&.dig(:employee) || 0
    ].sum

    total.to_i
  end

  # 計算總扣款
  # @param total_deductions [Integer] 其他扣款（如借支、缺勤）
  # @param total_insurance_premium [Integer] 保險費
  # @return [Integer] 總扣款
  def self.calculate_total_deductions(total_deductions:, total_insurance_premium:)
    total_deductions + total_insurance_premium
  end

  # 計算實發薪資
  # @param gross_pay [Integer] 應發薪資
  # @param total_deductions [Integer] 總扣款
  # @return [Integer] 實發薪資
  def self.calculate_net_pay(gross_pay:, total_deductions:)
    gross_pay - total_deductions
  end

  # 一次計算所有薪資項目
  # @param base_salary [Integer] 底薪
  # @param total_allowances [Integer] 津貼總額
  # @param total_deductions [Integer] 其他扣款
  # @return [Hash] 包含所有計算結果
  def self.calculate_all(base_salary:, total_allowances:, total_deductions:)
    # 計算應發薪資
    gross_pay = calculate_gross_pay(
      base_salary: base_salary,
      total_allowances: total_allowances
    )

    # 計算保險費
    insurance_premium = calculate_insurance_premium(base_salary)

    # 計算總扣款（含保險費）
    total_deductions_with_insurance = calculate_total_deductions(
      total_deductions: total_deductions,
      total_insurance_premium: insurance_premium
    )

    # 計算實發薪資
    net_pay = calculate_net_pay(
      gross_pay: gross_pay,
      total_deductions: total_deductions_with_insurance
    )

    {
      gross_pay: gross_pay,
      total_insurance_premium: insurance_premium,
      total_deductions_with_insurance: total_deductions_with_insurance,
      net_pay: net_pay
    }
  end
end
