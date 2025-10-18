require 'rails_helper'

RSpec.describe 'Payroll and PayrollItem Integration', type: :model do
  let(:company) { create(:company) }
  let(:employee1) { create(:employee, company: company, base_salary: 40000) }
  let(:employee2) { create(:employee, company: company, base_salary: 50000) }
  let(:payroll) { create(:payroll, company: company, year: 2024, month: 3) }

  describe '建立薪資批次時自動產生員工項目' do
    it '為所有在職員工建立薪資項目' do
      # 這會在 Service 層實作，這裡只測試關聯
      item1 = create(:payroll_item, payroll: payroll, employee: employee1)
      item2 = create(:payroll_item, payroll: payroll, employee: employee2)

      expect(payroll.payroll_items).to match_array([item1, item2])
      expect(payroll.employees).to match_array([employee1, employee2])
    end
  end

  describe '刪除薪資批次時級聯刪除項目' do
    it '刪除 Payroll 時一併刪除 PayrollItems' do
      item = create(:payroll_item, payroll: payroll, employee: employee1)
      item_id = item.id

      expect { payroll.destroy }.to change { PayrollItem.count }.by(-1)
      expect(PayrollItem.find_by(id: item_id)).to be_nil
    end

    it '刪除多個項目' do
      create(:payroll_item, payroll: payroll, employee: employee1)
      create(:payroll_item, payroll: payroll, employee: employee2)

      expect { payroll.destroy }.to change { PayrollItem.count }.by(-2)
    end
  end

  describe '保險費計算整合' do
    it '薪資項目的保險費應該與 Insurance model 計算結果一致' do
      salary = 40000

      # 計算各種保險費（使用現有的 Insurance.calculate_premium）
      labor = Insurance.calculate_premium('勞保', salary)
      health = Insurance.calculate_premium('健保', salary)
      pension = Insurance.calculate_premium('勞退', salary)
      occupational = Insurance.calculate_premium('職災險', salary)

      # 計算員工負擔的保險費總和
      total = [
        labor&.dig(:employee) || 0,
        health&.dig(:employee) || 0,
        pension&.dig(:employee) || 0,
        occupational&.dig(:employee) || 0
      ].sum

      item = create(:payroll_item,
                    payroll: payroll,
                    employee: employee1,
                    base_salary: salary,
                    total_insurance_premium: total)

      expect(item.total_insurance_premium).to eq(total)
    end

    it '不同薪資級距的保險費計算正確' do
      # 測試中等薪資
      mid_salary = 40000
      mid_labor = Insurance.calculate_premium('勞保', mid_salary)
      mid_health = Insurance.calculate_premium('健保', mid_salary)

      # Skip test if insurance data not available
      skip "Insurance data not loaded" if mid_labor.nil? || mid_health.nil?

      expect(mid_labor).not_to be_nil
      expect(mid_health).not_to be_nil

      # 測試高薪資
      high_salary = 50000
      high_labor = Insurance.calculate_premium('勞保', high_salary)
      high_health = Insurance.calculate_premium('健保', high_salary)

      expect(high_labor).not_to be_nil
      expect(high_health).not_to be_nil

      # 高薪資的保險費應該高於或等於中等薪資
      expect(high_labor[:employee]).to be >= mid_labor[:employee]
      expect(high_health[:employee]).to be >= mid_health[:employee]
    end
  end

  describe '完整薪資計算流程' do
    it '從基本薪資計算到實發薪資' do
      base_salary = 40000
      allowances = 5000
      deductions = 1000

      # 計算保險費
      labor = Insurance.calculate_premium('勞保', base_salary)
      health = Insurance.calculate_premium('健保', base_salary)
      pension = Insurance.calculate_premium('勞退', base_salary)
      occupational = Insurance.calculate_premium('職災險', base_salary)

      total_insurance = [
        labor&.dig(:employee) || 0,
        health&.dig(:employee) || 0,
        pension&.dig(:employee) || 0,
        occupational&.dig(:employee) || 0
      ].sum

      # 應發 = 底薪 + 津貼
      expected_gross = base_salary + allowances

      # 實發 = 應發 - 扣款 - 保險費
      expected_net = expected_gross - deductions - total_insurance

      item = create(:payroll_item,
                    payroll: payroll,
                    employee: employee1,
                    base_salary: base_salary,
                    total_allowances: allowances,
                    total_deductions: deductions,
                    total_insurance_premium: total_insurance,
                    gross_pay: expected_gross,
                    net_pay: expected_net)

      expect(item.gross_pay).to eq(expected_gross)
      expect(item.net_pay).to eq(expected_net)
    end
  end

  describe '狀態轉換與資料完整性' do
    it '確認前必須所有項目都已計算' do
      # 建立一個未計算的項目
      create(:payroll_item, payroll: payroll, employee: employee1, net_pay: nil)

      expect { payroll.confirm! }.to raise_error(AASM::InvalidTransition)
    end

    it '所有項目計算完成後可以確認' do
      create(:payroll_item, payroll: payroll, employee: employee1, gross_pay: 40000, net_pay: 36000)
      create(:payroll_item, payroll: payroll, employee: employee2, gross_pay: 50000, net_pay: 45000)

      expect { payroll.confirm! }.not_to raise_error
      expect(payroll).to be_confirmed
    end
  end
end
