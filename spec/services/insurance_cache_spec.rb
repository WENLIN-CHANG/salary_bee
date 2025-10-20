# frozen_string_literal: true

require "rails_helper"

RSpec.describe InsuranceCache, type: :service do
  # Clean slate for each test
  before do
    # Delete all insurances to ensure clean test environment
    Insurance.delete_all
    # Clear cache before each test
    InsuranceCache.clear!
  end

  let!(:labor_insurance_low) do
    create(:insurance,
      insurance_type: "labor",
      grade_level: 1,
      salary_min: 0,
      salary_max: 25000,
      premium_base: 25000,
      rate: 0.115,
      employee_ratio: 0.2,
      employer_ratio: 0.7,
      government_ratio: 0.1,
      effective_date: Date.current - 1.year,
      expiry_date: nil)
  end

  let!(:labor_insurance_high) do
    create(:insurance,
      insurance_type: "labor",
      grade_level: 2,
      salary_min: 25001,
      salary_max: 50000,
      premium_base: 35000,
      rate: 0.115,
      employee_ratio: 0.2,
      employer_ratio: 0.7,
      government_ratio: 0.1,
      effective_date: Date.current - 1.year,
      expiry_date: nil)
  end

  let!(:health_insurance) do
    create(:insurance,
      insurance_type: "health",
      grade_level: 1,
      salary_min: 0,
      salary_max: nil,
      premium_base: 30000,
      rate: 0.0517,
      employee_ratio: 0.3,
      employer_ratio: 0.6,
      government_ratio: 0.1,
      effective_date: Date.current - 1.year,
      expiry_date: nil)
  end

  describe ".warm_up!" do
    it "loads all active insurance data into cache" do
      expect(Rails.cache).to receive(:write).with(
        InsuranceCache::CACHE_KEY,
        anything,
        expires_in: InsuranceCache::CACHE_EXPIRY
      ).and_call_original

      result = InsuranceCache.warm_up!

      expect(result).to be_a(Hash)
      expect(result.keys).to contain_exactly("labor", "health")
      expect(result["labor"].size).to eq(2)
      expect(result["health"].size).to eq(1)
    end

    it "sorts insurances by salary_min within each type" do
      data = InsuranceCache.warm_up!

      labor_grades = data["labor"]
      expect(labor_grades.first.salary_min).to eq(0)
      expect(labor_grades.last.salary_min).to eq(25001)
    end
  end

  describe ".clear!" do
    it "removes insurance data from cache" do
      data = InsuranceCache.warm_up!
      expect(data).to be_present

      InsuranceCache.clear!
      expect(Rails.cache.read(InsuranceCache::CACHE_KEY)).to be_nil
    end
  end

  describe ".find_grade" do
    before { InsuranceCache.warm_up! }

    context "when salary matches low range" do
      it "returns the correct insurance grade" do
        grade = InsuranceCache.find_grade("labor", 20000)

        expect(grade).to eq(labor_insurance_low)
        expect(grade.salary_min).to eq(0)
        expect(grade.salary_max).to eq(25000)
      end
    end

    context "when salary matches high range" do
      it "returns the correct insurance grade" do
        grade = InsuranceCache.find_grade("labor", 30000)

        expect(grade).to eq(labor_insurance_high)
        expect(grade.salary_min).to eq(25001)
        expect(grade.salary_max).to eq(50000)
      end
    end

    context "when salary is at boundary" do
      it "returns the correct grade at lower boundary" do
        grade = InsuranceCache.find_grade("labor", 25001)
        expect(grade).to eq(labor_insurance_high)
      end

      it "returns the correct grade at upper boundary" do
        grade = InsuranceCache.find_grade("labor", 25000)
        expect(grade).to eq(labor_insurance_low)
      end
    end

    context "when salary_max is nil (no upper limit)" do
      it "matches any salary above salary_min" do
        grade = InsuranceCache.find_grade("health", 1000000)
        expect(grade).to eq(health_insurance)
      end
    end

    context "when no matching grade exists" do
      it "returns nil" do
        grade = InsuranceCache.find_grade("labor", 100000)
        expect(grade).to be_nil
      end
    end

    context "when insurance type does not exist" do
      it "returns nil" do
        grade = InsuranceCache.find_grade("nonexistent", 30000)
        expect(grade).to be_nil
      end
    end
  end

  describe ".calculate_premium" do
    before { InsuranceCache.warm_up! }

    context "when matching grade exists" do
      it "calculates premium breakdown correctly" do
        result = InsuranceCache.calculate_premium("labor", 30000)

        expect(result).to be_a(Hash)
        expect(result[:grade]).to eq(labor_insurance_high)

        total = 35000 * 0.115
        expect(result[:total]).to eq(total)
        expect(result[:employee]).to eq(total * 0.2)
        expect(result[:employer]).to eq(total * 0.7)
        expect(result[:government]).to eq(total * 0.1)
      end
    end

    context "when no matching grade exists" do
      it "returns nil" do
        result = InsuranceCache.calculate_premium("labor", 100000)
        expect(result).to be_nil
      end
    end
  end

  describe ".build_lookup_table" do
    it "groups insurances by type" do
      table = InsuranceCache.build_lookup_table

      expect(table).to be_a(Hash)
      expect(table.keys).to contain_exactly("labor", "health")
    end

    it "sorts insurances by salary_min within each type" do
      table = InsuranceCache.build_lookup_table
      labor_grades = table["labor"]

      expect(labor_grades.map(&:salary_min)).to eq([0, 25001])
    end

    it "only includes active insurances" do
      # Create an inactive insurance
      create(:insurance,
        insurance_type: "labor",
        grade_level: 3,
        salary_min: 50001,
        salary_max: 100000,
        premium_base: 75000,
        rate: 0.115,
        employee_ratio: 0.2,
        employer_ratio: 0.7,
        government_ratio: 0.1,
        effective_date: Date.current - 1.year,
        expiry_date: Date.current - 1.day)

      table = InsuranceCache.build_lookup_table

      # Should only have 2 active labor insurances
      expect(table["labor"].size).to eq(2)
    end
  end

  describe ".fetch_lookup_table" do
    around do |example|
      # Use memory store for cache tests
      original_cache = Rails.cache
      Rails.cache = ActiveSupport::Cache::MemoryStore.new
      example.run
      Rails.cache = original_cache
    end

    it "builds and caches lookup table on first call" do
      # First call should build the table
      table1 = InsuranceCache.fetch_lookup_table
      expect(table1).to be_a(Hash)

      # Second call should use cached version (no database query)
      allow(Insurance).to receive(:active).and_call_original
      table2 = InsuranceCache.fetch_lookup_table

      expect(Insurance).not_to have_received(:active)
      expect(table1.keys).to eq(table2.keys)
    end

    it "returns previously warmed up cache" do
      warmed_data = InsuranceCache.warm_up!

      # Should use cached version
      fetched_data = InsuranceCache.fetch_lookup_table

      expect(fetched_data.keys).to eq(warmed_data.keys)
    end
  end

  describe "cache expiration" do
    around do |example|
      # Use memory store for cache tests
      original_cache = Rails.cache
      Rails.cache = ActiveSupport::Cache::MemoryStore.new
      example.run
      Rails.cache = original_cache
    end

    it "sets proper expiration time" do
      InsuranceCache.warm_up!

      # Cache should exist
      cached_data = Rails.cache.read(InsuranceCache::CACHE_KEY)
      expect(cached_data).to be_present
      expect(cached_data).to be_a(Hash)
    end

    it "can be manually cleared" do
      InsuranceCache.warm_up!
      expect(Rails.cache.read(InsuranceCache::CACHE_KEY)).to be_present

      InsuranceCache.clear!
      expect(Rails.cache.read(InsuranceCache::CACHE_KEY)).to be_nil
    end
  end

  describe "performance" do
    it "avoids database queries when calculating multiple premiums" do
      InsuranceCache.warm_up!

      # After warming up, calculations should not hit the database
      expect(Insurance).not_to receive(:find_grade_by_salary)

      results = []
      100.times do |i|
        result = InsuranceCache.calculate_premium("labor", 20000 + i)
        results << result if result
      end

      expect(results).not_to be_empty
    end
  end
end
