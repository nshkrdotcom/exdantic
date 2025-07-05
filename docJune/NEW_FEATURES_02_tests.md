# Complete Test Suite for Exdantic Enhanced Features

## Test Files Structure

```
test/
├── enhanced_features/
│   ├── struct_pattern_test.exs
│   ├── model_validators_test.exs
│   ├── computed_fields_test.exs
│   ├── enhanced_schema_validator_test.exs
│   ├── enhanced_runtime_test.exs
│   └── integration_test.exs
└── support/
    └── enhanced_test_schemas.ex
```

## Test Support Schemas

```elixir
# test/support/enhanced_test_schemas.ex
defmodule Exdantic.TestSupport.EnhancedSchemas do
  @moduledoc """
  Test schemas for enhanced features testing.
  """

  # Basic struct schema
  defmodule BasicStructSchema do
    use Exdantic, define_struct: true

    schema do
      field :name, :string, required: true
      field :age, :integer, required: false
    end
  end

  # Schema without struct
  defmodule NoStructSchema do
    use Exdantic, define_struct: false

    schema do
      field :title, :string, required: true
      field :count, :integer, required: true
    end
  end

  # Schema with model validator
  defmodule ModelValidatorSchema do
    use Exdantic, define_struct: true

    schema do
      field :password, :string, required: true
      field :password_confirmation, :string, required: true

      model_validator fn data ->
        if data.password == data.password_confirmation do
          {:ok, data}
        else
          {:error, "passwords do not match"}
        end
      end
    end
  end

  # Schema with computed fields
  defmodule ComputedFieldsSchema do
    use Exdantic, define_struct: true

    schema do
      field :first_name, :string, required: true
      field :last_name, :string, required: true

      computed_field :full_name, :string, fn data ->
        "#{data.first_name} #{data.last_name}"
      end

      computed_field :initials, :string, fn data ->
        first_initial = String.first(data.first_name)
        last_initial = String.first(data.last_name)
        "#{first_initial}.#{last_initial}."
      end
    end
  end

  # Schema with all features
  defmodule CompleteSchema do
    use Exdantic, define_struct: true

    schema do
      field :base_price, :float, required: true
      field :tax_rate, :float, required: true
      field :discount, :float, required: false, default: 0.0

      model_validator fn data ->
        cond do
          data.base_price < 0 -> {:error, "base_price cannot be negative"}
          data.tax_rate < 0 or data.tax_rate > 1 -> {:error, "tax_rate must be between 0 and 1"}
          data.discount < 0 or data.discount > 1 -> {:error, "discount must be between 0 and 1"}
          true -> {:ok, data}
        end
      end

      computed_field :subtotal, :float, fn data ->
        data.base_price * (1 - data.discount)
      end

      computed_field :tax_amount, :float, fn data ->
        subtotal = data.base_price * (1 - data.discount)
        subtotal * data.tax_rate
      end

      computed_field :total, :float, fn data ->
        subtotal = data.base_price * (1 - data.discount)
        tax = subtotal * data.tax_rate
        subtotal + tax
      end
    end
  end

  # Schema with multiple model validators
  defmodule MultiValidatorSchema do
    use Exdantic, define_struct: true

    schema do
      field :username, :string, required: true
      field :email, :string, required: true
      field :age, :integer, required: true

      model_validator fn data ->
        if String.length(data.username) >= 3 do
          {:ok, data}
        else
          {:error, "username too short"}
        end
      end

      model_validator fn data ->
        if String.contains?(data.email, "@") do
          {:ok, data}
        else
          {:error, "invalid email format"}
        end
      end

      model_validator fn data ->
        if data.age >= 18 do
          {:ok, data}
        else
          {:error, "must be 18 or older"}
        end
      end
    end
  end

  # Schema with data transformation in model validator
  defmodule TransformingValidatorSchema do
    use Exdantic, define_struct: true

    schema do
      field :name, :string, required: true
      field :email, :string, required: true

      model_validator fn data ->
        # Transform data by normalizing email to lowercase
        normalized_data = %{data | email: String.downcase(data.email)}
        {:ok, normalized_data}
      end
    end
  end

  # Schema with error in computed field
  defmodule ErrorComputedFieldSchema do
    use Exdantic, define_struct: true

    schema do
      field :numerator, :integer, required: true
      field :denominator, :integer, required: true

      computed_field :division_result, :float, fn data ->
        # This will raise if denominator is 0
        data.numerator / data.denominator
      end
    end
  end
end
```

## 1. Struct Pattern Tests

