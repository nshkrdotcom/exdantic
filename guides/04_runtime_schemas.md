# Runtime Schemas

Exdantic runtime schemas let you build validation contracts dynamically from data or configuration.

## Runtime Schema Types

Exdantic runtime layer includes:

- `Exdantic.Runtime.DynamicSchema` for field-level runtime schemas
- `Exdantic.Runtime.EnhancedSchema` for runtime model validators and computed fields
- `Exdantic.Runtime.Validator` as a unified interface for both

## Create a Dynamic Schema

```elixir
fields = [
  {:name, :string, [required: true, min_length: 2]},
  {:age, :integer, [optional: true, gteq: 0]},
  {:tags, {:array, :string}, [optional: true, min_items: 1]}
]

schema = Exdantic.Runtime.create_schema(fields,
  name: "UserRuntime",
  title: "Runtime User",
  description: "Generated at runtime",
  strict: true
)
```

Validate:

```elixir
{:ok, validated} = Exdantic.Runtime.validate(%{name: "Jane", age: 31}, schema)
```

Generate JSON Schema:

```elixir
json = Exdantic.Runtime.to_json_schema(schema)
```

## Dynamic Field Definition Format

Accepted tuples:

- `{field_name, type}`
- `{field_name, type, opts}`

Common field opts:

- `required`, `optional`, `default`
- `description`, `example`, `examples`
- standard constraints (`min_length`, `gteq`, etc.)

## DynamicSchema Utility APIs

`Exdantic.Runtime.DynamicSchema` includes helpers:

- `new/4`
- `get_field/2`
- `field_names/1`
- `required_fields/1`
- `optional_fields/1`
- `strict?/1`
- `update_config/2`
- `add_field/3`
- `remove_field/2`
- `summary/1`

## Enhanced Runtime Schema

Use `create_enhanced_schema/2` to add runtime model validators and computed fields:

```elixir
schema =
  Exdantic.Runtime.create_enhanced_schema(
    [
      {:name, :string, [required: true]},
      {:email, :string, [required: true]}
    ],
    model_validators: [
      fn data -> {:ok, %{data | name: String.trim(data.name)}} end
    ],
    computed_fields: [
      {:email_domain, :string, fn data -> {:ok, data.email |> String.split("@") |> List.last()} end}
    ],
    strict: true
  )

{:ok, result} = Exdantic.Runtime.validate_enhanced(%{name: " Jane ", email: "jane@x.com"}, schema)
```

Enhanced runtime schemas keep runtime functions in an internal function registry when anonymous functions are used.

## EnhancedSchema Utility APIs

`Exdantic.Runtime.EnhancedSchema` supports:

- `create/2`
- `validate/3`
- `to_json_schema/2`
- `info/1`
- `add_model_validator/2`
- `add_computed_field/4`
- `process_model_validators/1`
- `process_computed_fields/2`

## Unified Runtime Validator

Use `Exdantic.Runtime.Validator` when callers should not care if schema is dynamic or enhanced:

```elixir
{:ok, validated} = Exdantic.Runtime.Validator.validate(input, runtime_schema)
json = Exdantic.Runtime.Validator.to_json_schema(runtime_schema)
info = Exdantic.Runtime.Validator.schema_info(runtime_schema)
```

## Phase 6 Runtime Helpers

Runtime module also includes advanced helpers:

- `create_enhanced_schema_v6/2`
- `validate_enhanced_v6/3`

These can add provider compatibility testing, performance metadata, and JSON Schema checks in one call.

## Error Semantics

Runtime validation returns the same structured error shape as compile-time schemas (`Exdantic.Error`).

Strict mode behaves similarly: unknown keys produce `:additional_properties` errors.

## When Runtime Schemas Are the Right Tool

Choose runtime schemas when:

- Fields are generated from external metadata
- Inputs differ per tenant, pipeline stage, or task
- You need map-based validation contracts without compile-time module generation

Choose compile-time schemas when contracts are stable and shared.

## Next Guides

- `guides/05_type_adapter_wrapper_root_schema.md`
- `guides/06_json_schema_and_resolvers.md`
