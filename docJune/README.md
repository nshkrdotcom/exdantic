# Exdantic

**A powerful, flexible schema definition and validation library for Elixir, inspired by Python's Pydantic.**

Exdantic provides a comprehensive type system with rich validation capabilities, automatic JSON Schema generation, and excellent developer experience. Perfect for API input validation, configuration management, and data processing pipelines.

## ✨ Features

- 🎯 **Rich Type System** - Support for basic types, complex structures, and custom types
- 🔍 **Advanced Validation** - Built-in constraints plus custom validation functions
- 📊 **JSON Schema Generation** - automatic JSON Schema output from Elixir schemas
- 🎨 **Custom Error Messages** - User-friendly, contextual error messages
- 🏗️ **Object Validation** - Fixed-key map validation with field-by-field validation
- 🧩 **Custom Types** - Define reusable, composable custom types
- 🎄 **Nested Structures** - Deep nested validation with path-aware error reporting
- ⛓️ **Rich Constraints** - Comprehensive built-in constraints for all types
- 🔧 **Value Transformation** - Transform values during validation (normalization, formatting)
- 🚨 **Structured Errors** - Detailed error information with field paths and codes

## 🚀 Quick Start

### Installation

Add `exdantic` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:exdantic, "~> 0.1.0"}
  ]
end
```

### Basic Usage

```elixir
# Simple type validation
alias Exdantic.{Types, Validator}

# Validate basic types
{:ok, "hello"} = Validator.validate(Types.string(), "hello")
{:error, _} = Validator.validate(Types.integer(), "not a number")

# Add constraints
age_type = Types.integer() |> Types.with_constraints(gt: 0, lt: 150)
{:ok, 25} = Validator.validate(age_type, 25)
{:error, _} = Validator.validate(age_type, -5)
```

### Schema-Based Validation

```elixir
defmodule UserSchema do
  use Exdantic

  schema "User account information" do
    field :name, :string do
      description "User's full name"
      min_length 2
      max_length 50
    end

    field :age, :integer do
      description "User's age"
      gt 0
      lt 150
      optional true
    end

    field :email, :string do
      format ~r/^[^\s]+@[^\s]+$/
    end

    field :tags, {:array, :string} do
      description "User tags"
      min_items 0
      max_items 5
      default []
    end

    config do
      title "User Schema"
      strict true
    end
  end
end

# Use the schema
case UserSchema.validate(%{
  name: "John Doe",
  email: "john@example.com",
  age: 30,
  tags: ["admin"]
}) do
  {:ok, validated_data} -> 
    # Use validated data
    IO.inspect(validated_data)
  
  {:error, errors} -> 
    # Handle validation errors
    Enum.each(errors, &IO.puts(Exdantic.Error.format(&1)))
end
```

## 🛠️ Core Features

### 1. Rich Type System

Exdantic supports a comprehensive type system:

```elixir
# Basic types
Types.string()
Types.integer()
Types.float()
Types.boolean()
Types.type(:atom)

# Complex types
Types.array(Types.string())
Types.map(Types.string(), Types.integer())
Types.union([Types.string(), Types.integer()])
Types.object(%{name: Types.string(), age: Types.integer()})

# With constraints
Types.string()
|> Types.with_constraints([
  min_length: 3,
  max_length: 50,
  format: ~r/^[a-zA-Z ]+$/
])
```

### 2. Object Validation (Fixed-Key Maps)

Validate structured data with field-by-field validation:

```elixir
user_type = Types.object(%{
  name: Types.string() 
        |> Types.with_constraints(min_length: 1),
  age: Types.integer() 
       |> Types.with_constraints(gt: 0, lt: 120),
  email: Types.string() 
         |> Types.with_constraints(format: ~r/^[^\s]+@[^\s]+\.[^\s]+$/),
  active: Types.boolean()
})

# Validates each field individually
{:ok, user} = Validator.validate(user_type, %{
  name: "John Doe",
  age: 30,
  email: "john@example.com", 
  active: true
})
```

### 3. Custom Validation Functions

Add business logic validation beyond basic constraints:

```elixir
email_type = Types.string()
|> Types.with_constraints(min_length: 5)
|> Types.with_validator(fn value ->
  cond do
    not String.contains?(value, "@") -> 
      {:error, "Must be a valid email address"}
    not String.match?(value, ~r/^[^@]+@[^@]+\.[^@]+$/) -> 
      {:error, "Email format is invalid"}
    true -> 
      {:ok, String.downcase(value)}  # Transform to lowercase
  end
end)

{:ok, "user@example.com"} = Validator.validate(email_type, "USER@EXAMPLE.COM")
```

### 4. Custom Error Messages

Provide user-friendly error messages:

```elixir
# Single custom message
name_type = Types.string()
|> Types.with_constraints(min_length: 3)
|> Types.with_error_message(:min_length, "Name must be at least 3 characters long")

# Multiple custom messages
password_type = Types.string()
|> Types.with_constraints(min_length: 8, max_length: 100)
|> Types.with_error_messages(%{
  min_length: "Password must be at least 8 characters long",
  max_length: "Password cannot exceed 100 characters"
})
```

### 5. Complex Nested Structures

Handle deeply nested data with path-aware error reporting:

```elixir
person_type = Types.object(%{
  name: Types.string(),
  address: Types.object(%{
    street: Types.string(), 
    city: Types.string(),
    zip: Types.string() |> Types.with_constraints(format: ~r/^\d{5}$/)
  })
})

