class PayrollsController < ApplicationController
  before_action :require_authentication
  before_action :set_company
  before_action :set_payroll, only: [ :show, :calculate, :confirm ]

  def index
    @payrolls = @company.payrolls.recent
  end

  def show
    @payroll_items = @payroll.payroll_items.includes(:employee).order("employees.name")
  end

  def new
    @payroll = @company.payrolls.build(
      year: params[:year] || Date.current.year,
      month: params[:month] || Date.current.month
    )
  end

  def create
    @payroll = @company.payrolls.build(payroll_params)

    if @payroll.save
      redirect_to payroll_path(@payroll), notice: "薪資批次建立成功"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def calculate
    unless @payroll.can_edit?
      redirect_to payroll_path(@payroll), alert: "薪資批次已確認，無法重新計算"
      return
    end

    begin
      service = PayrollCalculationService.new(@payroll)
      service.call

      redirect_to payroll_path(@payroll), notice: "薪資計算完成"
    rescue StandardError => e
      redirect_to payroll_path(@payroll), alert: "計算錯誤：#{e.message}"
    end
  end

  def confirm
    unless @payroll.can_edit?
      redirect_to payroll_path(@payroll), alert: "薪資批次已確認"
      return
    end

    unless @payroll.may_confirm?
      redirect_to payroll_path(@payroll), alert: "薪資批次無法確認，請先計算薪資"
      return
    end

    if @payroll.confirm!
      redirect_to payroll_path(@payroll), notice: "薪資批次已確認"
    else
      redirect_to payroll_path(@payroll), alert: "確認失敗"
    end
  end

  private

  def set_company
    # 支援多公司場景：優先使用 params[:company_id]，否則使用使用者的第一個公司
    if params[:company_id].present?
      @company = Current.user.companies.find(params[:company_id])
    elsif @payroll&.company
      @company = @payroll.company
      # 檢查權限
      unless Current.user.companies.include?(@company)
        raise ActiveRecord::RecordNotFound
      end
    else
      # 使用使用者的第一個公司（簡化處理）
      @company = Current.user.companies.first
      redirect_to root_path, alert: "請先建立公司" if @company.nil?
    end
  end

  def set_payroll
    # 確保只能查看自己公司的 payroll
    @payroll = Payroll.joins(:company)
                      .where(companies: { id: Current.user.company_ids })
                      .find(params[:id])
  rescue ActiveRecord::RecordNotFound
    raise ActiveRecord::RecordNotFound
  end

  def payroll_params
    params.require(:payroll).permit(:year, :month)
  end
end
