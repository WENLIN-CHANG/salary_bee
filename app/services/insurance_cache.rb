# frozen_string_literal: true

# InsuranceCache provides an in-memory cache for Insurance data to avoid N+1 queries
# during payroll calculations.
#
# Usage:
#   # Warm up cache on application startup (see config/initializers/insurance_cache.rb)
#   InsuranceCache.warm_up!
#
#   # Find insurance grade by type and salary (reads from cache)
#   grade = InsuranceCache.find_grade('labor', 30000)
#
#   # Calculate premium using cached data
#   premium = InsuranceCache.calculate_premium('labor', 30000)
#
class InsuranceCache
  CACHE_KEY = "insurance_lookup_table"
  CACHE_EXPIRY = 24.hours

  # Warm up the cache by loading all active insurance data
  # This should be called on application startup
  def self.warm_up!
    Rails.logger.info "[InsuranceCache] Warming up insurance cache..."
    data = build_lookup_table
    Rails.cache.write(CACHE_KEY, data, expires_in: CACHE_EXPIRY)
    Rails.logger.info "[InsuranceCache] Cache warmed up with #{data.values.flatten.size} insurance grades"
    data
  end

  # Clear the cache (useful for testing or when insurance data is updated)
  def self.clear!
    Rails.cache.delete(CACHE_KEY)
  end

  # Find insurance grade by type and salary from cache
  # Returns Insurance object or nil
  def self.find_grade(insurance_type, salary)
    lookup_table = fetch_lookup_table
    insurances = lookup_table[insurance_type] || []

    insurances.find do |ins|
      ins.salary_min <= salary && (ins.salary_max.nil? || ins.salary_max >= salary)
    end
  end

  # Calculate premium using cached insurance data
  # Returns hash with premium breakdown or nil if no matching grade found
  def self.calculate_premium(insurance_type, salary)
    grade = find_grade(insurance_type, salary)
    return nil unless grade

    total_premium = grade.premium_base * grade.rate
    {
      total: total_premium,
      employee: total_premium * grade.employee_ratio,
      employer: total_premium * grade.employer_ratio,
      government: total_premium * grade.government_ratio,
      grade: grade
    }
  end

  # Build lookup table grouped by insurance type
  # Returns Hash: { 'labor' => [Insurance, ...], 'health' => [...], ... }
  def self.build_lookup_table
    Insurance.active.group_by(&:insurance_type).transform_values do |insurances|
      insurances.sort_by(&:salary_min)
    end
  end

  # Fetch lookup table from cache, or build and cache it if not present
  def self.fetch_lookup_table
    Rails.cache.fetch(CACHE_KEY, expires_in: CACHE_EXPIRY) do
      build_lookup_table
    end
  end
end
