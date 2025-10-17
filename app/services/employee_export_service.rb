require "csv"

class EmployeeExportService
  attr_reader :employees, :format

  HEADERS = [
    "公司名稱", "員工編號", "姓名", "身分證字號", "Email", "電話",
    "生日", "到職日期", "離職日期", "部門", "職位", "底薪",
    "津貼總額", "扣款總額", "毛薪", "狀態"
  ].freeze

  def initialize(employees, format = :csv)
    @employees = employees
    @format = format
  end

  def call
    case format
    when :csv
      generate_csv
    when :xlsx
      generate_excel
    else
      generate_csv
    end
  end

  private

  def generate_csv
    CSV.generate do |csv|
      csv << HEADERS

      employees.each do |employee|
        csv << employee_row_data(employee)
      end
    end
  end

  def generate_excel
    workbook = RubyXL::Workbook.new
    worksheet = workbook[0]
    worksheet.sheet_name = "員工清單"

    # Headers
    HEADERS.each_with_index do |header, idx|
      worksheet.add_cell(0, idx, header)
    end

    # Data rows
    employees.each_with_index do |employee, row_idx|
      row_number = row_idx + 1
      data = employee_row_data(employee)

      data.each_with_index do |value, col_idx|
        worksheet.add_cell(row_number, col_idx, value)
      end
    end

    workbook.stream.string
  end

  def employee_row_data(employee)
    [
      employee.company.name,
      employee.employee_id,
      employee.name,
      employee.id_number,
      employee.email,
      employee.phone,
      format_date(employee.birth_date),
      format_date(employee.hire_date),
      format_date(employee.resign_date),
      employee.department,
      employee.position,
      employee.base_salary.to_f,
      employee.total_allowances.to_f,
      employee.total_deductions.to_f,
      employee.gross_salary.to_f,
      employee.active ? "在職" : "離職"
    ]
  end

  def format_date(date)
    return nil if date.blank?
    date.to_s
  end
end