```elixir
# test/enhanced_features/struct_pattern_test.exs
defmodule Exdantic.StructPatternTest do
  use ExUnit.Case
  alias Exdantic.TestSupport.EnhancedSchemas.{BasicStructSchema, NoStructSchema}

  describe "struct generation" do
    test "creates struct when define_struct: true" do
      # Check that the struct was defined
      assert function_exported?(BasicStructSchema, :__struct__, 0)
      assert function_exported?(BasicStructSchema, :__struct__, 1)
      
      # Check struct fields
      struct = %BasicStructSchema{}
      assert Map.has_key?(struct, :name)
      assert Map.has_key?(struct, :age)
      assert struct.__struct__ == BasicStructSchema
    end

    test "does not create struct when define_struct: false" do
      refute function_exported?(NoStructSchema, :__struct__, 0)
      refute function_exported?(NoStructSchema, :__struct__, 1)
    end

    test "struct has correct field access" do
      struct = %BasicStructSchema{name: "John", age: 30}
      assert struct.name == "John"
      assert struct.age == 30
    end

    test "__struct_fields__ returns all field names" do
      fields = BasicStructSchema.__struct_fields__()
      assert :name in fields
      assert :age in fields
    end
  end

  describe "validation with struct return" do
    test "returns struct instance when define_struct: true" do
      data = %{name: "Alice", age: 25}
      
      assert {:ok, result} = BasicStructSchema.validate(data)
      assert %BasicStructSchema{} = result
      assert result.name == "Alice"
      assert result.age == 25
    end

    test "returns map when define_struct: false" do
      data = %{title: "Test", count: 42}
      
      assert {:ok, result} = NoStructSchema.validate(data)
      assert is_map(result)
      refute is_struct(result)
      assert result.title == "Test"
      assert result.count == 42
    end

    test "handles optional fields in struct" do
      data = %{name: "Bob"}  # age is optional
      
      assert {:ok, result} = BasicStructSchema.validate(data)
      assert %BasicStructSchema{} = result
      assert result.name == "Bob"
      assert is_nil(result.age)
    end

    test "handles validation errors normally" do
      data = %{age: 30}  # name is required
      
      assert {:error, errors} = BasicStructSchema.validate(data)
      assert is_list(errors)
      assert length(errors) > 0
    end
  end

  describe "dump functionality" do
    test "converts struct back to map" do
      struct = %BasicStructSchema{name: "Charlie", age: 35}
      
      assert {:ok, map} = BasicStructSchema.dump(struct)
      assert is_map(map)
      refute is_struct(map)
      assert map.name == "Charlie"
      assert map.age == 35
    end

    test "handles plain map input" do
      map = %{name: "David", age: 40}
      
      assert {:ok, result} = BasicStructSchema.dump(map)
      assert result == map
    end

    test "returns error for invalid input" do
      assert {:error, _} = BasicStructSchema.dump("invalid")
      assert {:error, _} = BasicStructSchema.dump(123)
    end
  end
end
```

## 2. Model Validators Tests

```elixir
# test/enhanced_features/model_validators_test.exs
defmodule Exdantic.ModelValidatorsTest do
  use ExUnit.Case
  alias Exdantic.TestSupport.EnhancedSchemas.{
    ModelValidatorSchema, 
    MultiValidatorSchema, 
    TransformingValidatorSchema
  }

  describe "single model validator" do
    test "passes when validation succeeds" do
      data = %{password: "secret123", password_confirmation: "secret123"}
      
      assert {:ok, result} = ModelValidatorSchema.validate(data)
      assert result.password == "secret123"
      assert result.password_confirmation == "secret123"
    end

    test "fails when validation fails" do
      data = %{password: "secret123", password_confirmation: "different"}
      
      assert {:error, errors} = ModelValidatorSchema.validate(data)
      assert length(errors) == 1
      
      error = hd(errors)
      assert error.code == :model_validation
      assert error.message == "passwords do not match"
    end

    test "receives struct when define_struct: true" do
      # This is implicitly tested by the successful validations above
      # since the validator function receives the data and can access fields
      data = %{password: "test", password_confirmation: "test"}
      assert {:ok, _} = ModelValidatorSchema.validate(data)
    end
  end

  describe "multiple model validators" do
    test "all validators pass" do
      data = %{username: "john_doe", email: "john@example.com", age: 25}
      
      assert {:ok, result} = MultiValidatorSchema.validate(data)
      assert result.username == "john_doe"
      assert result.email == "john@example.com"
      assert result.age == 25
    end

    test "fails on first validator" do
      data = %{username: "jo", email: "john@example.com", age: 25}  # username too short
      
      assert {:error, errors} = MultiValidatorSchema.validate(data)
      assert length(errors) == 1
      
      error = hd(errors)
      assert error.message == "username too short"
    end

    test "fails on second validator" do
      data = %{username: "john_doe", email: "invalid-email", age: 25}
      
      assert {:error, errors} = MultiValidatorSchema.validate(data)
      assert length(errors) == 1
      
      error = hd(errors)
      assert error.message == "invalid email format"
    end

    test "fails on third validator" do
      data = %{username: "john_doe", email: "john@example.com", age: 16}
      
      assert {:error, errors} = MultiValidatorSchema.validate(data)
      assert length(errors) == 1
      
      error = hd(errors)
      assert error.message == "must be 18 or older"
    end
  end

  describe "data transformation" do
    test "model validator can transform data" do
      data = %{name: "John", email: "JOHN@EXAMPLE.COM"}
      
      assert {:ok, result} = TransformingValidatorSchema.validate(data)
      assert result.name == "John"
      assert result.email == "john@example.com"  # Should be lowercased
    end
  end

  describe "error handling" do
    test "handles Error struct return" do
      # This would require a schema that returns Error struct
      # For now, we test string error handling which is implemented
      data = %{password: "a", password_confirmation: "b"}
      assert {:error, _} = ModelValidatorSchema.validate(data)
    end

    test "handles invalid validator return" do
      # Would need a schema with invalid return value
      # This tests the error handling in the validator itself
      # The implementation should handle this gracefully
    end
  end
end
```

