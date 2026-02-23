# Schema DSL and Types

This guide covers compile-time schema definition with `Exdantic.Schema` and the complete type system used by validation and JSON Schema generation.

## Declaring Schemas

A schema module starts with:

```elixir
defmodule UserSchema do
  use Exdantic

  schema "User payload" do
    # fields here
  end
end
```

`schema/2` accepts an optional description string and a `do` block with fields and configuration.

## Field Declaration

Use `field/2` or `field/3`:

```elixir
field :name, :string

field :age, :integer do
  optional()
  gteq(0)
  lteq(150)
end
```

You can also pass options directly:

```elixir
field :title, :string, required: true
field :active, :boolean, default: true
field :meta, :string, extra: %{"source" => "api"}
```

## Field Metadata Macros

Inside a `field` block:

- `required()`
- `optional()`
- `default(value)`
- `description(text)`
- `example(value)`
- `examples(list)`
- `extra(key, value)`

`default/1` also marks the field optional.

## Constraint Macros

Supported constraints in the schema DSL:

- String length: `min_length/1`, `max_length/1`
- Array length: `min_items/1`, `max_items/1`
- Numeric bounds: `gt/1`, `lt/1`, `gteq/1`, `lteq/1`
- Regex pattern: `format/1`
- Enumerated values: `choices/1`

Example:

```elixir
field :status, :string do
  choices(["pending", "approved", "rejected"])
end
```

## Built-in Types

Built-in primitive types:

- `:string`
- `:integer`
- `:float`
- `:boolean`
- `:atom`
- `:map`
- `:any`

## Composite Types

Array:

```elixir
field :tags, {:array, :string}
```

Map:

```elixir
field :scores, {:map, {:string, :integer}}
```

Object (typed fixed-key map):

```elixir
field :profile,
  {:object,
   %{
     first_name: :string,
     last_name: :string
   }}
```

Union:

```elixir
field :id, {:union, [:string, :integer]}
```

Tuple:

```elixir
field :coordinates, {:tuple, [:float, :float]}
```

Schema reference:

```elixir
field :address, AddressSchema
```

Literal atom matching is also supported by the validator path when used as a type atom.

## Programmatic Types with `Exdantic.Types`

`Exdantic.Types` provides constructors for runtime composition:

```elixir
alias Exdantic.Types

name_type =
  Types.string()
  |> Types.with_constraints(min_length: 2, max_length: 80)

email_type =
  Types.string()
  |> Types.with_constraints(format: ~r/@/)
  |> Types.with_error_message(:format, "must be a valid email")
```

Key helpers:

- `Types.string/0`, `Types.integer/0`, `Types.float/0`, `Types.boolean/0`
- `Types.type/1` generic constructor (e.g., `Types.type(:string)`)
- `Types.array/1`, `Types.map/2`, `Types.object/1`, `Types.union/1`, `Types.tuple/1`
- `Types.ref/1`, `Types.normalize_type/1`
- `Types.with_constraints/2`
- `Types.with_error_message/3`, `Types.with_error_messages/2`
- `Types.with_validator/2` for custom value-level checks
- `Types.validate/2` for direct type checking (e.g., `Types.validate(:string, value)`)
- `Types.coerce/2` for standalone type coercion (e.g., `Types.coerce(:integer, "123")`)

## Custom Type Modules with `Exdantic.Type`

Define reusable custom types by implementing `Exdantic.Type` behavior:

```elixir
defmodule MyApp.Types.Email do
  use Exdantic.Type

  def type_definition do
    {:type, :string, [format: ~r/^[^@]+@[^@]+\.[^@]+$/]}
  end

  def json_schema do
    %{"type" => "string", "format" => "email"}
  end

  def validate(value) do
    case Exdantic.Validator.validate(type_definition(), value, []) do
      {:ok, v} -> {:ok, v}
      {:error, _} -> {:error, "invalid email"}
    end
  end
end
```

Optional callbacks:

- `coerce_rule/0` — returns a coercion function or `{module, function}` tuple (default `nil`)
- `custom_rules/0` — returns a list of additional validation function names defined in the module (default `[]`)

Then use it as a field type:

```elixir
field :email, MyApp.Types.Email
```

## Schema Config Block

Configure schema-level behavior:

```elixir
config do
  title("User")
  config_description("Validates user payloads")
  strict(true)
end
```

- `strict(true)` forbids unknown input fields
- `title` and `config_description` propagate to JSON Schema metadata

## Validation Semantics to Know

- Both atom and string keys are accepted for input maps.
- Missing required fields emit `:required` errors.
- Unknown fields in strict mode emit `:additional_properties` errors.
- Constraints are enforced after base type checks.
- Custom validator constraints return `{:ok, value}` or `{:error, message}`.

## Next Guides

- `guides/03_structs_model_validators_computed_fields.md`
- `guides/04_runtime_schemas.md`
