require "csv"

class EmployeeImportService
  attr_reader :company, :file, :errors, :imported_count

  def initialize(company, file)
    @company = company
    @file = file
    @errors = []
    @imported_count = 0
  end

  def call
    return add_error("請選擇檔案") if file.blank?

    filename = file.respond_to?(:original_filename) ? file.original_filename : file.path
    extension = File.extname(filename).downcase

    case extension
    when ".csv"
      import_csv
    when ".xlsx", ".xls"
      import_excel
    else
      add_error("檔案格式不支援")
    end

    success?
  rescue => e
    add_error("檔案處理錯誤：#{e.message}")
    false
  end

  def success?
    @errors.empty?
  end

  private

  def import_csv
    csv_content = file.respond_to?(:read) ? file.read : File.read(file.path)
    csv_data = CSV.parse(csv_content, headers: true)

    import_rows(csv_data)
  rescue CSV::MalformedCSVError => e
    add_error("CSV 格式錯誤：#{e.message}")
  end

  def import_excel
    spreadsheet = Roo::Spreadsheet.open(file)
    rows = spreadsheet.parse(headers: true)

    import_rows(rows)
  rescue => e
    add_error("Excel 檔案讀取錯誤：#{e.message}")
  end

  def import_rows(rows)
    ActiveRecord::Base.transaction do
      rows.each_with_index do |row, index|
        row_number = index + 2 # Account for header row

        # Extract and validate data
        employee_data = extract_employee_data(row)

        # Validate required fields
        unless validate_required_fields(employee_data, row_number)
          raise ActiveRecord::Rollback
        end

        # Create employee (employee_id will be auto-generated)
        employee = company.employees.build(employee_data)

        unless employee.save
          error_messages = employee.errors.full_messages.join(", ")
          add_error("第 #{row_number} 行：#{error_messages}")
          raise ActiveRecord::Rollback
        end

        @imported_count += 1
      end
    end
  end

  def extract_employee_data(row)
    {
      name: row["姓名"],
      id_number: row["身分證字號"],
      email: row["Email"],
      phone: row["電話"],
      birth_date: parse_date(row["生日"]),
      hire_date: parse_date(row["到職日期"]),
      resign_date: parse_date(row["離職日期"]),
      department: row["部門"],
      position: row["職位"],
      base_salary: parse_decimal(row["底薪"]),
      allowances: parse_json(row["津貼（JSON格式）"]),
      deductions: parse_json(row["扣款（JSON格式）"]),
      labor_insurance_group: row["勞保投保組別"],
      health_insurance_group: row["健保投保組別"]
    }
  end

  def validate_required_fields(data, row_number)
    required_fields = [ :name, :hire_date, :base_salary ]

    missing = required_fields.select { |field| data[field].blank? }

    if missing.any?
      field_names = missing.map { |f| translate_field_name(f) }.join(", ")
      add_error("第 #{row_number} 行：缺少必填欄位（#{field_names}）")
      return false
    end

    true
  end

  def translate_field_name(field)
    {
      name: "姓名",
      hire_date: "到職日期",
      base_salary: "底薪"
    }[field] || field.to_s
  end

  def parse_date(value)
    return nil if value.blank?

    # Handle various date formats
    Date.parse(value.to_s)
  rescue ArgumentError
    nil
  end

  def parse_decimal(value)
    return 0 if value.blank?

    # Remove commas and parse
    value.to_s.gsub(",", "").to_f
  end

  def parse_json(value)
    return {} if value.blank?

    JSON.parse(value.to_s)
  rescue JSON::ParserError
    {}
  end

  def add_error(message)
    @errors << message
  end
end