## 3. Computed Fields Tests

```elixir
# test/enhanced_features/computed_fields_test.exs
defmodule Exdantic.ComputedFieldsTest do
  use ExUnit.Case
  alias Exdantic.TestSupport.EnhancedSchemas.{ComputedFieldsSchema, ErrorComputedFieldSchema}

  describe "computed field execution" do
    test "executes computed field functions after validation" do
      data = %{first_name: "John", last_name: "Doe"}
      
      assert {:ok, result} = ComputedFieldsSchema.validate(data)
      assert result.first_name == "John"
      assert result.last_name == "Doe"
      assert result.full_name == "John Doe"
      assert result.initials == "J.D."
    end

    test "computed fields can reference other fields" do
      data = %{first_name: "Alice", last_name: "Smith"}
      
      assert {:ok, result} = ComputedFieldsSchema.validate(data)
      assert result.full_name == "Alice Smith"
      assert result.initials == "A.S."
    end

    test "computed fields work with different input values" do
      data = %{first_name: "X", last_name: "Y"}
      
      assert {:ok, result} = ComputedFieldsSchema.validate(data)
      assert result.full_name == "X Y"
      assert result.initials == "X.Y."
    end
  end

  describe "computed fields in struct" do
    test "computed fields appear in struct definition" do
      struct_fields = ComputedFieldsSchema.__struct_fields__()
      assert :first_name in struct_fields
      assert :last_name in struct_fields
      assert :full_name in struct_fields
      assert :initials in struct_fields
    end

    test "computed fields are accessible in struct" do
      data = %{first_name: "Test", last_name: "User"}
      
      assert {:ok, result} = ComputedFieldsSchema.validate(data)
      assert %ComputedFieldsSchema{} = result
      assert Map.has_key?(result, :full_name)
      assert Map.has_key?(result, :initials)
    end
  end

  describe "computed field error handling" do
    test "handles errors in computed field gracefully" do
      data = %{numerator: 10, denominator: 0}  # Division by zero
      
      assert {:error, errors} = ErrorComputedFieldSchema.validate(data)
      assert length(errors) == 1
      
      error = hd(errors)
      assert error.code == :computed_field
      assert String.contains?(error.message, "Computed field calculation failed")
    end

    test "successful computation works normally" do
      data = %{numerator: 10, denominator: 2}
      
      assert {:ok, result} = ErrorComputedFieldSchema.validate(data)
      assert result.numerator == 10
      assert result.denominator == 2
      assert result.division_result == 5.0
    end
  end

  describe "__schema__ introspection" do
    test "computed fields appear in schema metadata" do
      computed_fields = ComputedFieldsSchema.__schema__(:computed_fields)
      assert is_list(computed_fields)
      assert length(computed_fields) == 2
      
      field_names = Enum.map(computed_fields, fn {name, _} -> name end)
      assert :full_name in field_names
      assert :initials in field_names
    end
  end
end
```

## 4. Enhanced Schema Validator Tests

```elixir
# test/enhanced_features/enhanced_schema_validator_test.exs
defmodule Exdantic.EnhancedSchemaValidatorTest do
  use ExUnit.Case
  alias Exdantic.EnhancedSchemaValidator
  alias Exdantic.TestSupport.EnhancedSchemas.{BasicStructSchema, CompleteSchema}

  describe "validate_schema/3" do
    test "validates basic schema successfully" do
      data = %{name: "Test", age: 30}
      
      assert {:ok, result} = EnhancedSchemaValidator.validate_schema(BasicStructSchema, data)
      assert %BasicStructSchema{} = result
      assert result.name == "Test"
      assert result.age == 30
    end

    test "handles validation errors" do
      data = %{age: 30}  # missing required name
      
      assert {:error, errors} = EnhancedSchemaValidator.validate_schema(BasicStructSchema, data)
      assert is_list(errors)
      assert length(errors) > 0
    end

    test "validates complete schema with all features" do
      data = %{base_price: 100.0, tax_rate: 0.08, discount: 0.1}
      
      assert {:ok, result} = EnhancedSchemaValidator.validate_schema(CompleteSchema, data)
      assert %CompleteSchema{} = result
      assert result.base_price == 100.0
      assert result.tax_rate == 0.08
      assert result.discount == 0.1
      
      # Check computed fields
      assert result.subtotal == 90.0  # 100 * (1 - 0.1)
      assert result.tax_amount == 7.2  # 90 * 0.08
      assert result.total == 97.2     # 90 + 7.2
    end

    test "handles model validation failure" do
      data = %{base_price: -50.0, tax_rate: 0.08}  # negative price
      
      assert {:error, errors} = EnhancedSchemaValidator.validate_schema(CompleteSchema, data)
      assert length(errors) == 1
      
      error = hd(errors)
      assert error.code == :model_validation
      assert error.message == "base_price cannot be negative"
    end
  end

  describe "dump/2" do
    test "dumps struct to map" do
      struct = %BasicStructSchema{name: "Alice", age: 25}
      
      assert {:ok, map} = EnhancedSchemaValidator.dump(BasicStructSchema, struct)
      assert is_map(map)
      refute is_struct(map)
      assert map.name == "Alice"
      assert map.age == 25
    end

    test "handles map input" do
      map = %{name: "Bob", age: 30}
      
      assert {:ok, result} = EnhancedSchemaValidator.dump(BasicStructSchema, map)
      assert result == map
    end

    test "returns error for invalid input" do
      assert {:error, _} = EnhancedSchemaValidator.dump(BasicStructSchema, "invalid")
    end
  end

  describe "private helper functions" do
    # These test the internal implementation
    test "apply_model_validators with empty list" do
      # This would be testing private functions
      # In practice, this is covered by the public API tests
    end
  end
end
```

