<p align="center">
  <img src="assets/exdantic.svg" width="200" height="200" alt="Exdantic logo" />
</p>

# Exdantic

Exdantic is a schema definition, validation, and JSON Schema toolkit for Elixir.
It combines compile-time schema modules with runtime schema generation, typed value adapters,
provider-oriented JSON Schema tooling, and environment-driven settings loading.

This project is directly based on [Elixact](https://github.com/LiboShen/elixact) by LiboShen.

[![CI](https://github.com/nshkrdotcom/exdantic/actions/workflows/ci.yml/badge.svg)](https://github.com/nshkrdotcom/exdantic/actions/workflows/ci.yml)
[![Hex.pm](https://img.shields.io/hexpm/v/exdantic.svg)](https://hex.pm/packages/exdantic)
[![Hex Docs](https://img.shields.io/badge/hex-docs-lightgreen.svg)](https://hexdocs.pm/exdantic/)

## Why Exdantic

Exdantic gives you one coherent stack for structured data workflows in Elixir:

- Declarative schema DSL (`use Exdantic`) with rich field constraints
- Optional struct output with `define_struct: true`
- Model validators for cross-field logic and transformations
- Computed fields with type-checked derived values
- Runtime schema generation for dynamic workflows
- Type-only validation (`Exdantic.TypeAdapter`) for schemaless paths
- JSON Schema generation, reference resolution, and LLM-provider shaping
- Environment-to-schema settings loading (`Exdantic.Settings`)

## Installation

Add Exdantic to your dependencies:

```elixir
def deps do
  [
    {:exdantic, "~> 0.1.0"}
  ]
end
```

Then run:

```bash
mix deps.get
```

## Quick Start

### 1. Define a schema

```elixir
defmodule UserSchema do
  use Exdantic, define_struct: true

  schema "User account payload" do
    field :name, :string do
      required()
      min_length(2)
      max_length(120)
    end

    field :email, :string do
      required()
      format(~r/^[^\s@]+@[^\s@]+\.[^\s@]+$/)
    end

    field :age, :integer do
      optional()
      gteq(0)
      lteq(150)
    end

    model_validator :normalize_name

    computed_field :email_domain, :string, :compute_email_domain,
      description: "Domain part of the email"

    config do
      title("User")
      strict(true)
    end
  end

  def normalize_name(input) do
    {:ok, %{input | name: String.trim(input.name)}}
  end

  def compute_email_domain(input) do
    {:ok, input.email |> String.split("@") |> List.last()}
  end
end
```

### 2. Validate and use the result

```elixir
{:ok, user} =
  UserSchema.validate(%{
    name: "  Jane Doe  ",
    email: "jane@company.com",
    age: 32
  })

user.name
# "Jane Doe"

user.email_domain
# "company.com"

{:ok, as_map} = UserSchema.dump(user)
```

### 3. Generate JSON Schema

```elixir
schema = UserSchema.json_schema()
```

## Runtime and Dynamic Workflows

Exdantic also supports schema creation at runtime:

```elixir
fields = [
  {:answer, :string, [required: true, min_length: 1]},
  {:confidence, :float, [required: true, gteq: 0.0, lteq: 1.0]},
  {:sources, {:array, :string}, [optional: true]}
]

runtime_schema = Exdantic.Runtime.create_schema(fields,
  title: "LLM Output",
  strict: true
)

{:ok, validated} = Exdantic.Runtime.validate(%{
  answer: "42",
  confidence: 0.91
}, runtime_schema)
```

For full runtime pipelines with model validators and computed fields, use
`Exdantic.Runtime.create_enhanced_schema/2` and `Exdantic.Runtime.validate_enhanced/3`.

## TypeAdapter, Wrapper, and RootSchema

For one-off or schemaless validation:

```elixir
{:ok, 123} = Exdantic.TypeAdapter.validate(:integer, "123", coerce: true)
```

For single-field wrapper validation:

```elixir
{:ok, score} =
  Exdantic.Wrapper.wrap_and_validate(
    :score,
    :integer,
    "98",
    coerce: true,
    constraints: [gteq: 0, lteq: 100]
  )
```

For non-map root payloads (RootModel-style):

```elixir
defmodule IntList do
  use Exdantic.RootSchema, root: {:array, :integer}
end

{:ok, [1, 2, 3]} = IntList.validate([1, 2, 3])
```

## JSON Schema, LLM, and DSPy Tooling

Exdantic includes advanced schema resolution and provider shaping:

- `Exdantic.JsonSchema.from_schema/1`
- `Exdantic.JsonSchema.Resolver.resolve_references/2`
- `Exdantic.JsonSchema.Resolver.enforce_structured_output/2`
- `Exdantic.JsonSchema.EnhancedResolver.resolve_enhanced/2`
- `Exdantic.JsonSchema.EnhancedResolver.optimize_for_dspy/2`

You can validate and generate provider-oriented schemas in one pass via:

- `Exdantic.EnhancedValidator.validate_with_schema/3`
- `Exdantic.EnhancedValidator.validate_for_llm/4`
- `Exdantic.EnhancedValidator.comprehensive_validation_report/3`

## Environment-Driven Settings

`Exdantic.Settings` loads env values into schema-shaped input, then delegates to
normal validation:

```elixir
{:ok, settings} =
  Exdantic.Settings.from_system_env(MySettingsSchema,
    env_prefix: "APP_",
    env_nested_delimiter: "__",
    ignore_empty: true
  )
```

## Documentation Map

The full guide set lives under `guides/` and is published in HexDocs:

- `guides/01_overview_and_quickstart.md`
- `guides/02_schema_dsl_and_types.md`
- `guides/03_structs_model_validators_computed_fields.md`
- `guides/04_runtime_schemas.md`
- `guides/05_type_adapter_wrapper_root_schema.md`
- `guides/06_json_schema_and_resolvers.md`
- `guides/07_llm_and_dspy_workflows.md`
- `guides/08_configuration_and_settings.md`
- `guides/09_errors_reports_and_operations.md`

## Examples

The `examples/` directory contains end-to-end scripts for all major capabilities,
including runtime schemas, TypeAdapter, Wrapper, computed fields, model validators,
and LLM-oriented schema flows.

Run examples with:

```bash
mix run examples/basic_usage.exs
mix run examples/model_validators.exs
mix run examples/llm_integration.exs
```

## License

Released under the MIT License. See `LICENSE`.
