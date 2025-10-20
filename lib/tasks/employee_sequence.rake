# frozen_string_literal: true

namespace :employee_sequence do
  desc "Initialize employee sequences for existing employees"
  task initialize: :environment do
    puts "Initializing employee sequences for existing employees..."

    Company.find_each do |company|
      puts "\nProcessing company: #{company.name} (ID: #{company.id})"

      # Group employees by year extracted from employee_id
      employees_by_year = company.employees.group_by do |employee|
        # Extract year from employee_id (format: "EMP2024####")
        match = employee.employee_id.match(/EMP(\d{4})/)
        match ? match[1].to_i : nil
      end.compact

      # Create or update sequence for each year
      employees_by_year.each do |year, employees|
        # Find the highest number for this year
        highest_number = employees.map do |employee|
          # Extract number from employee_id (format: "EMP2024####")
          employee.employee_id[7..].to_i
        end.max

        # Create or update the sequence
        sequence = EmployeeSequence.find_or_initialize_by(company: company, year: year)
        sequence.last_number = highest_number
        sequence.save!

        puts "  Year #{year}: Set sequence to #{highest_number} (#{employees.size} employees)"
      end
    end

    puts "\n✓ Employee sequence initialization completed!"
  end

  desc "Reset all employee sequences to 0"
  task reset: :environment do
    puts "Resetting all employee sequences..."

    EmployeeSequence.delete_all

    puts "✓ All employee sequences have been deleted!"
    puts "Run 'rake employee_sequence:initialize' to rebuild sequences from existing employees"
  end

  desc "Verify employee sequences integrity"
  task verify: :environment do
    puts "Verifying employee sequences integrity...\n"

    errors_found = false

    Company.find_each do |company|
      puts "Checking company: #{company.name}"

      # Check each employee has a unique ID
      duplicate_ids = company.employees
        .group_by(&:employee_id)
        .select { |_, employees| employees.size > 1 }

      if duplicate_ids.any?
        errors_found = true
        puts "  ✗ Found duplicate employee IDs:"
        duplicate_ids.each do |id, employees|
          puts "    - #{id}: #{employees.map(&:name).join(', ')}"
        end
      end

      # Check sequence integrity for each year
      EmployeeSequence.where(company: company).each do |sequence|
        year = sequence.year
        expected_count = sequence.last_number

        # Count actual employees for this year
        actual_employees = company.employees.select do |employee|
          employee.employee_id.match?(/EMP#{year}/)
        end

        if actual_employees.size > expected_count
          errors_found = true
          puts "  ✗ Year #{year}: Sequence is #{expected_count} but found #{actual_employees.size} employees"
        end
      end

      puts "  ✓ No issues found" unless errors_found
    end

    if errors_found
      puts "\n⚠ Issues found! Please review and fix manually."
      exit 1
    else
      puts "\n✓ All employee sequences are valid!"
    end
  end
end
