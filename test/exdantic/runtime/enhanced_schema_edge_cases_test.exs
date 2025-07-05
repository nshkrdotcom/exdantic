defmodule Exdantic.Runtime.EnhancedSchemaEdgeCasesTest do
  use ExUnit.Case, async: true

  alias Exdantic.Runtime.EnhancedSchema
  # No aliases needed for this test module

  describe "edge cases and error conditions" do
    test "handles empty field definitions" do
      schema = EnhancedSchema.create([])

      assert %EnhancedSchema{} = schema
      assert map_size(schema.base_schema.fields) == 0
      assert schema.model_validators == []
      assert schema.computed_fields == []
    end

    test "handles nil values in model validators" do
      fields = [{:name, :string, [required: true]}]

      validator = fn data ->
        if is_nil(data.name) do
          {:error, "name cannot be nil"}
        else
          {:ok, data}
        end
      end

      schema = EnhancedSchema.create(fields, model_validators: [validator])

      # Test with nil value
      assert {:error, [error]} = EnhancedSchema.validate(%{name: nil}, schema)
      assert error.code == :model_validation
      assert error.message == "name cannot be nil"
    end

    test "handles exceptions in model validators" do
      fields = [{:name, :string, [required: true]}]

      failing_validator = fn _data ->
        raise RuntimeError, "something went wrong"
      end

      schema = EnhancedSchema.create(fields, model_validators: [failing_validator])

      assert {:error, [error]} = EnhancedSchema.validate(%{name: "test"}, schema)
      assert error.code == :model_validation
      assert error.message =~ "Exception: something went wrong"
    end

    test "handles exceptions in computed fields" do
      fields = [{:name, :string, [required: true]}]

      failing_computer = fn _data ->
        raise RuntimeError, "computation failed"
      end

      computed_fields = [{:result, :string, failing_computer}]

      schema = EnhancedSchema.create(fields, computed_fields: computed_fields)

      assert {:error, [error]} = EnhancedSchema.validate(%{name: "test"}, schema)
      assert error.code == :computed_field
      assert error.message =~ "Exception: computation failed"
    end

    test "handles invalid return values from model validators" do
      fields = [{:name, :string, [required: true]}]

      bad_validator = fn _data ->
        "not a valid return"
      end

      schema = EnhancedSchema.create(fields, model_validators: [bad_validator])

      assert {:error, [error]} = EnhancedSchema.validate(%{name: "test"}, schema)
      assert error.code == :model_validation
      assert error.message =~ "Invalid return"
    end

    test "handles invalid return values from computed fields" do
      fields = [{:name, :string, [required: true]}]

      bad_computer = fn _data ->
        "not a valid return"
      end

      computed_fields = [{:result, :string, bad_computer}]

      schema = EnhancedSchema.create(fields, computed_fields: computed_fields)

      assert {:error, [error]} = EnhancedSchema.validate(%{name: "test"}, schema)
      assert error.code == :computed_field
      assert error.message =~ "Invalid return"
    end

    test "handles deeply nested field paths in errors" do
      fields = [{:user, {:map, {:string, :any}}, [required: true]}]

      validator = fn data ->
        case get_in(data, [:user, "profile", "name"]) do
          nil -> {:error, "nested name is required"}
          _ -> {:ok, data}
        end
      end

      schema = EnhancedSchema.create(fields, model_validators: [validator])

      data = %{user: %{"profile" => %{}}}

      assert {:error, [error]} = EnhancedSchema.validate(data, schema)
      assert error.message == "nested name is required"
    end

    test "handles large number of validators and computed fields" do
      fields = [{:value, :integer, [required: true]}]

      # Create many validators
      validators =
        1..50
        |> Enum.map(fn i ->
          fn data -> {:ok, %{data | value: data.value + i}} end
        end)

      # Create many computed fields
      computed_fields =
        1..20
        |> Enum.map(fn i ->
          {:"computed_#{i}", :integer, fn data -> {:ok, data.value * i} end}
        end)

      schema =
        EnhancedSchema.create(fields,
          model_validators: validators,
          computed_fields: computed_fields
        )

      assert {:ok, result} = EnhancedSchema.validate(%{value: 1}, schema)

      # Value should be incremented by sum of 1..50 = 1275
      assert result.value == 1 + Enum.sum(1..50)

      # Check some computed fields
      assert result.computed_1 == result.value
      assert result.computed_10 == result.value * 10
      assert result.computed_20 == result.value * 20
    end

    test "computed fields execute sequentially and can access previous computed fields" do
      fields = [{:base, :integer, [required: true]}]

      # Computed fields execute in order and each has access to previously computed fields
      computed_fields = [
        {:step1, :integer, fn data -> {:ok, data.base * 2} end},
        {:step2, :integer,
         fn data ->
           # step2 can access step1 because it was computed previously
           {:ok, data.step1 * 3}
         end},
        {:step3, :integer, fn data -> {:ok, data.base + 10} end}
      ]

      schema = EnhancedSchema.create(fields, computed_fields: computed_fields)

      # This should succeed and show the sequential computation
      assert {:ok, result} = EnhancedSchema.validate(%{base: 5}, schema)
      assert result.base == 5
      # base * 2
      assert result.step1 == 10
      # step1 * 3
      assert result.step2 == 30
      # base + 10
      assert result.step3 == 15
    end

    test "handles type mismatches in computed field results" do
      fields = [{:name, :string, [required: true]}]

      # Computed field returns wrong type
      wrong_type_computer = fn data ->
        # Returns integer but field expects string
        {:ok, String.length(data.name)}
      end

      computed_fields = [{:name_length_as_string, :string, wrong_type_computer}]

      schema = EnhancedSchema.create(fields, computed_fields: computed_fields)

      assert {:error, [error]} = EnhancedSchema.validate(%{name: "test"}, schema)
      assert error.path == [:name_length_as_string]
    end
  end
end
