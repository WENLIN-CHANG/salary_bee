FactoryBot.define do
  factory :employee do
    company
    sequence(:employee_id) { |n| "EMP#{n.to_s.rjust(4, '0')}" }
    sequence(:name) { |n| "員工#{n}" }
    sequence(:id_number) do |n|
      # 台灣身分證格式：1英文字母 + 9數字
      # 使用有效的格式範例（不驗證檢查碼）
      letters = %w[A B C D E F G H I J K L M N O P Q R S T U V W X Y Z]
      "#{letters[n % 26]}1234567#{(n % 10).to_s}#{((n + 1) % 10).to_s}"
    end
    sequence(:email) { |n| "employee#{n}@example.com" }
    sequence(:phone) { |n| "09#{n.to_s.rjust(8, '0')}" }
    birth_date { 30.years.ago.to_date }
    hire_date { 1.year.ago.to_date }
    department { "工程部" }
    position { "工程師" }
    base_salary { 40000 }
    allowances { {} }
    deductions { {} }
    labor_insurance_group { nil }
    health_insurance_group { nil }
    active { true }
    resign_date { nil }

    trait :active do
      active { true }
      resign_date { nil }
    end

    trait :resigned do
      active { false }
      resign_date { 1.month.ago.to_date }
    end

    trait :with_allowances do
      allowances do
        {
          "交通津貼" => 2000,
          "伙食津貼" => 3000,
          "職務加給" => 5000
        }
      end
    end

    trait :with_deductions do
      deductions do
        {
          "勞保費" => 1000,
          "健保費" => 800,
          "所得稅" => 1500
        }
      end
    end

    trait :with_full_salary_structure do
      with_allowances
      with_deductions
    end
  end
end