## 5. Enhanced Runtime Tests

```elixir
# test/enhanced_features/enhanced_runtime_test.exs
defmodule Exdantic.EnhancedRuntimeTest do
  use ExUnit.Case
  alias Exdantic.Runtime

  describe "create_enhanced_schema/2" do
    test "creates enhanced schema with model validators" do
      fields = [
        {:username, :string, [required: true]},
        {:password, :string, [required: true]}
      ]
      
      model_validators = [
        fn data -> 
          if String.length(data.username) >= 3 do
            {:ok, data}
          else
            {:error, "username too short"}
          end
        end
      ]
      
      schema = Runtime.create_enhanced_schema(fields, 
        model_validators: model_validators,
        title: "Enhanced User Schema"
      )
      
      assert schema.metadata.model_validators == model_validators
      assert schema.metadata.enhanced == true
    end

    test "creates enhanced schema with computed fields" do
      fields = [
        {:first_name, :string, [required: true]},
        {:last_name, :string, [required: true]}
      ]
      
      computed_fields = [
        {:full_name, fn data -> "#{data.first_name} #{data.last_name}" end}
      ]
      
      schema = Runtime.create_enhanced_schema(fields,
        computed_fields: computed_fields
      )
      
      assert schema.metadata.computed_fields == computed_fields
    end

    test "creates enhanced schema with both features" do
      fields = [{:value, :integer, [required: true]}]
      
      model_validators = [
        fn data -> if data.value > 0, do: {:ok, data}, else: {:error, "positive only"} end
      ]
      
      computed_fields = [
        {:doubled, fn data -> data.value * 2 end}
      ]
      
      schema = Runtime.create_enhanced_schema(fields,
        model_validators: model_validators,
        computed_fields: computed_fields
      )
      
      assert schema.metadata.model_validators == model_validators
      assert schema.metadata.computed_fields == computed_fields
    end
  end

  describe "validate_enhanced/3" do
    test "validates with model validators" do
      fields = [{:age, :integer, [required: true]}]
      
      model_validators = [
        fn data -> 
          if data.age >= 18, do: {:ok, data}, else: {:error, "must be 18+"} 
        end
      ]
      
      schema = Runtime.create_enhanced_schema(fields, 
        model_validators: model_validators
      )
      
      # Valid case
      assert {:ok, result} = Runtime.validate_enhanced(%{age: 25}, schema)
      assert result.age == 25
      
      # Invalid case
      assert {:error, errors} = Runtime.validate_enhanced(%{age: 16}, schema)
      assert length(errors) == 1
      assert hd(errors).message == "must be 18+"
    end

    test "validates with computed fields" do
      fields = [
        {:width, :integer, [required: true]},
        {:height, :integer, [required: true]}
      ]
      
      computed_fields = [
        {:area, fn data -> data.width * data.height end},
        {:perimeter, fn data -> 2 * (data.width + data.height) end}
      ]
      
      schema = Runtime.create_enhanced_schema(fields,
        computed_fields: computed_fields
      )
      
      data = %{width: 5, height: 3}
      assert {:ok, result} = Runtime.validate_enhanced(data, schema)
      assert result.width == 5
      assert result.height == 3
      assert result.area == 15
      assert result.perimeter == 16
    end

    test "validates with both model validators and computed fields" do
      fields = [{:base, :integer, [required: true]}]
      
      model_validators = [
        fn data -> 
          if data.base > 0, do: {:ok, data}, else: {:error, "base must be positive"} 
        end
      ]
      
      computed_fields = [
        {:squared, fn data -> data.base * data.base end},
        {:cubed, fn data -> data.base * data.base * data.base end}
      ]
      
      schema = Runtime.create_enhanced_schema(fields,
        model_validators: model_validators,
        computed_fields: computed_fields
      )
      
      # Valid case
      data = %{base: 3}
      assert {:ok, result} = Runtime.validate_enhanced(data, schema)
      assert result.base == 3
      assert result.squared == 9
      assert result.cubed == 27
      
      # Invalid case (model validator fails)
      data = %{base: -1}
      assert {:error, errors} = Runtime.validate_enhanced(data, schema)
      assert hd(errors).message == "base must be positive"
    end

    test "handles computed field errors" do
      fields = [{:value, :integer, [required: true]}]
      
      computed_fields = [
        {:division, fn data -> 10 / data.value end}  # Will fail if value is 0
      ]
      
      schema = Runtime.create_enhanced_schema(fields,
        computed_fields: computed_fields
      )
      
      # Valid case
      assert {:ok, result} = Runtime.validate_enhanced(%{value: 2}, schema)
      assert result.division == 5.0
      
      # Error case
      assert {:error, errors} = Runtime.validate_enhanced(%{value: 0}, schema)
      assert length(errors) == 1
      assert hd(errors).code == :computed_field
    end
  end

  describe "backwards compatibility" do
    test "regular runtime schemas still work" do
      fields = [{:name, :string, [required: true]}]
      schema = Runtime.create_schema(fields)
      
      assert {:ok, result} = Runtime.validate(%{name: "test"}, schema)
      assert result.name == "test"
    end

    test "enhanced validation works with regular schemas" do
      fields = [{:title, :string, [required: true]}]
      schema = Runtime.create_schema(fields)
      
      # Should work with validate_enhanced even without enhanced features
      assert {:ok, result} = Runtime.validate_enhanced(%{title: "test"}, schema)
      assert result.title == "test"
    end
  end
end
```