# Error paths show exactly where validation failed
case Validator.validate(person_type, %{
  name: "John",
  address: %{street: "123 Main", city: "Springfield", zip: "invalid"}
}) do
  {:error, [error]} -> 
    IO.puts("Error at #{inspect(error.path)}: #{error.message}")
    # Output: Error at [:address, :zip]: failed format constraint
end
```

## 📝 Available Types

### Basic Types
- `:string` - String values
- `:integer` - Integer values  
- `:float` - Float values
- `:boolean` - Boolean values (true/false)
- `:atom` - Atom values (with choices constraint support)
- `:any` - Any value (no validation)

### Complex Types
- `{:array, type}` - Arrays of specified type
- `{:map, {key_type, value_type}}` - Maps with typed keys and values
- `{:object, %{field => type}}` - Fixed-key maps (objects)
- `{:union, [type1, type2, ...]}` - Union of multiple types
- `{:tuple, [type1, type2, ...]}` - Tuples with typed elements
- Custom types - Any module implementing `Exdantic.Type` behaviour
- Schema references - References to other schema modules

## ⚙️ Constraints

### String Constraints
- `min_length: integer` - Minimum string length
- `max_length: integer` - Maximum string length  
- `format: regex` - String must match regex pattern
- `choices: [value, ...]` - String must be one of the provided choices

### Numeric Constraints (Integer/Float)
- `gt: number` - Greater than
- `lt: number` - Less than
- `gteq: number` - Greater than or equal to
- `lteq: number` - Less than or equal to
- `choices: [value, ...]` - Number must be one of the provided choices

### Array Constraints
- `min_items: integer` - Minimum number of items
- `max_items: integer` - Maximum number of items

### Map/Object Constraints
- `size?: integer` - Exact number of key-value pairs

### Atom Constraints
- `choices: [atom, ...]` - Atom must be one of the provided choices

### General Constraints
- `required: boolean` - Field is required (schema fields only)
- `optional: boolean` - Field is optional (schema fields only)
- `default: any` - Default value if not provided (schema fields only)

## 🎨 Custom Types

Create reusable custom types:

```elixir
defmodule Types.Email do
  use Exdantic.Type

  def type_definition do
    Exdantic.Types.string()
    |> Exdantic.Types.with_constraints([
      format: ~r/^[^\s]+@[^\s]+\.[^\s]+$/
    ])
    |> Exdantic.Types.with_error_message(:format, "Must be a valid email address")
  end

  def json_schema do
    %{
      "type" => "string",
      "format" => "email",
      "pattern" => "^[^\\s]+@[^\\s]+\\.[^\\s]+$"
    }
  end
end

# Use the custom type
user_type = Types.object(%{
  email: Types.Email,
  name: Types.string()
})
```

## 📊 JSON Schema Generation

Generate JSON Schema from your Elixir schemas:

```elixir
# Generate JSON Schema
json_schema = Exdantic.JsonSchema.from_schema(UserSchema)

# Convert to JSON string
json_string = Jason.encode!(json_schema)

# Use with any JSON Schema validator
File.write!("user_schema.json", json_string)
```

## 🚨 Error Handling

Exdantic provides structured error information:

```elixir
case Validator.validate(type, data) do
  {:ok, validated_data} ->
    # Success - use validated data
    validated_data
    
  {:error, errors} when is_list(errors) ->
    # Multiple validation errors
    Enum.each(errors, fn error ->
      IO.puts "#{Enum.join(error.path, ".")}: #{error.message}"
    end)
    
  {:error, error} ->
    # Single validation error
    IO.puts "#{Enum.join(error.path, ".")}: #{error.message}"
end
```

Error structure:
```elixir
%Exdantic.Error{
  path: [:field, :nested_field],  # Path to the invalid field
  code: :min_length,              # Error type
  message: "Custom error message" # Human-readable message
}
```

## 📚 Examples

Check out comprehensive examples in the [`examples/`](examples/) directory:

- **`basic_usage.exs`** - Fundamental features and type validation
- **`custom_validation.exs`** - Custom validation functions and business logic
- **`advanced_features.exs`** - Complex structures and integration patterns

Run any example:
```bash
mix run examples/basic_usage.exs
```

## 🗺️ Roadmap

### Completed Features ✅
- **Core Type System** - Basic and complex types with constraints
- **Custom Error Messages** - User-friendly error message customization  
- **Object Validation** - Fixed-key map validation with field-by-field validation
- **Custom Validation Functions** - Business logic validation beyond basic constraints
- **Enhanced Atom Support** - Full atom type support with choices constraints
- **Value Transformation** - Transform values during validation process
- **Nested Validation** - Deep nested structure validation with path tracking
- **JSON Schema Generation** - Export schemas to JSON Schema format

### Planned Features 🚧
- **Schema Composition** - Inherit and extend existing schemas
- **Conditional Validation** - Validate fields based on other field values
- **Array Element Constraints** - Per-element validation in arrays
- **Performance Optimizations** - Compile-time optimizations for frequently used schemas
- **Advanced Features**
  - Recursive schemas (self-referencing)
  - Cross-field validation
  - Schema versioning and migration

### Future Enhancements 🔮
- **Multi-language Schema Export** - Generate schemas for other languages (TypeScript, Python, etc.)
- **Schema Registry** - Centralized schema management and versioning
- **Performance Benchmarking** - Built-in performance monitoring and optimization

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

### Development Guidelines

- Write comprehensive tests for new features
- Follow existing code style and conventions
- Add documentation for public APIs
- Ensure zero dialyzer warnings
- Update examples when adding new features

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Inspired by Python's [Pydantic](https://pydantic-docs.helpmanual.io/) library
- Built with ❤️ for the Elixir community
- Thanks to all contributors and users providing feedback

---

**Made with Elixir** 💜