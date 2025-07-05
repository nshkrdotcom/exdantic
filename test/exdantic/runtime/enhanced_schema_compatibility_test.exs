defmodule Exdantic.Runtime.EnhancedSchemaCompatibilityTest do
  use ExUnit.Case, async: true

  alias Exdantic.JsonSchema.Resolver
  alias Exdantic.Runtime
  alias Exdantic.Runtime.{EnhancedSchema, Validator}

  describe "backward compatibility" do
    test "EnhancedSchema works with existing validation infrastructure" do
      fields = [{:name, :string, [required: true]}, {:age, :integer, [optional: true]}]

      # Create enhanced schema
      enhanced_schema =
        EnhancedSchema.create(fields,
          computed_fields: [
            {:display_name, :string, fn data -> {:ok, String.upcase(data.name)} end}
          ]
        )

      data = %{name: "john", age: 30}

      # Should work with Validator
      assert {:ok, result} = Validator.validate(data, enhanced_schema)
      assert result.name == "john"
      assert result.age == 30
      assert result.display_name == "JOHN"

      # Should work with JSON schema generation
      json_schema = Validator.to_json_schema(enhanced_schema, [])
      assert json_schema["properties"]["name"]["type"] == "string"
      assert json_schema["properties"]["display_name"]["readOnly"] == true
    end

    test "DynamicSchema continues to work unchanged" do
      fields = [{:name, :string, [required: true]}, {:age, :integer, [optional: true]}]

      # Create regular dynamic schema using existing API
      dynamic_schema = Runtime.create_schema(fields, title: "User Schema")

      data = %{name: "john", age: 30}

      # Existing validation should work unchanged
      assert {:ok, result} = Runtime.validate(data, dynamic_schema)
      assert result == %{name: "john", age: 30}

      # Should work with Validator module
      assert {:ok, result} = Validator.validate(data, dynamic_schema)
      assert result == %{name: "john", age: 30}

      # JSON schema generation should work
      json_schema = Validator.to_json_schema(dynamic_schema)
      assert json_schema["title"] == "User Schema"
      assert json_schema["properties"]["name"]["type"] == "string"
    end

    test "unified interface works with both schema types" do
      # Create both types of schemas
      basic_fields = [{:name, :string, [required: true]}]

      dynamic_schema = Runtime.create_schema(basic_fields)

      enhanced_schema =
        EnhancedSchema.create(basic_fields,
          computed_fields: [
            {:display_name, :string, fn data -> {:ok, String.upcase(data.name)} end}
          ]
        )

      data = %{name: "john"}

      # Validator.validate should work with both
      assert {:ok, dynamic_result} = Validator.validate(data, dynamic_schema)
      assert {:ok, enhanced_result} = Validator.validate(data, enhanced_schema)

      assert dynamic_result == %{name: "john"}
      assert enhanced_result.name == "john"
      assert enhanced_result.display_name == "JOHN"

      # Schema info should work with both
      dynamic_info = Validator.schema_info(dynamic_schema)
      enhanced_info = Validator.schema_info(enhanced_schema)

      assert dynamic_info.enhanced == false
      assert enhanced_info.enhanced == true

      # JSON schema generation should work with both
      dynamic_json = Validator.to_json_schema(dynamic_schema)
      enhanced_json = Validator.to_json_schema(enhanced_schema)

      assert dynamic_json["properties"]["name"]["type"] == "string"
      assert enhanced_json["properties"]["name"]["type"] == "string"
      assert enhanced_json["properties"]["display_name"]["readOnly"] == true
    end

    test "schema conversion works correctly" do
      # Create dynamic schema
      fields = [{:name, :string, [required: true]}, {:age, :integer, [optional: true]}]
      dynamic_schema = Runtime.create_schema(fields, title: "Original Schema")

      # Convert to enhanced schema
      validator = fn data -> {:ok, %{data | name: String.trim(data.name)}} end
      computer = fn data -> {:ok, String.upcase(data.name)} end

      enhanced_schema =
        Validator.enhance_schema(dynamic_schema,
          model_validators: [validator],
          computed_fields: [{:display_name, :string, computer}]
        )

      # Validate that conversion worked
      assert enhanced_schema.base_schema == dynamic_schema
      assert length(enhanced_schema.model_validators) == 1
      assert length(enhanced_schema.computed_fields) == 1

      # Test validation
      data = %{name: "  john  ", age: 30}

      assert {:ok, result} = Validator.validate(data, enhanced_schema)
      # Trimmed
      assert result.name == "john"
      assert result.age == 30
      # Computed
      assert result.display_name == "JOHN"
    end

    test "error handling consistency between schema types" do
      # Create both types with similar validation requirements
      fields = [{:name, :string, [required: true, min_length: 3]}]

      dynamic_schema = Runtime.create_schema(fields)
      enhanced_schema = EnhancedSchema.create(fields)

      # Test same validation errors
      # Too short
      invalid_data = %{name: "Jo"}

      assert {:error, [dynamic_error]} = Validator.validate(invalid_data, dynamic_schema)
      assert {:error, [enhanced_error]} = Validator.validate(invalid_data, enhanced_schema)

      # Error structure should be consistent
      assert dynamic_error.path == enhanced_error.path
      assert dynamic_error.code == enhanced_error.code
      # Messages might differ slightly but should be similar
      assert String.contains?(dynamic_error.message, "min_length")
      assert String.contains?(enhanced_error.message, "min_length")
    end

    test "JSON schema compatibility" do
      # Create schemas that should produce similar JSON schemas
      fields = [{:name, :string, [required: true]}, {:age, :integer, [optional: true]}]

      dynamic_schema = Runtime.create_schema(fields, title: "User Schema", strict: true)
      enhanced_schema = EnhancedSchema.create(fields, title: "User Schema", strict: true)

      dynamic_json = Validator.to_json_schema(dynamic_schema)
      enhanced_json = Validator.to_json_schema(enhanced_schema)

      # Core structure should be identical
      assert dynamic_json["type"] == enhanced_json["type"]
      assert dynamic_json["title"] == enhanced_json["title"]
      assert dynamic_json["required"] == enhanced_json["required"]

      # Properties should match for regular fields
      assert dynamic_json["properties"]["name"] == enhanced_json["properties"]["name"]
      assert dynamic_json["properties"]["age"] == enhanced_json["properties"]["age"]

      # Enhanced schema should have additional metadata
      assert enhanced_json["x-enhanced-schema"] == true
      refute Map.has_key?(dynamic_json, "x-enhanced-schema")
    end
  end

  describe "integration with compile-time schemas" do
    # This would test integration with schemas defined using the macro DSL
    # For now, we'll test conceptual compatibility

    test "enhanced runtime schemas provide similar capabilities to compile-time schemas" do
      # Create runtime schema that mimics compile-time schema capabilities
      fields = [
        {:first_name, :string, [required: true, min_length: 2]},
        {:last_name, :string, [required: true, min_length: 2]},
        {:email, :string, [required: true, format: ~r/@/]}
      ]

      # Model validator similar to compile-time schema
      normalize_names = fn data ->
        normalized = %{
          data
          | first_name: String.trim(data.first_name),
            last_name: String.trim(data.last_name)
        }

        {:ok, normalized}
      end

      # Computed fields similar to compile-time schema
      full_name_computer = fn data ->
        {:ok, "#{data.first_name} #{data.last_name}"}
      end

      enhanced_schema =
        EnhancedSchema.create(fields,
          title: "User Registration",
          model_validators: [normalize_names],
          computed_fields: [{:full_name, :string, full_name_computer}]
        )

      # Test validation pipeline
      input_data = %{
        first_name: "  John  ",
        last_name: "  Doe  ",
        email: "john@example.com"
      }

      assert {:ok, result} = Validator.validate(input_data, enhanced_schema)

      # Should have field validation
      # Trimmed by model validator
      assert result.first_name == "John"
      # Trimmed by model validator
      assert result.last_name == "Doe"
      assert result.email == "john@example.com"

      # Should have computed field
      assert result.full_name == "John Doe"

      # JSON schema should include computed field metadata
      json_schema = Validator.to_json_schema(enhanced_schema)
      assert json_schema["properties"]["full_name"]["readOnly"] == true
    end

    test "runtime and compile-time schemas can be used interchangeably in validation pipelines" do
      # This tests that runtime schemas integrate well with existing validation infrastructure
      # that might be designed for compile-time schemas

      fields = [{:name, :string, [required: true]}, {:value, :integer, [optional: true]}]

      enhanced_schema =
        EnhancedSchema.create(fields,
          computed_fields: [
            {:doubled_value, :integer, fn data -> {:ok, (data.value || 0) * 2} end}
          ]
        )

      # Use with EnhancedValidator (which might normally work with compile-time schemas)
      data = %{name: "test", value: 21}

      assert {:ok, result} = Validator.validate(data, enhanced_schema)
      assert result.name == "test"
      assert result.value == 21
      assert result.doubled_value == 42

      # Should work with JSON schema resolver
      json_schema = Validator.to_json_schema(enhanced_schema, [])

      # Should be able to resolve references (even though runtime schemas don't typically have them)
      resolved_schema = Resolver.resolve_references(json_schema)
      assert resolved_schema["properties"]["doubled_value"]["readOnly"] == true
    end
  end
end
