defmodule Exdantic.MultipleValidatorsTest do
  use ExUnit.Case
  alias Exdantic.ModelValidatorTestSchemas.MultipleValidators

  describe "multiple model validators" do
    test "all validators pass in sequence" do
      data = %{username: "john_doe", email: "john@example.com", age: 25}

      assert {:ok, result} = MultipleValidators.validate(data)
      assert %MultipleValidators{} = result
      assert result.username == "john_doe"
      assert result.email == "john@example.com"
      assert result.age == 25
    end

    test "fails on first validator" do
      # username too short
      data = %{username: "jo", email: "john@example.com", age: 25}

      assert {:error, errors} = MultipleValidators.validate(data)
      assert length(errors) == 1

      error = hd(errors)
      assert error.code == :model_validation
      assert error.message == "username must be at least 3 characters"
    end

    test "fails on second validator" do
      data = %{username: "john_doe", email: "invalid-email", age: 25}

      assert {:error, errors} = MultipleValidators.validate(data)
      assert length(errors) == 1

      error = hd(errors)
      assert error.code == :model_validation
      assert error.message == "email must contain @ symbol"
    end

    test "fails on third validator" do
      data = %{username: "john_doe", email: "john@example.com", age: 16}

      assert {:error, errors} = MultipleValidators.validate(data)
      assert length(errors) == 1

      error = hd(errors)
      assert error.code == :model_validation
      assert error.message == "must be 18 or older"
    end

    test "validator execution stops at first failure" do
      # This test ensures that if the first validator fails, subsequent ones aren't called
      # We can't directly test this without instrumentation, but we can verify
      # that only one error is returned when multiple validators would fail
      # All would fail
      data = %{username: "x", email: "bad", age: 10}

      assert {:error, errors} = MultipleValidators.validate(data)
      # Only first failure reported
      assert length(errors) == 1

      # Check that the first validator to fail was executed (order may vary)
      error_message = hd(errors).message

      assert error_message in [
               "username must be at least 3 characters",
               "email must contain @ symbol",
               "must be 18 or older"
             ]
    end
  end

  describe "introspection for multiple validators" do
    test "all model validators appear in metadata" do
      model_validators = MultipleValidators.__schema__(:model_validators)
      assert length(model_validators) == 3

      function_names = Enum.map(model_validators, fn {_module, name} -> name end)
      assert :validate_username_length in function_names
      assert :validate_email_format in function_names
      assert :validate_adult_age in function_names
    end
  end
end
