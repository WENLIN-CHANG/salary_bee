require 'rails_helper'

RSpec.describe Employee, type: :model do
  describe 'associations' do
    it { should belong_to(:company) }
  end

  describe 'validations' do
    subject { build(:employee) }

    # Presence validations
    it { should validate_presence_of(:name) }
    it { should validate_presence_of(:hire_date) }
    it { should validate_presence_of(:base_salary) }
    # employee_id is auto-generated, so we don't test for presence validation

    # Auto-generation tests
    describe 'employee_id auto-generation' do
      it 'automatically generates employee_id on create' do
        company = create(:company)
        employee = company.employees.create(
          name: '測試員工',
          hire_date: Date.current,
          base_salary: 40000
        )

        expect(employee.employee_id).to be_present
        expect(employee.employee_id).to match(/\AEMP\d{8}\z/)
      end

      it 'generates employee_id with current year' do
        company = create(:company)
        employee = create(:employee, company: company)

        year = Date.current.year
        expect(employee.employee_id).to start_with("EMP#{year}")
      end

      it 'increments employee_id for same company and year' do
        company = create(:company)
        employee1 = create(:employee, company: company)
        employee2 = create(:employee, company: company)

        # Extract the numeric part after "EMP" and year
        number1 = employee1.employee_id[7..].to_i
        number2 = employee2.employee_id[7..].to_i

        expect(number2).to eq(number1 + 1)
      end

      it 'does not override existing employee_id if provided' do
        company = create(:company)
        employee = company.employees.create(
          employee_id: 'CUSTOM001',
          name: '測試員工',
          hire_date: Date.current,
          base_salary: 40000
        )

        expect(employee.employee_id).to eq('CUSTOM001')
      end
    end

    # Numericality validation
    it { should validate_numericality_of(:base_salary).is_greater_than(0) }

    it 'rejects negative base_salary' do
      employee = build(:employee, base_salary: -1000)
      expect(employee).not_to be_valid
      expect(employee.errors[:base_salary]).to be_present
    end

    it 'rejects zero base_salary' do
      employee = build(:employee, base_salary: 0)
      expect(employee).not_to be_valid
      expect(employee.errors[:base_salary]).to be_present
    end

    # Taiwan ID number format validation
    describe 'id_number validation' do
      it 'accepts valid Taiwan ID format (1 letter + 9 digits)' do
        employee = build(:employee, id_number: 'A123456789')
        expect(employee).to be_valid
      end

      it 'rejects id_number without letter prefix' do
        employee = build(:employee, id_number: '1234567890')
        expect(employee).not_to be_valid
        expect(employee.errors[:id_number]).to include('格式錯誤（應為 1 個英文字母 + 9 個數字）')
      end

      it 'rejects id_number with lowercase letter' do
        employee = build(:employee, id_number: 'a123456789')
        expect(employee).not_to be_valid
        expect(employee.errors[:id_number]).to include('格式錯誤（應為 1 個英文字母 + 9 個數字）')
      end

      it 'rejects id_number with too few digits' do
        employee = build(:employee, id_number: 'A12345678')
        expect(employee).not_to be_valid
      end

      it 'rejects id_number with too many digits' do
        employee = build(:employee, id_number: 'A1234567890')
        expect(employee).not_to be_valid
      end

      it 'allows nil id_number (optional field)' do
        employee = build(:employee, id_number: nil)
        expect(employee).to be_valid
      end

      it 'allows blank id_number' do
        employee = build(:employee, id_number: '')
        expect(employee).to be_valid
      end
    end

    # Email format validation
    describe 'email validation' do
      it 'accepts valid email format' do
        employee = build(:employee, email: 'test@example.com')
        expect(employee).to be_valid
      end

      it 'rejects invalid email format' do
        employee = build(:employee, email: 'invalid_email')
        expect(employee).not_to be_valid
        expect(employee.errors[:email]).to be_present
      end

      it 'allows nil email' do
        employee = build(:employee, email: nil)
        expect(employee).to be_valid
      end
    end

    # Date validations
    describe 'hire_date validation' do
      it 'rejects hire_date in the future' do
        employee = build(:employee, hire_date: 1.day.from_now)
        expect(employee).not_to be_valid
        expect(employee.errors[:hire_date]).to include('不能是未來日期')
      end

      it 'accepts hire_date today' do
        employee = build(:employee, hire_date: Date.current)
        expect(employee).to be_valid
      end

      it 'accepts hire_date in the past' do
        employee = build(:employee, hire_date: 1.year.ago)
        expect(employee).to be_valid
      end
    end

    describe 'resign_date validation' do
      it 'rejects resign_date before hire_date' do
        employee = build(:employee, hire_date: Date.current, resign_date: 1.day.ago)
        expect(employee).not_to be_valid
        expect(employee.errors[:resign_date]).to include('不能早於到職日期')
      end

      it 'accepts resign_date after hire_date' do
        employee = build(:employee, hire_date: 1.year.ago, resign_date: Date.current)
        expect(employee).to be_valid
      end

      it 'accepts resign_date same as hire_date' do
        employee = build(:employee, hire_date: Date.current, resign_date: Date.current)
        expect(employee).to be_valid
      end

      it 'allows nil resign_date for active employees' do
        employee = build(:employee, resign_date: nil, active: true)
        expect(employee).to be_valid
      end
    end
  end

  describe 'scopes' do
    let(:company) { create(:company) }

    describe '.active' do
      it 'returns only active employees' do
        active_employee = create(:employee, :active, company: company)
        resigned_employee = create(:employee, :resigned, company: company)

        expect(Employee.active).to include(active_employee)
        expect(Employee.active).not_to include(resigned_employee)
      end
    end

    describe '.by_department' do
      it 'filters employees by department' do
        engineering = create(:employee, company: company, department: '工程部')
        sales = create(:employee, company: company, department: '業務部')

        result = Employee.by_department('工程部')

        expect(result).to include(engineering)
        expect(result).not_to include(sales)
      end
    end
  end

  describe 'instance methods' do
    describe '#total_allowances' do
      it 'sums all allowance values' do
        employee = create(:employee, :with_allowances)

        # From factory: 交通津貼 2000 + 伙食津貼 3000 + 職務加給 5000 = 10000
        expect(employee.total_allowances).to eq(10000)
      end

      it 'returns 0 when allowances is empty' do
        employee = create(:employee, allowances: {})
        expect(employee.total_allowances).to eq(0)
      end

      it 'returns 0 when allowances is nil' do
        employee = create(:employee, allowances: nil)
        expect(employee.total_allowances).to eq(0)
      end
    end

    describe '#total_deductions' do
      it 'sums all deduction values' do
        employee = create(:employee, :with_deductions)

        # From factory: 勞保費 1000 + 健保費 800 + 所得稅 1500 = 3300
        expect(employee.total_deductions).to eq(3300)
      end

      it 'returns 0 when deductions is empty' do
        employee = create(:employee, deductions: {})
        expect(employee.total_deductions).to eq(0)
      end

      it 'returns 0 when deductions is nil' do
        employee = create(:employee, deductions: nil)
        expect(employee.total_deductions).to eq(0)
      end
    end

    describe '#gross_salary' do
      it 'calculates gross salary correctly (base_salary + total_allowances)' do
        employee = create(:employee, base_salary: 40000, allowances: { "交通津貼" => 2000 })

        expect(employee.gross_salary).to eq(42000)
      end

      it 'equals base_salary when no allowances' do
        employee = create(:employee, base_salary: 40000, allowances: {})

        expect(employee.gross_salary).to eq(40000)
      end

      it 'handles employee with full salary structure' do
        employee = create(:employee, :with_full_salary_structure, base_salary: 50000)

        # base_salary 50000 + total_allowances 10000 = 60000
        expect(employee.gross_salary).to eq(60000)
      end
    end

    describe '#full_name_with_id' do
      it 'returns formatted string with name and employee_id' do
        employee = create(:employee, name: '張三', employee_id: 'EMP0001')

        expect(employee.full_name_with_id).to eq('張三 (EMP0001)')
      end
    end
  end

  describe 'edge cases' do
    it 'handles very large base_salary' do
      employee = build(:employee, base_salary: 999999999.99)
      expect(employee).to be_valid
    end

    it 'handles complex allowances structure' do
      complex_allowances = {
        "交通津貼" => 2000,
        "伙食津貼" => 3000,
        "職務加給" => 5000,
        "加班費" => 10000,
        "績效獎金" => 15000
      }

      employee = create(:employee, allowances: complex_allowances)

      expect(employee.total_allowances).to eq(35000)
      expect(employee.gross_salary).to eq(employee.base_salary + 35000)
    end

    it 'handles employee hired and resigned on same day' do
      employee = build(:employee, hire_date: Date.current, resign_date: Date.current)
      expect(employee).to be_valid
    end
  end
end
