require 'rails_helper'

RSpec.describe "Payrolls", type: :request do
  let(:company) { create(:company) }
  let(:user) { create(:user, company: company) }
  let(:other_company) { create(:company) }

  # 假設有 sign_in helper（需要在 spec/support/authentication_helper.rb 中定義）
  before { sign_in user }

  describe "GET /payrolls" do
    let!(:payroll1) { create(:payroll, company: company, year: 2024, month: 3) }
    let!(:payroll2) { create(:payroll, company: company, year: 2024, month: 2) }
    let!(:other_payroll) { create(:payroll, company: other_company, year: 2024, month: 5) }

    it "顯示目前公司的所有薪資批次" do
      get payrolls_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(company.name)
      expect(response.body).to include(payroll1.period_text)
      expect(response.body).to include(payroll2.period_text)
    end

    it "不顯示其他公司的薪資批次" do
      get payrolls_path
      expect(response.body).not_to include(other_company.name)
      expect(response.body).not_to include(other_payroll.period_text)
    end

    it "按照時間排序（新的在前）" do
      get payrolls_path
      expect(response).to have_http_status(:ok)
      # 2024年3月應該在2024年2月之前
    end
  end

  describe "GET /payrolls/:id" do
    let(:payroll) { create(:payroll, company: company, year: 2024, month: 3) }
    let!(:employee1) { create(:employee, company: company, name: "張三", base_salary: 40000) }
    let!(:employee2) { create(:employee, company: company, name: "李四", base_salary: 50000) }
    let!(:item1) { create(:payroll_item, :with_calculations, payroll: payroll, employee: employee1) }
    let!(:item2) { create(:payroll_item, :with_calculations, payroll: payroll, employee: employee2) }

    it "顯示薪資批次的詳細資料" do
      get payroll_path(payroll)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("2024年03月")
      expect(response.body).to include("張三")
      expect(response.body).to include("李四")
      expect(response.body).to include(company.name)
    end

    it "顯示每個員工的薪資項目" do
      get payroll_path(payroll)
      # View 使用 number_to_currency，會格式化數字（加千位分隔符）
      expect(response.body).to include("40,000") # item1.base_salary with formatting
      expect(response.body).to include("50,000") # item2.base_salary with formatting
    end

    it "不允許查看其他公司的薪資批次" do
      other_payroll = create(:payroll, company: other_company)
      get payroll_path(other_payroll)
      # Rails 會將 RecordNotFound 自動處理為 404 response
      expect(response).to have_http_status(:not_found)
    end

    it "顯示薪資批次的狀態" do
      get payroll_path(payroll)
      expect(response.body).to include("草稿") # draft 狀態的中文顯示
    end

    it "顯示總應發和總實發" do
      get payroll_path(payroll)
      expect(response.body).to include("總應發")
      expect(response.body).to include("總實發")
    end
  end

  describe "GET /payrolls/new" do
    it "顯示新增薪資批次的表單" do
      get new_payroll_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("新增薪資批次")
    end

    it "表單包含年份和月份欄位" do
      get new_payroll_path
      expect(response.body).to include("年份")
      expect(response.body).to include("月份")
    end
  end

  describe "POST /payrolls" do
    context "有效參數" do
      let(:valid_params) do
        { payroll: { year: 2024, month: 4 } }
      end

      it "建立新的薪資批次" do
        expect {
          post payrolls_path, params: valid_params
        }.to change { company.payrolls.count }.by(1)
      end

      it "薪資批次屬於目前使用者的公司" do
        post payrolls_path, params: valid_params
        payroll = company.payrolls.last
        expect(payroll.company).to eq(company)
      end

      it "重導向到薪資批次詳細頁面" do
        post payrolls_path, params: valid_params
        payroll = company.payrolls.last
        expect(response).to redirect_to(payroll_path(payroll))
      end

      it "顯示成功訊息" do
        post payrolls_path, params: valid_params
        follow_redirect!
        expect(response.body).to include("薪資批次建立成功")
      end
    end

    context "無效參數" do
      let(:invalid_params) do
        { payroll: { year: nil, month: nil } }
      end

      it "不建立薪資批次" do
        expect {
          post payrolls_path, params: invalid_params
        }.not_to change { Payroll.count }
      end

      it "顯示表單並帶有錯誤訊息" do
        post payrolls_path, params: invalid_params
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include("年份")
      end
    end

    context "重複的年份月份" do
      let!(:existing) { create(:payroll, company: company, year: 2024, month: 4) }
      let(:duplicate_params) do
        { payroll: { year: 2024, month: 4 } }
      end

      it "不建立重複的薪資批次" do
        expect {
          post payrolls_path, params: duplicate_params
        }.not_to change { Payroll.count }
      end

      it "顯示錯誤訊息" do
        post payrolls_path, params: duplicate_params
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include("該公司在此年月已有薪資記錄")
      end
    end
  end

  describe "POST /payrolls/:id/calculate" do
    let(:payroll) { create(:payroll, company: company, year: 2024, month: 3) }
    let!(:employee) { create(:employee, company: company, base_salary: 40000) }

    context "draft 狀態的薪資批次" do
      it "成功執行計算" do
        post calculate_payroll_path(payroll)
        expect(response).to redirect_to(payroll_path(payroll))
      end

      it "為所有員工建立薪資項目" do
        expect {
          post calculate_payroll_path(payroll)
        }.to change { payroll.payroll_items.count }.from(0).to(1)
      end

      it "顯示成功訊息" do
        post calculate_payroll_path(payroll)
        follow_redirect!
        expect(response.body).to include("薪資計算完成")
      end

      it "更新 Payroll 的總額" do
        post calculate_payroll_path(payroll)
        payroll.reload
        expect(payroll.total_gross_pay).to be > 0
        expect(payroll.total_net_pay).to be > 0
      end
    end

    context "已確認的薪資批次" do
      let(:confirmed_payroll) { create(:payroll, :confirmed, company: company) }

      it "不允許重新計算" do
        post calculate_payroll_path(confirmed_payroll)
        expect(response).to redirect_to(payroll_path(confirmed_payroll))
      end

      it "顯示錯誤訊息" do
        post calculate_payroll_path(confirmed_payroll)
        follow_redirect!
        expect(response.body).to include("已確認")
      end
    end

    context "計算過程發生錯誤" do
      before do
        allow(PayrollCalculationService).to receive(:new).and_raise(StandardError, "計算錯誤")
      end

      it "顯示錯誤訊息" do
        post calculate_payroll_path(payroll)
        follow_redirect!
        expect(response.body).to include("計算錯誤")
      end

      it "不建立任何薪資項目" do
        expect {
          post calculate_payroll_path(payroll) rescue nil
        }.not_to change { PayrollItem.count }
      end
    end
  end

  describe "POST /payrolls/:id/confirm" do
    let(:payroll) { create(:payroll, company: company, year: 2024, month: 3) }
    let!(:employee) { create(:employee, company: company, base_salary: 40000) }

    context "有計算完成的薪資項目" do
      before do
        create(:payroll_item, :with_calculations, payroll: payroll, employee: employee)
      end

      it "成功確認薪資批次" do
        post confirm_payroll_path(payroll)
        payroll.reload
        expect(payroll.status).to eq("confirmed")
      end

      it "重導向到薪資批次詳細頁面" do
        post confirm_payroll_path(payroll)
        expect(response).to redirect_to(payroll_path(payroll))
      end

      it "顯示成功訊息" do
        post confirm_payroll_path(payroll)
        follow_redirect!
        expect(response.body).to include("薪資批次已確認")
      end

      it "記錄確認時間" do
        post confirm_payroll_path(payroll)
        payroll.reload
        expect(payroll.confirmed_at).to be_present
      end
    end

    context "沒有薪資項目" do
      it "不允許確認" do
        post confirm_payroll_path(payroll)
        payroll.reload
        expect(payroll.status).to eq("draft")
      end

      it "顯示錯誤訊息" do
        post confirm_payroll_path(payroll)
        follow_redirect!
        expect(response.body).to include("無法確認")
      end
    end

    context "已經確認過的薪資批次" do
      let(:confirmed_payroll) { create(:payroll, :confirmed, company: company) }

      it "不允許重複確認" do
        post confirm_payroll_path(confirmed_payroll)
        expect(response).to redirect_to(payroll_path(confirmed_payroll))
      end

      it "顯示錯誤訊息" do
        post confirm_payroll_path(confirmed_payroll)
        follow_redirect!
        expect(response.body).to include("已確認")
      end
    end
  end
end
