# Phase 1: Struct Pattern Implementation

## Overview
Implement optional struct generation for Exdantic schemas without breaking existing functionality.

## Dependencies Setup

First, add testing utilities to `mix.exs`:

```elixir
# mix.exs - add to deps
defp deps do
  [
    # ... existing deps
    {:stream_data, "~> 0.6", only: [:test, :dev]},  # Property-based testing
    {:benchee, "~> 1.1", only: [:test, :dev]}       # Performance benchmarking
  ]
end

# Add test aliases
defp aliases do
  [
    "test.watch": ["test --listen-on-stdin"],
    "test.struct": ["test test/struct_pattern/"],
    "test.integration": ["test --include integration"],
    "benchmark": ["run benchmarks/struct_performance.exs"]
  ]
end
```

## Implementation Steps

### Step 1: Extend `use Exdantic` Macro

**File**: `lib/exdantic.ex`

```elixir
defmacro __using__(opts) do
  define_struct? = Keyword.get(opts, :define_struct, false)

  quote do
    import Exdantic.Schema

    # Register accumulating attributes
    Module.register_attribute(__MODULE__, :schema_description, [])
    Module.register_attribute(__MODULE__, :fields, accumulate: true)
    Module.register_attribute(__MODULE__, :validations, accumulate: true)
    Module.register_attribute(__MODULE__, :config, [])
    
    # NEW: Store struct option
    @exdantic_define_struct unquote(define_struct?)

    @before_compile Exdantic
  end
end
```

## Benchmarking Setup

**File**: `benchmarks/struct_performance.exs`

```elixir
defmodule StructBenchmarks do
  @moduledoc """
  Performance benchmarks for struct pattern functionality.
  """

  # Define test schemas
  defmodule BenchMapSchema do
    use Exdantic, define_struct: false
    
    schema do
      field :name, :string, required: true
      field :age, :integer, required: true
      field :email, :string, required: true
      field :active, :boolean, default: true
    end
  end

  defmodule BenchStructSchema do
    use Exdantic, define_struct: true
    
    schema do
      field :name, :string, required: true
      field :age, :integer, required: true
      field :email, :string, required: true
      field :active, :boolean, default: true
    end
  end

  def run do
    data = %{
      name: "John Doe",
      age: 30,
      email: "john@example.com"
    }

    Benchee.run(
      %{
        "map_validation" => fn -> BenchMapSchema.validate(data) end,
        "struct_validation" => fn -> BenchStructSchema.validate(data) end,
        "struct_dump" => fn -> 
          {:ok, struct} = BenchStructSchema.validate(data)
          BenchStructSchema.dump(struct)
        end
      },
      time: 10,
      memory_time: 2,
      formatters: [
        Benchee.Formatters.HTML,
        Benchee.Formatters.Console
      ]
    )
  end
end

StructBenchmarks.run()
```

## Stabilization Process

### 1. Test-Driven Development Cycle

```bash
# Run the full test suite to ensure no regressions
mix test

# Run struct-specific tests during development
mix test test/struct_pattern/

# Run performance tests separately
mix test --include performance

# Check test coverage
mix test --cover
```

### 2. Code Quality Validation

```bash
# Ensure Dialyzer remains green
mix dialyzer

# Format code consistently
mix format

# Run static analysis
mix credo --strict

# Check documentation coverage
mix docs
```

### 3. Integration Testing Process

```bash
# Test with existing functionality
mix test --include integration

# Benchmark performance
mix benchmark

# Test with various Elixir versions if needed
MIX_ENV=test mix deps.get
mix test
```

### 4. Validation Checklist

**Before Phase 1 Completion:**

- [ ] All 530 existing tests pass
- [ ] New struct functionality tests pass (minimum 20 tests)
- [ ] Dialyzer shows no new warnings/errors
- [ ] Performance benchmarks show acceptable overhead (<2x slower)
- [ ] Memory usage is reasonable (<2x struct vs map)
- [ ] Documentation is complete and accurate
- [ ] Code coverage >95% for new functionality

