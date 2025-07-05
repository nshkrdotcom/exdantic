defmodule Exdantic.ModelValidatorErrorHandlingTest do
  use ExUnit.Case
  alias Exdantic.ModelValidatorTestSchemas.{ErrorStructValidator, FailingValidator}

  describe "error handling" do
    test "model validator returning Error struct" do
      data = %{value: -5}

      assert {:error, errors} = ErrorStructValidator.validate(data)
      assert length(errors) == 1

      error = hd(errors)
      assert %Exdantic.Error{} = error
      assert error.path == [:value]
      assert error.code == :custom_validation
      assert error.message == "value must be positive"
    end

    test "model validator returning Error struct with success" do
      data = %{value: 10}

      assert {:ok, result} = ErrorStructValidator.validate(data)
      assert result.value == 10
    end

    test "model validator that raises exception" do
      data = %{trigger_failure: true}

      # The validator should catch the exception and convert it to a validation error
      assert {:error, errors} = FailingValidator.validate(data)
      assert length(errors) == 1

      error = hd(errors)
      assert error.code == :model_validation
      assert String.contains?(error.message, "execution failed")
    end

    test "model validator exception doesn't crash validation" do
      data = %{trigger_failure: false}

      # Should work normally when not triggering the exception
      assert {:ok, result} = FailingValidator.validate(data)
      assert result.trigger_failure == false
    end
  end

  describe "invalid model validator return values" do
    test "model validator returning invalid format" do
      defmodule InvalidReturnValidator do
        use Exdantic, define_struct: true

        schema do
          field(:test, :string, required: true)
          model_validator(:invalid_return)
        end

        def invalid_return(_data) do
          # Return invalid format (not {:ok, data} or {:error, reason})
          :invalid_return_format
        end
      end

      data = %{test: "value"}

      assert {:error, errors} = InvalidReturnValidator.validate(data)
      assert length(errors) == 1

      error = hd(errors)
      assert error.code == :model_validation
      assert String.contains?(error.message, "returned invalid format")
    end
  end
end
