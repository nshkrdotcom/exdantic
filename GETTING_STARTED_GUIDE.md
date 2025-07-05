# Getting Started with Exdantic

This guide will walk you through Exdantic's core features, from basic validation to advanced runtime schema generation.

## Installation

Add exdantic to your `mix.exs` dependencies:

```elixir
def deps do
  [
    {:exdantic, "~> 0.0.1"}
  ]
end
```

Run `mix deps.get` to install.

## Basic Concepts

Exdantic provides multiple approaches to data validation:

1. **Compile-time schemas** - Defined using macros, optimized for performance
2. **Runtime schemas** - Created dynamically from field definitions
3. **TypeAdapter** - Direct type validation without schemas
4. **Wrapper models** - Temporary single-field validation
5. **Root schemas** - Validate non-dictionary types at the root level

## Your First Schema

Let's start with a simple user schema:

```elixir
defmodule UserSchema do
  use Exdantic

  schema "User information" do
    field :name, :string do
      required()
      min_length(2)
      description("User's full name")
    end

    field :email, :string do
      required()
      format(~r/^[^\s@]+@[^\s@]+\.[^\s@]+$/)
      description("Email address")
    end

    field :age, :integer do
      optional()
      gt(0)
      lt(150)
    end

    config do
      title("User Schema")
      strict(true)
    end
  end
end
```

### Using the Schema

```elixir
# Valid data
valid_data = %{
  name: "John Doe",
  email: "john@example.com", 
  age: 30
}

case UserSchema.validate(valid_data) do
  {:ok, user} ->
    IO.puts("Valid user: #{user.name}")
    
  {:error, errors} ->
    Enum.each(errors, &IO.puts(Exdantic.Error.format(&1)))
end

# Invalid data
invalid_data = %{
  name: "A",  # Too short
  email: "invalid-email",  # Invalid format
  age: -5,    # Negative age
  extra_field: "not allowed"  # Extra field (strict mode)
}

{:error, errors} = UserSchema.validate(invalid_data)
# Multiple validation errors will be returned
```

## Adding Struct Support

Enable struct generation for type-safe data structures:

```elixir
defmodule UserSchema do
  use Exdantic, define_struct: true  # Enable struct generation

  schema do
    field :name, :string, required: true
    field :email, :string, required: true 
    field :age, :integer, optional: true
  end
end

# Validation now returns struct instances
{:ok, %UserSchema{name: name, email: email}} = UserSchema.validate(data)

# Serialize structs back to maps
{:ok, map_data} = UserSchema.dump(user_struct)
```

## Field Types and Constraints

### Basic Types

```elixir
field :name, :string           # String
field :age, :integer           # Integer
field :price, :float           # Float  
field :active, :boolean        # Boolean
field :category, :atom         # Atom
field :metadata, :any          # Any type
field :settings, :map          # Map
```

### Complex Types

```elixir
field :tags, {:array, :string}                    # Array of strings
field :scores, {:map, {:string, :integer}}        # Map with string keys, integer values
field :status, {:union, [:pending, :completed]}   # Union type
field :address, AddressSchema                     # Reference to another schema
```

### Common Constraints

```elixir
# String constraints
field :name, :string do
  min_length(2)
  max_length(50)
  format(~r/^[A-Za-z\s]+$/)
end

# Numeric constraints  
field :age, :integer do
  gt(0)        # Greater than
  lt(150)      # Less than
  gteq(18)     # Greater than or equal
  lteq(65)     # Less than or equal
end

# Array constraints
field :tags, {:array, :string} do
  min_items(1)
  max_items(5)
end

# Choice constraints
field :status, :string do
  choices(["active", "inactive", "pending"])
end
```

### Field Modifiers

```elixir
field :name, :string do
  required()                    # Field is required (default)
end

field :bio, :string do
  optional()                    # Field is optional
end

field :active, :boolean do
  default(true)                 # Default value (implies optional)
end

field :email, :string do
  description("Primary email")  # Documentation
  example("user@example.com")   # Example value
end
```

### Arbitrary Field Metadata

Fields can have arbitrary metadata attached using the `extra` option or `extra` macro:

```elixir
# Using options syntax
field :question, :string, extra: %{
  "__dspy_field_type" => "input",
  "prefix" => "Question:"
}

# Using do-block syntax
field :answer, :string do
  required()
  min_length(1)
  extra("__dspy_field_type", "output")
  extra("prefix", "Answer:")
end
```

Extra metadata is useful for:
- DSPy-style field type annotations
- Framework-specific field configuration
- Custom UI rendering hints
- Integration with external tools

