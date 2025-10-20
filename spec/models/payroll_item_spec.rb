require 'rails_helper'

RSpec.describe PayrollItem, type: :model do
  describe 'database columns' do
    it { should have_db_column(:payroll_id).of_type(:integer).with_options(null: false) }
    it { should have_db_column(:employee_id).of_type(:integer).with_options(null: false) }
    it { should have_db_column(:base_salary).of_type(:decimal).with_options(precision: 10, null: false) }
    it { should have_db_column(:total_allowances).of_type(:decimal).with_options(precision: 10, default: 0) }
    it { should have_db_column(:total_deductions).of_type(:decimal).with_options(precision: 10, default: 0) }
    it { should have_db_column(:total_insurance_premium).of_type(:decimal).with_options(precision: 10, default: 0) }
    it { should have_db_column(:gross_pay).of_type(:decimal).with_options(precision: 10) }
    it { should have_db_column(:net_pay).of_type(:decimal).with_options(precision: 10) }
  end

  describe 'indexes' do
    it { should have_db_index([ :payroll_id, :employee_id ]).unique(true) }
    it { should have_db_index(:employee_id) }
  end

  describe 'associations' do
    it { should belong_to(:payroll) }
    it { should belong_to(:employee) }
  end

  describe 'validations' do
    it { should validate_presence_of(:base_salary) }
    it { should validate_numericality_of(:base_salary).is_greater_than_or_equal_to(0) }

    it { should validate_numericality_of(:total_allowances).is_greater_than_or_equal_to(0) }
    it { should validate_numericality_of(:total_deductions).is_greater_than_or_equal_to(0) }
    it { should validate_numericality_of(:total_insurance_premium).is_greater_than_or_equal_to(0) }

    it { should validate_numericality_of(:gross_pay).is_greater_than_or_equal_to(0).allow_nil }
    it { should validate_numericality_of(:net_pay).is_greater_than_or_equal_to(0).allow_nil }

    context 'uniqueness' do
      subject { create(:payroll_item) }
      it do
        should validate_uniqueness_of(:employee_id)
          .scoped_to(:payroll_id)
          .with_message('該員工在此薪資批次中已存在')
      end
    end
  end

  describe 'edge cases' do
    it '處理極大薪資（千萬級）' do
      item = build(:payroll_item, base_salary: 10_000_000)
      expect(item).to be_valid
    end

    it '處理 0 薪資' do
      item = build(:payroll_item, base_salary: 0)
      expect(item).to be_valid
    end

    it '拒絕負數薪資' do
      item = build(:payroll_item, base_salary: -1000)
      expect(item).not_to be_valid
    end

    it '拒絕負數津貼' do
      item = build(:payroll_item, total_allowances: -100)
      expect(item).not_to be_valid
    end

    it '拒絕負數扣款' do
      item = build(:payroll_item, total_deductions: -100)
      expect(item).not_to be_valid
    end

    it '拒絕負數保險費' do
      item = build(:payroll_item, total_insurance_premium: -100)
      expect(item).not_to be_valid
    end

    it '拒絕負數應發薪資' do
      item = build(:payroll_item, gross_pay: -1000)
      expect(item).not_to be_valid
    end

    it '拒絕負數實發薪資' do
      item = build(:payroll_item, net_pay: -1000)
      expect(item).not_to be_valid
    end
  end
end
