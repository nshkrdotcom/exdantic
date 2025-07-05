defmodule Exdantic.ModelValidatorIntegrationTest do
  use ExUnit.Case

  @moduletag :integration

  # Define all test schemas at module level to avoid compilation issues
  defmodule EnhancedIntegrationSchema do
    use Exdantic, define_struct: true

    schema do
      field(:value, :integer, required: true)
      model_validator(:validate_positive)
    end

    def validate_positive(data) do
      if data.value > 0, do: {:ok, data}, else: {:error, "must be positive"}
    end
  end

  defmodule JsonSchemaIntegrationTest do
    use Exdantic, define_struct: true

    schema do
      field(:name, :string, required: true)
      model_validator(:validate_name_length)
    end

    def validate_name_length(data) do
      if String.length(data.name) > 2, do: {:ok, data}, else: {:error, "name too short"}
    end
  end

  defmodule FullFeatureSchema do
    use Exdantic, define_struct: true

    schema "Full feature test" do
      field :name, :string do
        required()
        min_length(2)
        max_length(50)
      end

      field :age, :integer do
        optional()
        gteq(0)
        lteq(150)
      end

      field :tags, {:array, :string} do
        optional()
        min_items(1)
      end

      model_validator(:validate_age_name_consistency)

      config do
        title("Full Feature Schema")
        strict(true)
      end
    end

    def validate_age_name_consistency(data) do
      # Silly example: if age > 100, name must start with "Elder"
      if data.age && data.age > 100 do
        if String.starts_with?(data.name, "Elder") do
          {:ok, data}
        else
          {:error, "centenarians must have names starting with 'Elder'"}
        end
      else
        {:ok, data}
      end
    end
  end

  defmodule PerfTestSchema do
    use Exdantic, define_struct: true

    schema do
      field(:value, :integer, required: true)
      model_validator(:simple_validation)
    end

    def simple_validation(data) do
      if data.value > 0, do: {:ok, data}, else: {:error, "positive only"}
    end
  end

  defmodule PerfTestNoValidator do
    use Exdantic, define_struct: true

    schema do
      field(:value, :integer, required: true)
    end
  end

  defmodule MultiPerfSchema do
    use Exdantic, define_struct: true

    schema do
      field(:a, :integer, required: true)
      field(:b, :integer, required: true)
      field(:c, :integer, required: true)

      model_validator(:validate_a)
      model_validator(:validate_b)
      model_validator(:validate_c)
    end

    def validate_a(data), do: if(data.a > 0, do: {:ok, data}, else: {:error, "a positive"})
    def validate_b(data), do: if(data.b > 0, do: {:ok, data}, else: {:error, "b positive"})
    def validate_c(data), do: if(data.c > 0, do: {:ok, data}, else: {:error, "c positive"})
  end

  describe "integration with existing Exdantic features" do
    test "model validators work with EnhancedValidator" do
      # Test with EnhancedValidator
      assert {:ok, result} =
               Exdantic.EnhancedValidator.validate(EnhancedIntegrationSchema, %{value: 5})

      assert %EnhancedIntegrationSchema{} = result
      assert result.value == 5

      assert {:error, _} =
               Exdantic.EnhancedValidator.validate(EnhancedIntegrationSchema, %{value: -1})
    end

    test "model validators work with JSON schema generation" do
      # JSON schema generation should work normally (model validators don't affect schema)
      json_schema = Exdantic.JsonSchema.from_schema(JsonSchemaIntegrationTest)

      assert json_schema["type"] == "object"
      assert Map.has_key?(json_schema, "properties")
      assert Map.has_key?(json_schema["properties"], "name")
      # Model validators should not appear in JSON schema
      refute Map.has_key?(json_schema, "modelValidators")
    end

    test "model validators work with TypeAdapter" do
      # TypeAdapter should be unaffected by model validators since it works with types, not schemas
      assert {:ok, 42} = Exdantic.TypeAdapter.validate(:integer, "42", coerce: true)
    end

    test "model validators preserve all existing schema functionality" do
      # Test all field validations still work
      valid_data = %{name: "Elder Smith", age: 105, tags: ["wise", "old"]}
      assert {:ok, result} = FullFeatureSchema.validate(valid_data)
      assert %FullFeatureSchema{} = result

      # Test field validation failures
      # Too short
      assert {:error, _} = FullFeatureSchema.validate(%{name: "X"})
      # Age negative
      assert {:error, _} = FullFeatureSchema.validate(%{name: "Valid", age: -1})

      # Test model validation failure
      # Age > 100 but name doesn't start with Elder
      invalid_data = %{name: "Young Smith", age: 105}
      assert {:error, errors} = FullFeatureSchema.validate(invalid_data)

      # Handle case where errors might be a single error or list
      error_list = if is_list(errors), do: errors, else: [errors]
      assert hd(error_list).message == "centenarians must have names starting with 'Elder'"

      # Test schema introspection still works
      assert FullFeatureSchema.__schema__(:description) == "Full feature test"
      assert length(FullFeatureSchema.__schema__(:fields)) == 3
      assert length(FullFeatureSchema.__schema__(:model_validators)) == 1
    end
  end

  describe "performance characteristics" do
    @tag :performance
    test "model validators add minimal overhead" do
      data = %{value: 42}

      # Warm up
      PerfTestSchema.validate(data)
      PerfTestNoValidator.validate(data)

      # Measure without model validator
      {time_without, _} =
        :timer.tc(fn ->
          Enum.each(1..1000, fn _ ->
            PerfTestNoValidator.validate(data)
          end)
        end)

      # Measure with model validator
      {time_with, _} =
        :timer.tc(fn ->
          Enum.each(1..1000, fn _ ->
            PerfTestSchema.validate(data)
          end)
        end)

      overhead_ratio = time_with / time_without

      # Model validator should add less than 50% overhead
      assert overhead_ratio < 1.5, "Model validator overhead ratio: #{overhead_ratio}"
    end

    @tag :performance
    test "multiple model validators performance is reasonable" do
      data = %{a: 1, b: 2, c: 3}

      {time_micro, _} =
        :timer.tc(fn ->
          Enum.each(1..1000, fn _ ->
            MultiPerfSchema.validate(data)
          end)
        end)

      avg_time_ms = time_micro / 1000 / 1000

      # Should complete 1000 validations with 3 model validators in reasonable time
      assert avg_time_ms < 2.0, "Multiple validators too slow: #{avg_time_ms}ms avg"
    end
  end
end