Example with DSPy-style helpers:

```elixir
defmodule QASchema do
  use Exdantic
  
  schema do
    # Input fields
    field :question, :string, extra: %{"__dspy_field_type" => "input"}
    field :context, :string, extra: %{"__dspy_field_type" => "input"}
    
    # Output fields with additional metadata
    field :reasoning, :string do
      extra("__dspy_field_type", "output")
      extra("prefix", "Reasoning:")
    end
    
    field :answer, :string do
      extra("__dspy_field_type", "output")
      extra("prefix", "Answer:")
    end
  end
end

# Filter fields by metadata
schema_fields = QASchema.__schema__(:fields)

input_fields = 
  Enum.filter(schema_fields, fn {_name, meta} -> 
    meta.extra["__dspy_field_type"] == "input"
  end)

output_fields =
  Enum.filter(schema_fields, fn {_name, meta} -> 
    meta.extra["__dspy_field_type"] == "output"
  end)
```

## Runtime Schema Creation

Create schemas dynamically for DSPy-style applications:

```elixir
# Define fields programmatically
fields = [
  {:query, :string, [required: true, min_length: 1]},
  {:max_results, :integer, [optional: true, gt: 0, lteq: 100]},
  {:include_metadata, :boolean, [default: false]}
]

# Create schema at runtime
search_schema = Exdantic.Runtime.create_schema(fields,
  title: "Search Parameters",
  description: "Schema for search API parameters"
)

# Use just like compile-time schemas
{:ok, validated} = Exdantic.Runtime.validate(params, search_schema)

# Generate JSON Schema
json_schema = Exdantic.Runtime.to_json_schema(search_schema)
```

## Type Validation with TypeAdapter

For simple type validation without full schemas:

```elixir
# Basic type validation
{:ok, "hello"} = Exdantic.TypeAdapter.validate(:string, "hello")
{:ok, 42} = Exdantic.TypeAdapter.validate(:integer, 42)

# Type coercion
{:ok, 123} = Exdantic.TypeAdapter.validate(:integer, "123", coerce: true)
{:ok, "hello"} = Exdantic.TypeAdapter.validate(:string, :hello, coerce: true)

# Complex types
array_type = {:array, :string}
{:ok, ["a", "b"]} = Exdantic.TypeAdapter.validate(array_type, ["a", "b"])

# Reusable adapters for performance
adapter = Exdantic.TypeAdapter.create({:array, :integer}, coerce: true)
{:ok, [1, 2, 3]} = Exdantic.TypeAdapter.Instance.validate(adapter, ["1", "2", "3"])
```

## Single-Value Validation with Wrappers

Validate and coerce individual values with constraints:

```elixir
# Simple wrapper validation
{:ok, 85} = Exdantic.Wrapper.wrap_and_validate(
  :score, 
  :integer, 
  "85",  # String input
  coerce: true,
  constraints: [gteq: 0, lteq: 100]
)

# Multiple field validation
specs = [
  {:name, :string, [constraints: [min_length: 1]]},
  {:age, :integer, [constraints: [gt: 0]]},
  {:email, :string, [constraints: [format: ~r/@/]]}
]

wrappers = Exdantic.Wrapper.create_multiple_wrappers(specs)
data = %{name: "John", age: "30", email: "john@example.com"}

{:ok, validated} = Exdantic.Wrapper.validate_multiple(wrappers, data)
```

## Root Schema Validation

