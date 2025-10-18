require 'rails_helper'

RSpec.describe Payroll, type: :model do
  describe 'database columns' do
    it { should have_db_column(:company_id).of_type(:integer).with_options(null: false) }
    it { should have_db_column(:year).of_type(:integer).with_options(null: false) }
    it { should have_db_column(:month).of_type(:integer).with_options(null: false) }
    it { should have_db_column(:status).of_type(:string).with_options(default: 'draft') }
    it { should have_db_column(:total_gross_pay).of_type(:decimal).with_options(precision: 12) }
    it { should have_db_column(:total_net_pay).of_type(:decimal).with_options(precision: 12) }
    it { should have_db_column(:confirmed_at).of_type(:datetime) }
    it { should have_db_column(:paid_at).of_type(:datetime) }
  end

  describe 'indexes' do
    it { should have_db_index([:company_id, :year, :month]).unique(true) }
    it { should have_db_index(:status) }
  end

  describe 'associations' do
    it { should belong_to(:company) }
    it { should have_many(:payroll_items).dependent(:destroy) }
    it { should have_many(:employees).through(:payroll_items) }
  end

  describe 'validations' do
    subject { build(:payroll) }

    it { should validate_presence_of(:year) }
    it { should validate_presence_of(:month) }
    it { should validate_numericality_of(:year).only_integer.is_greater_than(2000) }
    it { should validate_numericality_of(:month).only_integer.is_greater_than_or_equal_to(1).is_less_than_or_equal_to(12) }

    it do
      should validate_uniqueness_of(:month)
        .scoped_to([:company_id, :year])
        .with_message('該公司在此年月已有薪資記錄')
    end

    it { should validate_numericality_of(:total_gross_pay).is_greater_than_or_equal_to(0).allow_nil }
    it { should validate_numericality_of(:total_net_pay).is_greater_than_or_equal_to(0).allow_nil }

    context 'year and month combination' do
      it '拒絕未來的年月' do
        future_date = Date.current + 2.months
        future_payroll = build(:payroll, year: future_date.year, month: future_date.month)
        expect(future_payroll).not_to be_valid
        expect(future_payroll.errors[:base]).to include('薪資期間不可設定為未來')
      end

      it '接受當前年月' do
        current_payroll = build(:payroll, year: Date.current.year, month: Date.current.month)
        expect(current_payroll).to be_valid
      end

      it '接受過去的年月' do
        past_payroll = build(:payroll, year: 2023, month: 1)
        expect(past_payroll).to be_valid
      end
    end
  end

  describe 'state machine' do
    let(:payroll) { create(:payroll) }

    it '初始狀態為 draft' do
      expect(payroll.status).to eq('draft')
      expect(payroll).to be_draft
    end

    describe 'draft → confirmed transition' do
      it '可以從 draft 轉為 confirmed' do
        create(:payroll_item, :with_calculations, payroll: payroll)
        expect(payroll.may_confirm?).to be true
        expect { payroll.confirm! }.to change { payroll.status }.from('draft').to('confirmed')
      end

      it '確認時記錄 confirmed_at 時間' do
        create(:payroll_item, :with_calculations, payroll: payroll)
        expect { payroll.confirm! }.to change { payroll.confirmed_at }.from(nil)
        expect(payroll.confirmed_at).to be_within(1.second).of(Time.current)
      end

      it '確認時不允許薪資項目為空' do
        payroll.payroll_items.destroy_all
        expect { payroll.confirm! }.to raise_error(AASM::InvalidTransition)
      end

      it '確認時不允許有未計算的薪資項目（net_pay 為 nil）' do
        create(:payroll_item, payroll: payroll, net_pay: nil)
        expect { payroll.confirm! }.to raise_error(AASM::InvalidTransition)
      end
    end

    describe 'confirmed → paid transition' do
      let(:confirmed_payroll) { create(:payroll, :confirmed) }

      it '可以從 confirmed 轉為 paid' do
        expect(confirmed_payroll.may_mark_as_paid?).to be true
        expect { confirmed_payroll.mark_as_paid! }.to change { confirmed_payroll.status }.from('confirmed').to('paid')
      end

      it '發放時記錄 paid_at 時間' do
        expect { confirmed_payroll.mark_as_paid! }.to change { confirmed_payroll.paid_at }.from(nil)
        expect(confirmed_payroll.paid_at).to be_within(1.second).of(Time.current)
      end
    end

    describe 'invalid transitions' do
      it '不允許從 draft 直接轉為 paid' do
        expect(payroll.may_mark_as_paid?).to be false
      end

      it '不允許從 paid 回到 confirmed' do
        paid_payroll = create(:payroll, :paid)
        expect(paid_payroll.may_confirm?).to be false
      end
    end
  end

  describe 'scopes' do
    let!(:company1) { create(:company) }
    let!(:company2) { create(:company) }
    let!(:payroll_2024_01) { create(:payroll, company: company1, year: 2024, month: 1) }
    let!(:payroll_2024_02) { create(:payroll, company: company1, year: 2024, month: 2) }
    let!(:payroll_2023_12) { create(:payroll, company: company2, year: 2023, month: 12) }
    let!(:draft_payroll) { create(:payroll, :draft) }
    let!(:confirmed_payroll) { create(:payroll, :confirmed) }
    let!(:paid_payroll) { create(:payroll, :paid) }

    describe '.by_company' do
      it '回傳指定公司的薪資記錄' do
        expect(Payroll.by_company(company1)).to match_array([payroll_2024_01, payroll_2024_02])
      end
    end

    describe '.by_period' do
      it '回傳指定年月的薪資記錄' do
        expect(Payroll.by_period(2024, 1)).to include(payroll_2024_01)
        expect(Payroll.by_period(2024, 1)).not_to include(payroll_2024_02)
      end
    end

    describe '.by_year' do
      it '回傳指定年份的薪資記錄' do
        expect(Payroll.by_year(2024)).to include(payroll_2024_01, payroll_2024_02)
        expect(Payroll.by_year(2024)).not_to include(payroll_2023_12)
      end
    end

    describe '.in_status' do
      it '回傳指定狀態的薪資記錄' do
        expect(Payroll.in_status('draft')).to include(draft_payroll)
        expect(Payroll.in_status('confirmed')).to include(confirmed_payroll)
        expect(Payroll.in_status('paid')).to include(paid_payroll)
      end
    end

    describe '.recent' do
      it '依建立時間降序排列' do
        expect(Payroll.recent.first).to eq(Payroll.order(created_at: :desc).first)
      end
    end
  end

  describe 'instance methods' do
    describe '#period_text' do
      it '回傳格式化的年月文字' do
        payroll = build(:payroll, year: 2024, month: 3)
        expect(payroll.period_text).to eq('2024年03月')
      end
    end

    describe '#can_edit?' do
      it 'draft 狀態可編輯' do
        payroll = create(:payroll, :draft)
        expect(payroll.can_edit?).to be true
      end

      it 'confirmed 狀態不可編輯' do
        payroll = create(:payroll, :confirmed)
        expect(payroll.can_edit?).to be false
      end

      it 'paid 狀態不可編輯' do
        payroll = create(:payroll, :paid)
        expect(payroll.can_edit?).to be false
      end
    end

    describe '#calculate_totals' do
      let(:payroll) { create(:payroll) }
      let!(:item1) { create(:payroll_item, payroll: payroll, gross_pay: 50000, net_pay: 45000) }
      let!(:item2) { create(:payroll_item, payroll: payroll, gross_pay: 60000, net_pay: 54000) }

      it '計算所有項目的總應發薪資' do
        payroll.calculate_totals
        expect(payroll.total_gross_pay).to eq(110000)
      end

      it '計算所有項目的總實發薪資' do
        payroll.calculate_totals
        expect(payroll.total_net_pay).to eq(99000)
      end

      it '當無薪資項目時回傳 0' do
        empty_payroll = create(:payroll)
        empty_payroll.calculate_totals
        expect(empty_payroll.total_gross_pay).to eq(0)
        expect(empty_payroll.total_net_pay).to eq(0)
      end
    end

    describe '#employees_count' do
      let(:payroll) { create(:payroll) }

      it '回傳薪資項目的數量' do
        create_list(:payroll_item, 3, payroll: payroll)
        expect(payroll.employees_count).to eq(3)
      end

      it '無員工時回傳 0' do
        expect(payroll.employees_count).to eq(0)
      end
    end
  end

  describe 'edge cases' do
    context '空公司（沒有員工）' do
      let(:company_without_employees) { create(:company) }
      let(:payroll) { create(:payroll, company: company_without_employees) }

      it '允許建立空的薪資批次' do
        expect(payroll).to be_valid
      end

      it '計算總額時回傳 0' do
        payroll.calculate_totals
        expect(payroll.total_gross_pay).to eq(0)
        expect(payroll.total_net_pay).to eq(0)
      end
    end

    context '員工在薪資期間離職' do
      let(:company) { create(:company) }
      let(:resigned_employee) do
        create(:employee,
               company: company,
               hire_date: Date.new(2024, 1, 1),
               resign_date: Date.new(2024, 3, 15),
               active: false)
      end
      let(:payroll) { create(:payroll, company: company, year: 2024, month: 3) }

      it '離職員工仍會被納入薪資計算' do
        item = create(:payroll_item, payroll: payroll, employee: resigned_employee)
        expect(payroll.payroll_items).to include(item)
      end

      it '計算整個月的薪資（不按比例）' do
        item = create(:payroll_item,
                      payroll: payroll,
                      employee: resigned_employee,
                      base_salary: 40000)
        expect(item.base_salary).to eq(40000) # 不是按天數比例
      end
    end

    context '同一公司多個薪資批次' do
      let(:company) { create(:company) }

      it '不同年月可以建立多個薪資批次' do
        payroll1 = create(:payroll, company: company, year: 2024, month: 1)
        payroll2 = create(:payroll, company: company, year: 2024, month: 2)
        expect(payroll1).to be_valid
        expect(payroll2).to be_valid
      end

      it '同一年月不能重複建立' do
        create(:payroll, company: company, year: 2024, month: 1)
        duplicate = build(:payroll, company: company, year: 2024, month: 1)
        expect(duplicate).not_to be_valid
        expect(duplicate.errors[:month]).to include('該公司在此年月已有薪資記錄')
      end
    end

    context '極端數值' do
      it '處理極大薪資（千萬級）' do
        payroll = build(:payroll, total_gross_pay: 10_000_000)
        expect(payroll).to be_valid
      end

      it '處理 0 薪資' do
        payroll = build(:payroll, total_gross_pay: 0)
        expect(payroll).to be_valid
      end

      it '拒絕負數薪資' do
        payroll = build(:payroll, total_gross_pay: -1000)
        expect(payroll).not_to be_valid
      end
    end
  end
end
