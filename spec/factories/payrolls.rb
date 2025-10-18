FactoryBot.define do
  factory :payroll do
    company
    year { 2024 }
    month { 3 }
    status { 'draft' }
    total_gross_pay { nil }
    total_net_pay { nil }
    confirmed_at { nil }
    paid_at { nil }

    trait :draft do
      status { 'draft' }
      confirmed_at { nil }
      paid_at { nil }
    end

    trait :confirmed do
      status { 'confirmed' }
      confirmed_at { Time.current }
      paid_at { nil }

      after(:create) do |payroll|
        # 確認狀態需要至少一個已計算的薪資項目
        create(:payroll_item, :with_calculations, payroll: payroll) if payroll.payroll_items.empty?
      end
    end

    trait :paid do
      status { 'paid' }
      confirmed_at { 1.day.ago }
      paid_at { Time.current }

      after(:create) do |payroll|
        # 發放狀態需要至少一個已計算的薪資項目
        create(:payroll_item, :with_calculations, payroll: payroll) if payroll.payroll_items.empty?
      end
    end

    trait :with_items do
      after(:create) do |payroll|
        create_list(:payroll_item, 3, :with_calculations, payroll: payroll)
      end
    end

    trait :calculated do
      after(:create) do |payroll|
        create_list(:payroll_item, 2, :with_calculations, payroll: payroll)
        payroll.calculate_totals
        payroll.save
      end
    end
  end
end
