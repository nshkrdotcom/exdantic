defmodule Exdantic.Runtime.ValidatorTest do
  use ExUnit.Case, async: true

  alias Exdantic.Runtime.{EnhancedSchema, Validator}
  alias Exdantic.ValidationError

  describe "validate/3 with DynamicSchema" do
    test "validates against dynamic schema" do
      fields = [{:name, :string, [required: true]}, {:age, :integer, [optional: true]}]
      schema = Exdantic.Runtime.create_schema(fields)

      data = %{name: "John", age: 30}

      assert {:ok, validated} = Validator.validate(data, schema)
      assert validated == %{name: "John", age: 30}
    end

    test "returns validation errors" do
      fields = [{:name, :string, [required: true]}]
      schema = Exdantic.Runtime.create_schema(fields)

      # Missing required name
      data = %{age: 30}

      assert {:error, [error]} = Validator.validate(data, schema)
      assert error.code == :required
    end
  end

  describe "validate/3 with EnhancedSchema" do
    test "validates against enhanced schema" do
      fields = [{:name, :string, [required: true]}]

      validator = fn data ->
        {:ok, %{data | name: String.trim(data.name)}}
      end

      computed_fields = [{:display_name, :string, fn data -> {:ok, String.upcase(data.name)} end}]

      schema =
        EnhancedSchema.create(fields,
          model_validators: [validator],
          computed_fields: computed_fields
        )

      data = %{name: "  john  "}

      assert {:ok, validated} = Validator.validate(data, schema)
      assert validated.name == "john"
      assert validated.display_name == "JOHN"
    end

    test "handles enhanced schema validation errors" do
      fields = [{:name, :string, [required: true]}]

      failing_validator = fn _data ->
        {:error, "validation failed"}
      end

      schema = EnhancedSchema.create(fields, model_validators: [failing_validator])

      data = %{name: "John"}

      assert {:error, [error]} = Validator.validate(data, schema)
      assert error.code == :model_validation
    end
  end

  describe "validate!/3" do
    test "returns validated data on success" do
      fields = [{:name, :string, [required: true]}]
      schema = Exdantic.Runtime.create_schema(fields)

      data = %{name: "John"}

      assert %{name: "John"} = Validator.validate!(data, schema)
    end

    test "raises ValidationError on failure" do
      fields = [{:name, :string, [required: true]}]
      schema = Exdantic.Runtime.create_schema(fields)

      # Missing required name
      data = %{age: 30}

      assert_raise ValidationError, fn ->
        Validator.validate!(data, schema)
      end
    end
  end

  describe "to_json_schema/2" do
    test "generates JSON schema for DynamicSchema" do
      fields = [{:name, :string, [required: true]}, {:age, :integer, [optional: true]}]
      schema = Exdantic.Runtime.create_schema(fields)

      json_schema = Validator.to_json_schema(schema)

      assert json_schema["type"] == "object"
      assert json_schema["properties"]["name"]["type"] == "string"
      assert json_schema["properties"]["age"]["type"] == "integer"
    end

    test "generates JSON schema for EnhancedSchema" do
      fields = [{:name, :string, [required: true]}]

      computed_fields = [{:display_name, :string, fn data -> {:ok, String.upcase(data.name)} end}]

      schema = EnhancedSchema.create(fields, computed_fields: computed_fields)

      json_schema = Validator.to_json_schema(schema)

      assert json_schema["type"] == "object"
      assert json_schema["properties"]["name"]["type"] == "string"
      assert json_schema["properties"]["display_name"]["type"] == "string"
      assert json_schema["properties"]["display_name"]["readOnly"] == true
      assert json_schema["x-enhanced-schema"] == true
    end
  end

  describe "schema_info/1" do
    test "returns info for DynamicSchema" do
      fields = [{:name, :string, [required: true]}]
      schema = Exdantic.Runtime.create_schema(fields)

      info = Validator.schema_info(schema)

      assert info.schema_type == :dynamic
      assert info.enhanced == false
      assert info.field_count == 1
    end

    test "returns info for EnhancedSchema" do
      fields = [{:name, :string, [required: true]}]

      validator = fn data -> {:ok, data} end
      computed_fields = [{:display_name, :string, fn data -> {:ok, String.upcase(data.name)} end}]

      schema =
        EnhancedSchema.create(fields,
          model_validators: [validator],
          computed_fields: computed_fields
        )

      info = Validator.schema_info(schema)

      assert info.schema_type == :enhanced
      assert info.enhanced == true
      assert info.model_validator_count == 1
      assert info.computed_field_count == 1
    end
  end

  describe "enhanced_schema?/1" do
    test "returns false for DynamicSchema" do
      fields = [{:name, :string, [required: true]}]
      schema = Exdantic.Runtime.create_schema(fields)

      refute Validator.enhanced_schema?(schema)
    end

    test "returns true for EnhancedSchema" do
      fields = [{:name, :string, [required: true]}]
      schema = EnhancedSchema.create(fields)

      assert Validator.enhanced_schema?(schema)
    end
  end

  describe "enhance_schema/2" do
    test "converts DynamicSchema to EnhancedSchema" do
      fields = [{:name, :string, [required: true]}]
      dynamic_schema = Exdantic.Runtime.create_schema(fields)

      validator = fn data -> {:ok, data} end
      computed_fields = [{:display_name, :string, fn data -> {:ok, String.upcase(data.name)} end}]

      enhanced_schema =
        Validator.enhance_schema(dynamic_schema,
          model_validators: [validator],
          computed_fields: computed_fields
        )

      assert %EnhancedSchema{} = enhanced_schema
      assert enhanced_schema.base_schema == dynamic_schema
      assert length(enhanced_schema.model_validators) == 1
      assert length(enhanced_schema.computed_fields) == 1
      assert enhanced_schema.metadata.enhanced_from_dynamic == true
    end

    test "creates enhanced schema with empty enhancements" do
      fields = [{:name, :string, [required: true]}]
      dynamic_schema = Exdantic.Runtime.create_schema(fields)

      enhanced_schema = Validator.enhance_schema(dynamic_schema)

      assert %EnhancedSchema{} = enhanced_schema
      assert enhanced_schema.model_validators == []
      assert enhanced_schema.computed_fields == []
      assert enhanced_schema.runtime_functions == %{}
    end
  end
end
