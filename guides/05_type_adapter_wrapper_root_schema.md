# TypeAdapter, Wrapper, and RootSchema

This guide covers value-level validation APIs for cases where a full schema module is unnecessary or inconvenient.

## TypeAdapter

`Exdantic.TypeAdapter` validates and serializes values against type specs directly.

### Validate

```elixir
{:ok, 123} = Exdantic.TypeAdapter.validate(:integer, "123", coerce: true)
{:ok, ["a", "b"]} = Exdantic.TypeAdapter.validate({:array, :string}, ["a", "b"])
```

Options:

- `coerce: boolean` (default `false`)
- `strict: boolean`
- `path: [...]` for error context

### Dump (serialize)

```elixir
{:ok, serialized} = Exdantic.TypeAdapter.dump({:map, {:string, :any}}, %{name: "Jane"})
```

Options:

- `exclude_none: boolean`
- `exclude_defaults: boolean`

### JSON Schema from type spec

```elixir
schema = Exdantic.TypeAdapter.json_schema({:union, [:string, :integer]})
```

Options include `title`, `description`, `resolve_refs`.

### Reusable adapter instance

Use `Exdantic.TypeAdapter.Instance` for repeated validation:

```elixir
adapter = Exdantic.TypeAdapter.create({:array, :integer}, coerce: true)

{:ok, values} = Exdantic.TypeAdapter.Instance.validate_many(adapter, [[1, 2], ["3", "4"]])
```

Instance API includes:

- `new/2`, `validate/3`, `dump/3`, `json_schema/2`
- `validate_many/3`, `dump_many/3`
- `update_config/2`, `info/1`

## Wrapper

`Exdantic.Wrapper` creates temporary single-field runtime schemas.

This is useful for coercion-heavy single-value flows while preserving schema semantics.

### One-shot wrapper validation

```elixir
{:ok, score} =
  Exdantic.Wrapper.wrap_and_validate(
    :score,
    :integer,
    "85",
    coerce: true,
    constraints: [gteq: 0, lteq: 100]
  )
```

### Explicit wrapper schema

```elixir
wrapper = Exdantic.Wrapper.create_wrapper(:email, :string, constraints: [format: ~r/@/])
{:ok, email} = Exdantic.Wrapper.validate_and_extract(wrapper, %{email: "jane@x.com"}, :email)
```

### Batch wrappers

```elixir
wrappers = Exdantic.Wrapper.create_multiple_wrappers([
  {:name, :string, [constraints: [min_length: 1]]},
  {:age, :integer, [constraints: [gt: 0]]}
])

{:ok, result} = Exdantic.Wrapper.validate_multiple(wrappers, %{name: "Jane", age: 30})
```

### Flexible input handling

`create_flexible_wrapper/3` + `validate_flexible/3` accepts:

- raw value
- map with atom key
- map with string key

### Reusable wrapper factory

`create_wrapper_factory/2` returns a function that creates pre-configured wrappers:

```elixir
factory = Exdantic.Wrapper.create_wrapper_factory(:integer, constraints: [gt: 0], coerce: true)
wrapper = factory.(:score)
```

Wrapper helpers:

- `create_wrapper_factory/2`
- `to_json_schema/2`
- `unwrap_result/2`
- `wrapper_schema?/1`
- `wrapper_info/1`

## RootSchema

`Exdantic.RootSchema` validates non-map payloads at the root level.

### Define root schema

```elixir
defmodule IntegerList do
  use Exdantic.RootSchema, root: {:array, :integer}
end
```

### Validate root value

```elixir
{:ok, list} = IntegerList.validate([1, 2, 3])
list = IntegerList.validate!([1, 2, 3])
```

### JSON Schema for root payload

```elixir
schema = IntegerList.json_schema()
```

This is useful for list-based or primitive structured outputs from upstream systems.

## Choosing Between These APIs

Use `TypeAdapter` when:

- you need type-only validation/dumping
- you want minimal ceremony and fast one-off checks

Use `Wrapper` when:

- you need single-field schema semantics (constraints + metadata + coercion)
- you need reusable single-field wrapper patterns

Use `RootSchema` when:

- your canonical payload is not a map/object
- you still want module-level reuse and schema introspection

## Next Guides

- `guides/06_json_schema_and_resolvers.md`
- `guides/07_llm_and_dspy_workflows.md`
