# Exdantic Enhanced Features Documentation - Updated & Complete

## Overview

Exdantic has been enhanced with runtime capabilities that enable dynamic schema creation, type validation, and serialization patterns inspired by Pydantic. These features are specifically designed to support DSPy integration patterns while maintaining Elixir's functional programming principles.

### Key Enhancements (All Now Implemented ✅)

- **Runtime Schema Generation**: Create schemas dynamically from field definitions
- **TypeAdapter System**: Validate and serialize values against type specifications without full schemas
- **Wrapper Models**: Temporary single-field validation schemas for complex type coercion
- **Advanced Configuration**: Runtime configuration modification with preset patterns
- **Enhanced Validator**: Universal validation interface across all Exdantic features
- **JSON Schema Resolution**: Advanced reference handling and LLM provider optimization

## Runtime Schema Generation

### Creating Dynamic Schemas

The runtime system allows you to create schemas programmatically, supporting the DSPy pattern of `pydantic.create_model("ModelName", **fields)`.

```elixir
# Basic runtime schema creation
fields = [
  {:name, :string, [required: true, min_length: 2]},
  {:age, :integer, [required: false, gt: 0, lt: 150]},
  {:email, :string, [required: true, format: ~r/@/]}
]

schema = Exdantic.Runtime.create_schema(fields, 
  title: "User Schema",
  description: "Dynamic user validation schema"
)
```

### Field Definition Format

Fields are defined as tuples with the following format:

```elixir
{field_name, type_spec, options}
```

**Field Options:**
- `:required` - Whether field is required (default: true)
- `:optional` - Whether field is optional (overrides required: true)
- `:description` - Field description for documentation
- `:example` - Example value for the field
- `:examples` - Multiple example values
- `:default` - Default value (automatically makes field optional)
- Constraint options: `:min_length`, `:max_length`, `:gt`, `:lt`, `:format`, `:choices`, etc.

### Supported Type Specifications

```elixir
# Basic types
:string, :integer, :float, :boolean, :atom, :any, :map

# Complex types
{:array, inner_type}
{:map, {key_type, value_type}}
{:union, [type1, type2, ...]}

# Schema references
ModuleName  # References to existing schema modules

# With constraints (handled in options)
{field_name, :string, [min_length: 3, max_length: 100]}
```

### Validation with Runtime Schemas

```elixir
# Validate data against runtime schema
data = %{
  name: "John Doe",
  age: 30,
  email: "john@example.com"
}

case Exdantic.Runtime.validate(data, schema) do
  {:ok, validated_data} -> 
    # Process validated data
    IO.puts("User: #{validated_data.name}")
    
  {:error, errors} ->
    # Handle validation errors
    Enum.each(errors, &IO.puts(Exdantic.Error.format(&1)))
end
```

### JSON Schema Generation

```elixir
# Generate JSON Schema from runtime schema
json_schema = Exdantic.Runtime.to_json_schema(schema)

# JSON Schema will include:
# - Type definitions
# - Constraint mappings  
# - Required field specifications
# - Field descriptions and examples
```

## TypeAdapter System

### Basic TypeAdapter Usage

TypeAdapter provides runtime type validation and serialization without requiring a full schema definition, similar to Pydantic's `TypeAdapter(type).validate_python(value)`.

```elixir
# Basic type validation
{:ok, "hello"} = Exdantic.TypeAdapter.validate(:string, "hello")
{:ok, [1, 2, 3]} = Exdantic.TypeAdapter.validate({:array, :integer}, [1, 2, 3])

# Type coercion
{:ok, 123} = Exdantic.TypeAdapter.validate(:integer, "123", coerce: true)
{:ok, "hello"} = Exdantic.TypeAdapter.validate(:string, :hello, coerce: true)
```

### Complex Type Validation

```elixir
# Complex nested types
type_spec = {:map, {:string, {:union, [:string, :integer, {:array, :string}]}}}

data = %{
  "name" => "John",
  "age" => 30,
  "tags" => ["admin", "user"]
}

{:ok, validated} = Exdantic.TypeAdapter.validate(type_spec, data)
```

