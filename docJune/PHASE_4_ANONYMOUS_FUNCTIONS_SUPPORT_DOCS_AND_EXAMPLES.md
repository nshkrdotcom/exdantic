# Phase 4: Anonymous Function Support - Documentation and Examples

## Overview

Phase 4 enhances Exdantic with support for inline anonymous functions in both model validators and computed fields. This provides more flexibility for simple validation logic and computations without requiring separate named functions.

## New Features

### Anonymous Model Validators

You can now define model validators using three different syntaxes:

#### 1. Named Function (Existing - Phase 2)
```elixir
defmodule UserSchema do
  use Exdantic, define_struct: true

  schema do
    field :password, :string
    field :password_confirmation, :string

    model_validator :validate_passwords_match
  end

  def validate_passwords_match(input) do
    if input.password == input.password_confirmation do
      {:ok, input}
    else
      {:error, "passwords do not match"}
    end
  end
end
```

#### 2. Anonymous Function (New - Phase 4)
```elixir
defmodule UserSchema do
  use Exdantic, define_struct: true

  schema do
    field :password, :string
    field :password_confirmation, :string

    # Anonymous function syntax
    model_validator fn input ->
      if input.password == input.password_confirmation do
        {:ok, input}
      else
        {:error, "passwords do not match"}
      end
    end
  end
end
```

#### 3. Block Syntax with Implicit Input (New - Phase 4)
```elixir
defmodule UserSchema do
  use Exdantic, define_struct: true

  schema do
    field :password, :string
    field :password_confirmation, :string

    # Block syntax with implicit 'input' variable
    model_validator do
      if input.password == input.password_confirmation do
        {:ok, input}
      else
        {:error, "passwords do not match"}
      end
    end
  end
end
```

### Anonymous Computed Fields

Similarly, computed fields now support three syntaxes:

#### 1. Named Function (Existing - Phase 3)
```elixir
defmodule UserSchema do
  use Exdantic, define_struct: true

  schema do
    field :first_name, :string
    field :last_name, :string

    computed_field :full_name, :string, :generate_full_name
  end

  def generate_full_name(input) do
    {:ok, "#{input.first_name} #{input.last_name}"}
  end
end
```

#### 2. Anonymous Function (New - Phase 4)
```elixir
defmodule UserSchema do
  use Exdantic, define_struct: true

  schema do
    field :first_name, :string
    field :last_name, :string

    # Anonymous function syntax
    computed_field :full_name, :string, fn input ->
      {:ok, "#{input.first_name} #{input.last_name}"}
    end
  end
end
```

#### 3. Block Syntax with Implicit Input (New - Phase 4)
```elixir
defmodule UserSchema do
  use Exdantic, define_struct: true

  schema do
    field :first_name, :string
    field :last_name, :string

    # Block syntax with implicit 'input' variable
    computed_field :full_name, :string do
      {:ok, "#{input.first_name} #{input.last_name}"}
    end
  end
end
```

## Advanced Examples

### Complex Model Validation with Mixed Syntaxes

```elixir
defmodule AdvancedUserSchema do
  use Exdantic, define_struct: true

  schema do
    field :email, :string, required: true
    field :password, :string, required: true
    field :age, :integer, required: true
    field :terms_accepted, :boolean, required: true

    # Named validator for complex business logic
    model_validator :validate_email_domain

    # Anonymous validator for simple checks
    model_validator fn input ->
      if input.terms_accepted do
        {:ok, input}
      else
        {:error, "terms and conditions must be accepted"}
      end
    end

    # Block syntax for multi-step validation
    model_validator do
      cond do
        input.age < 13 ->
          {:error, "must be at least 13 years old"}
        
        input.age > 120 ->
          {:error, "age seems unrealistic"}
        
        String.length(input.password) < 8 ->
          {:error, "password must be at least 8 characters"}
        
        true ->
          {:ok, input}
      end
    end

    # Data transformation validator
    model_validator do
      normalized_email = String.downcase(String.trim(input.email))
      {:ok, %{input | email: normalized_email}}
    end
  end

  def validate_email_domain(input) do
    allowed_domains = ["company.com", "partner.org"]
    domain = input.email |> String.split("@") |> List.last()
    
    if domain in allowed_domains do
      {:ok, input}
    else
      {:error, "email domain not allowed"}
    end
  end
end
```

