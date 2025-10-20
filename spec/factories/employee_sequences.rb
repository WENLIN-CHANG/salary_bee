# frozen_string_literal: true

FactoryBot.define do
  factory :employee_sequence do
    association :company
    year { Date.current.year }
    last_number { 0 }
  end
end
