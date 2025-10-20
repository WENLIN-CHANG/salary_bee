# Helper to generate valid Taiwan Tax IDs for testing
module TaiwanTaxIdGenerator
  VALIDATORS = [ 1, 2, 1, 2, 1, 2, 4, 1 ].freeze

  def self.number_reducer(num)
    return num if num < 10
    number_reducer(num.digits.sum)
  end

  def self.generate(seed = nil)
    # Use seed to generate deterministic tax IDs
    base = seed ? (10_000_000 + (seed * 1234567) % 90_000_000) : rand(10_000_000..99_999_999)

    # Convert to 7-digit string and try different check digits
    first_7 = base.to_s[0..6]

    (0..9).each do |check_digit|
      tax_id = "#{first_7}#{check_digit}"
      return tax_id if valid?(tax_id)
    end

    # Fallback: return a known valid tax ID
    %w[10458575 88117125 53212539].sample
  end

  def self.valid?(tax_id)
    return false unless tax_id&.match?(/\A\d{8}\z/)

    check_sum = tax_id.chars
                      .map(&:to_i)
                      .zip(VALIDATORS)
                      .map { |a, b| number_reducer(a * b) }

    if tax_id[6] == "7"
      check_sum[6] = 0
      [ 0, 1 ].include?(check_sum.sum % 5)
    else
      check_sum.sum % 5 == 0
    end
  end
end
