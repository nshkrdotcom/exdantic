# Structs, Model Validators, and Computed Fields

This guide explains Exdantic's full compile-time validation pipeline and how struct output, model-level logic, and derived fields interact.

## Pipeline Order

`Exdantic.StructValidator` executes the following steps in order:

1. Field validation
2. Model validators
3. Computed fields
4. Optional struct creation

Each stage can stop the pipeline with structured errors.

## Struct Output (`define_struct: true`)

Enable struct output at module declaration:

```elixir
defmodule UserSchema do
  use Exdantic, define_struct: true

  schema do
    field :name, :string
  end
end
```

`validate/1` now returns `%UserSchema{...}` on success.

Additional generated functions:

- `__struct_enabled__?/0`
- `__struct_fields__/0`
- `__regular_fields__/0`
- `__computed_field_names__/0`
- `dump/1` (struct/map to map)

Without `define_struct: true`, validation returns plain maps.

## Model Validators

Model validators run after all field-level validation passes.

### Named function

```elixir
model_validator :normalize_email

def normalize_email(input) do
  {:ok, %{input | email: String.downcase(input.email)}}
end
```

### Anonymous function

```elixir
model_validator fn input ->
  if input.start_date <= input.end_date do
    {:ok, input}
  else
    {:error, "start_date must be <= end_date"}
  end
end
```

### `do ... end` block style

```elixir
model_validator do
  if String.contains?(input.email, "@") do
    {:ok, input}
  else
    {:error, "invalid email"}
  end
end
```

### Return contract

Model validator functions must return one of:

- `{:ok, updated_data}`
- `{:error, "message"}`
- `{:error, %Exdantic.Error{}}`
- `{:error, [%Exdantic.Error{}, ...]}`

Validators run in declaration order.

## Computed Fields

Computed fields add derived values after model validators complete.

### Named function

```elixir
computed_field :full_name, :string, :compute_full_name

def compute_full_name(input) do
  {:ok, "#{input.first_name} #{input.last_name}"}
end
```

### Anonymous function

```elixir
computed_field :initials, :string, fn input ->
  {:ok, String.first(input.first_name) <> String.first(input.last_name)}
end
```

### Metadata options

Named form supports extra metadata:

```elixir
computed_field :email_domain, :string, :domain,
  description: "Domain extracted from email",
  example: "company.com"
```

### Type checking of computed outputs

Computed values are validated against the declared computed field type.

If a function returns a mismatched value, Exdantic emits computed-field type errors with field path and function context.

## Schema Introspection APIs

All compile-time schemas expose:

- `__schema__(:fields)`
- `__schema__(:computed_fields)`
- `__schema__(:model_validators)`
- `__schema__(:config)`
- `__schema_info__/0`

Enhanced metadata/reporting helpers:

- `__enhanced_schema_info__/0`
- `validate_enhanced/2`

`validate_enhanced/2` can include optional metrics and schema metadata.

## Error Behavior in Pipeline Stages

Field stage errors:

- Required fields missing
- Type mismatches
- Constraint failures

Model stage errors:

- Invalid validator return format
- Explicit validator errors
- Exceptions in validator function

Computed stage errors:

- Missing function
- Execution failure
- Invalid return shape
- Computed value fails declared type

Struct stage errors:

- Invalid data keys for struct creation
- Unexpected fields introduced by transformations

## Practical Pattern

A common production pattern:

1. Field constraints handle local validation
2. Model validators normalize and enforce cross-field invariants
3. Computed fields generate output-ready derived values
4. Struct output gives clear typed result shape for downstream code

## Next Guides

- `guides/04_runtime_schemas.md`
- `guides/05_type_adapter_wrapper_root_schema.md`
