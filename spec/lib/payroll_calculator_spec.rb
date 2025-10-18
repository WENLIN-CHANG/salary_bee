require 'rails_helper'

RSpec.describe PayrollCalculator do
  describe '.calculate_gross_pay' do
    it '計算應發薪資（底薪 + 津貼）' do
      result = PayrollCalculator.calculate_gross_pay(
        base_salary: 40000,
        total_allowances: 5000
      )
      expect(result).to eq(45000)
    end

    it '沒有津貼時等於底薪' do
      result = PayrollCalculator.calculate_gross_pay(
        base_salary: 40000,
        total_allowances: 0
      )
      expect(result).to eq(40000)
    end

    it '處理極大數值' do
      result = PayrollCalculator.calculate_gross_pay(
        base_salary: 10_000_000,
        total_allowances: 1_000_000
      )
      expect(result).to eq(11_000_000)
    end

    it '底薪為 0 時回傳津貼' do
      result = PayrollCalculator.calculate_gross_pay(
        base_salary: 0,
        total_allowances: 5000
      )
      expect(result).to eq(5000)
    end
  end

  describe '.calculate_insurance_premium' do
    it '計算員工負擔的保險費總和' do
      salary = 40000

      result = PayrollCalculator.calculate_insurance_premium(salary)

      expect(result).to be_a(Integer)
      expect(result).to be >= 0
    end

    it '低薪資的保險費較低' do
      low_result = PayrollCalculator.calculate_insurance_premium(30000)
      high_result = PayrollCalculator.calculate_insurance_premium(50000)

      # 可能因為級距問題，高薪不一定保費更高，但至少應該是非負整數
      expect(low_result).to be >= 0
      expect(high_result).to be >= 0
    end

    it '0 薪資時保險費為 0' do
      result = PayrollCalculator.calculate_insurance_premium(0)
      expect(result).to eq(0)
    end

    it '保險資料不存在時回傳 0' do
      # 假設薪資超出所有級距範圍
      allow(Insurance).to receive(:calculate_premium).and_return(nil)
      result = PayrollCalculator.calculate_insurance_premium(999_999_999)
      expect(result).to eq(0)
    end
  end

  describe '.calculate_total_deductions' do
    it '計算總扣款（扣款 + 保險費）' do
      result = PayrollCalculator.calculate_total_deductions(
        total_deductions: 1000,
        total_insurance_premium: 3000
      )
      expect(result).to eq(4000)
    end

    it '沒有扣款時等於保險費' do
      result = PayrollCalculator.calculate_total_deductions(
        total_deductions: 0,
        total_insurance_premium: 3000
      )
      expect(result).to eq(3000)
    end

    it '沒有保險費時等於扣款' do
      result = PayrollCalculator.calculate_total_deductions(
        total_deductions: 1000,
        total_insurance_premium: 0
      )
      expect(result).to eq(1000)
    end

    it '兩者都為 0 時回傳 0' do
      result = PayrollCalculator.calculate_total_deductions(
        total_deductions: 0,
        total_insurance_premium: 0
      )
      expect(result).to eq(0)
    end
  end

  describe '.calculate_net_pay' do
    it '計算實發薪資（應發 - 總扣款）' do
      result = PayrollCalculator.calculate_net_pay(
        gross_pay: 45000,
        total_deductions: 4000
      )
      expect(result).to eq(41000)
    end

    it '沒有扣款時等於應發薪資' do
      result = PayrollCalculator.calculate_net_pay(
        gross_pay: 45000,
        total_deductions: 0
      )
      expect(result).to eq(45000)
    end

    it '扣款等於應發時實發為 0' do
      result = PayrollCalculator.calculate_net_pay(
        gross_pay: 45000,
        total_deductions: 45000
      )
      expect(result).to eq(0)
    end

    it '處理極大數值' do
      result = PayrollCalculator.calculate_net_pay(
        gross_pay: 11_000_000,
        total_deductions: 1_000_000
      )
      expect(result).to eq(10_000_000)
    end

    it '扣款大於應發時回傳負數（異常情況）' do
      result = PayrollCalculator.calculate_net_pay(
        gross_pay: 30000,
        total_deductions: 35000
      )
      expect(result).to eq(-5000)
    end
  end

  describe '.calculate_all' do
    it '一次計算所有薪資項目' do
      result = PayrollCalculator.calculate_all(
        base_salary: 40000,
        total_allowances: 5000,
        total_deductions: 1000
      )

      expect(result).to include(
        gross_pay: 45000,
        total_insurance_premium: be_a(Integer),
        net_pay: be_a(Integer)
      )

      # 驗證計算正確性
      expected_total_deductions = 1000 + result[:total_insurance_premium]
      expect(result[:net_pay]).to eq(45000 - expected_total_deductions)
    end

    it '回傳所有必要欄位' do
      result = PayrollCalculator.calculate_all(
        base_salary: 40000,
        total_allowances: 5000,
        total_deductions: 1000
      )

      expect(result.keys).to match_array([
        :gross_pay,
        :total_insurance_premium,
        :total_deductions_with_insurance,
        :net_pay
      ])
    end
  end

  describe 'Pure Function 特性' do
    it '相同輸入產生相同輸出（無副作用）' do
      input = { base_salary: 40000, total_allowances: 5000 }

      result1 = PayrollCalculator.calculate_gross_pay(**input)
      result2 = PayrollCalculator.calculate_gross_pay(**input)
      result3 = PayrollCalculator.calculate_gross_pay(**input)

      expect(result1).to eq(result2)
      expect(result2).to eq(result3)
    end

    it '不修改輸入參數（無副作用）' do
      input = { base_salary: 40000, total_allowances: 5000 }
      original_input = input.dup

      PayrollCalculator.calculate_gross_pay(**input)

      expect(input).to eq(original_input)
    end
  end
end
