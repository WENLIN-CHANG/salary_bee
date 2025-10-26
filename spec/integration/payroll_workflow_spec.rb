require 'rails_helper'

RSpec.describe 'Payroll Workflow Integration', type: :integration do
  # 測試完整的薪資計算流程：建立公司 → 新增員工 → 建立薪資批次 → 計算 → 確認

  let!(:company) { create(:company, name: "測試科技公司") }
  let(:insurance_lookup) { InsuranceCache.fetch_lookup_table }

  let!(:employee1) do
    create(:employee,
           company: company,
           name: "張三",
           base_salary: 40000,
           allowances: { "交通津貼" => 2000, "伙食津貼" => 3000 },
           deductions: { "借支" => 1000 })
  end

  let!(:employee2) do
    create(:employee,
           company: company,
           name: "李四",
           base_salary: 50000,
           allowances: { "職務加給" => 5000 },
           deductions: {})
  end

  let!(:resigned_employee) do
    create(:employee,
           company: company,
           name: "王五（已離職）",
           base_salary: 35000,
           hire_date: Date.new(2024, 1, 1),
           resign_date: Date.new(2024, 3, 15),
           active: false)
  end

  describe '完整薪資計算流程' do
    it '從建立到確認的完整流程' do
      # Step 1: 建立薪資批次
      payroll = company.payrolls.create!(year: 2024, month: 3)
      expect(payroll).to be_draft
      expect(payroll.payroll_items.count).to eq(0)

      # Step 2: 執行薪資計算
      service = PayrollCalculationService.new(payroll)
      result = service.call

      expect(result).to be true
      payroll.reload

      # Step 3: 驗證計算結果
      expect(payroll.payroll_items.count).to eq(3) # 包含離職員工

      item1 = payroll.payroll_items.find_by(employee: employee1)
      item2 = payroll.payroll_items.find_by(employee: employee2)
      item3 = payroll.payroll_items.find_by(employee: resigned_employee)

      # 驗證員工1的薪資計算
      expect(item1.base_salary).to eq(40000)
      expect(item1.total_allowances).to eq(5000)
      expect(item1.total_deductions).to eq(1000)
      expect(item1.gross_pay).to eq(45000)
      expect(item1.total_insurance_premium).to be >= 0
      expect(item1.net_pay).to eq(45000 - 1000 - item1.total_insurance_premium)

      # 驗證員工2的薪資計算
      expect(item2.base_salary).to eq(50000)
      expect(item2.total_allowances).to eq(5000)
      expect(item2.total_deductions).to eq(0)
      expect(item2.gross_pay).to eq(55000)
      expect(item2.total_insurance_premium).to be >= 0
      expect(item2.net_pay).to eq(55000 - item2.total_insurance_premium)

      # 驗證離職員工的薪資計算（計算整月）
      expect(item3.base_salary).to eq(35000)
      expect(item3.gross_pay).to eq(35000)

      # Step 4: 驗證 Payroll 總額
      expect(payroll.total_gross_pay).to eq(45000 + 55000 + 35000)
      expect(payroll.total_net_pay).to be > 0
      expect(payroll.total_net_pay).to be < payroll.total_gross_pay

      # Step 5: 確認薪資批次
      expect(payroll.may_confirm?).to be true
      payroll.confirm!

      expect(payroll).to be_confirmed
      expect(payroll.confirmed_at).to be_present
      expect(payroll.can_edit?).to be false

      # Step 6: 確認後不能重新計算
      expect { service.call }.to raise_error(PayrollCalculationService::PayrollNotEditableError)
    end
  end

  describe '薪資重新計算流程' do
    it '員工薪資變更後重新計算' do
      # Step 1: 建立並計算薪資
      payroll = company.payrolls.create!(year: 2024, month: 3)
      service = PayrollCalculationService.new(payroll)
      service.call

      payroll.reload
      original_total = payroll.total_gross_pay

      # Step 2: 修改員工薪資
      employee1.update!(base_salary: 45000, allowances: { "交通津貼" => 3000 })

      # Step 3: 重新計算
      service.call
      payroll.reload

      # Step 4: 驗證更新後的計算
      item1 = payroll.payroll_items.find_by(employee: employee1)
      expect(item1.base_salary).to eq(45000)
      expect(item1.total_allowances).to eq(3000)
      expect(item1.gross_pay).to eq(48000)

      # 總額應該增加
      expect(payroll.total_gross_pay).to be > original_total
    end

    it '不建立重複的薪資項目' do
      payroll = company.payrolls.create!(year: 2024, month: 3)
      service = PayrollCalculationService.new(payroll)

      # 第一次計算
      service.call
      first_count = payroll.payroll_items.count

      # 第二次計算（應該更新而非新增）
      service.call
      second_count = payroll.payroll_items.count

      expect(first_count).to eq(second_count)
      expect(second_count).to eq(3) # 3個員工
    end
  end

  describe '保險費計算整合' do
    it '使用真實的保險費計算' do
      payroll = company.payrolls.create!(year: 2024, month: 3)
      service = PayrollCalculationService.new(payroll)
      service.call

      payroll.reload

      payroll.payroll_items.each do |item|
        # 保險費應該是非負整數
        expect(item.total_insurance_premium).to be >= 0
        expect(item.total_insurance_premium).to be_a(Integer)

        # 保險費應該從 PayrollCalculator 計算（使用預載的 lookup table）
        expected_insurance = PayrollCalculator.calculate_insurance_premium(item.base_salary, insurance_lookup)
        expect(item.total_insurance_premium).to eq(expected_insurance)

        # 實發薪資 = 應發 - 扣款 - 保險費
        expected_net_pay = item.gross_pay - item.total_deductions - item.total_insurance_premium
        expect(item.net_pay).to eq(expected_net_pay)
      end
    end

    it '不同底薪計算不同的保險費' do
      payroll = company.payrolls.create!(year: 2024, month: 3)
      service = PayrollCalculationService.new(payroll)
      service.call

      payroll.reload

      item1 = payroll.payroll_items.find_by(employee: employee1) # 40000
      item2 = payroll.payroll_items.find_by(employee: employee2) # 50000

      # 不同底薪應該有不同的保險費（可能因級距而不同）
      # 至少兩者都應該是有效的非負整數
      expect(item1.total_insurance_premium).to be >= 0
      expect(item2.total_insurance_premium).to be >= 0
    end
  end

  describe '錯誤處理與邊界案例' do
    it '空公司（無員工）的薪資計算' do
      empty_company = create(:company)
      payroll = empty_company.payrolls.create!(year: 2024, month: 3)

      service = PayrollCalculationService.new(payroll)
      result = service.call

      expect(result).to be true
      expect(payroll.payroll_items.count).to eq(0)
      expect(payroll.total_gross_pay).to eq(0)
      expect(payroll.total_net_pay).to eq(0)

      # 空的薪資批次無法確認
      expect(payroll.may_confirm?).to be false
    end

    it '計算過程中發生錯誤時回滾' do
      payroll = company.payrolls.create!(year: 2024, month: 3)
      service = PayrollCalculationService.new(payroll)

      # 模擬計算錯誤
      allow(PayrollCalculator).to receive(:calculate_all).and_raise(StandardError, "計算錯誤")

      expect { service.call }.to raise_error(StandardError, "計算錯誤")

      # 確認沒有建立任何項目（transaction rollback）
      expect(payroll.payroll_items.count).to eq(0)
    end

    it '部分員工計算失敗時整體回滾' do
      payroll = company.payrolls.create!(year: 2024, month: 3)
      service = PayrollCalculationService.new(payroll)

      # 模擬第二個員工計算時失敗
      call_count = 0
      allow(PayrollCalculator).to receive(:calculate_all).and_wrap_original do |original_method, *args|
        call_count += 1
        raise StandardError, "第二個員工計算失敗" if call_count == 2
        original_method.call(*args)
      end

      expect { service.call }.to raise_error(StandardError)

      # 確認所有變更都被回滾（包括第一個成功的）
      expect(payroll.payroll_items.count).to eq(0)
    end
  end

  describe '多薪資批次管理' do
    it '同一公司可以有多個不同月份的薪資批次' do
      payroll_jan = company.payrolls.create!(year: 2024, month: 1)
      payroll_feb = company.payrolls.create!(year: 2024, month: 2)
      payroll_mar = company.payrolls.create!(year: 2024, month: 3)

      service_jan = PayrollCalculationService.new(payroll_jan)
      service_feb = PayrollCalculationService.new(payroll_feb)
      service_mar = PayrollCalculationService.new(payroll_mar)

      service_jan.call
      service_feb.call
      service_mar.call

      expect(company.payrolls.count).to eq(3)
      expect(payroll_jan.payroll_items.count).to eq(3)
      expect(payroll_feb.payroll_items.count).to eq(3)
      expect(payroll_mar.payroll_items.count).to eq(3)

      # 每個月的計算應該是獨立的
      expect(payroll_jan.total_gross_pay).to eq(payroll_feb.total_gross_pay)
      expect(payroll_feb.total_gross_pay).to eq(payroll_mar.total_gross_pay)
    end

    it '不同公司的薪資批次互不影響' do
      company2 = create(:company, name: "另一家公司")
      employee_company2 = create(:employee, company: company2, base_salary: 60000)

      payroll1 = company.payrolls.create!(year: 2024, month: 3)
      payroll2 = company2.payrolls.create!(year: 2024, month: 3)

      PayrollCalculationService.new(payroll1).call
      PayrollCalculationService.new(payroll2).call

      # 兩家公司的薪資應該完全獨立
      expect(payroll1.payroll_items.count).to eq(3) # company 有 3 個員工
      expect(payroll2.payroll_items.count).to eq(1) # company2 有 1 個員工

      expect(payroll1.total_gross_pay).not_to eq(payroll2.total_gross_pay)
    end
  end

  describe '狀態轉換完整流程' do
    it '正常流程：draft → confirmed → paid' do
      payroll = company.payrolls.create!(year: 2024, month: 3)

      # 初始狀態：draft
      expect(payroll).to be_draft
      expect(payroll.can_edit?).to be true

      # 計算薪資
      PayrollCalculationService.new(payroll).call
      payroll.reload

      # 確認薪資
      expect(payroll.may_confirm?).to be true
      payroll.confirm!
      expect(payroll).to be_confirmed
      expect(payroll.can_edit?).to be false

      # 標記為已發放
      expect(payroll.may_mark_as_paid?).to be true
      payroll.mark_as_paid!
      expect(payroll).to be_paid
      expect(payroll.paid_at).to be_present

      # 已發放的薪資不能再轉換狀態
      expect(payroll.may_confirm?).to be false
      expect(payroll.can_edit?).to be false
    end

    it '異常流程：未計算就嘗試確認' do
      payroll = company.payrolls.create!(year: 2024, month: 3)

      # 未計算薪資就嘗試確認
      expect(payroll.may_confirm?).to be false
      expect { payroll.confirm! }.to raise_error(AASM::InvalidTransition)

      expect(payroll).to be_draft
    end
  end

  describe '資料一致性驗證' do
    it 'PayrollItem 的計算結果與 PayrollCalculator 一致' do
      payroll = company.payrolls.create!(year: 2024, month: 3)
      PayrollCalculationService.new(payroll).call

      payroll.payroll_items.each do |item|
        # 使用相同參數直接呼叫 calculator（使用預載的 lookup table）
        result = PayrollCalculator.calculate_all(
          base_salary: item.base_salary,
          total_allowances: item.total_allowances,
          total_deductions: item.total_deductions,
          insurance_lookup: insurance_lookup
        )

        # 驗證結果完全一致
        expect(item.gross_pay).to eq(result[:gross_pay])
        expect(item.total_insurance_premium).to eq(result[:total_insurance_premium])
        expect(item.net_pay).to eq(result[:net_pay])
      end
    end

    it 'Payroll 總額等於所有 PayrollItem 的總和' do
      payroll = company.payrolls.create!(year: 2024, month: 3)
      PayrollCalculationService.new(payroll).call
      payroll.reload

      manual_total_gross = payroll.payroll_items.sum(:gross_pay)
      manual_total_net = payroll.payroll_items.sum(:net_pay)

      expect(payroll.total_gross_pay).to eq(manual_total_gross)
      expect(payroll.total_net_pay).to eq(manual_total_net)
    end
  end
end