### Rich Computed Fields with Mixed Syntaxes

```elixir
defmodule ProfileSchema do
  use Exdantic, define_struct: true

  schema do
    field :first_name, :string, required: true
    field :last_name, :string, required: true
    field :birth_date, :string, required: true  # ISO date format
    field :email, :string, required: true
    field :skills, {:array, :string}, required: true

    # Named computed field for complex logic
    computed_field :age, :integer, :calculate_age

    # Anonymous function for simple string manipulation
    computed_field :display_name, :string, fn input ->
      {:ok, "#{input.first_name} #{input.last_name}"}
    end

    # Block syntax for complex computations
    computed_field :skill_summary, :string do
      skill_count = length(input.skills)
      
      case skill_count do
        0 -> {:ok, "No skills listed"}
        1 -> {:ok, "1 skill: #{hd(input.skills)}"}
        n when n <= 3 -> {:ok, "#{n} skills: #{Enum.join(input.skills, ", ")}"}
        n -> {:ok, "#{n} skills including #{Enum.take(input.skills, 2) |> Enum.join(", ")}"}
      end
    end

    # Named computed field that depends on other computed fields
    computed_field :profile_summary, :string, :generate_profile_summary

    # Anonymous computed field with error handling
    computed_field :username_suggestion, :string, fn input ->
      try do
        first_part = input.first_name |> String.slice(0, 3) |> String.downcase()
        last_part = input.last_name |> String.slice(0, 3) |> String.downcase()
        {:ok, "#{first_part}#{last_part}"}
      rescue
        _ -> {:error, "could not generate username suggestion"}
      end
    end
  end

  def calculate_age(input) do
    case Date.from_iso8601(input.birth_date) do
      {:ok, birth_date} ->
        today = Date.utc_today()
        age = Date.diff(today, birth_date) |> div(365)
        {:ok, age}
      
      {:error, _} ->
        {:error, "invalid birth date format"}
    end
  end

  def generate_profile_summary(input) do
    summary = """
    #{input.display_name} (Age: #{input.age})
    Email: #{input.email}
    Skills: #{input.skill_summary}
    Suggested username: #{input.username_suggestion}
    """
    
    {:ok, String.trim(summary)}
  end
end
```

### Computed Fields with Metadata

```elixir
defmodule ProductSchema do
  use Exdantic, define_struct: true

  schema do
    field :name, :string, required: true
    field :base_price, :float, required: true
    field :tax_rate, :float, required: true

    # Anonymous computed field with metadata
    computed_field :total_price, :float,
      description: "Price including tax",
      example: 10.99 do
      total = input.base_price * (1 + input.tax_rate)
      {:ok, Float.round(total, 2)}
    end

    # Block syntax with conditional logic and metadata
    computed_field :price_category, :string,
      description: "Category based on price range",
      example: "standard" do
      cond do
        input.base_price < 10.0 -> {:ok, "budget"}
        input.base_price < 50.0 -> {:ok, "standard"}
        input.base_price < 200.0 -> {:ok, "premium"}
        true -> {:ok, "luxury"}
      end
    end
  end
end
```

## Migration Guide

### From Named Functions to Anonymous Functions

If you have existing named functions that are simple and only used for one validator or computed field, you can migrate them to anonymous functions:

#### Before (Phase 2/3)
```elixir
defmodule UserSchema do
  use Exdantic

  schema do
    field :name, :string
    model_validator :check_name_length
    computed_field :upper_name, :string, :make_uppercase
  end

  def check_name_length(input) do
    if String.length(input.name) >= 2 do
      {:ok, input}
    else
      {:error, "name too short"}
    end
  end

  def make_uppercase(input) do
    {:ok, String.upcase(input.name)}
  end
end
```

#### After (Phase 4)
```elixir
defmodule UserSchema do
  use Exdantic

  schema do
    field :name, :string
    
    # Migrated to anonymous function
    model_validator do
      if String.length(input.name) >= 2 do
        {:ok, input}
      else
        {:error, "name too short"}
      end
    end
    
    # Migrated to anonymous function
    computed_field :upper_name, :string do
      {:ok, String.upcase(input.name)}
    end
  end
end
```

### When to Use Each Approach

#### Use Named Functions When:
- Logic is complex and benefits from being testable in isolation
- The same logic is used in multiple places
- You want to provide comprehensive documentation for the function
- The function performs side effects or external calls