### Type Constraints

**Note**: TypeAdapter uses raw type definitions. For constraints, use Runtime schemas or Wrapper models.

```elixir
# For constraints, use normalized type definitions
normalized_type = Exdantic.Types.string() 
                 |> Exdantic.Types.with_constraints([min_length: 3, max_length: 50])

{:ok, "hello"} = Exdantic.TypeAdapter.validate(normalized_type, "hello")
```

### Serialization (Dump)

```elixir
# Serialize values according to type specifications
{:ok, "hello"} = Exdantic.TypeAdapter.dump(:string, "hello")
{:ok, "test_atom"} = Exdantic.TypeAdapter.dump(:atom, :test_atom)

# Complex serialization
type_spec = {:array, {:map, {:string, :integer}}}
data = [%{"score1" => 85}, %{"score2" => 92}]
{:ok, serialized} = Exdantic.TypeAdapter.dump(type_spec, data)
```

### Reusable TypeAdapter Instances

```elixir
# Create reusable adapter for efficiency
adapter = Exdantic.TypeAdapter.create({:array, :string}, coerce: true)

# Validate multiple values efficiently
{:ok, ["a", "b", "c"]} = Exdantic.TypeAdapter.Instance.validate(adapter, ["a", "b", "c"])

# Batch validation
values = [["a", "b"], ["c", "d"], ["e", "f"]]
{:ok, validated_list} = Exdantic.TypeAdapter.Instance.validate_many(adapter, values)
```

### JSON Schema Generation

```elixir
# Generate JSON Schema for type specifications
schema = Exdantic.TypeAdapter.json_schema({:array, :string})
# => %{"type" => "array", "items" => %{"type" => "string"}}

# With metadata
schema = Exdantic.TypeAdapter.json_schema(:string, 
  title: "User Name",
  description: "The user's full name"
)
```

## Wrapper Models

### Creating Wrapper Schemas

Wrapper models create temporary, single-field validation schemas for complex type coercion, implementing the DSPy pattern of `create_model("Wrapper", value=(target_type, ...))`.

```elixir
# Basic wrapper creation
wrapper = Exdantic.Wrapper.create_wrapper(:score, :integer, 
  constraints: [gteq: 0, lteq: 100],
  description: "Test score out of 100"
)

# Validate and extract value
{:ok, 85} = Exdantic.Wrapper.validate_and_extract(wrapper, 85, :score)

# One-step validation
{:ok, 85} = Exdantic.Wrapper.wrap_and_validate(:score, :integer, "85", 
  coerce: true,
  constraints: [gteq: 0, lteq: 100]
)
```

### Flexible Input Handling

```elixir
wrapper = Exdantic.Wrapper.create_flexible_wrapper(:age, :integer, coerce: true)

# All of these work:
{:ok, 25} = Exdantic.Wrapper.validate_flexible(wrapper, 25, :age)           # Raw value
{:ok, 25} = Exdantic.Wrapper.validate_flexible(wrapper, %{age: 25}, :age)   # Atom key
{:ok, 25} = Exdantic.Wrapper.validate_flexible(wrapper, %{"age" => 25}, :age) # String key
```

### Multiple Wrapper Operations

```elixir
# Create multiple wrappers
specs = [
  {:name, :string, [constraints: [min_length: 1]]},
  {:age, :integer, [constraints: [gt: 0]]},
  {:email, :string, [constraints: [format: ~r/@/]]}
]

wrappers = Exdantic.Wrapper.create_multiple_wrappers(specs)

# Validate multiple fields
data = %{name: "John", age: 30, email: "john@example.com"}
{:ok, validated} = Exdantic.Wrapper.validate_multiple(wrappers, data)
```

### Wrapper Factory Pattern

```elixir
# Create reusable wrapper factory
email_factory = Exdantic.Wrapper.create_wrapper_factory(:string,
  constraints: [format: ~r/@/],
  description: "Email address"
)

# Use factory to create specific wrappers
user_email = email_factory.(:user_email)
admin_email = email_factory.(:admin_email)
```

