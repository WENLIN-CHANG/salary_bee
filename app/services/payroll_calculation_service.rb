# Service Object for Payroll Calculation
# Handles creating/updating payroll items and calculating salaries
#
# This service follows the two-phase pattern:
# 1. Calculate (pure function, no side effects)
# 2. Persist (batch write to database)
#
# Usage:
#   service = PayrollCalculationService.new(payroll)
#
#   # Calculate only (preview, no database writes)
#   results = service.calculate_all
#
#   # Calculate and persist
#   service.call
#
class PayrollCalculationService
  class PayrollNotEditableError < StandardError; end

  attr_reader :payroll, :insurance_lookup

  def initialize(payroll)
    @payroll = payroll
    # 預先載入所有保險資料到記憶體，避免 N+1 查詢
    @insurance_lookup = InsuranceCache.fetch_lookup_table
  end

  # 完整流程：計算並持久化（向後相容的 API）
  # @return [Boolean] 成功回傳 true
  # @raise [PayrollNotEditableError] 如果 payroll 不可編輯
  def call
    raise PayrollNotEditableError, "Payroll 已確認，無法重新計算" unless payroll.can_edit?

    calculations = calculate_all
    persist!(calculations)
    true
  end

  # 階段 1: 純計算（無 side effect）
  # 計算所有員工的薪資，但不寫入資料庫
  # @return [Array<Hash>] 計算結果陣列，每個元素包含 :employee 和 :result
  def calculate_all
    employees.map do |employee|
      {
        employee: employee,
        result: calculate_for_employee_pure(employee)
      }
    end
  end

  # 階段 2: 批次持久化
  # 將計算結果寫入資料庫
  # @param calculations [Array<Hash>] 由 calculate_all 回傳的計算結果
  # @return [Boolean] 成功回傳 true
  def persist!(calculations)
    ActiveRecord::Base.transaction do
      calculations.each do |calc|
        persist_payroll_item(calc[:employee], calc[:result])
      end

      update_payroll_totals
    end

    true
  end

  # 為單一員工計算薪資（純函數版本）
  # @param employee [Employee] 員工
  # @return [Hash] 計算結果
  def calculate_for_employee_pure(employee)
    PayrollCalculator.calculate_all(
      base_salary: employee.base_salary,
      total_allowances: employee.total_allowances,
      total_deductions: employee.total_deductions,
      insurance_lookup: @insurance_lookup
    )
  end

  # 為單一員工計算薪資（舊版 API，向後相容）
  # @param employee [Employee] 員工
  # @return [PayrollItem] 建立或更新的薪資項目
  # @deprecated 請使用 calculate_all + persist! 的兩階段模式
  def calculate_for_employee(employee)
    result = calculate_for_employee_pure(employee)
    persist_payroll_item(employee, result)
  end

  private

  # 取得公司所有員工（包含離職員工）
  # @return [ActiveRecord::Relation<Employee>]
  def employees
    payroll.company.employees
  end

  # 持久化單一員工的薪資項目
  # @param employee [Employee] 員工
  # @param calculation_result [Hash] 計算結果
  # @return [PayrollItem] 建立或更新的薪資項目
  def persist_payroll_item(employee, calculation_result)
    # 找到或建立薪資項目
    item = payroll.payroll_items.find_or_initialize_by(employee: employee)

    # 從員工資料取得基本薪資和津貼/扣款
    item.base_salary = employee.base_salary
    item.total_allowances = employee.total_allowances
    item.total_deductions = employee.total_deductions

    # 更新計算結果
    item.gross_pay = calculation_result[:gross_pay]
    item.total_insurance_premium = calculation_result[:total_insurance_premium]
    item.net_pay = calculation_result[:net_pay]

    item.save!
    item
  end

  # 更新 Payroll 的總額
  def update_payroll_totals
    payroll.calculate_totals
    payroll.save!
  end
end
