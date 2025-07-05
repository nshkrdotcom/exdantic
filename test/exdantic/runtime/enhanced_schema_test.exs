defmodule Exdantic.Runtime.EnhancedSchemaTest do
  use ExUnit.Case, async: true

  alias Exdantic.{ComputedFieldMeta, Error}
  alias Exdantic.Runtime.EnhancedSchema

  describe "create/2" do
    test "creates enhanced schema with basic fields" do
      fields = [{:name, :string, [required: true]}, {:age, :integer, [optional: true]}]

      schema = EnhancedSchema.create(fields)

      assert %EnhancedSchema{} = schema
      assert schema.base_schema.name =~ "DynamicSchema_"
      assert map_size(schema.base_schema.fields) == 2
      assert schema.model_validators == []
      assert schema.computed_fields == []
      assert schema.runtime_functions == %{}
    end

    test "creates enhanced schema with model validators" do
      fields = [{:name, :string, [required: true]}]

      trim_validator = fn data ->
        {:ok, %{data | name: String.trim(data.name)}}
      end

      schema = EnhancedSchema.create(fields, model_validators: [trim_validator])

      assert length(schema.model_validators) == 1
      assert map_size(schema.runtime_functions) == 1

      [{:runtime, function_name}] = schema.model_validators
      assert Map.has_key?(schema.runtime_functions, function_name)
    end

    test "creates enhanced schema with computed fields" do
      fields = [{:name, :string, [required: true]}]

      upcase_computer = fn data ->
        {:ok, String.upcase(data.name)}
      end

      computed_fields = [{:display_name, :string, upcase_computer}]

      schema = EnhancedSchema.create(fields, computed_fields: computed_fields)

      assert length(schema.computed_fields) == 1
      assert map_size(schema.runtime_functions) == 1

      [{:display_name, %ComputedFieldMeta{}}] = schema.computed_fields
    end

    test "creates enhanced schema with named function references" do
      fields = [{:name, :string, [required: true]}]

      # Named model validator
      model_validators = [{TestHelpers, :trim_name}]

      # Named computed field
      computed_fields = [{:display_name, :string, {TestHelpers, :upcase_name}}]

      schema =
        EnhancedSchema.create(fields,
          model_validators: model_validators,
          computed_fields: computed_fields
        )

      assert schema.model_validators == [{TestHelpers, :trim_name}]

      assert [
               {:display_name,
                %ComputedFieldMeta{module: TestHelpers, function_name: :upcase_name}}
             ] = schema.computed_fields

      assert schema.runtime_functions == %{}
    end

    test "creates enhanced schema with mixed validator types" do
      fields = [{:name, :string, [required: true]}]

      # Mix of named and anonymous validators
      anonymous_validator = fn data -> {:ok, %{data | name: String.trim(data.name)}} end
      model_validators = [{TestHelpers, :validate_name}, anonymous_validator]

      schema = EnhancedSchema.create(fields, model_validators: model_validators)

      assert length(schema.model_validators) == 2
      assert [{TestHelpers, :validate_name}, {:runtime, _function_name}] = schema.model_validators
      assert map_size(schema.runtime_functions) == 1
    end
  end

  describe "validate/3" do
    test "validates basic fields successfully" do
      fields = [{:name, :string, [required: true]}, {:age, :integer, [optional: true]}]
      schema = EnhancedSchema.create(fields)

      data = %{name: "John", age: 30}

      assert {:ok, validated} = EnhancedSchema.validate(data, schema)
      assert validated == %{name: "John", age: 30}
    end

    test "applies model validators in sequence" do
      fields = [{:name, :string, [required: true]}]

      trim_validator = fn data ->
        {:ok, %{data | name: String.trim(data.name)}}
      end

      upcase_validator = fn data ->
        {:ok, %{data | name: String.upcase(data.name)}}
      end

      schema =
        EnhancedSchema.create(fields,
          model_validators: [trim_validator, upcase_validator]
        )

      data = %{name: "  john  "}

      assert {:ok, validated} = EnhancedSchema.validate(data, schema)
      assert validated.name == "JOHN"
    end

    test "executes computed fields after model validation" do
      fields = [{:name, :string, [required: true]}]

      trim_validator = fn data ->
        {:ok, %{data | name: String.trim(data.name)}}
      end

      display_computer = fn data ->
        {:ok, "Display: #{data.name}"}
      end

      computed_fields = [{:display_name, :string, display_computer}]

      schema =
        EnhancedSchema.create(fields,
          model_validators: [trim_validator],
          computed_fields: computed_fields
        )

      data = %{name: "  John  "}

      assert {:ok, validated} = EnhancedSchema.validate(data, schema)
      assert validated.name == "John"
      assert validated.display_name == "Display: John"
    end

    test "handles model validator errors" do
      fields = [{:name, :string, [required: true]}]

      failing_validator = fn _data ->
        {:error, "validation failed"}
      end

      schema = EnhancedSchema.create(fields, model_validators: [failing_validator])

      data = %{name: "John"}

      assert {:error, [error]} = EnhancedSchema.validate(data, schema)
      assert %Error{code: :model_validation, message: "validation failed"} = error
    end

    test "handles computed field errors" do
      fields = [{:name, :string, [required: true]}]

      failing_computer = fn _data ->
        {:error, "computation failed"}
      end

      computed_fields = [{:result, :string, failing_computer}]

      schema = EnhancedSchema.create(fields, computed_fields: computed_fields)

      data = %{name: "John"}

      assert {:error, [error]} = EnhancedSchema.validate(data, schema)
      assert %Error{code: :computed_field, message: "computation failed"} = error
    end

    test "validates computed field return values against types" do
      fields = [{:name, :string, [required: true]}]

      # Computer returns wrong type
      bad_computer = fn _data ->
        # Returns integer instead of string
        {:ok, 123}
      end

      computed_fields = [{:result, :string, bad_computer}]

      schema = EnhancedSchema.create(fields, computed_fields: computed_fields)

      data = %{name: "John"}

      assert {:error, [error]} = EnhancedSchema.validate(data, schema)
      assert error.path == [:result]
    end

    test "executes named function validators" do
      fields = [{:name, :string, [required: true]}]

      schema =
        EnhancedSchema.create(fields,
          model_validators: [{TestHelpers, :trim_name}]
        )

      data = %{name: "  John  "}

      assert {:ok, validated} = EnhancedSchema.validate(data, schema)
      assert validated.name == "John"
    end

    test "executes named function computed fields" do
      fields = [{:name, :string, [required: true]}]

      computed_fields = [{:display_name, :string, {TestHelpers, :upcase_name}}]

      schema = EnhancedSchema.create(fields, computed_fields: computed_fields)

      data = %{name: "john"}

      assert {:ok, validated} = EnhancedSchema.validate(data, schema)
      assert validated.display_name == "JOHN"
    end
  end

  describe "to_json_schema/2" do
    test "generates JSON schema for basic enhanced schema" do
      fields = [{:name, :string, [required: true]}, {:age, :integer, [optional: true]}]
      schema = EnhancedSchema.create(fields)

      json_schema = EnhancedSchema.to_json_schema(schema)

      assert json_schema["type"] == "object"
      assert is_map(json_schema["properties"])
      assert json_schema["properties"]["name"]["type"] == "string"
      assert json_schema["properties"]["age"]["type"] == "integer"
      assert json_schema["required"] == ["name"]
    end

    test "includes computed fields in JSON schema" do
      fields = [{:name, :string, [required: true]}]

      computed_fields = [{:display_name, :string, fn data -> {:ok, String.upcase(data.name)} end}]

      schema = EnhancedSchema.create(fields, computed_fields: computed_fields)

      json_schema = EnhancedSchema.to_json_schema(schema)

      assert json_schema["properties"]["display_name"]["type"] == "string"
      assert json_schema["properties"]["display_name"]["readOnly"] == true
    end

    test "includes enhanced metadata" do
      fields = [{:name, :string, [required: true]}]

      validator = fn data -> {:ok, data} end
      computed_fields = [{:display_name, :string, fn data -> {:ok, String.upcase(data.name)} end}]

      schema =
        EnhancedSchema.create(fields,
          model_validators: [validator],
          computed_fields: computed_fields
        )

      json_schema = EnhancedSchema.to_json_schema(schema)

      assert json_schema["x-enhanced-schema"] == true
      assert json_schema["x-model-validators"] == 1
      assert json_schema["x-computed-fields"] == 1
    end
  end

  describe "info/1" do
    test "returns comprehensive schema information" do
      fields = [{:name, :string, [required: true]}, {:age, :integer, [optional: true]}]

      validator = fn data -> {:ok, data} end
      computed_fields = [{:display_name, :string, fn data -> {:ok, String.upcase(data.name)} end}]

      schema =
        EnhancedSchema.create(fields,
          model_validators: [validator],
          computed_fields: computed_fields
        )

      info = EnhancedSchema.info(schema)

      assert info.model_validator_count == 1
      assert info.computed_field_count == 1
      # One for validator, one for computed field
      assert info.runtime_function_count == 2
      # 2 regular + 1 computed
      assert info.total_field_count == 3
      assert is_map(info.base_schema)
      assert is_map(info.metadata)
    end
  end

  describe "add_model_validator/2" do
    test "adds model validator to existing schema" do
      fields = [{:name, :string, [required: true]}]
      schema = EnhancedSchema.create(fields)

      new_validator = fn data -> {:ok, %{data | name: String.trim(data.name)}} end

      updated_schema = EnhancedSchema.add_model_validator(schema, new_validator)

      assert length(updated_schema.model_validators) == 1
      assert map_size(updated_schema.runtime_functions) == 1
      assert updated_schema.metadata.validator_count == 1
    end

    test "adds named function validator" do
      fields = [{:name, :string, [required: true]}]
      schema = EnhancedSchema.create(fields)

      updated_schema = EnhancedSchema.add_model_validator(schema, {TestHelpers, :trim_name})

      assert updated_schema.model_validators == [{TestHelpers, :trim_name}]
      assert updated_schema.runtime_functions == %{}
    end
  end

  describe "add_computed_field/4" do
    test "adds computed field to existing schema" do
      fields = [{:name, :string, [required: true]}]
      schema = EnhancedSchema.create(fields)

      computer = fn data -> {:ok, String.upcase(data.name)} end

      updated_schema = EnhancedSchema.add_computed_field(schema, :display_name, :string, computer)

      assert length(updated_schema.computed_fields) == 1
      assert map_size(updated_schema.runtime_functions) == 1
      assert updated_schema.metadata.computed_field_count == 1

      [{:display_name, computed_meta}] = updated_schema.computed_fields
      assert %ComputedFieldMeta{name: :display_name, type: {:type, :string, []}} = computed_meta
    end

    test "adds named function computed field" do
      fields = [{:name, :string, [required: true]}]
      schema = EnhancedSchema.create(fields)

      updated_schema =
        EnhancedSchema.add_computed_field(
          schema,
          :display_name,
          :string,
          {TestHelpers, :upcase_name}
        )

      [{:display_name, computed_meta}] = updated_schema.computed_fields
      assert computed_meta.module == TestHelpers
      assert computed_meta.function_name == :upcase_name
      assert updated_schema.runtime_functions == %{}
    end
  end
end