## Advanced Configuration

### Configuration Creation and Modification

The configuration system supports runtime modification patterns similar to DSPy's `ConfigDict(extra="forbid", frozen=True)`.

```elixir
# Basic configuration
config = Exdantic.Config.create(%{
  strict: true,
  extra: :forbid,
  coercion: :safe,
  error_format: :detailed
})

# Configuration merging (non-frozen configs only)
base_config = Exdantic.Config.create(strict: false)
strict_config = Exdantic.Config.merge(base_config, %{
  strict: true,
  extra: :forbid
})

# Frozen configuration (immutable)
frozen_config = Exdantic.Config.create(%{frozen: true, strict: true})
# Exdantic.Config.merge(frozen_config, %{strict: false})  # Raises RuntimeError
```

### Configuration Presets

```elixir
# Use predefined configuration presets
api_config = Exdantic.Config.preset(:api)        # Strict, safe for APIs
dev_config = Exdantic.Config.preset(:development) # Lenient, good for development
prod_config = Exdantic.Config.preset(:production) # Strict, optimized for production

# JSON Schema generation preset
schema_config = Exdantic.Config.preset(:json_schema)
lenient_config = Exdantic.Config.preset(:lenient)
strict_config = Exdantic.Config.preset(:strict)
```

### Builder Pattern

```elixir
# Fluent configuration building
config = Exdantic.Config.builder()
|> Exdantic.Config.Builder.strict(true)
|> Exdantic.Config.Builder.forbid_extra()
|> Exdantic.Config.Builder.safe_coercion()
|> Exdantic.Config.Builder.detailed_errors()
|> Exdantic.Config.Builder.build()

# Conditional configuration
config = Exdantic.Config.builder()
|> Exdantic.Config.Builder.when_true(Mix.env() == :prod, &Exdantic.Config.Builder.frozen/1)
|> Exdantic.Config.Builder.for_production()
|> Exdantic.Config.Builder.build()
```

### Configuration Options

**Validation Behavior:**
- `:strict` - Enforce strict validation (no unknown fields)
- `:extra` - How to handle extra fields (`:allow`, `:forbid`, `:ignore`)
- `:coercion` - Type coercion strategy (`:none`, `:safe`, `:aggressive`)
- `:validate_assignment` - Validate field assignments

**Error Handling:**
- `:error_format` - Error detail level (`:detailed`, `:simple`, `:minimal`)
- `:case_sensitive` - Case sensitivity for field names

**Schema Generation:**
- `:use_enum_values` - Use enum values instead of names
- `:max_anyof_union_len` - Maximum length for anyOf unions
- `:title_generator` - Function to generate field titles
- `:description_generator` - Function to generate field descriptions

**Protection:**
- `:frozen` - Whether configuration is immutable

## Enhanced Validator

### Universal Validation Interface

The Enhanced Validator provides a unified interface for validating against any Exdantic target type with advanced configuration support.

```elixir
# Validate against runtime schema
schema = Exdantic.Runtime.create_schema([{:name, :string}])
{:ok, validated} = Exdantic.EnhancedValidator.validate(schema, %{name: "John"})

# Validate against compiled schema
{:ok, validated} = Exdantic.EnhancedValidator.validate(MySchema, data)

# Validate against type specification
{:ok, validated} = Exdantic.EnhancedValidator.validate({:array, :string}, ["a", "b", "c"])

# Validate with custom configuration
config = Exdantic.Config.create(strict: true, coercion: :safe)
{:ok, validated} = Exdantic.EnhancedValidator.validate(schema, data, config: config)
```

### Wrapper Validation

```elixir
# Validate and unwrap single values
{:ok, 85} = Exdantic.EnhancedValidator.validate_wrapped(:score, :integer, "85", 
  config: Exdantic.Config.create(coercion: :safe)
)
```

### Batch Validation

```elixir
# Validate multiple values against same type
values = ["hello", "world", "test"]
{:ok, validated_list} = Exdantic.EnhancedValidator.validate_many(:string, values)

# Handle validation errors by index
values = [1, "invalid", 3]
{:error, error_map} = Exdantic.EnhancedValidator.validate_many(:integer, values)
# error_map[1] contains errors for the second item
```

