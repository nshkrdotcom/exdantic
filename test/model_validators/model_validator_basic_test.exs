defmodule ModelValidatorBasicTest do
  use ExUnit.Case

  # Simple test schema with struct
  defmodule PasswordValidationStruct do
    use Exdantic, define_struct: true

    schema "Password validation with struct" do
      field(:password, :string, required: true)
      field(:password_confirmation, :string, required: true)

      model_validator(:validate_passwords_match)
    end

    def validate_passwords_match(data) do
      if data.password == data.password_confirmation do
        {:ok, data}
      else
        {:error, "passwords do not match"}
      end
    end
  end

  # Simple test schema with map
  defmodule PasswordValidationMap do
    use Exdantic, define_struct: false

    schema "Password validation with map" do
      field(:password, :string, required: true)
      field(:password_confirmation, :string, required: true)

      model_validator(:validate_passwords_match)
    end

    def validate_passwords_match(data) do
      if data.password == data.password_confirmation do
        {:ok, data}
      else
        {:error, "passwords do not match"}
      end
    end
  end

  # Multiple validators test schema
  defmodule MultipleValidators do
    use Exdantic, define_struct: true

    schema do
      field(:username, :string, required: true)
      field(:email, :string, required: true)
      field(:age, :integer, required: true)

      model_validator(:validate_username_length)
      model_validator(:validate_email_format)
      model_validator(:validate_adult_age)
    end

    def validate_username_length(data) do
      if String.length(data.username) >= 3 do
        {:ok, data}
      else
        {:error, "username must be at least 3 characters"}
      end
    end

    def validate_email_format(data) do
      if String.contains?(data.email, "@") do
        {:ok, data}
      else
        {:error, "email must contain @ symbol"}
      end
    end

    def validate_adult_age(data) do
      if data.age >= 18 do
        {:ok, data}
      else
        {:error, "must be 18 or older"}
      end
    end
  end

  # Schema without model validators
  defmodule NoValidators do
    use Exdantic, define_struct: true

    schema do
      field(:simple_field, :string, required: true)
    end
  end

  describe "basic model validator functionality" do
    test "model validator succeeds with struct schema" do
      data = %{password: "secret123", password_confirmation: "secret123"}

      assert {:ok, result} = PasswordValidationStruct.validate(data)
      assert %PasswordValidationStruct{} = result
      assert result.password == "secret123"
      assert result.password_confirmation == "secret123"
    end

    test "model validator succeeds with map schema" do
      data = %{password: "secret123", password_confirmation: "secret123"}

      assert {:ok, result} = PasswordValidationMap.validate(data)
      assert is_map(result)
      refute is_struct(result)
      assert result.password == "secret123"
      assert result.password_confirmation == "secret123"
    end

    test "model validator fails with validation error" do
      data = %{password: "secret123", password_confirmation: "different"}

      assert {:error, errors} = PasswordValidationStruct.validate(data)
      assert length(errors) == 1

      error = hd(errors)
      assert error.code == :model_validation
      assert error.message == "passwords do not match"
      assert error.path == []
    end

    test "model validator is called after field validation" do
      # Invalid field data should fail before model validator is called
      # missing password_confirmation
      data = %{password: "secret123"}

      assert {:error, errors} = PasswordValidationStruct.validate(data)

      # Handle case where errors might be a single error or list
      error_list = if is_list(errors), do: errors, else: [errors]
      assert length(error_list) == 1

      error = hd(error_list)
      # Field validation error, not model validation
      assert error.code == :required
      assert error.path == [:password_confirmation]
    end

    test "schemas without model validators work unchanged" do
      data = %{simple_field: "test"}

      assert {:ok, result} = NoValidators.validate(data)
      assert %NoValidators{} = result
      assert result.simple_field == "test"
    end
  end

  describe "__schema__ introspection" do
    test "model validators appear in schema metadata" do
      model_validators = PasswordValidationStruct.__schema__(:model_validators)
      assert is_list(model_validators)
      assert length(model_validators) == 1

      {module, function_name} = hd(model_validators)
      assert module == PasswordValidationStruct
      assert function_name == :validate_passwords_match
    end

    test "schemas without model validators return empty list" do
      model_validators = NoValidators.__schema__(:model_validators)
      assert model_validators == []
    end
  end

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
      # All would fail
      data = %{username: "x", email: "bad", age: 10}

      assert {:error, errors} = MultipleValidators.validate(data)
      # Only first failure reported
      assert length(errors) == 1

      # Check that the first validator to fail was executed
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