**Specific Validation Steps:**

1. **Regression Testing**:
   ```bash
   # Run original test suite multiple times to catch flaky tests
   for i in {1..5}; do mix test; done
   ```

2. **Edge Case Testing**:
   ```bash
   # Test with various field combinations
   mix test test/struct_pattern/
   
   # Test error conditions
   mix test --include error_cases
   ```

3. **Performance Validation**:
   ```bash
   # Benchmark against baseline
   mix benchmark
   
   # Memory profiling if needed
   mix test --include memory_profile
   ```

4. **API Consistency Check**:
   - Ensure all schemas with `define_struct: true` have `dump/1`
   - Verify `__struct_enabled__?/0` is always available
   - Check `__struct_fields__/0` only exists for struct schemas

### 5. Common Issues and Solutions

**Issue**: Struct creation fails with ArgumentError
**Solution**: Ensure field names in struct match exactly with validated data keys

**Issue**: Performance degradation
**Solution**: Profile struct creation bottlenecks, consider lazy field extraction

**Issue**: Dialyzer warnings about struct types
**Solution**: Add proper `@type` annotations and specs

**Issue**: Test flakiness
**Solution**: Ensure test isolation, avoid global state, use deterministic data

### 6. Rollback Strategy

If critical issues are discovered:

1. **Immediate rollback**: Revert `lib/exdantic.ex` changes
2. **Isolate changes**: Move struct functionality to separate module
3. **Feature flag**: Add runtime flag to disable struct generation
4. **Gradual rollout**: Enable struct pattern for specific schemas only

### 7. Documentation Requirements

**Code Documentation**:
- All public functions have `@doc` and `@spec`
- Module documentation explains struct pattern benefits
- Examples show both struct and map usage

**User Documentation**:
- Migration guide for enabling structs
- Performance characteristics explained
- Best practices for struct vs map choice

### 8. Next Phase Preparation

**Before moving to Phase 2:**

1. **API Stability**: Struct pattern API is finalized and won't change
2. **Performance Baseline**: Established performance benchmarks for comparison
3. **Test Infrastructure**: Robust test patterns established for model validators
4. **Documentation**: Complete foundation documentation for building upon

**Phase 2 Prerequisites**:
- All Phase 1 tests passing
- Performance acceptable
- API design reviewed and approved
- Migration path for existing schemas clear

This stabilization process ensures that Phase 1 provides a solid foundation for the subsequent phases while maintaining the high quality and reliability of the existing Exdantic codebase.

defmacro __before_compile__(env) do
  define_struct? = Module.get_attribute(env.module, :exdantic_define_struct)
  fields = Module.get_attribute(env.module, :fields) || []
  
  # Extract field names for struct
  field_names = Enum.map(fields, fn {name, _meta} -> name end)
  
  struct_def = if define_struct? do
    quote do
      defstruct unquote(field_names)
      
      @type t :: %__MODULE__{}
      
      @doc """
      Returns the struct definition fields for this schema.
      """
      def __struct_fields__, do: unquote(field_names)
      
      @doc """
      Returns whether this schema defines a struct.
      """
      def __struct_enabled__?, do: true
    end
  else
    quote do
      @doc """
      Returns whether this schema defines a struct.
      """
      def __struct_enabled__?, do: false
    end
  end
  
  quote do
    # Inject struct definition if requested
    unquote(struct_def)

    # Define __schema__ functions (existing)
    def __schema__(:description), do: @schema_description
    def __schema__(:fields), do: @fields
    def __schema__(:validations), do: @validations
    def __schema__(:config), do: @config
    
    # Enhanced validation function that returns struct or map
    @doc """
    Validates data against this schema.
    """
    @spec validate(map()) :: {:ok, map() | struct()} | {:error, [Exdantic.Error.t()]}
    def validate(data) do
      Exdantic.StructValidator.validate_schema(__MODULE__, data)
    end

    @doc """
    Validates data against this schema, raising an exception on failure.
    """
    @spec validate!(map()) :: map() | struct()
    def validate!(data) do
      case validate(data) do
        {:ok, validated} -> validated
        {:error, errors} -> raise Exdantic.ValidationError, errors: errors
      end
    end
    
    # NEW: Dump function for struct serialization
    if unquote(define_struct?) do
      @doc """
      Serializes a struct instance back to a map.
      """
      @spec dump(struct() | map()) :: {:ok, map()} | {:error, String.t()}
      def dump(%__MODULE__{} = struct) do
        {:ok, Map.from_struct(struct)}
      end
      
      def dump(map) when is_map(map) do
        {:ok, map}
      end
      
      def dump(other) do
        {:error, "Expected #{__MODULE__} struct or map, got: #{inspect(other)}"}
      end
    end
  end
