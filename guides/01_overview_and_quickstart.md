# Overview and Quickstart

This guide introduces Exdantic's architecture and gives a practical path from first schema to advanced workflows.

## What Exdantic Solves

Exdantic provides a single data-contract stack in Elixir for:

- Schema definition with field constraints
- Structured validation with typed error paths
- Cross-field logic and transformations
- Derived fields
- Runtime schema generation
- JSON Schema export and optimization
- Environment-driven settings loading

## Core Building Blocks

Exdantic has three complementary layers:

1. Compile-time schema modules
- `use Exdantic`
- Best for stable contracts and shared domain models
- Supports model validators, computed fields, and optional struct output

2. Runtime schemas
- `Exdantic.Runtime.create_schema/2`
- Best for dynamic field sets discovered at runtime
- Supports both basic (`DynamicSchema`) and enhanced (`EnhancedSchema`) pipelines

3. Type-centric validation
- `Exdantic.TypeAdapter`
- Best when you need to validate values without defining full schema modules

## First Schema

```elixir
defmodule AccountSchema do
  use Exdantic, define_struct: true

  schema "Account payload" do
    field :name, :string do
      required()
      min_length(2)
      max_length(80)
    end

    field :email, :string do
      required()
      format(~r/^[^\s@]+@[^\s@]+\.[^\s@]+$/)
    end

    field :active, :boolean do
      default(true)
    end

    config do
      title("Account")
      strict(true)
    end
  end
end
```

Validate data:

```elixir
{:ok, account} = AccountSchema.validate(%{
  name: "Jane",
  email: "jane@example.com"
})

# account is %AccountSchema{} because define_struct: true
```

Raise on failure:

```elixir
account = AccountSchema.validate!(%{name: "Jane", email: "jane@example.com"})
```

Serialize struct back to map:

```elixir
{:ok, payload} = AccountSchema.dump(account)
```

## Error Model

Validation errors use `Exdantic.Error`:

- `path`: nested location of the failure
- `code`: machine-friendly error code
- `message`: readable description

For `validate!/1`, Exdantic raises `Exdantic.ValidationError` containing all errors.

## Runtime Quickstart

```elixir
fields = [
  {:answer, :string, [required: true]},
  {:confidence, :float, [required: true, gteq: 0.0, lteq: 1.0]}
]

schema = Exdantic.Runtime.create_schema(fields, title: "LLM Result", strict: true)

{:ok, result} = Exdantic.Runtime.validate(%{answer: "42", confidence: 0.95}, schema)
```

## TypeAdapter Quickstart

```elixir
{:ok, 42} = Exdantic.TypeAdapter.validate(:integer, "42", coerce: true)
{:ok, ["a", "b"]} = Exdantic.TypeAdapter.validate({:array, :string}, ["a", "b"])
```

## JSON Schema Quickstart

Compile-time schema:

```elixir
schema = AccountSchema.json_schema()
```

Type spec:

```elixir
schema = Exdantic.TypeAdapter.json_schema({:array, :integer})
```

Resolve references or enforce provider requirements:

```elixir
resolved = Exdantic.JsonSchema.Resolver.resolve_references(schema)
openai = Exdantic.JsonSchema.Resolver.enforce_structured_output(schema, provider: :openai)
```

## Choosing the Right API

Use compile-time schema modules when:

- Contract is stable and shared across codebase
- You need full DSL expressiveness
- You want struct output and introspection

Use runtime schemas when:

- Fields are discovered at runtime
- You need programmatic schema assembly
- You still want map-based validation + JSON Schema generation

Use `TypeAdapter` when:

- You validate isolated values or fragments
- You want minimal surface area and low ceremony

## Next Guides

- `guides/02_schema_dsl_and_types.md`: field DSL, constraints, and type system
- `guides/03_structs_model_validators_computed_fields.md`: full validation pipeline behavior
- `guides/04_runtime_schemas.md`: dynamic schema creation and enhanced runtime pipeline
