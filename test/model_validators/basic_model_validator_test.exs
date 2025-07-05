defmodule Exdantic.BasicModelValidatorTest do
  use ExUnit.Case

  alias Exdantic.ModelValidatorTestSchemas.{
    NoValidators,
    PasswordValidationMap,
    PasswordValidationStruct
  }

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
end