end
```

### Step 2: Create Struct Validator

**File**: `lib/exdantic/struct_validator.ex`

```elixir
defmodule Exdantic.StructValidator do
  @moduledoc """
  Validator that optionally returns struct instances instead of maps.
  
  This module extends the existing validation logic to support returning
  struct instances when a schema is defined with `define_struct: true`.
  """

  alias Exdantic.{Error, Validator}

  @doc """
  Validates data against a schema, returning struct or map based on schema configuration.
  """
  @spec validate_schema(module(), map(), [atom()]) :: 
    {:ok, map() | struct()} | {:error, [Error.t()]}
  def validate_schema(schema_module, data, path \\ []) when is_atom(schema_module) do
    # Use existing validation logic
    case Validator.validate_schema(schema_module, data, path) do
      {:ok, validated_map} ->
        # Check if schema defines a struct
        if function_exported?(schema_module, :__struct_enabled__?, 0) and 
           schema_module.__struct_enabled__?() do
          # Create struct instance
          try do
            validated_struct = struct!(schema_module, validated_map)
            {:ok, validated_struct}
          rescue
            e in ArgumentError ->
              # This should not happen if our field extraction is correct
              error = Error.new(path, :struct_creation, 
                "Failed to create struct: #{Exception.message(e)}")
              {:error, [error]}
          end
        else
          # Return map as before
          {:ok, validated_map}
        end
      
      {:error, errors} ->
        {:error, errors}
    end
  end
end
```

## Test Implementation

### Test Structure

```
test/
├── struct_pattern/
│   ├── basic_struct_test.exs
│   ├── struct_validation_test.exs  
│   ├── struct_serialization_test.exs
│   ├── backwards_compatibility_test.exs
│   └── performance_test.exs
└── support/
    └── struct_test_schemas.ex
```

### Test Schemas

**File**: `test/support/struct_test_schemas.ex`

```elixir
defmodule Exdantic.StructTestSchemas do
  @moduledoc """
  Test schemas for struct pattern testing.
  """

  # Schema with struct enabled
  defmodule UserStructSchema do
    use Exdantic, define_struct: true

    schema "User with struct" do
      field :name, :string do
        required()
        min_length(1)
      end

      field :age, :integer do
        optional()
        gteq(0)
      end

      field :email, :string do
        required()
        format(~r/@/)
      end

      field :active, :boolean do
        default(true)
      end
    end
  end

  # Schema without struct (existing behavior)
  defmodule UserMapSchema do
    use Exdantic, define_struct: false

    schema "User without struct" do
      field :name, :string do
        required()
        min_length(1)
      end

      field :age, :integer do
        optional()
        gteq(0)
      end
    end
  end

  # Schema with default behavior (no struct)
  defmodule DefaultSchema do
    use Exdantic  # No explicit define_struct option

    schema do
      field :title, :string, required: true
      field :count, :integer, required: true
    end
  end

  # Complex schema with nested types
  defmodule ComplexStructSchema do
    use Exdantic, define_struct: true

    schema do
      field :tags, {:array, :string} do
        required()
        min_items(1)
      end

      field :metadata, {:map, {:string, :any}} do
        optional()
      end

      field :score, :float do
        optional()
        gteq(0.0)
        lteq(1.0)
      end
    end
  end
