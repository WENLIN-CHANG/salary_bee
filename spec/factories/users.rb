FactoryBot.define do
  factory :user do
    sequence(:email_address) { |n| "user#{n}@example.com" }
    password { "password123" }
    password_confirmation { "password123" }

    # 支援直接設定 company
    transient do
      company { nil }
    end

    after(:create) do |user, evaluator|
      if evaluator.company
        user.companies << evaluator.company unless user.companies.include?(evaluator.company)
      end
    end
  end
end