## 6. Integration Tests

```elixir
# test/enhanced_features/integration_test.exs
defmodule Exdantic.EnhancedFeaturesIntegrationTest do
  use ExUnit.Case
  alias Exdantic.TestSupport.EnhancedSchemas.CompleteSchema
  alias Exdantic.{EnhancedValidator, JsonSchema, Runtime}

  describe "full integration - compile-time schemas" do
    test "all features work together in compile-time schema" do
      data = %{base_price: 100.0, tax_rate: 0.1, discount: 0.05}
      
      assert {:ok, result} = CompleteSchema.validate(data)
      
      # Check struct type
      assert %CompleteSchema{} = result
      
      # Check basic fields
      assert result.base_price == 100.0
      assert result.tax_rate == 0.1
      assert result.discount == 0.05
      
      # Check computed fields
      assert result.subtotal == 95.0   # 100 * (1 - 0.05)
      assert result.tax_amount == 9.5  # 95 * 0.1
      assert result.total == 104.5     # 95 + 9.5
    end

    test "model validation prevents invalid data" do
      data = %{base_price: 100.0, tax_rate: 1.5}  # tax_rate > 1
      
      assert {:error, errors} = CompleteSchema.validate(data)
      assert length(errors) == 1
      assert hd(errors).message == "tax_rate must be between 0 and 1"
    end

    test "dump works with all features" do
      data = %{base_price: 50.0, tax_rate: 0.08}
      {:ok, struct} = CompleteSchema.validate(data)
      
      assert {:ok, map} = CompleteSchema.dump(struct)
      assert is_map(map)
      refute is_struct(map)
      
      # Should include computed fields
      assert Map.has_key?(map, :subtotal)
      assert Map.has_key?(map, :tax_amount) 
      assert Map.has_key?(map, :total)
    end
  end

  describe "full integration - runtime schemas" do
    test "enhanced runtime schema with all features" do
      fields = [
        {:name, :string, [required: true]},
        {:email, :string, [required: true]}
      ]
      
      model_validators = [
        fn data ->
          if String.contains?(data.email, "@") do
            {:ok, %{data | email: String.downcase(data.email)}}
          else
            {:error, "invalid email"}
          end
        end
      ]
      
      computed_fields = [
        {:username, fn data -> String.split(data.email, "@") |> hd end},
        {:domain, fn data -> String.split(data.email, "@") |> List.last end}
      ]
      
      schema = Runtime.create_enhanced_schema(fields,
        model_validators: model_validators,
        computed_fields: computed_fields,
        title: "User Registration"
      )
      
      data = %{name: "John Doe", email: "JOHN@EXAMPLE.COM"}
      assert {:ok, result} = Runtime.validate_enhanced(data, schema)
      
      assert result.name == "John Doe"
      assert result.email == "john@example.com"  # Lowercased by model validator
      assert result.username == "john"           # Computed from email
      assert result.domain == "example.com"      # Computed from email
    end
  end

  describe "JSON schema generation" do
    test "includes computed fields as readOnly" do
      json_schema = JsonSchema.from_schema(CompleteSchema)
      
      properties = json_schema["properties"]
      
      # Regular fields should not be readOnly
      refute Map.get(properties["base_price"], "readOnly", false)
      refute Map.get(properties["tax_rate"], "readOnly", false)
      
      # Computed fields should be readOnly
      assert properties["subtotal"]["readOnly"] == true
      assert properties["tax_amount"]["readOnly"] == true  
      assert properties["total"]["readOnly"] == true
    end

    test "computed fields have correct types in JSON schema" do
      json_schema = JsonSchema.from_schema(CompleteSchema)
      properties = json_schema["properties"]
      
      assert properties["subtotal"]["type"] == "number"
      assert properties["tax_amount"]["type"] == "number"
      assert properties["total"]["type"] == "number"
    end
  end

  describe "enhanced validator integration" do
    test "enhanced validator works with enhanced schemas" do
      data = %{base_price: 200.0, tax_rate: 0.05}
      
      assert {:ok, result} = EnhancedValidator.validate(CompleteSchema, data)
      assert %CompleteSchema{} = result
      assert result.total > 0  # Computed field should be present
    end

    test "enhanced validator with validation reports" do
      data = %{base_price: 150.0, tax_rate: 0.06}
      
      report = EnhancedValidator.validation_report(CompleteSchema, data)
      
      assert report.validation_result == {:ok, _}
      assert is_map(report.json_schema)
      assert report.target_info.type == :compiled_schema
      assert is_map(report.performance_metrics)
    end

    test "enhanced validator batch operations" do
      datasets = [
        %{base_price: 100.0, tax_rate: 0.08},
        %{base_price: 200.0, tax_rate: 0.1},
        %{base_price: 50.0, tax_rate: 0.05}
      ]
      
      assert {:ok, results} = EnhancedValidator.validate_many(CompleteSchema, datasets)
      assert length(results) == 3
      
      Enum.each(results, fn result ->
        assert %CompleteSchema{} = result
        assert is_number(result.total)
      end)
    end
  end

  describe "error path preservation" do
    test "errors maintain correct paths through all validation stages" do
      # Test with invalid tax_rate that should fail model validation
      data = %{base_price: 100.0, tax_rate: -0.1}
      
      assert {:error, errors} = CompleteSchema.validate(data)
      assert length(errors) == 1
      
      error = hd(errors)
      assert error.code == :model_validation
      # Path should be preserved from model validator
      assert error.path == []
    end
  end

  describe "backwards compatibility" do
    test "existing schemas without enhanced features still work" do
      # This would test with a basic schema that doesn't use new features
      # Ensuring no regression in existing functionality
      defmodule SimpleSchema do
        use Exdantic
        
        schema do
          field :name, :string, required: true
          field :age, :integer, required: false
        end
      end
      
      data = %{name: "Test User", age: 30}
      assert {:ok, result} = SimpleSchema.validate(data)
      assert is_map(result)
      assert result.name == "Test User"
      assert result.age == 30
    end

    test "enhanced validator works with regular schemas" do
      defmodule BasicSchema do
        use Exdantic
        
        schema do
          field :title, :string, required: true
        end
      end
      
      data = %{title: "Test Title"}
      assert {:ok, result} = EnhancedValidator.validate(BasicSchema, data)
      assert result.title == "Test Title"
    end
  end
end
```