#### Use Anonymous Functions When:
- Logic is simple and self-contained
- The validation/computation is specific to this schema
- You want to keep related logic close to the field definitions
- The logic is unlikely to be reused elsewhere

## Error Handling

Anonymous functions follow the same error handling patterns as named functions:

### Model Validator Errors
```elixir
schema do
  field :age, :integer

  model_validator do
    cond do
      input.age < 0 -> {:error, "age cannot be negative"}
      input.age > 150 -> {:error, "age seems unrealistic"}
      true -> {:ok, input}
    end
  end
end
```

### Computed Field Errors
```elixir
schema do
  field :numerator, :integer
  field :denominator, :integer

  computed_field :ratio, :float do
    if input.denominator == 0 do
      {:error, "cannot divide by zero"}
    else
      {:ok, input.numerator / input.denominator}
    end
  end
end
```

### Error Messages

Anonymous functions generate helpful error messages:

```elixir
# For model validators:
"Anonymous model validator failed: age cannot be negative"

# For computed fields:
"MySchema.<anonymous computed field :ratio>/1 execution failed: cannot divide by zero"
```

## Performance Considerations

- **Function Generation**: Anonymous functions generate unique function names at compile time
- **No Runtime Overhead**: Anonymous functions have the same performance as named functions
- **Memory Usage**: Generated function names use timestamps and unique integers to avoid conflicts
- **Compilation**: Each anonymous function creates a new function definition in the module

## Best Practices

### 1. Keep Anonymous Functions Simple
```elixir
# Good: Simple validation
model_validator do
  if input.age >= 18, do: {:ok, input}, else: {:error, "must be adult"}
end

# Consider named function: Complex validation
model_validator :validate_complex_business_rules
```

### 2. Use Descriptive Variable Names in Blocks
```elixir
# Good: Clear variable usage
computed_field :formatted_price, :string do
  price_str = :erlang.float_to_binary(input.price, decimals: 2)
  {:ok, "$#{price_str}"}
end
```

### 3. Handle Errors Gracefully
```elixir
computed_field :safe_computation, :string do
  try do
    result = complex_computation(input)
    {:ok, result}
  rescue
    e -> {:error, "computation failed: #{Exception.message(e)}"}
  end
end
```

### 4. Combine Approaches Strategically
```elixir
schema do
  field :data, :map

  # Use named function for complex, reusable logic
  model_validator :validate_business_rules

  # Use anonymous function for simple, specific checks
  model_validator do
    if map_size(input.data) > 0, do: {:ok, input}, else: {:error, "data required"}
  end
end
```

## JSON Schema Generation

Anonymous functions are properly handled in JSON Schema generation:

```elixir
defmodule ExampleSchema do
  use Exdantic

  schema do
    field :name, :string

    computed_field :upper_name, :string do
      {:ok, String.upcase(input.name)}
    end
  end
end

# Generate JSON Schema
json_schema = Exdantic.JsonSchema.from_schema(ExampleSchema)

# Results in:
%{
  "type" => "object",
  "properties" => %{
    "name" => %{"type" => "string"},
    "upper_name" => %{
      "type" => "string",
      "readOnly" => true,
      "x-computed-field" => %{
        "function" => "ExampleSchema.<anonymous computed field :upper_name>/1",
        "module" => "ExampleSchema",
        "function_name" => "__generated_computed_field_upper_name_123_456"
      }
    }
  }
}
```

## Compatibility

Phase 4 is fully backward compatible:

- All existing named function syntax continues to work unchanged
- Mix and match named and anonymous functions in the same schema
- No performance impact on existing code
- All existing tests pass without modification

## Implementation Details

### Function Name Generation

Anonymous functions generate unique names using:
- Prefix indicating the type (`__generated_model_validator_` or `__generated_computed_field_`)
- Field name (for computed fields)
- Unique integer
- Timestamp

Example: `__generated_computed_field_full_name_123_1640995200000`

### Execution Pipeline

Anonymous functions integrate seamlessly into the existing execution pipeline:
1. Field validation
2. Model validators (named and anonymous, in definition order)
3. Computed fields (named and anonymous, in definition order)
4. Struct creation (if enabled)

### Error Reporting

Enhanced error reporting provides context for anonymous functions while maintaining the same error structure and handling patterns.