Validate non-dictionary types at the root level (similar to Pydantic's RootModel):

```elixir
# Validate an array of integers
defmodule NumberListSchema do
  use Exdantic.RootSchema, root: {:array, :integer}
end

{:ok, [1, 2, 3]} = NumberListSchema.validate([1, 2, 3])
{:error, _} = NumberListSchema.validate(["not", "numbers"])

# Validate a string with format constraints
defmodule EmailSchema do
  use Exdantic.RootSchema, 
    root: {:type, :string, [format: ~r/^[^\s@]+@[^\s@]+\.[^\s@]+$/]}
end

{:ok, "user@example.com"} = EmailSchema.validate("user@example.com")
{:error, _} = EmailSchema.validate("invalid-email")

# Validate union types
defmodule IdSchema do
  use Exdantic.RootSchema, root: {:union, [:string, :integer]}
end

{:ok, "user_123"} = IdSchema.validate("user_123")
{:ok, 456} = IdSchema.validate(456)
{:error, _} = IdSchema.validate(3.14)  # float not allowed

# Validate arrays of complex schemas
defmodule UserListSchema do
  use Exdantic.RootSchema, root: {:array, UserSchema}
end

users = [
  %{name: "John", email: "john@example.com"},
  %{name: "Jane", email: "jane@example.com"}
]
{:ok, validated_users} = UserListSchema.validate(users)

# Generate JSON Schema
json_schema = NumberListSchema.json_schema()
# Returns: %{"type" => "array", "items" => %{"type" => "integer"}}
```

## Configuration and Behavior Control

Control validation behavior with configurations:

```elixir
# Create custom configuration
config = Exdantic.Config.create(
  strict: true,          # No extra fields allowed
  coercion: :safe,       # Enable safe type coercion
  error_format: :detailed # Detailed error messages
)

# Use configuration with validation
{:ok, result} = Exdantic.EnhancedValidator.validate(schema, data, config: config)

# Preset configurations
api_config = Exdantic.Config.preset(:api)        # Strict, safe for APIs
dev_config = Exdantic.Config.preset(:development) # Lenient for development

# Builder pattern
config = Exdantic.Config.builder()
|> Exdantic.Config.Builder.strict(true)
|> Exdantic.Config.Builder.safe_coercion()
|> Exdantic.Config.Builder.detailed_errors()
|> Exdantic.Config.Builder.build()
```

## Error Handling

Exdantic provides structured, path-aware errors:

```elixir
case UserSchema.validate(invalid_data) do
  {:ok, validated} ->
    # Use validated data
    validated
    
  {:error, errors} ->
    # Handle validation errors
    Enum.each(errors, fn error ->
      path = Enum.join(error.path, ".")
      IO.puts("Error at #{path}: #{error.message} (#{error.code})")
    end)
end

# Error structure
%Exdantic.Error{
  path: [:user, :address, :zip_code],  # Exact location
  code: :format,                       # Error type
  message: "invalid zip code format"   # Human-readable message
}

# Format errors for display
errors
|> Enum.map(&Exdantic.Error.format/1)
|> Enum.join("\n")
|> IO.puts()
```

## JSON Schema Generation

Generate JSON Schema for API documentation and LLM integration:

```elixir
# Basic JSON Schema generation
json_schema = Exdantic.JsonSchema.from_schema(UserSchema)

# Enhanced JSON Schema with metadata
enhanced_schema = Exdantic.JsonSchema.EnhancedResolver.resolve_enhanced(
  UserSchema,
  optimize_for_provider: :openai,
  include_model_validators: true,
  include_computed_fields: true
)

# Optimize for specific LLM providers
openai_schema = Exdantic.JsonSchema.Resolver.enforce_structured_output(
  json_schema,
  provider: :openai,
  remove_unsupported: true
)

# Export to JSON file
json_string = Jason.encode!(json_schema, pretty: true)
File.write!("user_schema.json", json_string)
```

## Advanced Features Preview

### Model Validators (Cross-field validation)

```elixir
schema do
  field :password, :string, min_length: 8
  field :password_confirmation, :string
  
  # Named function validator
  model_validator :validate_passwords_match
  
  # Anonymous function validator
  model_validator fn input ->
    if input.password == input.password_confirmation do
      {:ok, Map.delete(input, :password_confirmation)}
    else
      {:error, "Passwords do not match"}
    end
  end
end

def validate_passwords_match(input) do
  if input.password == input.password_confirmation do
    {:ok, input}
  else
    {:error, "Passwords must match"}
  end
end
```

### Computed Fields (Derived data)

```elixir
schema do
  field :first_name, :string, required: true
  field :last_name, :string, required: true
  field :email, :string, required: true
  
  # Computed fields are added after validation
  computed_field :full_name, :string, :generate_full_name
  computed_field :email_domain, :string, fn input ->
    domain = input.email |> String.split("@") |> List.last()
    {:ok, domain}
  end
end

def generate_full_name(input) do
  {:ok, "#{input.first_name} #{input.last_name}"}
end
```

### Enhanced Runtime Schemas

```elixir
# Runtime schema with model validators and computed fields
fields = [{:name, :string, [required: true]}]

validators = [
  fn data -> {:ok, %{data | name: String.trim(data.name)}} end
]

computed_fields = [
  {:display_name, :string, fn data -> {:ok, String.upcase(data.name)} end}
]

enhanced_schema = Exdantic.Runtime.create_enhanced_schema(fields,
  model_validators: validators,
  computed_fields: computed_fields
)

{:ok, result} = Exdantic.Runtime.validate_enhanced(
  %{name: "  john  "}, 
  enhanced_schema
)
# Result: %{name: "john", display_name: "JOHN"}
```

## Common Patterns

### API Request Validation

```elixir
defmodule APIRequestSchema do
  use Exdantic, define_struct: true

  schema do
    field :method, :string, choices: ["GET", "POST", "PUT", "DELETE"]
    field :path, :string, min_length: 1
    field :headers, {:map, {:string, :string}}, default: %{}
    field :body, :any, optional: true
    
    model_validator :validate_body_for_method
  end
  
  def validate_body_for_method(input) do
    if input.method in ["POST", "PUT"] and is_nil(input.body) do
      {:error, "Body is required for #{input.method} requests"}
    else
      {:ok, input}
    end
  end
end
```

### Configuration Validation

```elixir
defmodule AppConfigSchema do
  use Exdantic

  schema do
    field :database_url, :string, format: ~r/^postgres:\/\//
    field :port, :integer, gteq: 1024, lteq: 65535, default: 4000
    field :log_level, :atom, choices: [:debug, :info, :warn, :error]
    field :features, {:array, :atom}, default: []
    
    computed_field :database_name, :string, :extract_db_name
  end
  
  def extract_db_name(config) do
    name = config.database_url
           |> String.split("/")
           |> List.last()
    {:ok, name}
  end
end
```

### LLM Output Validation

```elixir
# Dynamic schema for LLM structured output
llm_fields = [
  {:reasoning, :string, [description: "Step by step reasoning"]},
  {:answer, :string, [required: true, min_length: 1]},
  {:confidence, :float, [gteq: 0.0, lteq: 1.0]},
  {:sources, {:array, :string}, [optional: true]}
]

llm_schema = Exdantic.Runtime.create_schema(llm_fields,
  title: "LLM_Response",
  strict: true
)

# Generate JSON Schema for LLM prompt
json_schema = Exdantic.JsonSchema.EnhancedResolver.optimize_for_dspy(
  llm_schema,
  field_descriptions: true,
  strict_types: true
)

# Validate LLM response with coercion
config = Exdantic.Config.create(coercion: :safe)
{:ok, validated} = Exdantic.EnhancedValidator.validate(
  llm_schema, 
  llm_response, 
  config: config
)
```

## Performance Tips

1. **Reuse schemas**: Create once, use many times
2. **Use TypeAdapter instances**: For repeated type validation
3. **Choose the right tool**:
   - Compile-time schemas for static validation
   - Runtime schemas for dynamic validation
   - TypeAdapter for simple types
   - Wrapper for single values
   - RootSchema for non-dictionary root types
4. **Batch validation**: Use `validate_many` for multiple items
5. **Cache JSON schemas**: Generate once, reuse multiple times

## Next Steps

### 📚 Hands-On Learning
- **Start with Examples**: [`examples/basic_usage.exs`](examples/basic_usage.exs) - Try the fundamentals
- **Explore Advanced Examples**: [`examples/advanced_features.exs`](examples/advanced_features.exs) - See complex patterns
- **Complete Examples Guide**: [`examples/README.md`](examples/README.md) - Full learning path

### 📖 Documentation
- Read the [Advanced Features Guide](ADVANCED_FEATURES_GUIDE.md) for model validators and computed fields
- See [LLM Integration Guide](LLM_INTEGRATION_GUIDE.md) for AI/ML use cases  
- Check [API Reference](https://hexdocs.pm/exdantic/) for complete documentation

### 🚀 Try It Now
```bash
# Run your first example
mix run examples/basic_usage.exs

# See all available examples
ls examples/*.exs
```

## Common Issues

### Type Coercion Not Working
```elixir
# Wrong: coercion not enabled
{:error, _} = Exdantic.TypeAdapter.validate(:integer, "123")

# Right: enable coercion
{:ok, 123} = Exdantic.TypeAdapter.validate(:integer, "123", coerce: true)
```

### Extra Fields in Strict Mode
```elixir
# Wrong: extra fields with strict config
config = Exdantic.Config.create(strict: true)
{:error, _} = Exdantic.EnhancedValidator.validate(schema, %{name: "John", extra: "field"}, config: config)

# Right: either remove extra fields or use lenient config
{:ok, _} = Exdantic.EnhancedValidator.validate(schema, %{name: "John"}, config: config)
```

### Missing Required Fields
```elixir
# Wrong: missing required field
{:error, _} = UserSchema.validate(%{email: "john@example.com"})  # Missing name

# Right: provide all required fields
{:ok, _} = UserSchema.validate(%{name: "John", email: "john@example.com"})
```

This guide covers the essential features to get you started with Exdantic. For more advanced topics, continue to the specific feature guides.