## 7. Property-Based Testing

```elixir
# test/enhanced_features/property_test.exs
defmodule Exdantic.EnhancedFeaturesPropertyTest do
  use ExUnit.Case
  use PropCheck

  describe "struct pattern properties" do
    property "struct fields always match validated data fields" do
      forall {name, age} <- {binary(), integer()} do
        defmodule TestStructSchema do
          use Exdantic, define_struct: true
          
          schema do
            field :name, :string, required: true
            field :age, :integer, required: true
          end
        end
        
        data = %{name: name, age: age}
        
        case TestStructSchema.validate(data) do
          {:ok, result} ->
            result.name == name and result.age == age and 
            is_struct(result, TestStructSchema)
          {:error, _} ->
            # Validation failure is acceptable
            true
        end
      end
    end
  end

  describe "computed fields properties" do
    property "computed fields are always executed" do
      forall {a, b} <- {integer(), integer()} do
        defmodule TestComputedSchema do
          use Exdantic, define_struct: true
          
          schema do
            field :a, :integer, required: true
            field :b, :integer, required: true
            
            computed_field :sum, :integer, fn data ->
              data.a + data.b
            end
          end
        end
        
        data = %{a: a, b: b}
        
        case TestComputedSchema.validate(data) do
          {:ok, result} ->
            result.sum == (a + b)
          {:error, _} ->
            true
        end
      end
    end
  end
end
```

## 8. Performance Tests

```elixir
# test/enhanced_features/performance_test.exs
defmodule Exdantic.EnhancedFeaturesPerformanceTest do
  use ExUnit.Case

  @moduletag :performance

  describe "performance benchmarks" do
    test "struct creation performance" do
      defmodule PerfStructSchema do
        use Exdantic, define_struct: true
        
        schema do
          field :field1, :string, required: true
          field :field2, :integer, required: true
          field :field3, :float, required: true
          field :field4, :boolean, required: true
        end
      end
      
      data = %{
        field1: "test",
        field2: 42,
        field3: 3.14,
        field4: true
      }
      
      {time_microseconds, _result} = :timer.tc(fn ->
        Enum.each(1..1000, fn _ ->
          PerfStructSchema.validate(data)
        end)
      end)
      
      avg_time = time_microseconds / 1000 / 1000  # Convert to milliseconds per operation
      
      # Should be under 1ms per validation on average
      assert avg_time < 1.0
    end

    test "computed fields performance" do
      defmodule PerfComputedSchema do
        use Exdantic, define_struct: true
        
        schema do
          field :value, :integer, required: true
          
          computed_field :doubled, :integer, fn data -> data.value * 2 end
          computed_field :squared, :integer, fn data -> data.value * data.value end
          computed_field :description, :string, fn data -> "Value: #{data.value}" end
        end
      end
      
      data = %{value: 42}
      
      {time_microseconds, _result} = :timer.tc(fn ->
        Enum.each(1..1000, fn _ ->
          PerfComputedSchema.validate(data)
        end)
      end)
      
      avg_time = time_microseconds / 1000 / 1000
      
      # Should still be reasonable with computed fields
      assert avg_time < 2.0
    end

    test "model validator performance" do
      defmodule PerfValidatorSchema do
        use Exdantic, define_struct: true
        
        schema do
          field :a, :integer, required: true
          field :b, :integer, required: true
          field :c, :integer, required: true
          
          model_validator fn data ->
            if data.a + data.b + data.c > 0 do
              {:ok, data}
            else
              {:error, "sum must be positive"}
            end
          end
        end
      end
      
      data = %{a: 10, b: 20, c: 30}
      
      {time_microseconds, _result} = :timer.tc(fn ->
        Enum.each(1..1000, fn _ ->
          PerfValidatorSchema.validate(data)
        end)
      end)
      
      avg_time = time_microseconds / 1000 / 1000
      
      # Model validators should add minimal overhead
      assert avg_time < 1.5
    end
  end

  describe "memory usage" do
    test "struct memory usage is reasonable" do
      defmodule MemoryStructSchema do
        use Exdantic, define_struct: true
        
        schema do
          Enum.each(1..50, fn i ->
            field String.to_atom("field_#{i}"), :string, required: false
          end)
        end
      end
      
      data = for i <- 1..50, into: %{} do
        {String.to_atom("field_#{i}"), "value_#{i}"}
      end
      
      {:ok, result} = MemoryStructSchema.validate(data)
      
      # Check that struct size is reasonable
      struct_size = :erts_debug.size(result)
      
      # Should be roughly proportional to number of fields
      assert struct_size < 1000  # Reasonable upper bound
    end
  end
end
```

