class EmployeesController < ApplicationController
  before_action :require_authentication
  before_action :set_company
  before_action :authorize_company_access
  before_action :set_employee, only: [ :show, :edit, :update, :destroy, :activate ]

  def index
    @employees = @company.employees

    # Search filter
    if params[:search].present?
      @employees = @employees.where("name LIKE ?", "%#{params[:search]}%")
    end

    # Department filter
    if params[:department].present?
      @employees = @employees.by_department(params[:department])
    end

    # Active/All filter
    unless params[:show_all] == "1"
      @employees = @employees.active
    end

    # Pagination (simplified without pagy for now)
    @employees = @employees.order(created_at: :desc)

    respond_to do |format|
      format.html
      format.csv do
        csv_content = EmployeeExportService.new(@employees, :csv).call
        send_data csv_content,
                  filename: "employees_#{Date.current}.csv",
                  type: "text/csv",
                  disposition: "attachment"
      end
      format.xlsx do
        xlsx_content = EmployeeExportService.new(@employees, :xlsx).call
        send_data xlsx_content,
                  filename: "employees_#{Date.current}.xlsx",
                  type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
                  disposition: "attachment"
      end
    end
  end

  def show
  end

  def new
    @employee = @company.employees.build
  end

  def create
    @employee = @company.employees.build(employee_params)

    if @employee.save
      redirect_to company_employee_path(@company, @employee),
                  notice: "員工資料已成功建立"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @employee.update(employee_params)
      redirect_to company_employee_path(@company, @employee),
                  notice: "員工資料已更新"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @employee.update(active: false, resign_date: Date.current)
    redirect_to company_employees_path(@company),
                notice: "員工已設為離職狀態"
  end

  def activate
    @employee.update(active: true, resign_date: nil)
    redirect_to company_employees_path(@company),
                notice: "員工已重新啟用"
  end

  def bulk_import
    if request.post?
      if params[:file].blank?
        @import_errors = [ "請選擇檔案" ]
        render :bulk_import, status: :unprocessable_entity
        return
      end

      service = EmployeeImportService.new(@company, params[:file])
      service.call

      if service.success?
        redirect_to company_employees_path(@company),
                    notice: "成功匯入 #{service.imported_count} 筆員工資料"
      else
        @import_errors = service.errors
        render :bulk_import, status: :unprocessable_entity
      end
    end
  end

  def download_template
    # Create template Excel file
    workbook = RubyXL::Workbook.new
    worksheet = workbook[0]
    worksheet.sheet_name = "員工資料範本"

    # Headers
    headers = [
      "員工編號", "姓名", "身分證字號", "Email", "電話", "生日",
      "到職日期", "部門", "職位", "底薪",
      "津貼（JSON格式）", "扣款（JSON格式）"
    ]

    headers.each_with_index do |header, idx|
      worksheet.add_cell(0, idx, header)
    end

    # Example row
    example = [
      "EMP0001", "張三", "A123456789", "zhang@example.com",
      "0912345678", "1990-01-01", "2024-01-01", "工程部",
      "工程師", 40000, "{}", "{}"
    ]

    example.each_with_index do |value, idx|
      worksheet.add_cell(1, idx, value)
    end

    send_data workbook.stream.string,
              filename: "員工資料匯入範本.xlsx",
              type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
              disposition: "attachment"
  end

  private

  def set_company
    @company = Current.user.companies.find(params[:company_id])
  rescue ActiveRecord::RecordNotFound
    redirect_to companies_path, alert: "無權限存取此公司"
  end

  def authorize_company_access
    unless Current.user.companies.include?(@company)
      redirect_to companies_path, alert: "無權限存取此公司"
    end
  end

  def set_employee
    @employee = @company.employees.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to company_employees_path(@company), alert: "找不到該員工"
  end

  def employee_params
    params.require(:employee).permit(
      :employee_id, :name, :id_number, :email, :phone, :birth_date,
      :hire_date, :resign_date, :department, :position, :base_salary,
      :labor_insurance_group, :health_insurance_group,
      allowances: {}, deductions: {}
    )
  end
end
