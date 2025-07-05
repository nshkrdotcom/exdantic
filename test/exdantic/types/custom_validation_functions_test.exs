defmodule Exdantic.Types.CustomValidationFunctionsTest do
  use ExUnit.Case, async: true
  alias Exdantic.Types
  alias Exdantic.Validator

  describe "with_validator/2" do
    test "adds custom validator function for simple validation" do
      validator_fn = fn value ->
        if String.contains?(value, "@"), do: {:ok, value}, else: {:error, "Must contain @"}
      end

      type =
        Types.string()
        |> Types.with_constraints(min_length: 3)
        |> Types.with_validator(validator_fn)

      assert {:type, :string,
              [
                {:min_length, 3},
                {:validator, ^validator_fn}
              ]} = type
    end

    test "adds custom validator function for complex validation" do
      validator_fn = fn value ->
        cond do
          String.length(value) < 5 -> {:error, "Too short for complex validation"}
          not String.contains?(value, "@") -> {:error, "Must be an email"}
          not String.match?(value, ~r/.*\.com$/) -> {:error, "Must end with .com"}
          true -> {:ok, value}
        end
      end

      type =
        Types.string()
        |> Types.with_validator(validator_fn)

      assert {:type, :string, [{:validator, ^validator_fn}]} = type
    end

    test "works with integer type" do
      validator_fn = fn value ->
        if rem(value, 2) == 0, do: {:ok, value}, else: {:error, "Must be even"}
      end

      type =
        Types.integer()
        |> Types.with_constraints(gt: 0)
        |> Types.with_validator(validator_fn)

      assert {:type, :integer, [{:gt, 0}, {:validator, ^validator_fn}]} = type
    end

    test "works with array type" do
      validator_fn = fn value ->
        if Enum.all?(value, &is_binary/1),
          do: {:ok, value},
          else: {:error, "All elements must be strings"}
      end

      type =
        Types.array(Types.string())
        |> Types.with_constraints(min_items: 1)
        |> Types.with_validator(validator_fn)

      assert {:array, {:type, :string, []}, [{:min_items, 1}, {:validator, ^validator_fn}]} = type
    end

    test "multiple validators can be added" do
      validator_fn1 = fn value ->
        if String.contains?(value, "@"), do: {:ok, value}, else: {:error, "Must contain @"}
      end

      validator_fn2 = fn value ->
        if String.match?(value, ~r/.*\.com$/),
          do: {:ok, value},
          else: {:error, "Must end with .com"}
      end

      type =
        Types.string()
        |> Types.with_validator(validator_fn1)
        |> Types.with_validator(validator_fn2)

      assert {:type, :string, [{:validator, ^validator_fn1}, {:validator, ^validator_fn2}]} = type
    end
  end

  describe "validation with custom validator functions" do
    test "validates successfully when custom validator passes" do
      validator_fn = fn value ->
        if String.contains?(value, "@"), do: {:ok, value}, else: {:error, "Must contain @"}
      end

      type =
        Types.string()
        |> Types.with_constraints(min_length: 3)
        |> Types.with_validator(validator_fn)

      assert {:ok, "test@example.com"} = Validator.validate(type, "test@example.com")
    end

    test "fails validation when custom validator fails" do
      validator_fn = fn value ->
        if String.contains?(value, "@"), do: {:ok, value}, else: {:error, "Must contain @"}
      end

      type =
        Types.string()
        |> Types.with_constraints(min_length: 3)
        |> Types.with_validator(validator_fn)

      assert {:error, error} = Validator.validate(type, "test")
      assert error.message == "Must contain @"
      assert error.code == :custom_validation
      assert error.path == []
    end

    test "custom validator runs after regular constraints" do
      validator_fn = fn value ->
        if String.contains?(value, "@"), do: {:ok, value}, else: {:error, "Must contain @"}
      end

      type =
        Types.string()
        |> Types.with_constraints(min_length: 10)
        |> Types.with_validator(validator_fn)

      # Should fail min_length constraint first
      assert {:error, error} = Validator.validate(type, "test")
      assert error.message == "failed min_length constraint"
      assert error.code == :min_length
    end

    test "custom validator can transform the value" do
      validator_fn = fn value ->
        {:ok, String.downcase(value)}
      end

      type =
        Types.string()
        |> Types.with_validator(validator_fn)

      assert {:ok, "hello@example.com"} = Validator.validate(type, "HELLO@EXAMPLE.COM")
    end

    test "complex custom validator with multiple conditions" do
      email_validator = fn value ->
        cond do
          not String.contains?(value, "@") ->
            {:error, "Must be a valid email address"}

          not String.match?(value, ~r/^[^@]+@[^@]+\.[^@]+$/) ->
            {:error, "Email format is invalid"}

          String.length(value) > 100 ->
            {:error, "Email address too long"}

          true ->
            {:ok, String.downcase(value)}
        end
      end

      type =
        Types.string()
        |> Types.with_constraints(min_length: 5)
        |> Types.with_validator(email_validator)

      # Valid email
      assert {:ok, "test@example.com"} = Validator.validate(type, "TEST@EXAMPLE.COM")

      # Missing @
      assert {:error, error} = Validator.validate(type, "testexample.com")
      assert error.message == "Must be a valid email address"

      # Invalid format
      assert {:error, error} = Validator.validate(type, "test@@example.com")
      assert error.message == "Email format is invalid"

      # Too long
      long_email = String.duplicate("a", 90) <> "@example.com"
      assert {:error, error} = Validator.validate(type, long_email)
      assert error.message == "Email address too long"

      # Too short (constraint fails first)
      assert {:error, error} = Validator.validate(type, "a@b")
      assert error.message == "failed min_length constraint"
      assert error.code == :min_length
    end

    test "integer custom validator" do
      even_validator = fn value ->
        if rem(value, 2) == 0, do: {:ok, value}, else: {:error, "Must be even"}
      end

      type =
        Types.integer()
        |> Types.with_constraints(gt: 0, lt: 100)
        |> Types.with_validator(even_validator)

      # Valid even number
      assert {:ok, 42} = Validator.validate(type, 42)

      # Invalid odd number
      assert {:error, error} = Validator.validate(type, 43)
      assert error.message == "Must be even"
      assert error.code == :custom_validation

      # Constraint fails first
      assert {:error, error} = Validator.validate(type, -2)
      assert error.message == "failed gt constraint"
      assert error.code == :gt
    end

    test "array custom validator" do
      no_duplicates_validator = fn value ->
        if length(Enum.uniq(value)) == length(value),
          do: {:ok, value},
          else: {:error, "Array must not contain duplicates"}
      end

      type =
        Types.array(Types.string())
        |> Types.with_constraints(min_items: 2)
        |> Types.with_validator(no_duplicates_validator)

      # Valid array
      assert {:ok, ["a", "b", "c"]} = Validator.validate(type, ["a", "b", "c"])

      # Array with duplicates
      assert {:error, [error]} = Validator.validate(type, ["a", "b", "a"])
      assert error.message == "Array must not contain duplicates"
      assert error.code == :custom_validation

      # Constraint fails first
      assert {:error, [error]} = Validator.validate(type, ["a"])
      assert error.message == "failed min_items constraint"
      assert error.code == :min_items
    end

    test "multiple custom validators execute in order" do
      validator_fn1 = fn value ->
        if String.contains?(value, "@"), do: {:ok, value}, else: {:error, "Must contain @"}
      end

      validator_fn2 = fn value ->
        if String.match?(value, ~r/.*\.com$/),
          do: {:ok, value},
          else: {:error, "Must end with .com"}
      end

      type =
        Types.string()
        |> Types.with_validator(validator_fn1)
        |> Types.with_validator(validator_fn2)

      # Both validators pass
      assert {:ok, "test@example.com"} = Validator.validate(type, "test@example.com")

      # First validator fails
      assert {:error, error} = Validator.validate(type, "testexample.com")
      assert error.message == "Must contain @"

      # First passes, second fails
      assert {:error, error} = Validator.validate(type, "test@example.org")
      assert error.message == "Must end with .com"
    end

    test "custom validators work with custom error messages" do
      validator_fn = fn value ->
        if String.contains?(value, "@"), do: {:ok, value}, else: {:error, "Must contain @"}
      end

      type =
        Types.string()
        |> Types.with_constraints(min_length: 3)
        |> Types.with_error_message(:min_length, "Name too short")
        |> Types.with_validator(validator_fn)

      # Custom error message for constraint
      assert {:error, error} = Validator.validate(type, "ab")
      assert error.message == "Name too short"
      assert error.code == :min_length

      # Custom validator error
      assert {:error, error} = Validator.validate(type, "test")
      assert error.message == "Must contain @"
      assert error.code == :custom_validation
    end
  end

  describe "edge cases" do
    test "custom validator with invalid function arity raises error at definition time" do
      assert_raise FunctionClauseError, fn ->
        Types.string()
        # Wrong arity
        |> Types.with_validator(fn -> :ok end)
      end
    end

    test "custom validator that returns invalid format is handled gracefully" do
      bad_validator = fn _value -> :invalid_return end

      type =
        Types.string()
        |> Types.with_validator(bad_validator)

      # Should return an error with a descriptive message
      assert {:error, error} = Validator.validate(type, "test")
      assert error.code == :custom_validation
      assert String.contains?(error.message, "Custom validator returned invalid format")
      assert String.contains?(error.message, ":invalid_return")
    end

    test "custom validator that throws exception is handled" do
      throwing_validator = fn _value ->
        raise "Something went wrong"
      end

      type =
        Types.string()
        |> Types.with_validator(throwing_validator)

      # The exception should be raised during validation
      # Note: The validator framework doesn't currently catch exceptions
      # This is expected behavior - let exceptions bubble up
      assert_raise RuntimeError, "Something went wrong", fn ->
        Validator.validate(type, "test")
      end
    end

    test "custom validator with complex types" do
      # Validator that checks map structure
      map_validator = fn value ->
        required_keys = [:name, :age]

        if Enum.all?(required_keys, &Map.has_key?(value, &1)),
          do: {:ok, value},
          else: {:error, "Map must have both name and age keys"}
      end

      # Note: This would typically be used with a map type, but we're testing
      # that the validator function itself works
      type =
        Types.map(Types.string(), Types.string())
        |> Types.with_validator(map_validator)

      # Would need actual map validation implementation to test fully
      # This mainly tests that the validator function is stored correctly
      assert {:map, _, [{:validator, ^map_validator}]} = type
    end
  end

  describe "integration with existing constraint system" do
    test "custom validators work alongside all constraint types" do
      unique_validator = fn value ->
        chars = String.graphemes(value)

        if length(Enum.uniq(chars)) == length(chars),
          do: {:ok, value},
          else: {:error, "String must have unique characters"}
      end

      type =
        Types.string()
        |> Types.with_constraints(
          min_length: 3,
          max_length: 10,
          format: ~r/^[a-z]+$/,
          choices: ["abc", "def", "ghi", "jklm"]
        )
        |> Types.with_error_messages(
          min_length: "Too short",
          max_length: "Too long",
          format: "Lowercase only",
          choices: "Must be abc, def, ghi, or jklm"
        )
        |> Types.with_validator(unique_validator)

      # All constraints and validator pass
      assert {:ok, "abc"} = Validator.validate(type, "abc")

      # min_length fails first
      assert {:error, error} = Validator.validate(type, "ab")
      assert error.message == "Too short"

      # format fails
      assert {:error, error} = Validator.validate(type, "ABC")
      assert error.message == "Lowercase only"

      # choices fails
      assert {:error, error} = Validator.validate(type, "xyz")
      assert error.message == "Must be abc, def, ghi, or jklm"

      # Custom validator would fail (but choices fails first)
      # We can't easily test this case since "aaa" would fail choices first
    end

    test "validator execution order is constraints then custom validators" do
      # This test verifies that built-in constraints are always checked first
      validator_fn = fn _value ->
        # This validator always fails, but should only be reached
        # if all constraints pass
        {:error, "Custom validator always fails"}
      end

      type =
        Types.string()
        |> Types.with_constraints(min_length: 10)
        |> Types.with_validator(validator_fn)

      # Constraint should fail first, validator never reached
      assert {:error, error} = Validator.validate(type, "short")
      assert error.message == "failed min_length constraint"
      assert error.code == :min_length

      # When constraint passes, validator is reached
      assert {:error, error} = Validator.validate(type, "long enough string")
      assert error.message == "Custom validator always fails"
      assert error.code == :custom_validation
    end
  end
end