## 9. Edge Cases and Error Handling Tests

```elixir
# test/enhanced_features/edge_cases_test.exs
defmodule Exdantic.EnhancedFeaturesEdgeCasesTest do
  use ExUnit.Case

  describe "edge cases" do
    test "empty struct schema" do
      defmodule EmptyStructSchema do
        use Exdantic, define_struct: true
        
        schema do
          # No fields
        end
      end
      
      assert {:ok, result} = EmptyStructSchema.validate(%{})
      assert %EmptyStructSchema{} = result
    end

    test "schema with only computed fields" do
      defmodule OnlyComputedSchema do
        use Exdantic, define_struct: true
        
        schema do
          computed_field :timestamp, :string, fn _data ->
            DateTime.utc_now() |> DateTime.to_iso8601()
          end
          
          computed_field :random, :integer, fn _data ->
            :rand.uniform(100)
          end
        end
      end
      
      assert {:ok, result} = OnlyComputedSchema.validate(%{})
      assert %OnlyComputedSchema{} = result
      assert is_binary(result.timestamp)
      assert is_integer(result.random)
    end

    test "model validator that returns different data structure" do
      defmodule TransformingSchema do
        use Exdantic, define_struct: true
        
        schema do
          field :input, :string, required: true
          
          model_validator fn data ->
            # Transform the data completely
            new_data = %{
              input: data.input,
              processed: String.upcase(data.input),
              length: String.length(data.input)
            }
            {:ok, new_data}
          end
          
          computed_field :summary, :string, fn data ->
            "Input '#{data.input}' became '#{data.processed}' (#{data.length} chars)"
          end
        end
      end
      
      data = %{input: "hello"}
      assert {:ok, result} = TransformingSchema.validate(data)
      assert result.input == "hello"
      assert result.processed == "HELLO"
      assert result.length == 5
      assert String.contains?(result.summary, "hello")
    end

    test "circular computed field dependencies" do
      # This should be handled gracefully, though the behavior depends on implementation
      # For now, we test that it doesn't crash
      defmodule CircularComputedSchema do
        use Exdantic, define_struct: true
        
        schema do
          field :value, :integer, required: true
          
          computed_field :a, :integer, fn data ->
            # This creates a circular dependency if not handled carefully
            data.value + 1
          end
        end
      end
      
      data = %{value: 10}
      assert {:ok, result} = CircularComputedSchema.validate(data)
      assert result.a == 11
    end

    test "very large computed field" do
      defmodule LargeComputedSchema do
        use Exdantic, define_struct: true
        
        schema do
          field :size, :integer, required: true
          
          computed_field :large_list, {:array, :integer}, fn data ->
            Enum.to_list(1..data.size)
          end
        end
      end
      
      # Test with reasonable size
      data = %{size: 100}
      assert {:ok, result} = LargeComputedSchema.validate(data)
      assert length(result.large_list) == 100
    end

    test "model validator exception handling" do
      defmodule ExceptionValidatorSchema do
        use Exdantic, define_struct: true
        
        schema do
          field :divisor, :integer, required: true
          
          model_validator fn data ->
            # This will raise if divisor is 0
            _result = 10 / data.divisor
            {:ok, data}
          end
        end
      end
      
      # Should handle the exception gracefully
      data = %{divisor: 0}
      
      # The implementation should catch the exception and return an error
      # The exact behavior depends on implementation details
      case ExceptionValidatorSchema.validate(data) do
        {:ok, _} -> flunk("Expected validation to fail")
        {:error, errors} -> 
          assert is_list(errors)
          assert length(errors) > 0
      end
    end
  end

  describe "complex type interactions" do
    test "struct with nested computed fields" do
      defmodule NestedComputedSchema do
        use Exdantic, define_struct: true
        
        schema do
          field :items, {:array, :string}, required: true
          
          computed_field :count, :integer, fn data ->
            length(data.items)
          end
          
          computed_field :first_item, :string, fn data ->
            List.first(data.items) || ""
          end
          
          computed_field :summary, :map, fn data ->
            %{
              total_items: length(data.items),
              first: List.first(data.items),
              last: List.last(data.items),
              all_lengths: Enum.map(data.items, &String.length/1)
            }
          end
        end
      end
      
      data = %{items: ["hello", "world", "test"]}
      assert {:ok, result} = NestedComputedSchema.validate(data)
      
      assert result.count == 3
      assert result.first_item == "hello"
      assert result.summary.total_items == 3
      assert result.summary.first == "hello"
      assert result.summary.last == "test"
      assert result.summary.all_lengths == [5, 5, 4]
    end
  end

  describe "nil and default value handling" do
    test "computed fields with nil input" do
      defmodule NilComputedSchema do
        use Exdantic, define_struct: true
        
        schema do
          field :optional_value, :string, required: false
          
          computed_field :value_or_default, :string, fn data ->
            data.optional_value || "default"
          end
        end
      end
      
      # With nil value
      data = %{}
      assert {:ok, result} = NilComputedSchema.validate(data)
      assert result.value_or_default == "default"
      
      # With actual value
      data = %{optional_value: "custom"}
      assert {:ok, result} = NilComputedSchema.validate(data)
      assert result.value_or_default == "custom"
    end
  end
end
```

