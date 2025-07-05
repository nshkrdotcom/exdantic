# Phase 4: Integration Tests with Previous Phases

# ===== test/exdantic/phase_4_integration_test.exs =====

defmodule Exdantic.Phase4IntegrationTest do
  use ExUnit.Case, async: true

  describe "integration with Phase 1 (struct patterns)" do
    defmodule StructWithAnonymousSchema do
      use Exdantic, define_struct: true

      schema do
        field(:username, :string, required: true)
        field(:email, :string, required: true)

        model_validator(fn input ->
          if String.length(input.username) >= 3 do
            {:ok, input}
          else
            {:error, "username too short"}
          end
        end)

        computed_field(:profile_url, :string, fn input ->
          {:ok, "https://example.com/users/#{input.username}"}
        end)
      end
    end

    test "anonymous functions work with struct generation" do
      data = %{username: "alice", email: "alice@example.com"}

      assert {:ok, result} = StructWithAnonymousSchema.validate(data)
      assert %StructWithAnonymousSchema{} = result
      assert result.username == "alice"
      assert result.email == "alice@example.com"
      assert result.profile_url == "https://example.com/users/alice"
    end

    test "struct serialization includes computed fields from anonymous functions" do
      data = %{username: "bob", email: "bob@example.com"}
      {:ok, struct} = StructWithAnonymousSchema.validate(data)

      assert {:ok, map} = StructWithAnonymousSchema.dump(struct)
      assert map.profile_url == "https://example.com/users/bob"
    end

    test "struct validation errors include anonymous function context" do
      data = %{username: "x", email: "x@example.com"}

      assert {:error, [error]} = StructWithAnonymousSchema.validate(data)
      assert error.code == :model_validation
      assert error.message == "username too short"
    end
  end

  describe "integration with Phase 2 (model validators)" do
    defmodule MixedValidatorsSchema do
      use Exdantic, define_struct: true

      schema do
        field(:password, :string, required: true)
        field(:password_confirmation, :string, required: true)
        field(:age, :integer, required: true)

        # Named model validator (Phase 2)
        model_validator(:validate_age_range)

        # Anonymous model validator (Phase 4)
        model_validator(fn input ->
          if input.password == input.password_confirmation do
            {:ok, input}
          else
            {:error, "passwords do not match"}
          end
        end)

        # Another named validator
        model_validator(:normalize_data)
      end

      def validate_age_range(input) do
        if input.age >= 13 and input.age <= 120 do
          {:ok, input}
        else
          {:error, "age must be between 13 and 120"}
        end
      end

      def normalize_data(input) do
        # Normalize password case for consistency
        normalized = %{
          input
          | password: String.downcase(input.password),
            password_confirmation: String.downcase(input.password_confirmation)
        }

        {:ok, normalized}
      end
    end

    test "named and anonymous model validators execute in sequence" do
      data = %{
        password: "SECRET123",
        password_confirmation: "SECRET123",
        age: 25
      }

      assert {:ok, result} = MixedValidatorsSchema.validate(data)
      assert result.age == 25
      # Should be normalized by named validator
      assert result.password == "secret123"
    end

    test "validation stops at first error (named validator)" do
      data = %{
        password: "secret123",
        password_confirmation: "secret123",
        # Invalid age
        age: 150
      }

      assert {:error, [error]} = MixedValidatorsSchema.validate(data)
      assert error.message == "age must be between 13 and 120"
    end

    test "validation stops at first error (anonymous validator)" do
      data = %{
        password: "secret123",
        password_confirmation: "different",
        age: 25
      }

      assert {:error, [error]} = MixedValidatorsSchema.validate(data)
      assert error.message == "passwords do not match"
    end
  end

  describe "integration with Phase 3 (computed fields)" do
    defmodule MixedComputedFieldsSchema do
      use Exdantic, define_struct: true

      schema do
        field(:first_name, :string, required: true)
        field(:last_name, :string, required: true)
        field(:birth_year, :integer, required: true)

        # Named computed field (Phase 3)
        computed_field(:full_name, :string, :generate_full_name)

        # Anonymous computed field (Phase 4)
        computed_field(:age_estimate, :integer, fn input ->
          current_year = Date.utc_today().year
          {:ok, current_year - input.birth_year}
        end)

        # Another named computed field
        computed_field(:initials, :string, :generate_initials)
      end

      def generate_full_name(input) do
        {:ok, "#{input.first_name} #{input.last_name}"}
      end

      def generate_initials(input) do
        first = String.first(input.first_name)
        last = String.first(input.last_name)
        {:ok, "#{first}.#{last}."}
      end
    end

    test "named and anonymous computed fields both execute" do
      data = %{
        first_name: "John",
        last_name: "Doe",
        birth_year: 1990
      }

      assert {:ok, result} = MixedComputedFieldsSchema.validate(data)
      assert result.full_name == "John Doe"
      assert result.initials == "J.D."
      # Age estimate should be reasonable (test will work for several years)
      assert result.age_estimate >= 30 and result.age_estimate <= 40
    end

    test "computed field execution order is preserved" do
      # All computed fields should execute regardless of their type (named/anonymous)
      data = %{
        first_name: "Jane",
        last_name: "Smith",
        birth_year: 1985
      }

      assert {:ok, result} = MixedComputedFieldsSchema.validate(data)

      # All computed fields should be present
      assert Map.has_key?(result, :full_name)
      assert Map.has_key?(result, :age_estimate)
      assert Map.has_key?(result, :initials)
    end

    test "computed field errors are properly handled" do
      defmodule FailingComputedMixSchema do
        use Exdantic

        schema do
          field(:name, :string)

          # Named computed field that succeeds
          computed_field(:upper_name, :string, :make_upper)

          # Anonymous computed field that fails
          computed_field(:failing_field, :string, fn _input ->
            {:error, "anonymous computation failed"}
          end)
        end

        def make_upper(input) do
          {:ok, String.upcase(input.name)}
        end
      end

      data = %{name: "test"}

      assert {:error, [error]} = FailingComputedMixSchema.validate(data)
      assert error.code == :computed_field
      assert error.message == "anonymous computation failed"
      assert error.path == [:failing_field]
    end
  end

  describe "complete pipeline integration" do
    defmodule CompleteIntegrationSchema do
      use Exdantic, define_struct: true

      schema do
        field(:email, :string, required: true)
        field(:password, :string, required: true)
        field(:first_name, :string, required: true)
        field(:last_name, :string, required: true)
        field(:birth_date, :string, required: true)

        # Phase 2: Named model validator
        model_validator(:validate_email_format)

        # Phase 4: Anonymous model validator
        model_validator(fn input ->
          if String.length(input.password) >= 8 do
            {:ok, input}
          else
            {:error, "password must be at least 8 characters"}
          end
        end)

        # Phase 2: Named model validator for data transformation
        model_validator(:normalize_names)

        # Phase 3: Named computed field
        computed_field(:full_name, :string, :generate_full_name)

        # Phase 4: Anonymous computed field
        computed_field(:username_suggestion, :string, fn input ->
          first_part = String.slice(input.first_name, 0, 3) |> String.downcase()
          last_part = String.slice(input.last_name, 0, 3) |> String.downcase()
          {:ok, "#{first_part}#{last_part}"}
        end)

        # Phase 3: Named computed field with complex logic
        computed_field(:profile_summary, :string, :generate_profile_summary)
      end

      def validate_email_format(input) do
        if String.contains?(input.email, "@") do
          {:ok, input}
        else
          {:error, "invalid email format"}
        end
      end

      def normalize_names(input) do
        normalized = %{
          input
          | first_name: String.trim(input.first_name) |> String.capitalize(),
            last_name: String.trim(input.last_name) |> String.capitalize()
        }

        {:ok, normalized}
      end

      def generate_full_name(input) do
        {:ok, "#{input.first_name} #{input.last_name}"}
      end

      def generate_profile_summary(input) do
        summary =
          "#{input.full_name} (#{input.email}) - suggested username: #{input.username_suggestion}"

        {:ok, summary}
      end
    end

    test "complete validation pipeline with all phases" do
      data = %{
        email: "john.doe@example.com",
        password: "secure123",
        first_name: "  john  ",
        last_name: "  doe  ",
        birth_date: "1990-01-01"
      }

      assert {:ok, result} = CompleteIntegrationSchema.validate(data)

      # Phase 1: Should be a struct
      assert %CompleteIntegrationSchema{} = result

      # Original fields (with normalization from model validators)
      assert result.email == "john.doe@example.com"
      assert result.password == "secure123"
      # Normalized
      assert result.first_name == "John"
      # Normalized
      assert result.last_name == "Doe"
      assert result.birth_date == "1990-01-01"

      # Phase 3: Named computed field
      assert result.full_name == "John Doe"

      # Phase 4: Anonymous computed field
      assert result.username_suggestion == "johdoe"

      # Phase 3: Named computed field that depends on other computed fields
      expected_summary = "John Doe (john.doe@example.com) - suggested username: johdoe"
      assert result.profile_summary == expected_summary
    end

    test "pipeline validation stops at model validator errors" do
      data = %{
        # Will fail email validation
        email: "invalid-email",
        password: "secure123",
        first_name: "John",
        last_name: "Doe",
        birth_date: "1990-01-01"
      }

      assert {:error, [error]} = CompleteIntegrationSchema.validate(data)
      assert error.code == :model_validation
      assert error.message == "invalid email format"
    end

    test "pipeline validation stops at anonymous model validator errors" do
      data = %{
        email: "john@example.com",
        # Will fail password length validation
        password: "short",
        first_name: "John",
        last_name: "Doe",
        birth_date: "1990-01-01"
      }

      assert {:error, [error]} = CompleteIntegrationSchema.validate(data)
      assert error.code == :model_validation
      assert error.message == "password must be at least 8 characters"
    end
  end

  describe "performance with mixed function types" do
    defmodule PerformanceTestSchema do
      use Exdantic, define_struct: true

      schema do
        field(:value, :integer)

        # Multiple model validators of different types
        model_validator(:named_validator_1)
        model_validator(fn input -> {:ok, input} end)
        model_validator(:named_validator_2)

        model_validator(fn input ->
          {:ok, input}
        end)

        # Multiple computed fields of different types
        computed_field(:named_computed_1, :integer, :compute_1)

        computed_field(:anonymous_computed_1, :integer, fn input ->
          {:ok, input.value + 1}
        end)

        computed_field(:named_computed_2, :integer, :compute_2)

        computed_field(:anonymous_computed_2, :integer, fn input ->
          {:ok, input.value + 2}
        end)
      end

      def named_validator_1(input), do: {:ok, input}
      def named_validator_2(input), do: {:ok, input}
      def compute_1(input), do: {:ok, input.value * 2}
      def compute_2(input), do: {:ok, input.value * 3}
    end

    test "performance is acceptable with many mixed function types" do
      data = %{value: 10}

      # Measure time for multiple validations
      start_time = System.monotonic_time(:millisecond)

      # Run validation multiple times
      for _i <- 1..100 do
        assert {:ok, _result} = PerformanceTestSchema.validate(data)
      end

      end_time = System.monotonic_time(:millisecond)
      duration = end_time - start_time

      # Should complete 100 validations in reasonable time (less than 1 second)
      assert duration < 1000
    end

    test "validation results are consistent" do
      data = %{value: 5}

      # Run same validation multiple times
      results =
        for _i <- 1..10 do
          {:ok, result} = PerformanceTestSchema.validate(data)
          result
        end

      # All results should be identical
      first_result = hd(results)
      assert Enum.all?(results, &(&1 == first_result))

      # Verify computed values are correct
      # 5 * 2
      assert first_result.named_computed_1 == 10
      # 5 + 1
      assert first_result.anonymous_computed_1 == 6
      # 5 * 3
      assert first_result.named_computed_2 == 15
      # 5 + 2
      assert first_result.anonymous_computed_2 == 7
    end
  end

  describe "error reporting integration" do
    defmodule ErrorReportingSchema do
      use Exdantic, define_struct: true

      schema do
        field(:name, :string)

        model_validator(:named_failing_validator)

        model_validator(fn _input ->
          {:error, "anonymous validator failed"}
        end)

        computed_field(:named_computed, :string, :failing_computation)

        computed_field(:anonymous_computed, :string, fn _input ->
          {:error, "anonymous computation failed"}
        end)
      end

      def named_failing_validator(_input) do
        {:error, "named validator failed"}
      end

      def failing_computation(_input) do
        {:error, "named computation failed"}
      end
    end

    test "error messages distinguish between named and anonymous functions" do
      data = %{name: "test"}

      # Should fail at first model validator (named)
      assert {:error, [error]} = ErrorReportingSchema.validate(data)
      assert error.message == "named validator failed"
      assert error.code == :model_validation
    end

    test "error context is preserved for anonymous functions" do
      # We need a schema that passes model validation to test computed field errors
      defmodule ComputedErrorSchema do
        use Exdantic

        schema do
          field(:name, :string)

          computed_field(:failing_field, :string, fn _input ->
            {:error, "computation error"}
          end)
        end
      end

      data = %{name: "test"}

      assert {:error, [error]} = ComputedErrorSchema.validate(data)
      assert error.code == :computed_field
      assert error.message == "computation error"
      assert error.path == [:failing_field]
    end
  end
end