end
```

### Basic Struct Tests

**File**: `test/struct_pattern/basic_struct_test.exs`

```elixir
defmodule Exdantic.BasicStructTest do
  use ExUnit.Case
  alias Exdantic.StructTestSchemas.{UserStructSchema, UserMapSchema, DefaultSchema}

  describe "struct definition" do
    test "creates struct when define_struct: true" do
      # Check that the struct was defined
      assert function_exported?(UserStructSchema, :__struct__, 0)
      assert function_exported?(UserStructSchema, :__struct__, 1)
      
      # Check struct fields
      struct = %UserStructSchema{}
      assert Map.has_key?(struct, :name)
      assert Map.has_key?(struct, :age)
      assert Map.has_key?(struct, :email)
      assert Map.has_key?(struct, :active)
      assert struct.__struct__ == UserStructSchema
    end

    test "does not create struct when define_struct: false" do
      refute function_exported?(UserMapSchema, :__struct__, 0)
      assert function_exported?(UserMapSchema, :__struct_enabled__?, 0)
      refute UserMapSchema.__struct_enabled__?()
    end

    test "defaults to no struct when option not specified" do
      refute function_exported?(DefaultSchema, :__struct__, 0)
      refute DefaultSchema.__struct_enabled__?()
    end

    test "__struct_fields__ returns all field names" do
      fields = UserStructSchema.__struct_fields__()
      assert :name in fields
      assert :age in fields  
      assert :email in fields
      assert :active in fields
      assert length(fields) == 4
    end

    test "__struct_enabled__? returns correct value" do
      assert UserStructSchema.__struct_enabled__?()
      refute UserMapSchema.__struct_enabled__?()
      refute DefaultSchema.__struct_enabled__?()
    end
  end

  describe "struct field access" do
    test "struct has correct field access" do
      struct = %UserStructSchema{name: "John", age: 30, email: "john@test.com"}
      assert struct.name == "John"
      assert struct.age == 30
      assert struct.email == "john@test.com"
      assert struct.active == nil  # Not set, no default in struct
    end

    test "struct can be pattern matched" do
      struct = %UserStructSchema{name: "Alice", email: "alice@test.com"}
      
      assert %UserStructSchema{name: name, email: email} = struct
      assert name == "Alice"
      assert email == "alice@test.com"
    end

    test "struct maintains type information" do
      struct = %UserStructSchema{}
      assert is_struct(struct)
      assert is_struct(struct, UserStructSchema)
      refute is_struct(struct, UserMapSchema)
    end
  end