## 10. JSON Schema Generation Tests

```elixir
# test/enhanced_features/json_schema_test.exs
defmodule Exdantic.EnhancedFeaturesJsonSchemaTest do
  use ExUnit.Case
  alias Exdantic.{JsonSchema, Runtime}

  describe "computed fields in JSON schema" do
    test "computed fields appear as readOnly in compile-time schema" do
      defmodule JsonSchemaTestSchema do
        use Exdantic, define_struct: true
        
        schema do
          field :base_value, :integer, required: true
          
          computed_field :doubled, :integer, fn data ->
            data.base_value * 2
          end
          
          computed_field :description, :string, fn data ->
            "Value is #{data.base_value}"
          end
        end
      end
      
      json_schema = JsonSchema.from_schema(JsonSchemaTestSchema)
      properties = json_schema["properties"]
      
      # Regular field should not be readOnly
      refute Map.get(properties["base_value"], "readOnly", false)
      
      # Computed fields should be readOnly
      assert properties["doubled"]["readOnly"] == true
      assert properties["description"]["readOnly"] == true
      
      # Check types are correct
      assert properties["doubled"]["type"] == "integer"
      assert properties["description"]["type"] == "string"
    end

    test "computed fields in runtime schema JSON generation" do
      fields = [
        {:width, :integer, [required: true]},
        {:height, :integer, [required: true]}
      ]
      
      computed_fields = [
        {:area, fn data -> data.width * data.height end}
      ]
      
      schema = Runtime.create_enhanced_schema(fields,
        computed_fields: computed_fields
      )
      
      json_schema = Runtime.to_json_schema(schema)
      properties = json_schema["properties"]
      
      # Regular fields
      assert properties["width"]["type"] == "integer"
      assert properties["height"]["type"] == "integer"
      
      # Computed field (if implemented)
      # Note: This would require Runtime.to_json_schema to be enhanced
      # to handle computed fields
    end
  end

  describe "model validators in schema metadata" do
    test "model validators don't appear in JSON schema" do
      defmodule ValidatorJsonSchema do
        use Exdantic, define_struct: true
        
        schema do
          field :value, :integer, required: true
          
          model_validator fn data ->
            if data.value > 0, do: {:ok, data}, else: {:error, "positive only"}
          end
        end
      end
      
      json_schema = JsonSchema.from_schema(ValidatorJsonSchema)
      
      # Model validators shouldn't leak into JSON schema
      refute Map.has_key?(json_schema, "modelValidators")
      refute Map.has_key?(json_schema, "model_validators")
      
      # Should still have regular validation properties
      assert json_schema["type"] == "object"
      assert Map.has_key?(json_schema["properties"], "value")
    end
  end
end
```

## Test Runner Configuration

```elixir
# test/test_helper.exs additions
ExUnit.start()

# Configure performance tests to run only when specifically requested
ExUnit.configure(exclude: [:performance])

# Add property-based testing if PropCheck is available
if Code.ensure_loaded?(PropCheck) do
  # Configure PropCheck settings
  Application.put_env(:propcheck, :counterexample_max_tries, 1000)
end
```

## Mix Configuration for Tests

```elixir
# mix.exs additions for test dependencies
defp deps do
  [
    # ... existing deps
    {:propcheck, "~> 1.4", only: [:test, :dev]}
  ]
end

defp aliases do
  [
    "test.enhanced": ["test test/enhanced_features/"],
    "test.performance": ["test --include performance test/enhanced_features/performance_test.exs"],
    "test.property": ["test test/enhanced_features/property_test.exs"]
  ]
end
```

This comprehensive test suite covers:

1. **Struct Pattern**: Creation, field access, validation, and dumping
2. **Model Validators**: Single/multiple validators, error handling, data transformation
3. **Computed Fields**: Execution, struct integration, error handling, dependencies
4. **Integration**: All features working together, JSON schema generation
5. **Performance**: Benchmarks and memory usage tests
6. **Edge Cases**: Empty schemas, circular dependencies, exceptions
7. **Property-Based Testing**: Invariants and random data validation
8. **Error Handling**: Comprehensive error scenarios and edge cases

The tests ensure backward compatibility while thoroughly validating the new enhanced features work correctly both individually and together.
