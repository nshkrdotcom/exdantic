# Exdantic

**A powerful, flexible, Pydantic-inspired schema definition and validation library for Elixir.**

[![CI](https://github.com/nshkrdotcom/exdantic/actions/workflows/ci.yml/badge.svg)](https://github.com/nshkrdotcom/exdantic/actions/workflows/ci.yml)
[![Hex.pm](https://img.shields.io/hexpm/v/exdantic.svg)](https://hex.pm/packages/exdantic)
[![Hex Docs](https://img.shields.io/badge/hex-docs-lightgreen.svg)](https://hexdocs.pm/exdantic/)

Exdantic provides a comprehensive toolset for data validation, serialization, and schema generation. It is perfect for building robust APIs, managing complex configurations, and creating data processing pipelines. With its new runtime features, Exdantic is uniquely suited for AI and LLM applications, enabling dynamic, DSPy-style programming patterns in Elixir.

## ✨ Features

-   🎯 **Rich Type System**: Support for basic types, complex nested structures (arrays, maps, unions), and custom types.
-   🚀 **Runtime & Compile-Time Schemas**: Define schemas dynamically at runtime or at compile-time for maximum flexibility and performance.
-   🔧 **Pydantic-Inspired Patterns**: First-class support for `create_model`, `TypeAdapter`, and `Wrapper` patterns familiar to Python developers.
-   🔍 **Advanced Validation**: A rich set of built-in constraints (`min_length`, `gt`, `format`, etc.) plus support for custom validation functions.
-   🔄 **Type Coercion**: Automatic and configurable type coercion (e.g., from string to integer).
-   📊 **Advanced JSON Schema**: Generate JSON Schema from any Exdantic type or schema, with tools to resolve references and optimize for LLM providers like OpenAI and Anthropic.
-   🚨 **Structured, Path-Aware Errors**: Get detailed, structured error messages that pinpoint the exact location of a validation failure.
-   ⚙️ **Dynamic Configuration**: Control validation behavior (e.g., strictness, coercion) at runtime with a powerful configuration system.

## 🚀 Quick Start

### Installation

Add `exdantic` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:exdantic, "~> 1.0"}
  ]
end
```

### Dynamic Validation Example

Here's how to create a schema at runtime, validate data against it with coercion, and generate an LLM-optimized JSON schema.

```elixir
# 1. Define fields for a runtime schema
fields = [
  {:reasoning, :string, description: "Chain of thought reasoning."},
  {:answer, :string, required: true, min_length: 1},
  {:confidence, :float, required: true, gteq: 0.0, lteq: 1.0}
]

# 2. Create the schema dynamically
output_schema = Exdantic.Runtime.create_schema(fields, title: "LLM_Output")

# 3. Define a safe configuration for validation
config = Exdantic.Config.create(strict: true, coercion: :safe)

# 4. Mock LLM output (with a string for `confidence` that needs coercion)
llm_output = %{
  "reasoning" => "The user is asking for a score.",
  "answer" => "The score is 42.",
  "confidence" => "0.95" # Note: this is a string
}

# 5. Validate the output using the EnhancedValidator
case Exdantic.EnhancedValidator.validate(output_schema, llm_output, config: config) do
  {:ok, validated} ->
    # The `confidence` field was successfully coerced from "0.95" to 0.95
    IO.inspect(validated)
    #=> %{answer: "The score is 42.", confidence: 0.95, reasoning: "The user is asking for a score."}

  {:error, errors} ->
    IO.inspect(errors)
end

# 6. Generate an optimized JSON schema to guide the LLM's next response
{:ok, _validated, llm_schema} = Exdantic.EnhancedValidator.validate_for_llm(
  output_schema,
  llm_output,
  :openai, # Optimize for OpenAI's structured output format
  config: config
)

IO.puts(Jason.encode!(llm_schema, pretty: true))
#=> {
#=>   "type": "object",
#=>   "title": "LLM_Output",
#=>   "properties": { ... },
#=>   "required": ["answer", "confidence"],
#=>   "additionalProperties": false
#=> }
```

##  DSPy-Inspired Patterns

Exdantic provides first-class support for patterns common in DSPy and Pydantic.

### Dynamic Schemas (`create_model`)

Use `Exdantic.Runtime.create_schema/2` to build schemas on the fly.

```elixir
fields = [
  {:question, :string, required: true},
  {:answer, :string, required: true}
]
schema = Exdantic.Runtime.create_schema(fields, name: "QASchema")
```

### Schemaless Validation (`TypeAdapter`)

Use `Exdantic.TypeAdapter.validate/3` for one-off validation without a full schema.

```elixir
# Simple validation
{:ok, 123} = Exdantic.TypeAdapter.validate(:integer, "123", coerce: true)

# Complex validation
type = {:array, {:union, [:string, :integer]}}
data = [1, "two", 3]
{:ok, [1, "two", 3]} = Exdantic.TypeAdapter.validate(type, data)
```

### Temporary Schemas (`Wrapper`)

Use `Exdantic.Wrapper.wrap_and_validate/4` to validate and extract a single, complex value. This is useful for coercing LLM outputs into specific types with constraints.

```elixir
# Validate that a value is an integer between 0 and 100
{:ok, 85} = Exdantic.Wrapper.wrap_and_validate(
  :score,
  :integer,
  "85", # Input can be a string
  coerce: true,
  constraints: [gteq: 0, lteq: 100]
)
```

### Dynamic Configuration (`ConfigDict`)

Use `Exdantic.Config` and `Exdantic.Config.Builder` to control validation behavior at runtime.

```elixir
# Create a strict, immutable config
config = Exdantic.Config.create(strict: true, extra: :forbid, frozen: true)

# Use the fluent builder
builder_config = Exdantic.Config.builder()
|> Exdantic.Config.Builder.strict()
|> Exdantic.Config.Builder.safe_coercion()
|> Exdantic.Config.Builder.build()

# Use with any validation call
Exdantic.EnhancedValidator.validate(schema, data, config: config)
```

## JSON Schema for LLMs

Generate JSON Schema from any Exdantic type or schema and optimize it for your LLM provider.

```elixir
# 1. Get the base JSON Schema
json_schema = Exdantic.Runtime.to_json_schema(my_schema)

# 2. Resolve all internal references
resolved_schema = Exdantic.JsonSchema.Resolver.resolve_references(json_schema)

# 3. Optimize for a specific provider (e.g., OpenAI)
openai_schema = Exdantic.JsonSchema.Resolver.enforce_structured_output(
  resolved_schema,
  provider: :openai
)
```

## Compile-Time Schemas

For performance-critical paths or static data structures, you can still define schemas at compile-time.

```elixir
defmodule UserSchema do
  use Exdantic

  schema "Static user schema" do
    field :name, :string, required: true
    field :age, :integer, optional: true, gt: 0
  end
end

# Validation is simple and fast
UserSchema.validate(%{name: "Jane", age: 42})
```

## Error Handling

All validation functions return a consistent `{:ok, value}` or `{:error, [errors]}` tuple. Errors are structured for easy programmatic handling.

```elixir
case Exdantic.EnhancedValidator.validate(target, data) do
  {:ok, validated} ->
    IO.puts("Validation successful!")
    # Use validated data

  {:error, errors} ->
    Enum.each(errors, fn error ->
      # error is %Exdantic.Error{path: [...], code: :..., message: "..."}
      path = Enum.join(error.path, ".")
      IO.puts("Error at [#{path}]: #{error.message} (code: #{error.code})")
    end)
end
```

## Contributing

Contributions are welcome! Please feel free to open an issue or submit a pull request.

1.  Fork the repository.
2.  Create your feature branch (`git checkout -b feature/amazing-feature`).
3.  Commit your changes (`git commit -am 'Add some amazing feature'`).
4.  Push to the branch (`git push origin feature/amazing-feature`).
5.  Open a new Pull Request.

## License

This project is licensed under the MIT License - see the `LICENSE` file for details.
```