end
```

### Validation Tests

**File**: `test/struct_pattern/struct_validation_test.exs`

```elixir
defmodule Exdantic.StructValidationTest do
  use ExUnit.Case
  alias Exdantic.StructTestSchemas.{UserStructSchema, UserMapSchema, ComplexStructSchema}

  describe "validation with struct return" do
    test "returns struct instance when define_struct: true" do
      data = %{name: "Alice", email: "alice@example.com", age: 25}
      
      assert {:ok, result} = UserStructSchema.validate(data)
      assert %UserStructSchema{} = result
      assert result.name == "Alice"
      assert result.email == "alice@example.com"
      assert result.age == 25
      assert result.active == true  # Default value applied
    end

    test "returns map when define_struct: false" do
      data = %{name: "Bob", age: 30}
      
      assert {:ok, result} = UserMapSchema.validate(data)
      assert is_map(result)
      refute is_struct(result)
      assert result.name == "Bob"
      assert result.age == 30
    end

    test "handles optional fields in struct" do
      data = %{name: "Charlie", email: "charlie@test.com"}  # age is optional
      
      assert {:ok, result} = UserStructSchema.validate(data)
      assert %UserStructSchema{} = result
      assert result.name == "Charlie"
      assert result.email == "charlie@test.com"
      assert is_nil(result.age)
      assert result.active == true
    end

    test "handles validation errors normally" do
      data = %{age: 30}  # name and email are required
      
      assert {:error, errors} = UserStructSchema.validate(data)
      assert is_list(errors)
      assert length(errors) >= 2  # At least name and email errors
    end

    test "validates field constraints in struct mode" do
      data = %{name: "", email: "invalid-email"}  # name too short, email invalid
      
      assert {:error, errors} = UserStructSchema.validate(data)
      assert length(errors) >= 2
      
      error_codes = Enum.map(errors, & &1.code)
      assert :min_length in error_codes or :type in error_codes
      assert :format in error_codes
    end
  end

  describe "complex type validation" do
    test "handles arrays and maps in struct" do
      data = %{
        tags: ["elixir", "testing"],
        metadata: %{"priority" => "high", "category" => "backend"},
        score: 0.85
      }
      
      assert {:ok, result} = ComplexStructSchema.validate(data)
      assert %ComplexStructSchema{} = result
      assert result.tags == ["elixir", "testing"]
      assert result.metadata == %{"priority" => "high", "category" => "backend"}
      assert result.score == 0.85
    end

    test "validates array constraints in struct mode" do
      data = %{tags: []}  # Empty array, but min_items(1) required
      
      assert {:error, errors} = ComplexStructSchema.validate(data)
      assert length(errors) >= 1
      
      error = Enum.find(errors, &(&1.code == :min_items))
      assert error != nil
    end
  end

  describe "struct creation edge cases" do
    test "handles struct creation with all nil optional fields" do
      data = %{name: "Test", email: "test@example.com"}
      
      assert {:ok, result} = UserStructSchema.validate(data)
      assert %UserStructSchema{} = result
      assert is_nil(result.age)
      assert result.active == true  # Has default
    end

    test "struct creation with extra fields in strict mode" do
      # This depends on the schema config, testing both scenarios
      data = %{
        name: "Test", 
        email: "test@example.com",
        extra_field: "should_be_ignored_or_error"
      }
      
      # Should either succeed (ignoring extra) or fail (strict mode)
      # The exact behavior depends on schema configuration
      case UserStructSchema.validate(data) do
        {:ok, result} ->
          assert %UserStructSchema{} = result
          refute Map.has_key?(result, :extra_field)
        
        {:error, errors} ->
          assert is_list(errors)
          # Should be an "unknown field" type error if strict
      end
    end
  end
end
```

### Serialization Tests

**File**: `test/struct_pattern/struct_serialization_test.exs`

```elixir
defmodule Exdantic.StructSerializationTest do
  use ExUnit.Case
  alias Exdantic.StructTestSchemas.{UserStructSchema, UserMapSchema}

  describe "dump functionality" do
    test "converts struct back to map" do
      struct = %UserStructSchema{
        name: "Charlie", 
        age: 35, 
        email: "charlie@test.com",
        active: false
      }
      
      assert {:ok, map} = UserStructSchema.dump(struct)
      assert is_map(map)
      refute is_struct(map)
      assert map.name == "Charlie"
      assert map.age == 35
      assert map.email == "charlie@test.com"
      assert map.active == false
    end

    test "handles plain map input" do
      map = %{name: "David", age: 40, email: "david@test.com"}
      
      assert {:ok, result} = UserStructSchema.dump(map)
      assert result == map
    end

    test "returns error for invalid input types" do
      assert {:error, error_msg} = UserStructSchema.dump("invalid")
      assert String.contains?(error_msg, "Expected")
      assert String.contains?(error_msg, "struct or map")
      
      assert {:error, _} = UserStructSchema.dump(123)
      assert {:error, _} = UserStructSchema.dump([:list])
    end

    test "returns error for wrong struct type" do
      other_struct = %{__struct__: SomeOtherStruct, data: "test"}
      
      assert {:error, error_msg} = UserStructSchema.dump(other_struct)
      assert String.contains?(error_msg, "Expected")
    end

    test "dump function not available for non-struct schemas" do
      refute function_exported?(UserMapSchema, :dump, 1)
    end
  end

  describe "round-trip validation and dumping" do
    test "validate then dump preserves data" do
      original_data = %{
        name: "Test User",
        age: 42,
        email: "test@example.com",
        active: false
      }
      
      assert {:ok, validated_struct} = UserStructSchema.validate(original_data)
      assert {:ok, dumped_map} = UserStructSchema.dump(validated_struct)
      
      # Should preserve all the data (though active might have default)
      assert dumped_map.name == original_data.name
      assert dumped_map.age == original_data.age
      assert dumped_map.email == original_data.email
      assert dumped_map.active == original_data.active
    end

    test "handles default values in round-trip" do
      # Only provide required fields
      minimal_data = %{name: "Minimal", email: "minimal@test.com"}
      
      assert {:ok, validated_struct} = UserStructSchema.validate(minimal_data)
      assert {:ok, dumped_map} = UserStructSchema.dump(validated_struct)
      
      # Should include default values
      assert dumped_map.name == "Minimal"
      assert dumped_map.email == "minimal@test.com"
      assert dumped_map.active == true  # Default value
      assert Map.has_key?(dumped_map, :age)  # Present but nil
    end
  end
