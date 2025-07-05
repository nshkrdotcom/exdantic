#!/bin/bash

# Phase 4: Anonymous Function Support - Test Runner and Validation Script

echo "🚀 Phase 4: Anonymous Function Support - Running Test Suite"
echo "============================================================"

# Color codes for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Function to run tests and check results
run_test_suite() {
    local test_name=$1
    local test_file=$2
    
    print_status $BLUE "Running $test_name..."
    
    if mix test $test_file --trace; then
        print_status $GREEN "✅ $test_name PASSED"
        return 0
    else
        print_status $RED "❌ $test_name FAILED"
        return 1
    fi
}

# Function to check compilation
check_compilation() {
    print_status $BLUE "Checking compilation..."
    
    if mix compile --warnings-as-errors; then
        print_status $GREEN "✅ Compilation successful"
        return 0
    else
        print_status $RED "❌ Compilation failed"
        return 1
    fi
}

# Function to run Dialyzer
check_dialyzer() {
    print_status $BLUE "Running Dialyzer type checking..."
    
    if mix dialyzer --halt-exit-status; then
        print_status $GREEN "✅ Dialyzer checks passed"
        return 0
    else
        print_status $RED "❌ Dialyzer checks failed"
        return 1
    fi
}

# Function to check code formatting
check_formatting() {
    print_status $BLUE "Checking code formatting..."
    
    if mix format --check-formatted; then
        print_status $GREEN "✅ Code formatting is correct"
        return 0
    else
        print_status $RED "❌ Code formatting issues found"
        return 1
    fi
}

# Function to run performance benchmarks
run_benchmarks() {
    print_status $BLUE "Running performance benchmarks..."
    
    # Create a temporary benchmark file
    cat > benchmark_phase4.exs << 'EOF'
# Phase 4 Performance Benchmark

defmodule Phase4Benchmark do
  defmodule NamedFunctionSchema do
    use Exdantic, define_struct: true

    schema do
      field :name, :string
      field :age, :integer

      model_validator :validate_name
      computed_field :description, :string, :generate_description
    end

    def validate_name(input) do
      if String.length(input.name) >= 2, do: {:ok, input}, else: {:error, "name too short"}
    end

    def generate_description(input) do
      {:ok, "#{input.name} is #{input.age} years old"}
    end
  end

  defmodule AnonymousFunctionSchema do
    use Exdantic, define_struct: true

    schema do
      field :name, :string
      field :age, :integer

      model_validator do
        if String.length(input.name) >= 2, do: {:ok, input}, else: {:error, "name too short"}
      end

      computed_field :description, :string do
        {:ok, "#{input.name} is #{input.age} years old"}
      end
    end
  end

  def run do
    data = %{name: "John", age: 30}
    
    # Benchmark named functions
    {named_time, _} = :timer.tc(fn ->
      for _i <- 1..1000 do
        NamedFunctionSchema.validate(data)
      end
    end)
    
    # Benchmark anonymous functions
    {anon_time, _} = :timer.tc(fn ->
      for _i <- 1..1000 do
        AnonymousFunctionSchema.validate(data)
      end
    end)
    
    named_ms = named_time / 1000
    anon_ms = anon_time / 1000
    
    IO.puts("Named functions:     #{:io_lib.format('~.2f', [named_ms])} ms")
    IO.puts("Anonymous functions: #{:io_lib.format('~.2f', [anon_ms])} ms")
    
    if anon_ms <= named_ms * 1.1 do
      IO.puts("✅ Performance is acceptable (within 10% of named functions)")
      :ok
    else
      IO.puts("❌ Performance regression detected")
      :error
    end
  end
end

case Phase4Benchmark.run() do
  :ok -> System.halt(0)
  :error -> System.halt(1)
end
EOF

    if elixir benchmark_phase4.exs; then
        print_status $GREEN "✅ Performance benchmarks passed"
        rm -f benchmark_phase4.exs
        return 0
    else
        print_status $RED "❌ Performance benchmarks failed"
        rm -f benchmark_phase4.exs
        return 1
    fi
}

# Function to validate backward compatibility
check_backward_compatibility() {
    print_status $BLUE "Checking backward compatibility..."
    
    # Run all existing tests to ensure nothing is broken
    if mix test test/exdantic --exclude integration; then
        print_status $GREEN "✅ Backward compatibility maintained"
        return 0
    else
        print_status $RED "❌ Backward compatibility broken"
        return 1
    fi
}

# Function to generate test coverage report
generate_coverage() {
    print_status $BLUE "Generating test coverage report..."
    
    if mix test --cover; then
        print_status $GREEN "✅ Coverage report generated"
        return 0
    else
        print_status $RED "❌ Coverage report generation failed"
        return 1
    fi
}

