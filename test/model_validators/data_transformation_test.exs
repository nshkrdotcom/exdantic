defmodule Exdantic.DataTransformationTest do
  use ExUnit.Case
  alias Exdantic.ModelValidatorTestSchemas.{DataEnhancer, DataTransformer}

  describe "data transformation in model validators" do
    test "model validator can transform data" do
      data = %{name: "  John Doe  ", email: "  JOHN@EXAMPLE.COM  "}

      assert {:ok, result} = DataTransformer.validate(data)
      assert %DataTransformer{} = result
      # Trimmed
      assert result.name == "John Doe"
      # Trimmed and lowercased
      assert result.email == "john@example.com"
    end

    test "model validator can add additional fields to struct" do
      data = %{first_name: "John", last_name: "Doe"}

      assert {:ok, result} = DataEnhancer.validate(data)
      assert %DataEnhancer{} = result
      assert result.first_name == "John"
      assert result.last_name == "Doe"
      # Added by model validator
      assert result.full_name == "John Doe"
    end

    test "transformed data maintains struct type" do
      data = %{name: "test", email: "test@example.com"}

      assert {:ok, result} = DataTransformer.validate(data)
      assert is_struct(result, DataTransformer)
      assert result.__struct__ == DataTransformer
    end
  end
end
