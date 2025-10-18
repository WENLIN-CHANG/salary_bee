FactoryBot.define do
  factory :payroll_item do
    payroll
    employee
    # 從 employee 取得 base_salary，如果沒有則用預設值
    base_salary { employee&.base_salary || 40000 }
    total_allowances { employee&.total_allowances || 0 }
    total_deductions { employee&.total_deductions || 0 }
    total_insurance_premium { 0 }
    gross_pay { nil }
    net_pay { nil }

    trait :with_calculations do
      total_insurance_premium { 3000 }

      # gross_pay = base_salary + total_allowances
      # net_pay = gross_pay - total_deductions - total_insurance_premium
      gross_pay { base_salary + total_allowances }
      net_pay { base_salary + total_allowances - total_deductions - total_insurance_premium }
    end

    trait :with_allowances do
      total_allowances { 5000 }
    end

    trait :with_deductions do
      total_deductions { 2000 }
    end

    trait :with_insurance do
      total_insurance_premium { 3500 }
    end

    trait :high_salary do
      base_salary { 80000 }
    end

    trait :low_salary do
      base_salary { 28590 }
    end
  end
end
