require 'rails_helper'

RSpec.describe EmployeeImportService, type: :service do
  let(:company) { create(:company) }
  let(:service) { described_class.new(company, file) }

  describe '#call' do
    context 'with valid CSV file' do
      let(:csv_content) do
        <<~CSV
          姓名,身分證字號,Email,電話,生日,到職日期,部門,職位,底薪,津貼（JSON格式）,扣款（JSON格式）
          張三,A123456789,zhang@example.com,0912345678,1990-01-01,2024-01-01,工程部,工程師,40000,{},{}
          李四,B987654321,li@example.com,0987654321,1992-05-15,2024-02-01,業務部,業務員,35000,"{""交通津貼"":2000}","{""勞保費"":1000}"
        CSV
      end

      let(:file) do
        Tempfile.new([ 'employees', '.csv' ]).tap do |f|
          f.write(csv_content)
          f.rewind
        end
      end

      after { file.close! }

      it 'imports all valid employees' do
        expect {
          service.call
        }.to change(Employee, :count).by(2)

        expect(service.success?).to be true
        expect(service.imported_count).to eq(2)
      end

      it 'parses employee attributes correctly' do
        service.call

        employee = company.employees.find_by(name: '張三')
        expect(employee).to be_present
        expect(employee.employee_id).to be_present # Auto-generated
        expect(employee.id_number).to eq('A123456789')
        expect(employee.email).to eq('zhang@example.com')
        expect(employee.phone).to eq('0912345678')
        expect(employee.birth_date).to eq(Date.parse('1990-01-01'))
        expect(employee.hire_date).to eq(Date.parse('2024-01-01'))
        expect(employee.department).to eq('工程部')
        expect(employee.position).to eq('工程師')
        expect(employee.base_salary).to eq(40000)
      end

      it 'parses JSON allowances correctly' do
        service.call

        employee = company.employees.find_by(name: '李四')
        expect(employee.allowances).to eq({ "交通津貼" => 2000 })
      end

      it 'parses JSON deductions correctly' do
        service.call

        employee = company.employees.find_by(name: '李四')
        expect(employee.deductions).to eq({ "勞保費" => 1000 })
      end
    end

    context 'with valid Excel file' do
      let(:file) { Tempfile.new([ 'employees', '.xlsx' ]) }

      it 'imports employees from Excel' do
        # Mock Roo spreadsheet
        mock_excel = double('Roo::Spreadsheet')
        allow(Roo::Spreadsheet).to receive(:open).and_return(mock_excel)
        allow(mock_excel).to receive(:parse).and_return([
          {
            "姓名" => "Excel員工",
            "到職日期" => Date.parse("2024-01-01"),
            "底薪" => 40000
          }
        ])

        expect {
          service.call
        }.to change(Employee, :count).by(1)

        expect(service.success?).to be true
      end
    end

    context 'with missing required fields' do
      let(:csv_content) do
        <<~CSV
          姓名,Email,到職日期,底薪
          張三,zhang@example.com,,40000
        CSV
      end

      let(:file) do
        Tempfile.new([ 'employees', '.csv' ]).tap do |f|
          f.write(csv_content)
          f.rewind
        end
      end

      after { file.close! }

      it 'rejects row with missing hire_date' do
        expect {
          service.call
        }.not_to change(Employee, :count)

        expect(service.success?).to be false
        expect(service.errors).to include(match(/第 2 行.*缺少必填欄位/))
      end
    end

    context 'with validation errors' do
      let(:csv_content) do
        <<~CSV
          姓名,到職日期,底薪
          員工A,2024-01-01,-1000
        CSV
      end

      let(:file) do
        Tempfile.new([ 'employees', '.csv' ]).tap do |f|
          f.write(csv_content)
          f.rewind
        end
      end

      after { file.close! }

      it 'rolls back transaction on validation error' do
        expect {
          service.call
        }.not_to change(Employee, :count)

        expect(service.success?).to be false
        expect(service.errors).to be_present
      end

      it 'returns row number with error message' do
        service.call

        expect(service.errors.first).to match(/第 2 行/)
      end
    end

    context 'with unsupported file format' do
      let(:file) do
        Tempfile.new([ 'employees', '.txt' ]).tap do |f|
          f.write("text content")
          f.rewind
        end
      end

      after { file.close! }

      it 'rejects unsupported file format' do
        expect {
          service.call
        }.not_to change(Employee, :count)

        expect(service.success?).to be false
        expect(service.errors).to include('檔案格式不支援')
      end
    end

    context 'without file parameter' do
      let(:file) { nil }

      it 'returns error message' do
        expect {
          service.call
        }.not_to change(Employee, :count)

        expect(service.success?).to be false
        expect(service.errors).to include('請選擇檔案')
      end
    end

    context 'with malformed CSV' do
      let(:csv_content) { "Invalid CSV\nwith\"unclosed\nquotes" }

      let(:file) do
        Tempfile.new([ 'employees', '.csv' ]).tap do |f|
          f.write(csv_content)
          f.rewind
        end
      end

      after { file.close! }

      it 'handles parsing errors gracefully' do
        expect {
          service.call
        }.not_to raise_error

        expect(service.success?).to be false
      end
    end

    context 'date parsing' do
      let(:csv_content) do
        <<~CSV
          姓名,生日,到職日期,底薪
          員工A,1990/01/01,2024-01-15,40000
        CSV
      end

      let(:file) do
        Tempfile.new([ 'employees', '.csv' ]).tap do |f|
          f.write(csv_content)
          f.rewind
        end
      end

      after { file.close! }

      it 'parses various date formats correctly' do
        service.call

        employee = company.employees.find_by(name: '員工A')
        expect(employee.birth_date).to eq(Date.parse('1990-01-01'))
        expect(employee.hire_date).to eq(Date.parse('2024-01-15'))
      end
    end

    context 'decimal parsing' do
      let(:csv_content) do
        <<~CSV
          姓名,到職日期,底薪
          員工A,2024-01-01,"40,000"
          員工B,2024-01-01,45000.50
        CSV
      end

      let(:file) do
        Tempfile.new([ 'employees', '.csv' ]).tap do |f|
          f.write(csv_content)
          f.rewind
        end
      end

      after { file.close! }

      it 'parses decimal values with commas and decimals' do
        service.call

        employee1 = company.employees.find_by(name: '員工A')
        employee2 = company.employees.find_by(name: '員工B')

        expect(employee1.base_salary).to eq(40000)
        expect(employee2.base_salary).to eq(45000.50)
      end
    end
  end
end
