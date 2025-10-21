require 'rails_helper'

RSpec.describe 'layouts/application.html.erb', type: :view do
  context 'when layout includes flash partial' do
    it 'includes render shared/flash in template' do
      # 直接檢查模板檔案內容
      template_content = File.read(Rails.root.join('app/views/layouts/application.html.erb'))
      expect(template_content).to include("render 'shared/flash'")
    end
  end

  context 'when rendering with content' do
    before do
      # 設定 content_for 以避免 layout 渲染錯誤
      content_for :title, 'Test Page'
    end

    it 'displays flash notice message' do
      flash[:notice] = 'Test notice message'
      render

      # 測試行為：訊息是否顯示
      expect(rendered).to include('Test notice message')
      # 測試行為：使用者是否能關閉訊息（檢查關閉按鈕存在）
      expect(rendered).to include('aria-label="關閉"')
    end

    it 'displays flash alert message' do
      flash[:alert] = 'Test alert message'
      render

      # 測試行為：訊息是否顯示
      expect(rendered).to include('Test alert message')
      # 測試行為：使用者是否能關閉訊息
      expect(rendered).to include('aria-label="關閉"')
    end

    it 'displays multiple flash messages' do
      flash[:notice] = 'Success message'
      flash[:alert] = 'Error message'
      render

      # 測試行為：兩個訊息都顯示
      expect(rendered).to include('Success message')
      expect(rendered).to include('Error message')
    end

    it 'does not render empty flash messages' do
      flash[:notice] = ''
      flash[:alert] = nil
      render

      # 測試行為：空訊息不應該產生額外的 div
      # 只有固定容器存在
      flash_containers = rendered.scan(/<div[^>]*x-data="{ show: true }"/).length
      expect(flash_containers).to eq(0)
    end
  end
end