### Validation with Schema Generation

```elixir
# Validate and generate JSON schema simultaneously
{:ok, validated, json_schema} = Exdantic.EnhancedValidator.validate_with_schema(schema, data)

# Validate with resolved references
{:ok, validated, resolved_schema} = Exdantic.EnhancedValidator.validate_with_resolved_schema(schema, data)

# Validate for specific LLM providers
{:ok, validated, llm_schema} = Exdantic.EnhancedValidator.validate_for_llm(schema, data, :openai)
```

### Validation Pipelines

```elixir
# Create validation and transformation pipelines
pipeline_steps = [
  :string,                           # Validate as string
  fn s -> {:ok, String.upcase(s)} end, # Transform to uppercase
  :string,                           # Validate again
  fn s -> {:ok, String.length(s)} end, # Get length
  :integer                           # Validate as integer
]

{:ok, 11} = Exdantic.EnhancedValidator.pipeline(pipeline_steps, "hello world")
```

### Validation Reports

```elixir
# Generate comprehensive validation reports for debugging
report = Exdantic.EnhancedValidator.validation_report(schema, data)

# Report includes:
# - validation_result: success/failure
# - json_schema: generated schema
# - target_info: information about validation target
# - input_analysis: analysis of input data
# - performance_metrics: timing information
# - configuration: applied configuration summary
```

## JSON Schema Resolution

### Reference Resolution

The resolver system handles complex JSON schema references and optimizes schemas for different LLM providers.

```elixir
# Resolve all $ref entries
schema_with_refs = %{
  "type" => "object",
  "properties" => %{
    "user" => %{"$ref" => "#/definitions/User"}
  },
  "definitions" => %{
    "User" => %{"type" => "object", "properties" => %{"name" => %{"type" => "string"}}}
  }
}

resolved = Exdantic.JsonSchema.Resolver.resolve_references(schema_with_refs)
# All references are now expanded inline
```

### Schema Flattening

```elixir
# Flatten schemas for LLM compatibility
flattened = Exdantic.JsonSchema.Resolver.flatten_schema(complex_schema,
  max_depth: 5,
  inline_simple_refs: true
)
```

### LLM Provider Optimization

```elixir
# Optimize for OpenAI structured output
openai_schema = Exdantic.JsonSchema.Resolver.enforce_structured_output(schema, 
  provider: :openai,
  remove_unsupported: true
)

# Optimize for Anthropic
anthropic_schema = Exdantic.JsonSchema.Resolver.enforce_structured_output(schema,
  provider: :anthropic
)

# General LLM optimization
optimized = Exdantic.JsonSchema.Resolver.optimize_for_llm(schema,
  remove_descriptions: true,
  simplify_unions: true,
  max_properties: 10
)
```

## DSPy Integration Patterns

### Create Model Pattern

```elixir
# DSPy: pydantic.create_model("DSPyProgramOutputs", **fields)
# Exdantic equivalent:

fields = [
  {:reasoning, :string, [description: "Chain of thought reasoning"]},
  {:answer, :string, [description: "Final answer", required: true]},
  {:confidence, :float, [gteq: 0.0, lteq: 1.0, description: "Confidence score"]},
  {:sources, {:array, :string}, [description: "Information sources"]}
]

schema = Exdantic.Runtime.create_schema(fields,
  title: "DSPyProgramOutputs",
  description: "Output schema for DSPy program"
)
```

### TypeAdapter Pattern

```elixir
# DSPy: TypeAdapter(type(value)).validate_python(value)
# Exdantic equivalent:

# Direct validation
{:ok, validated} = Exdantic.TypeAdapter.validate({:array, :string}, ["a", "b", "c"])

# Reusable adapter
adapter = Exdantic.TypeAdapter.create({:array, :string})
{:ok, validated} = Exdantic.TypeAdapter.Instance.validate(adapter, ["a", "b", "c"])
```

### Wrapper Model Pattern