end
```

### Backwards Compatibility Tests

**File**: `test/struct_pattern/backwards_compatibility_test.exs`

```elixir
defmodule Exdantic.BackwardsCompatibilityTest do
  use ExUnit.Case
  
  # Import existing test schemas to ensure they still work
  # These should be schemas that existed before struct support
  
  describe "existing schemas unchanged" do
    test "schemas without define_struct option work exactly as before" do
      defmodule LegacySchema do
        use Exdantic
        
        schema do
          field :name, :string, required: true
          field :count, :integer, required: true
        end
      end
      
      data = %{name: "test", count: 42}
      
      assert {:ok, result} = LegacySchema.validate(data)
      assert is_map(result)
      refute is_struct(result)
      assert result.name == "test"
      assert result.count == 42
    end

    test "all existing validation behaviors preserved" do
      defmodule LegacyValidationSchema do
        use Exdantic
        
        schema do
          field :email, :string do
            required()
            format(~r/@/)
          end
          
          field :age, :integer do
            optional()
            gteq(18)
          end
        end
      end
      
      # Valid data
      valid_data = %{email: "test@example.com", age: 25}
      assert {:ok, result} = LegacyValidationSchema.validate(valid_data)
      assert is_map(result)
      
      # Invalid data - should fail exactly as before  
      invalid_data = %{email: "not-email", age: 16}
      assert {:error, errors} = LegacyValidationSchema.validate(invalid_data)
      assert is_list(errors)
      assert length(errors) >= 2
    end

    test "JSON schema generation unchanged for non-struct schemas" do
      defmodule JsonTestSchema do
        use Exdantic
        
        schema do
          field :title, :string, required: true
          field :optional_field, :integer, required: false
        end
      end
      
      json_schema = Exdantic.JsonSchema.from_schema(JsonTestSchema)
      
      # Should have the same structure as before
      assert json_schema["type"] == "object"
      assert Map.has_key?(json_schema, "properties")
      assert Map.has_key?(json_schema["properties"], "title")
      assert Map.has_key?(json_schema["properties"], "optional_field")
      
      # Required fields should be marked correctly
      assert "title" in json_schema["required"]
      refute "optional_field" in json_schema["required"]
    end
  end

  describe "existing API methods preserved" do
    test "validate!/1 still works and throws same exceptions" do
      defmodule ExceptionTestSchema do
        use Exdantic
        
        schema do
          field :required_field, :string, required: true
        end
      end
      
      # Valid case
      valid_data = %{required_field: "test"}
      assert %{required_field: "test"} = ExceptionTestSchema.validate!(valid_data)
      
      # Invalid case - should raise ValidationError as before
      invalid_data = %{}
      assert_raise Exdantic.ValidationError, fn ->
        ExceptionTestSchema.validate!(invalid_data)
      end
    end

    test "__schema__/1 functions unchanged" do
      defmodule SchemaIntrospectionTest do
        use Exdantic
        
        schema "Test description" do
          field :test_field, :string, required: true
        end
      end
      
      # All existing introspection should work
      assert SchemaIntrospectionTest.__schema__(:description) == "Test description"
      assert is_list(SchemaIntrospectionTest.__schema__(:fields))
      assert SchemaIntrospectionTest.__schema__(:config) == nil
    end
  end

  @tag :integration
  describe "integration with existing features" do
    test "works with enhanced validator" do
      defmodule EnhancedCompatSchema do
        use Exdantic
        
        schema do
          field :value, :integer, required: true
        end
      end
      
      data = %{value: 42}
      
      # Should work with the enhanced validator
      assert {:ok, result} = Exdantic.EnhancedValidator.validate(EnhancedCompatSchema, data)
      assert result.value == 42
    end

    test "works with runtime schemas" do
      # Existing runtime schema functionality should be unaffected
      fields = [{:name, :string, [required: true]}]
      schema = Exdantic.Runtime.create_schema(fields)
      
      data = %{name: "test"}
      assert {:ok, result} = Exdantic.Runtime.validate(data, schema)
      assert result.name == "test"
    end
  end
