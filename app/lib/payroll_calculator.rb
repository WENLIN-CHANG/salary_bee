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
  # @param insurance_lookup [Hash] 保險查詢表（從記憶體，不查資料庫）
  # @return [Integer] 保險費總額
  def self.calculate_insurance_premium(base_salary, insurance_lookup)
    return 0 if base_salary <= 0

    # 計算四種保險的員工負擔（從記憶體查詢，不打資料庫）
    labor = calculate_premium_from_lookup(insurance_lookup, "labor", base_salary)
    health = calculate_premium_from_lookup(insurance_lookup, "health", base_salary)
    pension = calculate_premium_from_lookup(insurance_lookup, "labor_pension", base_salary)
    occupational = calculate_premium_from_lookup(insurance_lookup, "occupational_injury", base_salary)

    # 加總員工負擔部分（處理 nil 的情況）
    total = [
      labor&.dig(:employee) || 0,
      health&.dig(:employee) || 0,
      pension&.dig(:employee) || 0,
      occupational&.dig(:employee) || 0
    ].sum

    total.to_i
  end

  # 從記憶體中的查詢表計算保費（純函數，無 side effect）
  # @param lookup_table [Hash] 保險查詢表
  # @param insurance_type [String] 保險類型
  # @param salary [Integer] 薪資
  # @return [Hash, nil] 保費明細或 nil
  def self.calculate_premium_from_lookup(lookup_table, insurance_type, salary)
    insurances = lookup_table[insurance_type] || []

    grade = insurances.find do |ins|
      ins.salary_min <= salary && (ins.salary_max.nil? || ins.salary_max >= salary)
    end

    return nil unless grade

    total_premium = grade.premium_base * grade.rate
    {
      total: total_premium,
      employee: total_premium * grade.employee_ratio,
      employer: total_premium * grade.employer_ratio,
      government: total_premium * grade.government_ratio,
      grade: grade
    }
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
  # @param insurance_lookup [Hash] 保險查詢表（預先載入，避免 N+1）
  # @return [Hash] 包含所有計算結果
  def self.calculate_all(base_salary:, total_allowances:, total_deductions:, insurance_lookup:)
    # 計算應發薪資
    gross_pay = calculate_gross_pay(
      base_salary: base_salary,
      total_allowances: total_allowances
    )

    # 計算保險費（從記憶體查詢，不打資料庫）
    insurance_premium = calculate_insurance_premium(base_salary, insurance_lookup)

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