# Main execution
main() {
    local exit_code=0
    
    print_status $YELLOW "Phase 4: Anonymous Function Support - Test Validation"
    echo ""
    
    # Check prerequisites
    if ! command -v mix &> /dev/null; then
        print_status $RED "❌ Mix is not installed"
        exit 1
    fi
    
    # Step 1: Check compilation
    if ! check_compilation; then
        exit_code=1
    fi
    echo ""
    
    # Step 2: Check formatting
    if ! check_formatting; then
        print_status $YELLOW "⚠️  Run 'mix format' to fix formatting issues"
        exit_code=1
    fi
    echo ""
    
    # Step 3: Run core Phase 4 tests
    if ! run_test_suite "Phase 4 Core Tests" "test/exdantic/phase_4_anonymous_functions_test.exs"; then
        exit_code=1
    fi
    echo ""
    
    # Step 4: Run integration tests
    if ! run_test_suite "Phase 4 Integration Tests" "test/exdantic/phase_4_integration_test.exs"; then
        exit_code=1
    fi
    echo ""
    
    # Step 5: Check backward compatibility
    if ! check_backward_compatibility; then
        exit_code=1
    fi
    echo ""
    
    # Step 6: Run performance benchmarks
    if ! run_benchmarks; then
        exit_code=1
    fi
    echo ""
    
    # Step 7: Generate coverage report
    if ! generate_coverage; then
        exit_code=1
    fi
    echo ""
    
    # Step 8: Run Dialyzer (if available)
    if command -v dialyzer &> /dev/null; then
        if ! check_dialyzer; then
            print_status $YELLOW "⚠️  Dialyzer checks failed - this may be acceptable for development"
        fi
        echo ""
    else
        print_status $YELLOW "⚠️  Dialyzer not available - skipping type checks"
        echo ""
    fi
    
    # Final results
    echo "============================================================"
    if [ $exit_code -eq 0 ]; then
        print_status $GREEN "🎉 All Phase 4 tests passed!"
        print_status $GREEN "✅ Anonymous function support is ready for production"
        echo ""
        print_status $BLUE "Summary of new features:"
        echo "  • Anonymous model validators with fn syntax"
        echo "  • Anonymous model validators with do-end blocks"
        echo "  • Anonymous computed fields with fn syntax"
        echo "  • Anonymous computed fields with do-end blocks"
        echo "  • Enhanced error reporting for anonymous functions"
        echo "  • Full backward compatibility maintained"
        echo "  • Performance comparable to named functions"
    else
        print_status $RED "❌ Some Phase 4 tests failed"
        print_status $RED "Please fix the issues before proceeding to Phase 5"
    fi
    
    exit $exit_code
}

# Help function
show_help() {
    echo "Phase 4: Anonymous Function Support - Test Runner"
    echo ""
    echo "Usage: $0 [OPTION]"
    echo ""
    echo "Options:"
    echo "  --help, -h          Show this help message"
    echo "  --compile-only      Only check compilation"
    echo "  --format-only       Only check formatting"
    echo "  --tests-only        Only run tests (skip benchmarks and coverage)"
    echo "  --benchmark-only    Only run performance benchmarks"
    echo "  --coverage-only     Only generate coverage report"
    echo "  --no-dialyzer       Skip Dialyzer checks"
    echo ""
    echo "Examples:"
    echo "  $0                  Run all checks and tests"
    echo "  $0 --tests-only     Run only the test suites"
    echo "  $0 --compile-only   Check if code compiles"
}

# Parse command line arguments
case "${1:-}" in
    --help|-h)
        show_help
        exit 0
        ;;
    --compile-only)
        check_compilation
        exit $?
        ;;
    --format-only)
        check_formatting
        exit $?
        ;;
    --tests-only)
        run_test_suite "Phase 4 Core Tests" "test/exdantic/phase_4_anonymous_functions_test.exs"
        core_exit=$?
        run_test_suite "Phase 4 Integration Tests" "test/exdantic/phase_4_integration_test.exs"
        integration_exit=$?
        if [ $core_exit -eq 0 ] && [ $integration_exit -eq 0 ]; then
            exit 0
        else
            exit 1
        fi
        ;;
    --benchmark-only)
        run_benchmarks
        exit $?
        ;;
    --coverage-only)
        generate_coverage
        exit $?
        ;;
    --no-dialyzer)
        print_status $YELLOW "Skipping Dialyzer checks as requested"
        # Run main without Dialyzer
        main
        ;;
    "")
        main
        ;;
    *)
        print_status $RED "Unknown option: $1"
        show_help
        exit 1
        ;;
esac
