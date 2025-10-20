# frozen_string_literal: true

# Warm up the insurance cache on application startup to avoid N+1 queries
# during payroll calculations.
#
# The cache will be automatically refreshed every 24 hours.
# To manually refresh: InsuranceCache.warm_up!
# To clear: InsuranceCache.clear!

Rails.application.config.after_initialize do
  # Only warm up cache if database is available and not during assets precompilation
  next if ENV["SKIP_INSURANCE_CACHE"].present?
  next unless ActiveRecord::Base.connection.table_exists?("insurances")

  begin
    InsuranceCache.warm_up!
  rescue => e
    Rails.logger.warn "[InsuranceCache] Failed to warm up cache: #{e.message}"
    # Don't fail application startup if cache warming fails
  end
end
