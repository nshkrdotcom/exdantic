# Exdantic

**A powerful, flexible schema definition and validation library for Elixir, inspired by Python's Pydantic.**

This project is directly based on [Elixact](https://github.com/LiboShen/elixact) by LiboShen.

[![CI](https://github.com/nshkrdotcom/exdantic/actions/workflows/ci.yml/badge.svg)](https://github.com/nshkrdotcom/exdantic/actions/workflows/ci.yml)
[![Hex.pm](https://img.shields.io/hexpm/v/exdantic.svg)](https://hex.pm/packages/exdantic)
[![Hex Docs](https://img.shields.io/badge/hex-docs-lightgreen.svg)](https://hexdocs.pm/exdantic/)

Exdantic provides a comprehensive toolset for data validation, serialization, and schema generation. Perfect for building robust APIs, managing complex configurations, and creating data processing pipelines. With advanced runtime features, Exdantic is uniquely suited for AI and LLM applications, enabling dynamic, DSPy-style programming patterns in Elixir.

## Original Project

The original Elixact project can be found at: https://github.com/LiboShen/elixact

## ✨ Key Features

- 🎯 **Rich Type System**: Support for basic types, complex nested structures (arrays, maps, unions), and custom types
- 🚀 **Runtime & Compile-Time Schemas**: Define schemas dynamically at runtime or at compile-time for maximum flexibility
- 🏗️ **Struct Support**: Optional struct generation for type-safe data structures with automatic serialization
- 🔧 **Model Validators**: Cross-field validation and data transformation after field validation
- ⚡ **Computed Fields**: Derive additional fields from validated data automatically
- 🎨 **Pydantic-Inspired Patterns**: Support for `create_model`, `TypeAdapter`, `Wrapper`, and `RootModel` patterns
- 🔍 **Advanced Validation**: Rich constraints plus custom validation functions
- 🔄 **Type Coercion**: Automatic and configurable type coercion
- 📊 **Advanced JSON Schema**: Generate optimized JSON Schema for LLM providers (OpenAI, Anthropic)
- 🚨 **Structured Errors**: Path-aware error messages for precise debugging
- ⚙️ **Dynamic Configuration**: Runtime configuration with preset patterns

## 🚀 Quick Start

### Installation

Add `exdantic` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:exdantic, "~> 0.0.1"}
  ]
end
```

### Basic Schema Definition

```elixir
defmodule UserSchema do
  use Exdantic, define_struct: true

  schema "User account information" do
    field :name, :string do
      required()
      min_length(2)
      description("User's full name")
    end

    field :email, :string do
      required()
      format(~r/^[^\s@]+@[^\s@]+\.[^\s@]+$/)
      description("Primary email address")
    end

    field :age, :integer do
      optional()
      gt(0)
      lt(150)
      description("User's age in years")
    end

    field :active, :boolean do
      default(true)
      description("Whether the account is active")
    end

    # Cross-field validation
    model_validator :validate_adult_email

    # Computed field derived from other fields
    computed_field :display_name, :string, :generate_display_name

    config do
      title("User Schema")
      strict(true)
    end
  end

  def validate_adult_email(input) do
    if input.age && input.age >= 18 && String.contains?(input.email, "example.com") do
      {:error, "Adult users cannot use example.com emails"}
    else
      {:ok, input}
    end
  end

  def generate_display_name(input) do
    display = if input.age do
      "#{input.name} (#{input.age})"
    else
      input.name
    end
    {:ok, display}
  end
end

# Validation returns struct instances when define_struct: true
case UserSchema.validate(%{
  name: "John Doe",
  email: "john@company.com",
  age: 30
}) do
  {:ok, %UserSchema{} = user} ->
    IO.puts("User: #{user.display_name}")
    # Outputs: "User: John Doe (30)"
    
  {:error, errors} ->
    Enum.each(errors, &IO.puts(Exdantic.Error.format(&1)))
end
```

### Dynamic Runtime Schemas

Perfect for DSPy-style applications and dynamic validation:

```elixir
# Define fields programmatically
fields = [
  {:reasoning, :string, [description: "Chain of thought reasoning"]},
  {:answer, :string, [required: true, min_length: 1]},
  {:confidence, :float, [required: true, gteq: 0.0, lteq: 1.0]},
  {:sources, {:array, :string}, [optional: true]}
]

# Create schema at runtime (like Pydantic's create_model)
llm_output_schema = Exdantic.Runtime.create_schema(fields, 
  title: "LLM_Output_Schema",
  description: "Schema for LLM structured output"
)

# Validate with coercion
config = Exdantic.Config.create(coercion: :safe, strict: true)
llm_response = %{
  "reasoning" => "Based on the context provided...",
  "answer" => "The answer is 42",
  "confidence" => "0.95"  # String that needs coercion to float
}

{:ok, validated} = Exdantic.EnhancedValidator.validate(
  llm_output_schema, 
  llm_response, 
  config: config
)

# Generate JSON Schema for LLM providers
json_schema = Exdantic.JsonSchema.EnhancedResolver.resolve_enhanced(
  llm_output_schema,
  optimize_for_provider: :openai,
  flatten_for_llm: true
)
```

### TypeAdapter for Schemaless Validation

Validate individual values without full schema definition:

```elixir
# Simple type validation with coercion
{:ok, 123} = Exdantic.TypeAdapter.validate(:integer, "123", coerce: true)

# Complex type validation
type_spec = {:array, {:map, {:string, {:union, [:string, :integer]}}}}
data = [
  %{"name" => "John", "score" => 85},
  %{"name" => "Jane", "score" => "92"}  # String score gets coerced
]

{:ok, validated} = Exdantic.TypeAdapter.validate(type_spec, data, coerce: true)

# Reusable TypeAdapter instances for performance
adapter = Exdantic.TypeAdapter.create({:array, :string}, coerce: true)
{:ok, results} = Exdantic.TypeAdapter.Instance.validate_many(adapter, [
  ["a", "b"],
  [1, 2],     # Numbers get coerced to strings
  ["c", "d"]
])
```

### Wrapper Models for Single-Field Validation

Temporary schemas for complex type coercion patterns:

```elixir
# Validate and extract a single complex value
{:ok, score} = Exdantic.Wrapper.wrap_and_validate(
  :test_score,
  :integer,
  "85",  # String input
  coerce: true,
  constraints: [gteq: 0, lteq: 100],
  description: "Test score out of 100"
)

# Multiple wrapper validation
wrappers = Exdantic.Wrapper.create_multiple_wrappers([
  {:name, :string, [constraints: [min_length: 1]]},
  {:age, :integer, [constraints: [gt: 0]]},
  {:score, :float, [constraints: [gteq: 0.0, lteq: 1.0]]}
])

data = %{name: "Test", age: "25", score: "0.95"}  # All strings
{:ok, validated} = Exdantic.Wrapper.validate_multiple(wrappers, data)
# All values are properly coerced to their target types
```

### Root Schema for Non-Dictionary Validation

Validate non-dictionary types at the root level (similar to Pydantic's RootModel):

```elixir
# Validate an array of integers
defmodule IntegerListSchema do
  use Exdantic.RootSchema, root: {:array, :integer}
end

{:ok, [1, 2, 3]} = IntegerListSchema.validate([1, 2, 3])

# Validate a string with constraints
defmodule EmailSchema do
  use Exdantic.RootSchema, 
    root: {:type, :string, [format: ~r/^[^\s@]+@[^\s@]+\.[^\s@]+$/]}
end

{:ok, "user@example.com"} = EmailSchema.validate("user@example.com")

# Validate union types
defmodule StringOrNumberSchema do
  use Exdantic.RootSchema, root: {:union, [:string, :integer]}
end

{:ok, "hello"} = StringOrNumberSchema.validate("hello")
{:ok, 42} = StringOrNumberSchema.validate(42)

# Validate arrays of complex schemas
defmodule UserListSchema do
  use Exdantic.RootSchema, root: {:array, UserSchema}
end

users = [%{name: "John", email: "john@example.com"}]
{:ok, validated_users} = UserListSchema.validate(users)
```

## 🏗️ Core Concepts

### Schema Definition Approaches

**Compile-Time Schemas** (Best for static, performance-critical validation):
```elixir
defmodule APIRequestSchema do
  use Exdantic, define_struct: true
  
  schema do
    field :action, :string, choices: ["create", "update", "delete"]
    field :resource_id, :integer, gt: 0
    field :data, :map, optional: true
    
    model_validator :validate_action_data_consistency
  end
end
```

**Runtime Schemas** (Best for dynamic validation, DSPy patterns):
```elixir
# Schema created from field definitions at runtime
schema = Exdantic.Runtime.create_schema([
  {:query, :string, [required: true]},
  {:max_results, :integer, [optional: true, gt: 0, lteq: 100]}
])
```

### Type System

Exdantic supports a comprehensive type system:

```elixir
# Basic types
:string, :integer, :float, :boolean, :atom, :any, :map

# Complex types
{:array, inner_type}                    # Arrays
{:map, {key_type, value_type}}         # Maps with typed keys/values
{:union, [type1, type2, ...]}          # Union types
{:tuple, [type1, type2, ...]}          # Tuples

# Schema references
ModuleName                              # Reference to other schemas

# Custom types
MyCustomType                            # Modules implementing Exdantic.Type
```

### Validation Pipeline

1. **Field Validation**: Individual field type and constraint checking
2. **Model Validation**: Cross-field validation and data transformation
3. **Computed Fields**: Generation of derived fields
4. **Struct Creation**: Optional struct instantiation (when `define_struct: true`)

### Configuration System

Control validation behavior with dynamic configuration:

```elixir
# Create configurations
strict_config = Exdantic.Config.create(strict: true, extra: :forbid)
lenient_config = Exdantic.Config.preset(:development)

# Builder pattern
config = Exdantic.Config.builder()
|> Exdantic.Config.Builder.strict(true)
|> Exdantic.Config.Builder.safe_coercion()
|> Exdantic.Config.Builder.for_api()
|> Exdantic.Config.Builder.build()

# Use with any validation
Exdantic.EnhancedValidator.validate(schema, data, config: config)
```

## 🔍 Advanced Features

### Model Validators

Cross-field validation and data transformation:

```elixir
schema do
  field :password, :string, min_length: 8
  field :password_confirmation, :string
  
  # Named function validator
  model_validator :validate_passwords_match
  
  # Anonymous function validator  
  model_validator fn input ->
    if input.password == input.password_confirmation do
      # Transform: remove confirmation field
      {:ok, Map.delete(input, :password_confirmation)}
    else
      {:error, "Passwords do not match"}
    end
  end
end
```

### Computed Fields

Automatically derive fields from validated data:

```elixir
schema do
  field :first_name, :string, required: true
  field :last_name, :string, required: true
  field :email, :string, required: true
  
  # Named function computed field
  computed_field :full_name, :string, :generate_full_name
  
  # Anonymous function computed field
  computed_field :email_domain, :string, fn input ->
    domain = input.email |> String.split("@") |> List.last()
    {:ok, domain}
  end
end

def generate_full_name(input) do
  {:ok, "#{input.first_name} #{input.last_name}"}
end
```

### Enhanced JSON Schema Generation

Generate optimized schemas for different use cases:

```elixir
# Basic JSON Schema
json_schema = Exdantic.JsonSchema.from_schema(UserSchema)

# Enhanced schema with full metadata
enhanced_schema = Exdantic.JsonSchema.EnhancedResolver.resolve_enhanced(
  UserSchema,
  optimize_for_provider: :openai,
  include_model_validators: true,
  include_computed_fields: true
)

# DSPy-optimized schema
dspy_schema = Exdantic.JsonSchema.EnhancedResolver.optimize_for_dspy(
  UserSchema,
  signature_mode: true,
  field_descriptions: true,
  strict_types: true
)

# Comprehensive analysis
analysis = Exdantic.JsonSchema.EnhancedResolver.comprehensive_analysis(
  UserSchema,
  sample_data,
  test_llm_providers: [:openai, :anthropic, :generic]
)
```

### Runtime Enhanced Schemas

Runtime schemas with model validators and computed fields:

```elixir
# Enhanced runtime schema with full pipeline
fields = [{:name, :string, [required: true]}, {:age, :integer, [optional: true]}]

validators = [
  fn data -> {:ok, %{data | name: String.trim(data.name)}} end
]

computed_fields = [
  {:display_name, :string, fn data -> {:ok, String.upcase(data.name)} end}
]

enhanced_schema = Exdantic.Runtime.create_enhanced_schema(fields,
  model_validators: validators,
  computed_fields: computed_fields,
  title: "Enhanced User Schema"
)

{:ok, result} = Exdantic.Runtime.validate_enhanced(
  %{name: "  john  ", age: 25}, 
  enhanced_schema
)
# Result: %{name: "john", age: 25, display_name: "JOHN"}
```

## 📊 JSON Schema & LLM Integration

### LLM Provider Optimization

Generate optimized schemas for different LLM providers:

```elixir
# OpenAI Function Calling
openai_schema = Exdantic.JsonSchema.Resolver.enforce_structured_output(
  base_schema,
  provider: :openai,
  remove_unsupported: true
)

# Anthropic Tool Use
anthropic_schema = Exdantic.JsonSchema.Resolver.enforce_structured_output(
  base_schema,
  provider: :anthropic
)

# Resolve all references for simplified schemas
resolved_schema = Exdantic.JsonSchema.Resolver.resolve_references(complex_schema)
```

### DSPy Integration Patterns

```elixir
# Input schema (remove computed fields for input validation)
input_schema = Exdantic.JsonSchema.remove_computed_fields(full_schema)

# Output schema (include all fields for output validation)  
output_schema = Exdantic.JsonSchema.EnhancedResolver.optimize_for_dspy(
  full_schema,
  signature_mode: true
)

# DSPy-compatible configuration
dspy_config = Exdantic.Config.for_dspy(:signature, provider: :openai)
```

## ⚙️ Available Constraints

### String Constraints
- `min_length(n)` - Minimum string length
- `max_length(n)` - Maximum string length  
- `format(regex)` - String must match regex pattern
- `choices(list)` - String must be one of the provided choices

### Numeric Constraints (Integer/Float)
- `gt(n)` - Greater than
- `lt(n)` - Less than
- `gteq(n)` - Greater than or equal to
- `lteq(n)` - Less than or equal to
- `choices(list)` - Number must be one of the provided choices

### Array Constraints
- `min_items(n)` - Minimum number of items
- `max_items(n)` - Maximum number of items

### Field Modifiers
- `required()` - Field is required (default)
- `optional()` - Field is optional
- `default(value)` - Default value if not provided (implies optional)
- `description(text)` - Field description
- `example(value)` - Example value for documentation
- `examples(list)` - Multiple example values

## 🎨 Custom Types

Create reusable custom types:

```elixir
defmodule Types.Email do
  use Exdantic.Type

  def type_definition do
    {:type, :string, [format: ~r/^[^\s@]+@[^\s@]+\.[^\s@]+$/]}
  end

  def json_schema do
    %{
      "type" => "string",
      "format" => "email",
      "pattern" => "^[^\\s@]+@[^\\s@]+\\.[^\\s@]+$"
    }
  end

  def validate(value) do
    case type_definition() |> Exdantic.Validator.validate(value) do
      {:ok, validated} -> {:ok, String.downcase(validated)}
      {:error, _} -> {:error, "Must be a valid email address"}
    end
  end
end

# Use the custom type
schema do
  field :email, Types.Email
  field :backup_email, Types.Email, optional: true
end
```

## 🚨 Error Handling

Exdantic provides structured, path-aware error information:

```elixir
%Exdantic.Error{
  path: [:user, :address, :zip_code],  # Exact location of error
  code: :format,                       # Machine-readable error type
  message: "invalid zip code format"   # Human-readable message
}

# Format errors for display
case UserSchema.validate(invalid_data) do
  {:ok, validated} -> 
    validated
    
  {:error, errors} ->
    errors
    |> Enum.map(&Exdantic.Error.format/1)
    |> Enum.each(&IO.puts/1)
    # Outputs: "user.address.zip_code: invalid zip code format"
end
```

## 🔧 Configuration Options

### Validation Behavior
- `:strict` - Enforce strict validation (no unknown fields)
- `:extra` - Handle extra fields (`:allow`, `:forbid`, `:ignore`)
- `:coercion` - Type coercion strategy (`:none`, `:safe`, `:aggressive`)
- `:frozen` - Whether configuration is immutable
- `:validate_assignment` - Validate field assignments

### Error Handling
- `:error_format` - Error detail level (`:detailed`, `:simple`, `:minimal`)
- `:case_sensitive` - Case sensitivity for field names

### Schema Generation
- `:use_enum_values` - Use enum values instead of names
- `:max_anyof_union_len` - Maximum length for anyOf unions
- `:title_generator` - Function to generate field titles
- `:description_generator` - Function to generate field descriptions

## 📈 Performance Guidelines

### Best Practices

1. **Reuse Schemas and Adapters**: Create once, use many times
2. **Use Appropriate Configuration**: Avoid `:strict` if not needed
3. **Batch Operations**: Use `validate_many` for multiple items
4. **Cache JSON Schemas**: Generate once for repeated use
5. **Choose the Right Tool**:
   - Compile-time schemas for static, performance-critical validation
   - Runtime schemas for dynamic validation
   - TypeAdapter for simple type validation
   - Wrapper for single-value coercion

### Performance Characteristics

- **Simple validation**: Sub-millisecond for basic types
- **Complex schemas**: ~5-20ms for typical business objects
- **Runtime schema creation**: ~1000 schemas/second
- **JSON schema generation**: <50ms for complex schemas
- **Batch validation**: ~10k items/second for simple types

## 🗺️ Migration Guide

### From Basic Validation Libraries

```elixir
# Before: Manual validation
def validate_user(data) do
  with {:ok, name} <- validate_string(data["name"]),
       {:ok, age} <- validate_integer(data["age"]),
       {:ok, email} <- validate_email(data["email"]) do
    {:ok, %{name: name, age: age, email: email}}
  end
end

# After: Exdantic schema
defmodule UserSchema do
  use Exdantic
  
  schema do
    field :name, :string, required: true
    field :age, :integer, gt: 0
    field :email, :string, format: ~r/@/
  end
end

{:ok, user} = UserSchema.validate(data)
```

### From Static to Dynamic Validation

```elixir
# Static schema (compile-time)
defmodule APISchema do
  use Exdantic
  schema do
    field :endpoint, :string
    field :method, :string, choices: ["GET", "POST"]
  end
end

# Dynamic schema (runtime)
api_schema = Exdantic.Runtime.create_schema([
  {:endpoint, :string, [required: true]},
  {:method, :string, [choices: ["GET", "POST", "PUT", "DELETE"]]}
])
```

## 📚 Examples

The `examples/` directory contains comprehensive examples showcasing all of Exdantic's features:

### 🟢 **Getting Started**
- [`basic_usage.exs`](examples/basic_usage.exs) - Core concepts and fundamental patterns
- [`custom_validation.exs`](examples/custom_validation.exs) - Business logic and custom validators
- [`advanced_features.exs`](examples/advanced_features.exs) - Complex validation patterns

### 🤖 **LLM & DSPy Integration**
- [`llm_integration.exs`](examples/llm_integration.exs) - LLM output validation
- [`dspy_integration.exs`](examples/dspy_integration.exs) - Complete DSPy patterns
- [`llm_pipeline_orchestration.exs`](examples/llm_pipeline_orchestration.exs) - Multi-stage pipelines

### ⚡ **Runtime Features**
- [`runtime_schema.exs`](examples/runtime_schema.exs) - Dynamic schema creation
- [`type_adapter.exs`](examples/type_adapter.exs) - Runtime type validation
- [`wrapper_models.exs`](examples/wrapper_models.exs) - Single-field validation

### 🔧 **Advanced Features**
- [`model_validators.exs`](examples/model_validators.exs) - Cross-field validation
- [`computed_fields.exs`](examples/computed_fields.exs) - Derived fields
- [`root_schema.exs`](examples/root_schema.exs) - Non-dictionary validation

**Run any example:**
```bash
mix run examples/basic_usage.exs
```

**See the complete guide:** [`examples/README.md`](examples/README.md)

## 📖 Additional Documentation

- **[Production Error Handling Guide](PRODUCTION_ERROR_HANDLING_GUIDE.md)** - Complete guide to production-ready error handling, API responses, logging, monitoring, and recovery strategies
- **[Advanced Features Guide](ADVANCED_FEATURES_GUIDE.md)** - Model validators, computed fields, enhanced runtime schemas
- **[Getting Started Guide](GETTING_STARTED_GUIDE.md)** - Step-by-step introduction to core concepts
- **[LLM Integration Guide](LLM_INTEGRATION_GUIDE.md)** - AI/ML use cases and optimization patterns

## 🤝 Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Write tests for your changes
4. Ensure all tests pass (`mix test`)
5. Run quality checks:
   ```bash
   mix format
   mix credo --strict
   mix dialyzer
   ```
6. Commit your changes (`git commit -am 'Add amazing feature'`)
7. Push to the branch (`git push origin feature/amazing-feature`)
8. Open a Pull Request

### Development Setup

```bash
# Clone the repository
git clone https://github.com/nshkrdotcom/exdantic.git
cd exdantic

# Install dependencies
mix deps.get

# Run tests
mix test

# Generate docs
mix docs
```

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🙏 Acknowledgments

- Inspired by Python's [Pydantic](https://pydantic-docs.helpmanual.io/) library
- DSPy integration patterns inspired by [DSPy](https://dspy-docs.vercel.app/)
- Built with ❤️ for the Elixir community

---

**Made with Elixir** 💜
