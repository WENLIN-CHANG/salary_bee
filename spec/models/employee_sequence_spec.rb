require 'rails_helper'

RSpec.describe EmployeeSequence, type: :model do
  let(:company) { create(:company) }

  describe 'validations' do
    subject { build(:employee_sequence, company: company, year: 2024) }

    it { should validate_presence_of(:year) }
    it { should validate_presence_of(:last_number) }
    it { should validate_numericality_of(:year).only_integer.is_greater_than(1900) }
    it { should validate_numericality_of(:last_number).only_integer.is_greater_than_or_equal_to(0) }

    it 'validates uniqueness of company_id scoped to year' do
      create(:employee_sequence, company: company, year: 2024, last_number: 5)
      duplicate = build(:employee_sequence, company: company, year: 2024, last_number: 10)

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:company_id]).to include("已有該年度的序號")
    end

    it 'allows same year for different companies' do
      company2 = create(:company)
      create(:employee_sequence, company: company, year: 2024, last_number: 5)
      sequence2 = build(:employee_sequence, company: company2, year: 2024, last_number: 5)

      expect(sequence2).to be_valid
    end

    it 'allows different years for same company' do
      create(:employee_sequence, company: company, year: 2024, last_number: 5)
      sequence2 = build(:employee_sequence, company: company, year: 2025, last_number: 1)

      expect(sequence2).to be_valid
    end
  end

  describe 'associations' do
    it { should belong_to(:company) }
  end

  describe '.next_for' do
    context 'when sequence does not exist' do
      it 'creates a new sequence and returns 1' do
        expect {
          number = EmployeeSequence.next_for(company, 2024)
          expect(number).to eq(1)
        }.to change { EmployeeSequence.count }.by(1)
      end

      it 'sets initial last_number to 1' do
        EmployeeSequence.next_for(company, 2024)

        sequence = EmployeeSequence.find_by(company: company, year: 2024)
        expect(sequence.last_number).to eq(1)
      end
    end

    context 'when sequence exists' do
      let!(:sequence) { create(:employee_sequence, company: company, year: 2024, last_number: 5) }

      it 'increments the existing sequence' do
        number = EmployeeSequence.next_for(company, 2024)
        expect(number).to eq(6)
      end

      it 'updates last_number in database' do
        EmployeeSequence.next_for(company, 2024)

        sequence.reload
        expect(sequence.last_number).to eq(6)
      end

      it 'increments correctly on multiple calls' do
        expect(EmployeeSequence.next_for(company, 2024)).to eq(6)
        expect(EmployeeSequence.next_for(company, 2024)).to eq(7)
        expect(EmployeeSequence.next_for(company, 2024)).to eq(8)
      end
    end

    context 'multiple companies' do
      let(:company2) { create(:company) }

      it 'maintains separate sequences for different companies' do
        expect(EmployeeSequence.next_for(company, 2024)).to eq(1)
        expect(EmployeeSequence.next_for(company2, 2024)).to eq(1)
        expect(EmployeeSequence.next_for(company, 2024)).to eq(2)
        expect(EmployeeSequence.next_for(company2, 2024)).to eq(2)
      end
    end

    context 'multiple years' do
      it 'maintains separate sequences for different years' do
        expect(EmployeeSequence.next_for(company, 2024)).to eq(1)
        expect(EmployeeSequence.next_for(company, 2025)).to eq(1)
        expect(EmployeeSequence.next_for(company, 2024)).to eq(2)
        expect(EmployeeSequence.next_for(company, 2025)).to eq(2)
      end
    end

    context 'race condition prevention' do
      it 'prevents duplicate numbers with concurrent requests', :aggregate_failures do
        # Simulate 10 concurrent requests
        threads = []
        numbers = []
        mutex = Mutex.new

        10.times do
          threads << Thread.new do
            ActiveRecord::Base.connection_pool.with_connection do
              number = EmployeeSequence.next_for(company, 2024)
              mutex.synchronize { numbers << number }
            end
          end
        end

        threads.each(&:join)

        # All numbers should be unique
        expect(numbers.size).to eq(10)
        expect(numbers.uniq.size).to eq(10)

        # Numbers should be consecutive (1-10)
        expect(numbers.sort).to eq((1..10).to_a)

        # Final sequence should be 10
        sequence = EmployeeSequence.find_by(company: company, year: 2024)
        expect(sequence.last_number).to eq(10)
      end

      it 'handles concurrent creation of sequences for different years' do
        years = [ 2024, 2025, 2026 ]
        threads = []
        results = {}
        mutex = Mutex.new

        years.each do |year|
          5.times do
            threads << Thread.new do
              ActiveRecord::Base.connection_pool.with_connection do
                number = EmployeeSequence.next_for(company, year)
                mutex.synchronize do
                  results[year] ||= []
                  results[year] << number
                end
              end
            end
          end
        end

        threads.each(&:join)

        # Each year should have 5 unique numbers
        years.each do |year|
          expect(results[year].size).to eq(5)
          expect(results[year].uniq.size).to eq(5)
          expect(results[year].sort).to eq((1..5).to_a)
        end
      end
    end
  end

  describe '.reset_for' do
    let!(:sequence) { create(:employee_sequence, company: company, year: 2024, last_number: 10) }

    it 'resets the sequence to 0' do
      EmployeeSequence.reset_for(company, 2024)

      sequence.reload
      expect(sequence.last_number).to eq(0)
    end

    it 'returns true' do
      result = EmployeeSequence.reset_for(company, 2024)
      expect(result).to be true
    end

    context 'when sequence does not exist' do
      it 'returns true without creating a sequence' do
        result = EmployeeSequence.reset_for(company, 2025)
        expect(result).to be true

        expect(EmployeeSequence.find_by(company: company, year: 2025)).to be_nil
      end
    end
  end

  describe 'factory' do
    it 'has a valid factory' do
      sequence = create(:employee_sequence, company: company)
      expect(sequence).to be_valid
    end
  end
end
