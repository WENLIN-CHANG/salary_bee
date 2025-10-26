require 'rails_helper'

RSpec.describe PayrollCalculationService do
  let(:company) { create(:company) }
  let(:payroll) { create(:payroll, company: company, year: 2024, month: 3) }

  describe '#call' do
    context '有在職員工的公司' do
      let!(:employee1) do
        create(:employee,
               company: company,
               base_salary: 40000,
               allowances: { "交通津貼" => 2000, "伙食津貼" => 3000 },
               deductions: { "借支" => 1000 })
      end
      let!(:employee2) do
        create(:employee,
               company: company,
               base_salary: 50000,
               allowances: { "職務加給" => 5000 },
               deductions: {})
      end

      it '成功執行回傳 true' do
        service = PayrollCalculationService.new(payroll)
        expect(service.call).to be true
      end

      it '為所有在職員工建立薪資項目' do
        service = PayrollCalculationService.new(payroll)

        expect { service.call }.to change { payroll.payroll_items.count }.from(0).to(2)
      end

      it '正確計算每個員工的薪資' do
        service = PayrollCalculationService.new(payroll)
        service.call

        item1 = payroll.payroll_items.find_by(employee: employee1)
        item2 = payroll.payroll_items.find_by(employee: employee2)

        # 員工1：底薪 40000 + 津貼 5000 = 應發 45000
        expect(item1.base_salary).to eq(40000)
        expect(item1.total_allowances).to eq(5000)
        expect(item1.gross_pay).to eq(45000)

        # 員工2：底薪 50000 + 津貼 5000 = 應發 55000
        expect(item2.base_salary).to eq(50000)
        expect(item2.total_allowances).to eq(5000)
        expect(item2.gross_pay).to eq(55000)
      end

      it '正確計算保險費' do
        service = PayrollCalculationService.new(payroll)
        service.call

        item1 = payroll.payroll_items.find_by(employee: employee1)

        # 保險費應該是非負整數
        expect(item1.total_insurance_premium).to be >= 0
        expect(item1.total_insurance_premium).to be_a(Integer)
      end

      it '正確計算總扣款和實發薪資' do
        service = PayrollCalculationService.new(payroll)
        service.call

        item1 = payroll.payroll_items.find_by(employee: employee1)

        # 總扣款 = 其他扣款 + 保險費
        expected_total_deductions = 1000 + item1.total_insurance_premium

        # 實發 = 應發 - 總扣款
        expected_net_pay = 45000 - expected_total_deductions

        expect(item1.total_deductions).to eq(1000)
        expect(item1.net_pay).to eq(expected_net_pay)
      end

      it '更新 Payroll 的總額' do
        service = PayrollCalculationService.new(payroll)
        service.call

        payroll.reload

        # 總應發和總實發應該被更新
        expect(payroll.total_gross_pay).to be > 0
        expect(payroll.total_net_pay).to be > 0
        expect(payroll.total_net_pay).to be < payroll.total_gross_pay
      end

      it '保持在 draft 狀態' do
        service = PayrollCalculationService.new(payroll)
        service.call

        expect(payroll.reload).to be_draft
      end
    end

    context '重新計算' do
      let!(:employee) { create(:employee, company: company, base_salary: 40000) }
      let!(:existing_item) do
        create(:payroll_item,
               payroll: payroll,
               employee: employee,
               base_salary: 35000, # 舊的底薪
               gross_pay: 35000,
               net_pay: 30000)
      end

      it '更新現有的薪資項目而非建立新的' do
        service = PayrollCalculationService.new(payroll)

        expect { service.call }.not_to change { payroll.payroll_items.count }
      end

      it '使用員工最新的薪資資料重新計算' do
        service = PayrollCalculationService.new(payroll)
        service.call

        existing_item.reload

        # 應該使用員工當前的 base_salary (40000) 而非舊值 (35000)
        expect(existing_item.base_salary).to eq(40000)
        expect(existing_item.gross_pay).to eq(40000)
      end

      it '重新計算所有金額' do
        service = PayrollCalculationService.new(payroll)
        service.call

        existing_item.reload

        # 所有計算欄位都應該被更新
        expect(existing_item.gross_pay).not_to eq(35000)
        expect(existing_item.net_pay).not_to eq(30000)
      end
    end

    context '空公司（無員工）' do
      it '成功執行但不建立任何項目' do
        service = PayrollCalculationService.new(payroll)

        expect { service.call }.not_to change { payroll.payroll_items.count }
        expect(service.call).to be true
      end

      it '設定總額為 0' do
        service = PayrollCalculationService.new(payroll)
        service.call

        payroll.reload
        expect(payroll.total_gross_pay).to eq(0)
        expect(payroll.total_net_pay).to eq(0)
      end
    end

    context '包含離職員工' do
      let!(:active_employee) { create(:employee, company: company, base_salary: 40000, active: true) }
      let!(:resigned_employee) do
        create(:employee,
               company: company,
               base_salary: 50000,
               hire_date: Date.new(2024, 1, 1),
               resign_date: Date.new(2024, 3, 15),
               active: false)
      end

      it '仍然為離職員工計算薪資（計算整月）' do
        service = PayrollCalculationService.new(payroll)
        service.call

        # 應該為兩個員工都建立項目
        expect(payroll.payroll_items.count).to eq(2)

        resigned_item = payroll.payroll_items.find_by(employee: resigned_employee)
        expect(resigned_item).to be_present
        expect(resigned_item.base_salary).to eq(50000) # 計算整月，不按比例
      end
    end

    context '已確認的 Payroll' do
      let(:confirmed_payroll) { create(:payroll, :confirmed, company: company) }
      let!(:employee) { create(:employee, company: company, base_salary: 40000) }

      it '拋出錯誤不允許計算' do
        service = PayrollCalculationService.new(confirmed_payroll)

        expect { service.call }.to raise_error(PayrollCalculationService::PayrollNotEditableError)
      end
    end

    context '錯誤處理' do
      let!(:employee) { create(:employee, company: company, base_salary: 40000) }

      it '發生錯誤時回滾所有變更' do
        service = PayrollCalculationService.new(payroll)

        # 模擬計算過程中發生錯誤
        allow(PayrollCalculator).to receive(:calculate_all).and_raise(StandardError, "計算錯誤")

        expect { service.call }.to raise_error(StandardError, "計算錯誤")

        # 確認沒有建立任何項目
        expect(payroll.payroll_items.count).to eq(0)
      end
    end
  end

  describe '#calculate_all' do
    let!(:employee1) do
      create(:employee,
             company: company,
             base_salary: 40000,
             allowances: { "交通津貼" => 2000 },
             deductions: { "借支" => 500 })
    end
    let!(:employee2) do
      create(:employee,
             company: company,
             base_salary: 50000,
             allowances: {},
             deductions: {})
    end

    it '回傳所有員工的計算結果' do
      service = PayrollCalculationService.new(payroll)
      results = service.calculate_all

      expect(results).to be_an(Array)
      expect(results.size).to eq(2)
    end

    it '計算結果包含 employee 和 result' do
      service = PayrollCalculationService.new(payroll)
      results = service.calculate_all

      first_result = results.first
      expect(first_result).to have_key(:employee)
      expect(first_result).to have_key(:result)
      expect(first_result[:employee]).to be_a(Employee)
      expect(first_result[:result]).to be_a(Hash)
    end

    it '不寫入資料庫（純計算）' do
      service = PayrollCalculationService.new(payroll)

      expect { service.calculate_all }.not_to change { payroll.payroll_items.count }
    end

    it '計算結果包含正確的薪資數據' do
      service = PayrollCalculationService.new(payroll)
      results = service.calculate_all

      result1 = results.find { |r| r[:employee] == employee1 }[:result]

      expect(result1).to have_key(:gross_pay)
      expect(result1).to have_key(:total_insurance_premium)
      expect(result1).to have_key(:net_pay)
      expect(result1[:gross_pay]).to eq(42000) # 40000 + 2000
    end
  end

  describe '#persist!' do
    let!(:employee1) { create(:employee, company: company, base_salary: 40000) }
    let!(:employee2) { create(:employee, company: company, base_salary: 50000) }

    it '將計算結果寫入資料庫' do
      service = PayrollCalculationService.new(payroll)
      calculations = service.calculate_all

      expect { service.persist!(calculations) }.to change { payroll.payroll_items.count }.from(0).to(2)
    end

    it '回傳 true' do
      service = PayrollCalculationService.new(payroll)
      calculations = service.calculate_all

      expect(service.persist!(calculations)).to be true
    end

    it '正確存儲計算結果' do
      service = PayrollCalculationService.new(payroll)
      calculations = service.calculate_all

      service.persist!(calculations)

      item1 = payroll.payroll_items.find_by(employee: employee1)
      expect(item1.base_salary).to eq(40000)
      expect(item1.gross_pay).to eq(40000)
    end

    it '更新 Payroll 總額' do
      service = PayrollCalculationService.new(payroll)
      calculations = service.calculate_all

      service.persist!(calculations)

      payroll.reload
      expect(payroll.total_gross_pay).to be > 0
      expect(payroll.total_net_pay).to be > 0
    end

    it '在 transaction 中執行' do
      service = PayrollCalculationService.new(payroll)
      calculations = service.calculate_all

      # 模擬在持久化過程中發生錯誤
      allow(payroll).to receive(:calculate_totals).and_raise(StandardError, "計算總額失敗")

      expect { service.persist!(calculations) }.to raise_error(StandardError, "計算總額失敗")

      # 確認沒有建立任何項目（已回滾）
      expect(payroll.payroll_items.count).to eq(0)
    end
  end

  describe '#calculate_for_employee_pure' do
    let!(:employee) do
      create(:employee,
             company: company,
             base_salary: 40000,
             allowances: { "交通津貼" => 2000 },
             deductions: { "借支" => 500 })
    end

    it '回傳計算結果 hash' do
      service = PayrollCalculationService.new(payroll)
      result = service.calculate_for_employee_pure(employee)

      expect(result).to be_a(Hash)
      expect(result).to have_key(:gross_pay)
      expect(result).to have_key(:total_insurance_premium)
      expect(result).to have_key(:net_pay)
    end

    it '不寫入資料庫' do
      service = PayrollCalculationService.new(payroll)

      expect { service.calculate_for_employee_pure(employee) }.not_to change { payroll.payroll_items.count }
    end

    it '使用 PayrollCalculator 計算薪資' do
      service = PayrollCalculationService.new(payroll)

      expect(PayrollCalculator).to receive(:calculate_all).with(
        base_salary: 40000,
        total_allowances: 2000,
        total_deductions: 500,
        insurance_lookup: kind_of(Hash)
      ).and_call_original

      service.calculate_for_employee_pure(employee)
    end
  end

  describe '#calculate_for_employee' do
    let!(:employee) do
      create(:employee,
             company: company,
             base_salary: 40000,
             allowances: { "交通津貼" => 2000 },
             deductions: { "借支" => 500 })
    end

    it '為單一員工建立並計算薪資項目（向後相容）' do
      service = PayrollCalculationService.new(payroll)
      item = service.calculate_for_employee(employee)

      expect(item).to be_a(PayrollItem)
      expect(item.employee).to eq(employee)
      expect(item.payroll).to eq(payroll)
      expect(item.base_salary).to eq(40000)
      expect(item.total_allowances).to eq(2000)
      expect(item.total_deductions).to eq(500)
    end

    it '使用 PayrollCalculator 計算薪資' do
      service = PayrollCalculationService.new(payroll)

      expect(PayrollCalculator).to receive(:calculate_all).with(
        base_salary: 40000,
        total_allowances: 2000,
        total_deductions: 500,
        insurance_lookup: kind_of(Hash)
      ).and_call_original

      service.calculate_for_employee(employee)
    end
  end
end