end
```

### Performance Tests

**File**: `test/struct_pattern/performance_test.exs`

```elixir
defmodule Exdantic.StructPerformanceTest do
  use ExUnit.Case

  @moduletag :performance

  describe "struct creation performance" do
    test "struct validation performance is acceptable" do
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
      
      # Warm up
      PerfStructSchema.validate(data)
      
      {time_microseconds, _result} = :timer.tc(fn ->
        Enum.each(1..1000, fn _ ->
          PerfStructSchema.validate(data)
        end)
      end)
      
      avg_time_ms = time_microseconds / 1000 / 1000  # Convert to milliseconds per operation
      
      # Should be under 1ms per validation on average
      assert avg_time_ms < 1.0, "Average validation time #{avg_time_ms}ms exceeds 1ms threshold"
    end

    test "struct validation vs map validation performance comparison" do
      defmodule PerfMapSchema do
        use Exdantic, define_struct: false
        
        schema do
          field :field1, :string, required: true
          field :field2, :integer, required: true
        end
      end
      
      defmodule PerfStructSchemaComp do
        use Exdantic, define_struct: true
        
        schema do
          field :field1, :string, required: true
          field :field2, :integer, required: true
        end
      end
      
      data = %{field1: "test", field2: 42}
      
      # Measure map validation
      {map_time, _} = :timer.tc(fn ->
        Enum.each(1..1000, fn _ ->
          PerfMapSchema.validate(data)
        end)
      end)
      
      # Measure struct validation
      {struct_time, _} = :timer.tc(fn ->
        Enum.each(1..1000, fn _ ->
          PerfStructSchemaComp.validate(data)
        end)
      end)
      
      # Struct validation should not be more than 2x slower than map validation
      ratio = struct_time / map_time
      assert ratio < 2.0, "Struct validation is #{ratio}x slower than map validation"
    end
  end

  describe "memory usage" do
    test "struct memory usage is reasonable" do
      defmodule MemoryStructSchema do
        use Exdantic, define_struct: true
        
        schema do
          Enum.each(1..20, fn i ->
            field String.to_atom("field_#{i}"), :string, required: false
          end)
        end
      end
      
      data = for i <- 1..20, into: %{} do
        {String.to_atom("field_#{i}"), "value_#{i}"}
      end
      
      {:ok, result} = MemoryStructSchema.validate(data)
      
      # Check that struct size is reasonable
      struct_size = :erts_debug.size(result)
      map_size = :erts_debug.size(data)
      
      # Struct should not be dramatically larger than equivalent map
      assert struct_size < map_size * 2, "Struct size #{struct_size} vs map size #{map_size}"
    end
  end
