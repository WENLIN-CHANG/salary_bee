# Service Object for Payroll Calculation
# Handles creating/updating payroll items and calculating salaries
class PayrollCalculationService
  class PayrollNotEditableError < StandardError; end

  attr_reader :payroll

  def initialize(payroll)
    @payroll = payroll
  end

  # 計算整個薪資批次
  # @return [Boolean] 成功回傳 true
  # @raise [PayrollNotEditableError] 如果 payroll 不可編輯
  def call
    raise PayrollNotEditableError, "Payroll 已確認，無法重新計算" unless payroll.can_edit?

    ActiveRecord::Base.transaction do
      # 為所有員工計算薪資（包含離職員工）
      employees.each do |employee|
        calculate_for_employee(employee)
      end

      # 更新 Payroll 總額
      update_payroll_totals

      true
    end
  end

  # 為單一員工計算薪資
  # @param employee [Employee] 員工
  # @return [PayrollItem] 建立或更新的薪資項目
  def calculate_for_employee(employee)
    # 找到或建立薪資項目
    item = payroll.payroll_items.find_or_initialize_by(employee: employee)

    # 從員工資料取得基本薪資和津貼/扣款
    item.base_salary = employee.base_salary
    item.total_allowances = employee.total_allowances
    item.total_deductions = employee.total_deductions

    # 使用 PayrollCalculator 計算所有金額
    calculation_result = PayrollCalculator.calculate_all(
      base_salary: item.base_salary,
      total_allowances: item.total_allowances,
      total_deductions: item.total_deductions
    )

    # 更新計算結果
    item.gross_pay = calculation_result[:gross_pay]
    item.total_insurance_premium = calculation_result[:total_insurance_premium]
    item.net_pay = calculation_result[:net_pay]

    item.save!
    item
  end

  private

  # 取得公司所有員工（包含離職員工）
  # @return [ActiveRecord::Relation<Employee>]
  def employees
    payroll.company.employees
  end

  # 更新 Payroll 的總額
  def update_payroll_totals
    payroll.calculate_totals
    payroll.save!
  end
end