```elixir
# DSPy: create_model("Wrapper", value=(target_type, ...))
# Exdantic equivalent:

{:ok, validated} = Exdantic.Wrapper.wrap_and_validate(:result, :integer, "42",
  coerce: true,
  constraints: [gt: 0]
)
```

### Configuration Pattern

```elixir
# DSPy: ConfigDict(extra="forbid", frozen=True)
# Exdantic equivalent:

config = Exdantic.Config.create(%{
  extra: :forbid,
  frozen: true,
  strict: true
})

# Use configuration with validation
{:ok, validated} = Exdantic.EnhancedValidator.validate(schema, data, config: config)
```

## Performance Guidelines

### Runtime Schema Performance

- **Schema Creation**: ~1000 schemas/second for typical complexity
- **Validation**: ~10k validations/second for simple schemas
- **JSON Schema Generation**: <50ms for complex schemas

### TypeAdapter Performance

- **Single Validation**: Sub-millisecond for basic types
- **Batch Validation**: ~10k items/second for simple types
- **Complex Types**: Performance scales with nesting depth

### Memory Considerations

```elixir
# Use TypeAdapter instances for repeated operations
adapter = Exdantic.TypeAdapter.create(type_spec)  # Create once
# Use adapter.validate many times

# Avoid creating new schemas for each validation
schema = Exdantic.Runtime.create_schema(fields)   # Create once
# Use schema for multiple validations

# For very large datasets, consider streaming validation
large_dataset
|> Stream.chunk_every(1000)
|> Stream.map(&Exdantic.EnhancedValidator.validate_many(type_spec, &1))
|> Enum.to_list()
```

### Optimization Tips

1. **Reuse Schemas and Adapters**: Create once, use many times
2. **Use Appropriate Configuration**: Don't use `:strict` if not needed
3. **Batch Operations**: Use `validate_many` for multiple items
4. **Cache JSON Schemas**: Generate once for repeated use
5. **Profile in Production**: Use `:fprof` to identify bottlenecks

## Error Handling & Debugging

### Structured Error Format

All validation functions return errors in a consistent format:

```elixir
%Exdantic.Error{
  path: [:user, :email],      # Path to error location
  code: :format,              # Error classification  
  message: "invalid email"    # Human-readable message
}
```

### Common Error Codes

- `:required` - Required field missing
- `:type` - Type mismatch
- `:format` - Format constraint violation
- `:min_length`, `:max_length` - Length constraints
- `:gt`, `:lt`, `:gteq`, `:lteq` - Numeric constraints
- `:additional_properties` - Extra fields in strict mode
- `:custom_validation` - Custom validator failure

### Best Practices

1. **Always Handle Errors**: Use pattern matching on `{:ok, result}` vs `{:error, errors}`
2. **Format for Users**: Use `Exdantic.Error.format/1` for human-readable error messages
3. **Log for Debugging**: Include error paths and codes in logs
4. **Validate Early**: Validate input at system boundaries
5. **Use Validation Reports**: For complex debugging scenarios

## Migration from Basic Exdantic

### From Compile-Time to Runtime Schemas

```elixir
# Old: Compile-time schema
defmodule UserSchema do
  use Exdantic
  
  schema do
    field :name, :string
    field :age, :integer
  end
end

# New: Runtime schema
user_schema = Exdantic.Runtime.create_schema([
  {:name, :string, [required: true]},
  {:age, :integer, [required: true]}
])
```

### From Manual Validation to TypeAdapter

```elixir
# Old: Manual type checking
if is_binary(value) and String.length(value) > 0 do
  {:ok, value}
else
  {:error, "invalid string"}
end

# New: TypeAdapter validation
Exdantic.TypeAdapter.validate(:string, value)
```

### From Static to Dynamic Configuration

```elixir
# Old: Fixed validation options
UserSchema.validate(data)

# New: Dynamic configuration
config = Exdantic.Config.create(strict: true, coercion: :safe)
Exdantic.EnhancedValidator.validate(schema, data, config: config)
```

This documentation now reflects all implemented features and provides comprehensive guidance for using Exdantic's enhanced capabilities.
