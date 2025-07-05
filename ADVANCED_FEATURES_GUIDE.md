# Advanced Features Guide

This guide covers Exdantic's advanced features: model validators, computed fields, enhanced runtime schemas, root schema validation, and sophisticated validation patterns.

## Table of Contents

- [Model Validators](#model-validators)
- [Computed Fields](#computed-fields) 
- [Enhanced Runtime Schemas](#enhanced-runtime-schemas)
- [Root Schema Validation](#root-schema-validation)
- [Advanced JSON Schema Features](#advanced-json-schema-features)
- [Configuration System](#configuration-system)
- [Performance Optimization](#performance-optimization)
- [Complex Validation Patterns](#complex-validation-patterns)

## Model Validators

Model validators perform cross-field validation and data transformation after individual field validation succeeds.

### Basic Model Validators

```elixir
defmodule UserRegistrationSchema do
  use Exdantic, define_struct: true

  schema do
    field :username, :string, min_length: 3
    field :email, :string, format: ~r/@/
    field :password, :string, min_length: 8
    field :password_confirmation, :string
    field :age, :integer, optional: true
    
    # Named function validator
    model_validator :validate_passwords_match
    model_validator :validate_adult_content
    model_validator :normalize_data
  end

  def validate_passwords_match(input) do
    if input.password == input.password_confirmation do
      # Remove confirmation field from final data
      {:ok, Map.delete(input, :password_confirmation)}
    else
      {:error, "Password confirmation does not match"}
    end
  end
  
  def validate_adult_content(input) do
    if input.age && input.age < 18 && String.contains?(input.username, "adult") do
      {:error, "Username not appropriate for minors"}
    else
      {:ok, input}
    end
  end
  
  def normalize_data(input) do
    normalized = %{
      input |
      username: String.downcase(input.username),
      email: String.downcase(input.email)
    }
    {:ok, normalized}
  end
end
```

### Anonymous Function Validators

```elixir
schema do
  field :start_date, :string
  field :end_date, :string
  
  # Anonymous function validator
  model_validator fn input ->
    with {:ok, start_date} <- Date.from_iso8601(input.start_date),
         {:ok, end_date} <- Date.from_iso8601(input.end_date) do
      if Date.compare(start_date, end_date) == :lt do
        {:ok, input}
      else
        {:error, "End date must be after start date"}
      end
    else
      _ -> {:error, "Invalid date format"}
    end
  end
  
  # Block syntax validator
  model_validator do
    if valid_business_logic?(input) do
      {:ok, transform_data(input)}
    else
      {:error, "Business logic validation failed"}
    end
  end
end
```

### Validator Execution Order

Model validators execute in the order they are declared:

```elixir
schema do
  field :data, :string
  
  model_validator :step_1  # Executes first
  model_validator :step_2  # Executes second (receives output from step_1)
  model_validator :step_3  # Executes third (receives output from step_2)
end

def step_1(input), do: {:ok, %{input | data: "step1:" <> input.data}}
def step_2(input), do: {:ok, %{input | data: "step2:" <> input.data}}
def step_3(input), do: {:ok, %{input | data: "step3:" <> input.data}}

# Input: %{data: "original"}
# Output: %{data: "step3:step2:step1:original"}
```

### Error Handling in Validators

```elixir
def complex_business_validator(input) do
  try do
    result = complex_business_logic(input)
    {:ok, result}
  rescue
    BusinessLogicError -> 
      {:error, "Business validation failed"}
    e in ArgumentError -> 
      {:error, "Invalid input: #{e.message}"}
  end
end

# Multiple error conditions
def validate_user_permissions(input) do
  cond do
    not input.active -> 
      {:error, "User account is inactive"}
    input.role not in ["admin", "user"] -> 
      {:error, "Invalid user role: #{input.role}"}
    expired?(input.last_login) -> 
      {:error, "User session has expired"}
    true -> 
      {:ok, input}
  end
end
```

## Computed Fields

Computed fields generate additional data from validated input after model validation completes.

### Basic Computed Fields

```elixir
defmodule UserProfileSchema do
  use Exdantic, define_struct: true

  schema do
    field :first_name, :string, required: true
    field :last_name, :string, required: true
    field :email, :string, required: true
    field :birth_date, :string, required: true
    
    # Named function computed fields
    computed_field :full_name, :string, :generate_full_name
    computed_field :email_domain, :string, :extract_email_domain
    computed_field :age, :integer, :calculate_age
  end

  def generate_full_name(input) do
    {:ok, "#{input.first_name} #{input.last_name}"}
  end
  
  def extract_email_domain(input) do
    domain = input.email |> String.split("@") |> List.last()
    {:ok, domain}
  end
  
  def calculate_age(input) do
    case Date.from_iso8601(input.birth_date) do
      {:ok, birth_date} ->
        today = Date.utc_today()
        age = Date.diff(today, birth_date) |> div(365)
        {:ok, age}
      {:error, _} ->
        {:error, "Invalid birth date format"}
    end
  end
end

# Usage
{:ok, %UserProfileSchema{} = user} = UserProfileSchema.validate(%{
  first_name: "John",
  last_name: "Doe", 
  email: "john@example.com",
  birth_date: "1990-01-01"
})

IO.puts(user.full_name)     # "John Doe"
IO.puts(user.email_domain)  # "example.com"
IO.puts(user.age)          # 34 (calculated)
```

### Anonymous Function Computed Fields

```elixir
schema do
  field :items, {:array, :map}, required: true
  field :tax_rate, :float, default: 0.08
  
  # Anonymous function computed field
  computed_field :subtotal, :float, fn input ->
    subtotal = input.items
               |> Enum.map(&Map.get(&1, "price", 0))
               |> Enum.sum()
    {:ok, subtotal}
  end
  
  # Block syntax computed field  
  computed_field :total, :float do
    subtotal = input.subtotal
    tax = subtotal * input.tax_rate
    total = subtotal + tax
    {:ok, total}
  end
  
  computed_field :formatted_total, :string, fn input ->
    formatted = :erlang.float_to_binary(input.total, decimals: 2)
    {:ok, "$#{formatted}"}
  end
end
```

### Computed Field Type Validation

Computed field return values are validated against their declared types:

```elixir
computed_field :score, :integer, fn input ->
  # This will fail validation - returns string instead of integer
  {:ok, "not an integer"}
end

computed_field :valid_score, :integer, fn input ->
  score = calculate_score(input)
  if is_integer(score) do
    {:ok, score}
  else
    {:error, "Score calculation failed"}
  end
end
```

### Computed Fields in JSON Schema

Computed fields are marked as `readOnly` in generated JSON Schema:

```elixir
json_schema = Exdantic.JsonSchema.from_schema(UserProfileSchema)
# Generated schema includes:
# "full_name": {"type": "string", "readOnly": true}
# "email_domain": {"type": "string", "readOnly": true}
# "age": {"type": "integer", "readOnly": true}

# For input validation, remove computed fields
input_schema = Exdantic.JsonSchema.remove_computed_fields(json_schema)
```

## Enhanced Runtime Schemas

Runtime schemas can include model validators and computed fields just like compile-time schemas.

### Creating Enhanced Runtime Schemas

```elixir
# Define fields
fields = [
  {:name, :string, [required: true, min_length: 1]},
  {:email, :string, [required: true, format: ~r/@/]},
  {:age, :integer, [optional: true, gt: 0]}
]

# Define model validators (anonymous functions)
validators = [
  fn data ->
    # Normalize email to lowercase
    {:ok, %{data | email: String.downcase(data.email)}}
  end,
  fn data ->
    # Validate adult email domains
    if data.age && data.age >= 18 && String.contains?(data.email, "@example.com") do
      {:error, "Adults cannot use example.com domain"}
    else
      {:ok, data}
    end
  end
]

# Define computed fields
computed_fields = [
  {:display_name, :string, fn data ->
    display = if data.age do
      "#{data.name} (#{data.age})"
    else
      data.name
    end
    {:ok, display}
  end},
  {:email_domain, :string, fn data ->
    domain = data.email |> String.split("@") |> List.last()
    {:ok, domain}
  end}
]

# Create enhanced schema
enhanced_schema = Exdantic.Runtime.create_enhanced_schema(fields,
  model_validators: validators,
  computed_fields: computed_fields,
  title: "Enhanced User Schema"
)

# Validate with full pipeline
{:ok, result} = Exdantic.Runtime.validate_enhanced(%{
  name: "John Doe",
  email: "JOHN@COMPANY.COM",  # Will be normalized to lowercase
  age: 30
}, enhanced_schema)

# Result includes computed fields:
# %{
#   name: "John Doe",
#   email: "john@company.com",  # normalized
#   age: 30,
#   display_name: "John Doe (30)",    # computed
#   email_domain: "company.com"       # computed
# }
```

### Named Function References in Runtime Schemas

```elixir
# Module with validation and computation functions
defmodule UserHelpers do
  def normalize_email(data) do
    {:ok, %{data | email: String.downcase(data.email)}}
  end
  
  def generate_username(data) do
    username = data.email |> String.split("@") |> hd()
    {:ok, username}
  end
end

# Use named function references
enhanced_schema = Exdantic.Runtime.create_enhanced_schema(fields,
  model_validators: [{UserHelpers, :normalize_email}],
  computed_fields: [
    {:username, :string, {UserHelpers, :generate_username}}
  ]
)
```

### Runtime Schema Evolution

```elixir
# Start with basic schema
schema = Exdantic.Runtime.create_schema(basic_fields)

# Enhance with additional features
enhanced_schema = Exdantic.Runtime.Validator.enhance_schema(schema,
  model_validators: [validation_function],
  computed_fields: [computed_field_spec]
)

# Add more validators dynamically
final_schema = Exdantic.Runtime.EnhancedSchema.add_model_validator(
  enhanced_schema, 
  additional_validator
)

# Add more computed fields
complete_schema = Exdantic.Runtime.EnhancedSchema.add_computed_field(
  final_schema,
  :new_field,
  :string,
  computation_function
)
```

## Root Schema Validation

Root schemas allow validation of non-dictionary types at the top level, similar to Pydantic's RootModel. This is particularly useful when your data structure is not an object/map but an array, primitive, or other type.

### Basic Root Schema Usage

```elixir
# Validate arrays of primitives
defmodule TagListSchema do
  use Exdantic.RootSchema, root: {:array, :string}
end

{:ok, ["tag1", "tag2"]} = TagListSchema.validate(["tag1", "tag2"])

# Validate single values with constraints
defmodule ScoreSchema do
  use Exdantic.RootSchema, 
    root: {:type, :integer, [gteq: 0, lteq: 100]}
end

{:ok, 85} = ScoreSchema.validate(85)
{:error, _} = ScoreSchema.validate(150)  # Out of range

# Validate union types
defmodule IdSchema do
  use Exdantic.RootSchema, root: {:union, [:string, :integer]}
end

{:ok, "user_123"} = IdSchema.validate("user_123")
{:ok, 456} = IdSchema.validate(456)
```

### Root Schemas with Complex Types

```elixir
# Validate arrays of complex schemas
defmodule UserSchema do
  use Exdantic

  schema do
    field :name, :string, required: true
    field :email, :string, required: true
    field :age, :integer, optional: true
  end
end

defmodule UserListSchema do
  use Exdantic.RootSchema, root: {:array, UserSchema}
end

users = [
  %{name: "John", email: "john@example.com", age: 30},
  %{name: "Jane", email: "jane@example.com"}
]

{:ok, validated_users} = UserListSchema.validate(users)

# Validate nested structures
defmodule NestedDataSchema do
  use Exdantic.RootSchema, 
    root: {:map, {:string, {:array, :integer}}}
end

data = %{"scores" => [85, 90, 78], "grades" => [88, 92, 85]}
{:ok, validated_data} = NestedDataSchema.validate(data)
```

### Root Schema JSON Schema Generation

Root schemas generate appropriate JSON Schema representations:

```elixir
# Array schema
array_schema = TagListSchema.json_schema()
# Returns: %{"type" => "array", "items" => %{"type" => "string"}}

# Union schema  
union_schema = IdSchema.json_schema()
# Returns: %{"oneOf" => [%{"type" => "string"}, %{"type" => "integer"}]}

# Complex nested schema
nested_schema = NestedDataSchema.json_schema()
# Returns: %{
#   "type" => "object", 
#   "additionalProperties" => %{
#     "type" => "array", 
#     "items" => %{"type" => "integer"}
#   }
# }
```

### Integration with Existing Features

Root schemas work seamlessly with other Exdantic features:

```elixir
# With TypeAdapter
adapter = Exdantic.TypeAdapter.create({:array, :string})
root_schema = TagListSchema

data = ["tag1", "tag2", "tag3"]

# Both validate the same way
{:ok, result1} = Exdantic.TypeAdapter.Instance.validate(adapter, data)
{:ok, result2} = root_schema.validate(data)
assert result1 == result2

# With enhanced validation and coercion
defmodule FlexibleNumberListSchema do
  use Exdantic.RootSchema, root: {:array, :integer}
end

# Coercion works with root schemas too
config = Exdantic.Config.create(coercion: :safe)
mixed_data = ["1", "2", "3"]  # Strings that can be coerced

{:ok, [1, 2, 3]} = Exdantic.EnhancedValidator.validate(
  FlexibleNumberListSchema, 
  mixed_data, 
  config: config
)
```

### When to Use Root Schemas

Root schemas are ideal for:

1. **API endpoints that return arrays**: When your API returns a list of items directly
2. **LLM outputs**: When language models return arrays or single values
3. **Configuration files**: When config is a single value or array
4. **Data transformation**: When you need to validate intermediate results
5. **Microservice communication**: When services exchange simple data structures

```elixir
# API endpoint returning array of strings
defmodule TagsEndpointSchema do
  use Exdantic.RootSchema, root: {:array, :string}
end

# LLM classification output
defmodule SentimentSchema do
  use Exdantic.RootSchema, 
    root: {:type, :string, [choices: ["positive", "negative", "neutral"]]}
end

# Configuration value
defmodule PortConfigSchema do
  use Exdantic.RootSchema, 
    root: {:type, :integer, [gteq: 1024, lteq: 65535]}
end
```

## Advanced JSON Schema Features

### Enhanced Resolution

```elixir
# Generate enhanced JSON schema with full metadata
enhanced_schema = Exdantic.JsonSchema.EnhancedResolver.resolve_enhanced(
  UserSchema,
  optimize_for_provider: :openai,
  include_model_validators: true,
  include_computed_fields: true,
  flatten_for_llm: true
)

# Result includes enhanced metadata:
# {
#   "type": "object",
#   "x-exdantic-enhanced": true,
#   "x-model-validators": 3,
#   "x-computed-fields": 2,
#   "x-supports-struct": true,
#   ...
# }
```

### Provider-Specific Optimization

```elixir
# Optimize for OpenAI Function Calling
openai_schema = Exdantic.JsonSchema.Resolver.enforce_structured_output(
  base_schema,
  provider: :openai,
  remove_unsupported: true,
  add_required_fields: true
)

# Optimize for Anthropic Tool Use
anthropic_schema = Exdantic.JsonSchema.Resolver.enforce_structured_output(
  base_schema,
  provider: :anthropic
)

# Generic LLM optimization
optimized_schema = Exdantic.JsonSchema.Resolver.optimize_for_llm(
  base_schema,
  remove_descriptions: false,
  simplify_unions: true,
  max_properties: 20
)
```

### DSPy Integration

```elixir
# Optimize schema for DSPy signatures
dspy_schema = Exdantic.JsonSchema.EnhancedResolver.optimize_for_dspy(
  UserSchema,
  signature_mode: true,
  remove_computed_fields: true,  # For input validation
  strict_types: true,
  field_descriptions: true
)

# DSPy-compatible configuration
dspy_config = Exdantic.Config.for_dspy(:signature, provider: :openai)
```

### Comprehensive Schema Analysis

```elixir
# Analyze schema compatibility and performance
analysis = Exdantic.JsonSchema.EnhancedResolver.comprehensive_analysis(
  UserSchema,
  sample_data,
  include_validation_test: true,
  test_llm_providers: [:openai, :anthropic, :generic]
)

# Analysis includes:
# - Schema structure and complexity
# - Performance metrics and recommendations
# - LLM provider compatibility scores
# - DSPy readiness assessment
# - Optimization suggestions
```

## Configuration System

### Advanced Configuration Options

```elixir
# Create enhanced configuration for specific use cases
config = Exdantic.Config.create_enhanced(%{
  llm_provider: :openai,           # Target LLM provider
  dspy_compatible: true,           # Ensure DSPy compatibility
  performance_mode: :balanced,     # :speed, :memory, or :balanced
  enhanced_validation: true,       # Enable model validators/computed fields
  include_metadata: true           # Include validation metadata
})

# DSPy-specific configurations
signature_config = Exdantic.Config.for_dspy(:signature, provider: :openai)
chain_config = Exdantic.Config.for_dspy(:chain_of_thought, provider: :anthropic)
io_config = Exdantic.Config.for_dspy(:input_output)
```

### Configuration Inheritance and Merging

```elixir
# Base configuration
base_config = Exdantic.Config.preset(:api)

# Environment-specific overrides
dev_config = Exdantic.Config.merge(base_config, %{
  error_format: :detailed,
  validate_assignment: false
})

prod_config = Exdantic.Config.merge(base_config, %{
  error_format: :simple,
  frozen: true
})

# Conditional configuration
config = Exdantic.Config.builder()
|> Exdantic.Config.Builder.when_true(Mix.env() == :prod, &Exdantic.Config.Builder.frozen/1)
|> Exdantic.Config.Builder.when_false(Mix.env() == :test, &Exdantic.Config.Builder.strict/1)
|> Exdantic.Config.Builder.build()
```

### Configuration Validation

```elixir
# Validate configuration compatibility
case Exdantic.Config.validate_config(config) do
  :ok -> 
    IO.puts("Configuration is valid")
  {:error, issues} -> 
    IO.puts("Configuration issues: #{inspect(issues)}")
end

# Example validation issues:
# - "strict mode conflicts with extra: :allow"
# - "aggressive coercion conflicts with validate_assignment"
# - "max_anyof_union_len must be at least 1"
```

## Performance Optimization

### Schema Design Best Practices

```elixir
# ✅ Good: Efficient schema design
defmodule OptimizedSchema do
  use Exdantic, define_struct: true

  schema do
    # Simple, fast validations first
    field :id, :integer, gt: 0
    field :status, :string, choices: ["active", "inactive"]
    
    # More complex validations later
    field :email, :string, format: ~r/@/
    field :metadata, :map, optional: true
    
    # Limit expensive model validators
    model_validator :quick_validation
    
    # Simple computed fields
    computed_field :display_id, :string, fn input ->
      {:ok, "ID-#{input.id}"}
    end
  end

  def quick_validation(input) do
    # Fast, simple validation
    if input.id > 0, do: {:ok, input}, else: {:error, "Invalid ID"}
  end
end
```

### Reusable Components

```elixir
# Create reusable TypeAdapter instances
email_adapter = Exdantic.TypeAdapter.create(
  {:type, :string, [format: ~r/@/]},
  coerce: true
)

# Reuse for multiple validations
results = emails
|> Exdantic.TypeAdapter.Instance.validate_many(email_adapter, emails)

# Cache runtime schemas
@user_schema Exdantic.Runtime.create_schema(user_fields)

def validate_user(data) do
  Exdantic.Runtime.validate(data, @user_schema)
end
```

### Batch Operations

```elixir
# Validate multiple items efficiently
users_data = [
  %{name: "John", email: "john@example.com"},
  %{name: "Jane", email: "jane@example.com"},
  # ... more users
]

# Batch validation
case Exdantic.EnhancedValidator.validate_many(UserSchema, users_data) do
  {:ok, validated_users} ->
    # All users valid
    validated_users
    
  {:error, errors_by_index} ->
    # Some users invalid - errors mapped by index
    Enum.each(errors_by_index, fn {index, errors} ->
      IO.puts("User #{index} errors: #{inspect(errors)}")
    end)
end
```

## Complex Validation Patterns

### Conditional Validation

```elixir
defmodule ConditionalSchema do
  use Exdantic

  schema do
    field :user_type, :string, choices: ["individual", "business"]
    field :first_name, :string, optional: true
    field :last_name, :string, optional: true
    field :business_name, :string, optional: true
    field :tax_id, :string, optional: true
    
    model_validator :validate_user_type_fields
  end

  def validate_user_type_fields(input) do
    case input.user_type do
      "individual" ->
        validate_individual_fields(input)
      "business" ->
        validate_business_fields(input)
    end
  end
  
  defp validate_individual_fields(input) do
    cond do
      is_nil(input.first_name) -> {:error, "First name required for individuals"}
      is_nil(input.last_name) -> {:error, "Last name required for individuals"}
      true -> {:ok, input}
    end
  end
  
  defp validate_business_fields(input) do
    cond do
      is_nil(input.business_name) -> {:error, "Business name required for businesses"}
      is_nil(input.tax_id) -> {:error, "Tax ID required for businesses"}
      true -> {:ok, input}
    end
  end
end
```

### Multi-Step Validation Pipeline

```elixir
# Create validation pipeline with multiple steps
pipeline_steps = [
  # Step 1: Basic type validation
  UserSchema,
  
  # Step 2: Business logic validation
  fn user ->
    case validate_business_rules(user) do
      :ok -> {:ok, user}
      error -> error
    end
  end,
  
  # Step 3: External service validation
  fn user ->
    case external_validation_service(user.email) do
      {:ok, _} -> {:ok, user}
      {:error, reason} -> {:error, "External validation failed: #{reason}"}
    end
  end,
  
  # Step 4: Final transformation
  fn user ->
    transformed = apply_final_transformations(user)
    {:ok, transformed}
  end
]

# Execute pipeline
case Exdantic.EnhancedValidator.pipeline(pipeline_steps, input_data) do
  {:ok, final_result} ->
    # All steps succeeded
    final_result
    
  {:error, {step_index, errors}} ->
    # Failed at specific step
    IO.puts("Pipeline failed at step #{step_index}: #{inspect(errors)}")
end
```

### Dynamic Schema Selection

```elixir
defmodule DynamicValidation do
  @schemas %{
    "user_v1" => UserV1Schema,
    "user_v2" => UserV2Schema,
    "admin" => AdminSchema
  }

  def validate_by_type(data, schema_type) do
    case Map.get(@schemas, schema_type) do
      nil ->
        {:error, "Unknown schema type: #{schema_type}"}
      schema ->
        schema.validate(data)
    end
  end
  
  def validate_with_fallback(data, primary_schema, fallback_schema) do
    case primary_schema.validate(data) do
      {:ok, result} -> 
        {:ok, result}
      {:error, _} ->
        # Try fallback schema
        fallback_schema.validate(data)
    end
  end
end
```

### Cross-Schema Validation

```elixir
defmodule OrderValidation do
  def validate_order_with_user(order_data, user_data) do
    with {:ok, user} <- UserSchema.validate(user_data),
         {:ok, order} <- OrderSchema.validate(order_data),
         :ok <- validate_user_can_order(user, order) do
      {:ok, {user, order}}
    else
      error -> error
    end
  end
  
  defp validate_user_can_order(user, order) do
    cond do
      not user.active ->
        {:error, "User account is not active"}
      user.credit_limit < order.total ->
        {:error, "Order exceeds user credit limit"}
      order.items == [] ->
        {:error, "Order must contain at least one item"}
      true ->
        :ok
    end
  end
end
```

### Recursive Schema Validation

```elixir
defmodule TreeNodeSchema do
  use Exdantic

  schema do
    field :value, :any, required: true
    field :children, {:array, TreeNodeSchema}, default: []
    
    model_validator :validate_tree_structure
    computed_field :depth, :integer, :calculate_depth
    computed_field :node_count, :integer, :count_nodes
  end

  def validate_tree_structure(input) do
    if length(input.children) > 10 do
      {:error, "Node cannot have more than 10 children"}
    else
      {:ok, input}
    end
  end
  
  def calculate_depth(input) do
    depth = if input.children == [] do
      1
    else
      max_child_depth = input.children
                       |> Enum.map(& &1.depth)
                       |> Enum.max(fn -> 0 end)
      max_child_depth + 1
    end
    {:ok, depth}
  end
  
  def count_nodes(input) do
    count = 1 + Enum.sum(Enum.map(input.children, & &1.node_count))
    {:ok, count}
  end
end
```

## Testing Advanced Features

### Testing Model Validators

```elixir
defmodule UserSchemaTest do
  use ExUnit.Case

  describe "model validators" do
    test "validates password confirmation" do
      valid_data = %{
        username: "john",
        password: "secret123",
        password_confirmation: "secret123"
      }
      
      assert {:ok, user} = UserSchema.validate(valid_data)
      refute Map.has_key?(user, :password_confirmation)
    end
    
    test "rejects mismatched passwords" do
      invalid_data = %{
        username: "john",
        password: "secret123",
        password_confirmation: "different"
      }
      
      assert {:error, [error]} = UserSchema.validate(invalid_data)
      assert error.code == :model_validation
      assert error.message =~ "Password confirmation"
    end
  end

  describe "computed fields" do
    test "generates full name" do
      data = %{first_name: "John", last_name: "Doe"}
      
      assert {:ok, user} = UserSchema.validate(data)
      assert user.full_name == "John Doe"
    end
    
    test "handles computed field errors" do
      data = %{first_name: "John", birth_date: "invalid-date"}
      
      assert {:error, errors} = UserSchema.validate(data)
      assert Enum.any?(errors, & &1.code == :computed_field)
    end
  end
end
```

### Testing Runtime Schemas

```elixir
defmodule RuntimeSchemaTest do
  use ExUnit.Case

  test "enhanced runtime schema with validators and computed fields" do
    fields = [{:name, :string, [required: true]}]
    
    validators = [
      fn data -> {:ok, %{data | name: String.upcase(data.name)}} end
    ]
    
    computed_fields = [
      {:name_length, :integer, fn data -> {:ok, String.length(data.name)} end}
    ]
    
    schema = Exdantic.Runtime.create_enhanced_schema(fields,
      model_validators: validators,
      computed_fields: computed_fields
    )
    
    {:ok, result} = Exdantic.Runtime.validate_enhanced(%{name: "john"}, schema)
    
    assert result.name == "JOHN"
    assert result.name_length == 4
  end
end
```

### Performance Testing

```elixir
defmodule PerformanceTest do
  use ExUnit.Case

  @tag :performance
  test "validation performance under load" do
    data = %{name: "Test User", email: "test@example.com"}
    
    {time, _results} = :timer.tc(fn ->
      for _ <- 1..1000 do
        UserSchema.validate(data)
      end
    end)
    
    avg_time = time / 1000
    assert avg_time < 5000  # Less than 5ms average
  end
  
  @tag :performance
  test "batch validation performance" do
    users_data = for i <- 1..1000 do
      %{name: "User #{i}", email: "user#{i}@example.com"}
    end
    
    {time, {:ok, _results}} = :timer.tc(fn ->
      Exdantic.EnhancedValidator.validate_many(UserSchema, users_data)
    end)
    
    assert time < 100_000  # Less than 100ms for 1000 items
  end
end
```

## Debugging and Troubleshooting

### Validation Reports

```elixir
# Generate comprehensive validation report
report = Exdantic.EnhancedValidator.validation_report(UserSchema, data)

# Report includes:
# - validation_result: success/failure with details
# - json_schema: generated schema
# - target_info: schema analysis
# - input_analysis: data structure analysis
# - performance_metrics: timing information
# - configuration: applied settings

IO.inspect(report, pretty: true)
```

### Schema Analysis

```elixir
# Analyze schema capabilities and compatibility
info = UserSchema.__enhanced_schema_info__()

IO.puts("Schema features:")
IO.puts("- Has struct: #{info.has_struct}")
IO.puts("- Field count: #{info.field_count}")
IO.puts("- Computed fields: #{info.computed_field_count}")
IO.puts("- Model validators: #{info.model_validator_count}")
IO.puts("- DSPy ready: #{info.dspy_ready.ready}")

# Performance profile
profile = info.performance_profile
IO.puts("Performance:")
IO.puts("- Complexity score: #{profile.complexity_score}")
IO.puts("- Estimated time: #{profile.estimated_validation_time}")
IO.puts("- Memory footprint: #{profile.memory_footprint}")
```

### Error Analysis

```elixir
# Detailed error analysis for debugging
case UserSchema.validate(problematic_data) do
  {:error, errors} ->
    Enum.each(errors, fn error ->
      IO.puts("Error Analysis:")
      IO.puts("  Path: #{Enum.join(error.path, " -> ")}")
      IO.puts("  Code: #{error.code}")
      IO.puts("  Message: #{error.message}")
      IO.puts("  Context: #{inspect(error)}")
      IO.puts("")
    end)
end
```

## Best Practices Summary

1. **Model Validators**:
   - Keep validators focused and single-purpose
   - Order validators logically (data transformation before business logic)
   - Handle errors gracefully with clear messages
   - Use anonymous functions for simple transformations

2. **Computed Fields**:
   - Keep computations simple and fast
   - Validate computed field return values
   - Use computed fields for derived data, not complex business logic
   - Consider caching for expensive computations

3. **Runtime Schemas**:
   - Create schemas once and reuse them
   - Use enhanced schemas when you need model validators or computed fields
   - Consider performance implications for high-throughput scenarios

4. **Configuration**:
   - Use appropriate presets for common scenarios
   - Create environment-specific configurations
   - Validate configurations before using them

5. **Performance**:
   - Profile validation performance in realistic scenarios
   - Use batch operations for multiple validations
   - Cache schemas and TypeAdapter instances
   - Choose the right validation approach for your use case

This guide covers the advanced features that make Exdantic suitable for complex validation scenarios, from simple business logic to sophisticated AI/LLM integration patterns.

## 📚 Practical Examples

For hands-on examples of all the patterns covered in this guide, see the [`examples/`](../examples/) directory:

- **Advanced Features**: [`advanced_features.exs`](../examples/advanced_features.exs)
- **Model Validators**: [`model_validators.exs`](../examples/model_validators.exs)
- **Computed Fields**: [`computed_fields.exs`](../examples/computed_fields.exs)
- **Enhanced Validator**: [`enhanced_validator.exs`](../examples/enhanced_validator.exs)
- **Advanced Configuration**: [`advanced_config.exs`](../examples/advanced_config.exs)
- **Conditional & Recursive Validation**: [`conditional_recursive_validation.exs`](../examples/conditional_recursive_validation.exs)
- **Root Schema**: [`root_schema.exs`](../examples/root_schema.exs)

Run any example with:
```bash
mix run examples/<example_name>.exs
```

See [`examples/README.md`](../examples/README.md) for the complete guide.
