require 'rails_helper'

RSpec.describe EmployeeExportService, type: :service do
  let(:company) { create(:company, name: "測試公司") }
  let!(:employee1) do
    create(:employee,
           company: company,
           employee_id: "EMP0001",
           name: "張三",
           id_number: "A123456789",
           email: "zhang@example.com",
           phone: "0912345678",
           birth_date: Date.parse("1990-01-01"),
           hire_date: Date.parse("2024-01-01"),
           department: "工程部",
           position: "工程師",
           base_salary: 40000,
           allowances: { "交通津貼" => 2000 },
           deductions: { "勞保費" => 1000 },
           active: true)
  end

  let!(:employee2) do
    create(:employee,
           company: company,
           employee_id: "EMP0002",
           name: "李四",
           hire_date: Date.parse("2024-01-01"),
           active: false,
           resign_date: Date.parse("2024-06-30"))
  end

  let(:employees) { company.employees }

  describe '#call with CSV format' do
    let(:service) { described_class.new(employees, :csv) }

    it 'generates valid CSV content' do
      csv_content = service.call

      expect(csv_content).to be_a(String)
      expect(csv_content).to include('公司名稱,員工編號,姓名')
    end

    it 'includes all CSV headers' do
      csv_content = service.call

      expected_headers = [
        '公司名稱', '員工編號', '姓名', '身分證字號', 'Email', '電話',
        '生日', '到職日期', '離職日期', '部門', '職位', '底薪',
        '津貼總額', '扣款總額', '毛薪', '狀態'
      ]

      csv_lines = CSV.parse(csv_content)
      headers = csv_lines.first

      expected_headers.each do |header|
        expect(headers).to include(header)
      end
    end

    it 'includes all employee data rows' do
      csv_content = service.call

      csv_lines = CSV.parse(csv_content)

      # Header + 2 employees = 3 rows
      expect(csv_lines.count).to eq(3)
    end

    it 'exports employee basic information correctly' do
      csv_content = service.call

      csv_lines = CSV.parse(csv_content, headers: true)
      emp1_row = csv_lines.find { |row| row['員工編號'] == 'EMP0001' }

      expect(emp1_row['公司名稱']).to eq('測試公司')
      expect(emp1_row['姓名']).to eq('張三')
      expect(emp1_row['身分證字號']).to eq('A123456789')
      expect(emp1_row['Email']).to eq('zhang@example.com')
      expect(emp1_row['電話']).to eq('0912345678')
      expect(emp1_row['部門']).to eq('工程部')
      expect(emp1_row['職位']).to eq('工程師')
    end

    it 'exports calculated salary fields correctly' do
      csv_content = service.call

      csv_lines = CSV.parse(csv_content, headers: true)
      emp1_row = csv_lines.find { |row| row['員工編號'] == 'EMP0001' }

      expect(emp1_row['底薪'].to_i).to eq(40000)
      expect(emp1_row['津貼總額'].to_i).to eq(2000)
      expect(emp1_row['扣款總額'].to_i).to eq(1000)
      expect(emp1_row['毛薪'].to_i).to eq(42000) # base_salary + allowances
    end

    it 'exports employee status correctly' do
      csv_content = service.call

      csv_lines = CSV.parse(csv_content, headers: true)
      active_emp = csv_lines.find { |row| row['員工編號'] == 'EMP0001' }
      resigned_emp = csv_lines.find { |row| row['員工編號'] == 'EMP0002' }

      expect(active_emp['狀態']).to eq('在職')
      expect(resigned_emp['狀態']).to eq('離職')
    end

    it 'formats dates correctly' do
      csv_content = service.call

      csv_lines = CSV.parse(csv_content, headers: true)
      emp1_row = csv_lines.find { |row| row['員工編號'] == 'EMP0001' }

      expect(emp1_row['生日']).to match(/1990-01-01/)
      expect(emp1_row['到職日期']).to match(/2024-01-01/)
    end

    it 'handles nil resign_date for active employees' do
      csv_content = service.call

      csv_lines = CSV.parse(csv_content, headers: true)
      active_emp = csv_lines.find { |row| row['員工編號'] == 'EMP0001' }

      expect(active_emp['離職日期']).to be_nil.or be_empty
    end

    it 'exports resign_date for resigned employees' do
      csv_content = service.call

      csv_lines = CSV.parse(csv_content, headers: true)
      resigned_emp = csv_lines.find { |row| row['員工編號'] == 'EMP0002' }

      expect(resigned_emp['離職日期']).to match(/2024-06-30/)
    end
  end

  describe '#call with Excel format' do
    let(:service) { described_class.new(employees, :xlsx) }

    it 'generates Excel workbook content' do
      xlsx_content = service.call

      expect(xlsx_content).to be_a(String)
      expect(xlsx_content.encoding).to eq(Encoding::ASCII_8BIT)
    end

    it 'creates workbook with correct headers' do
      xlsx_content = service.call

      workbook = RubyXL::Parser.parse_buffer(xlsx_content)
      worksheet = workbook[0]

      expected_headers = [
        '公司名稱', '員工編號', '姓名', '身分證字號', 'Email', '電話',
        '生日', '到職日期', '離職日期', '部門', '職位', '底薪',
        '津貼總額', '扣款總額', '毛薪', '狀態'
      ]

      header_row = worksheet[0]
      actual_headers = header_row.cells.map(&:value)

      expect(actual_headers).to eq(expected_headers)
    end

    it 'includes all employee data rows' do
      xlsx_content = service.call

      workbook = RubyXL::Parser.parse_buffer(xlsx_content)
      worksheet = workbook[0]

      # Header row + 2 employees = 3 rows
      expect(worksheet.sheet_data.rows.count).to eq(3)
    end

    it 'exports employee data to correct cells' do
      xlsx_content = service.call

      workbook = RubyXL::Parser.parse_buffer(xlsx_content)
      worksheet = workbook[0]

      # Find EMP0001 row (should be row 1, 0-indexed)
      emp1_row = worksheet[1]

      expect(emp1_row[1].value).to eq('EMP0001') # 員工編號
      expect(emp1_row[2].value).to eq('張三')     # 姓名
      expect(emp1_row[9].value).to eq('工程部')   # 部門
      expect(emp1_row[10].value).to eq('工程師')  # 職位
    end

    it 'exports calculated fields correctly' do
      xlsx_content = service.call

      workbook = RubyXL::Parser.parse_buffer(xlsx_content)
      worksheet = workbook[0]

      emp1_row = worksheet[1]

      expect(emp1_row[11].value).to eq(40000)  # 底薪
      expect(emp1_row[12].value).to eq(2000)   # 津貼總額
      expect(emp1_row[13].value).to eq(1000)   # 扣款總額
      expect(emp1_row[14].value).to eq(42000)  # 毛薪
    end

    it 'sets worksheet name correctly' do
      xlsx_content = service.call

      workbook = RubyXL::Parser.parse_buffer(xlsx_content)
      worksheet = workbook[0]

      expect(worksheet.sheet_name).to eq('員工清單')
    end
  end

  describe 'with empty employee list' do
    let(:employees) { Employee.none }
    let(:service) { described_class.new(employees, :csv) }

    it 'exports only headers when no employees' do
      csv_content = service.call

      csv_lines = CSV.parse(csv_content)

      expect(csv_lines.count).to eq(1) # Only header row
    end
  end

  describe 'with filtered employees' do
    let(:filtered_employees) { company.employees.where(active: true) }
    let(:service) { described_class.new(filtered_employees, :csv) }

    it 'exports only filtered employees' do
      csv_content = service.call

      csv_lines = CSV.parse(csv_content, headers: true)

      expect(csv_lines.count).to eq(1) # Only active employee
      expect(csv_lines.first['員工編號']).to eq('EMP0001')
    end
  end
end
