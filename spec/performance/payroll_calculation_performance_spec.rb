require 'rails_helper'
require 'benchmark'

RSpec.describe 'Payroll Calculation Performance', type: :performance do
  # 性能測試：確保薪資計算在大量員工時也能快速完成
  # 目標：100 個員工的計算應該在 2 秒內完成

  let!(:company) { create(:company, name: "大型企業") }
  let!(:payroll) { company.payrolls.create!(year: 2024, month: 3) }

  before do
    # 預先建立 100 個員工資料
    100.times do |i|
      create(:employee,
             company: company,
             name: "員工#{i + 1}",
             base_salary: rand(30000..80000),
             allowances: { "交通津貼" => rand(1000..3000), "伙食津貼" => rand(2000..5000) },
             deductions: { "借支" => rand(0..2000) })
    end

    # 預熱 InsuranceCache（模擬生產環境）
    InsuranceCache.warm_up!
  end

  describe '大量員工薪資計算性能' do
    it '100 個員工的計算應該在 2 秒內完成', :performance do
      service = PayrollCalculationService.new(payroll)

      elapsed_time = Benchmark.realtime do
        service.call
      end

      puts "\n  ✓ 計算 100 個員工薪資耗時: #{(elapsed_time * 1000).round(2)}ms"
      puts "  ✓ 建立的薪資項目數: #{payroll.payroll_items.count}"

      # 驗證計算完成
      expect(payroll.payroll_items.count).to eq(100)

      # 性能要求：應該在 2 秒內完成
      expect(elapsed_time).to be < 2.0,
                              "計算時間 #{elapsed_time.round(3)}s 超過 2 秒限制"
    end

    it '計算時不應該產生 N+1 查詢', :performance do
      service = PayrollCalculationService.new(payroll)

      # 記錄 SQL 查詢數量
      queries = []
      query_counter = ->(name, started, finished, unique_id, payload) {
        queries << payload[:sql] unless payload[:name] == 'SCHEMA'
      }

      ActiveSupport::Notifications.subscribed(query_counter, 'sql.active_record') do
        service.call
      end

      puts "\n  ✓ 執行的 SQL 查詢總數: #{queries.size}"

      # 驗證沒有大量重複查詢（N+1 問題）
      # 應該只有：
      # - 1 次查詢員工列表
      # - 100 次 INSERT/UPDATE payroll_items（批次操作）
      # - 1 次更新 payroll totals
      # - 少量的 transaction 相關查詢
      #
      # 總數應該遠小於 500（如果有 N+1 會是 400+ 保險查詢 + 100 員工）
      # 合理的查詢數：~100 INSERT + ~50 UPDATE + transaction 相關
      expect(queries.size).to be < 350,
                              "查詢數量 #{queries.size} 過多，可能有 N+1 問題"

      # 確保沒有大量的 Insurance 查詢
      insurance_queries = queries.select { |q| q.include?('insurances') }
      puts "  ✓ Insurance 相關查詢: #{insurance_queries.size}"

      expect(insurance_queries.size).to be < 5,
                                        "Insurance 查詢過多 (#{insurance_queries.size})，應該使用快取"
    end

    it '計算階段（calculate_all）應該非常快速', :performance do
      service = PayrollCalculationService.new(payroll)

      elapsed_time = Benchmark.realtime do
        results = service.calculate_all
        expect(results.size).to eq(100)
      end

      puts "\n  ✓ 純計算階段耗時: #{(elapsed_time * 1000).round(2)}ms"

      # 純計算（不含資料庫寫入）應該非常快，< 500ms
      expect(elapsed_time).to be < 0.5,
                              "純計算時間 #{elapsed_time.round(3)}s 過慢"
    end
  end

  describe 'InsuranceCache 效能' do
    it 'fetch_lookup_table 應該很快（從快取讀取）', :performance do
      # 第一次載入（可能從資料庫）
      InsuranceCache.clear!
      first_time = Benchmark.realtime do
        InsuranceCache.fetch_lookup_table
      end

      # 第二次載入（應該從快取）
      second_time = Benchmark.realtime do
        InsuranceCache.fetch_lookup_table
      end

      puts "\n  ✓ 第一次載入（含資料庫）: #{(first_time * 1000).round(2)}ms"
      puts "  ✓ 第二次載入（快取命中）: #{(second_time * 1000).round(2)}ms"

      # 快取命中應該 < 10ms
      expect(second_time).to be < 0.01,
                             "快取讀取時間 #{second_time.round(4)}s 過慢"
    end
  end

  describe '可擴展性測試' do
    it '500 個員工的計算應該在 10 秒內完成', :performance do
      # 建立額外 400 個員工（總共 500）
      400.times do |i|
        create(:employee,
               company: company,
               name: "員工#{i + 101}",
               base_salary: rand(30000..80000),
               allowances: { "交通津貼" => rand(1000..3000) },
               deductions: {})
      end

      service = PayrollCalculationService.new(payroll)

      elapsed_time = Benchmark.realtime do
        service.call
      end

      puts "\n  ✓ 計算 500 個員工薪資耗時: #{(elapsed_time * 1000).round(2)}ms"

      expect(payroll.payroll_items.count).to eq(500)
      expect(elapsed_time).to be < 10.0,
                              "500 員工計算時間 #{elapsed_time.round(2)}s 超過 10 秒限制"
    end
  end
end
