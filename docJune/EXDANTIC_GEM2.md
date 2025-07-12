# Exdantic: Core Schema API

This document details the fundamental API for defining schemas and validating data with Exdantic.

## 1. Defining a Schema

Schemas are defined inside any Elixir module by using `use Exdantic.Schema` and the `defschema` macro.

```elixir
defmodule UserProfile do
  use Exdantic.Schema

  defschema do
    # Field definitions go here
  end
end
```

### `field/3` Macro

The `field` macro is used inside a `defschema` block to define a data field.

**Signature**: `field(name, type, options \\ [])`

*   `name`: An atom representing the field's name (e.g., `:username`).
*   `type`: The field's type. Can be a basic type atom, a complex type tuple, or a module for custom types.
*   `options`: A keyword list of constraints and metadata.

#### Basic Types

*   `:string`
*   `:integer`
*   `:float`
*   `:boolean`
*   `:atom`
*   `:map`
*   `:list`
*   `:any`

#### Complex Types

*   `{:array, type}`: A list where every element must match the inner `type`.
*   `{:map, {key_type, value_type}}`: A map where all keys and values must match the specified types.
*   `{:union, [type1, type2, ...]}`: A value that can be one of several types.

#### Options

*   `required: true`: The field must be present. This is the default.
*   `optional: true`: The field may be omitted.
*   `default: value`: Provides a default value if the field is omitted. Implies `optional: true`.
*   `description: "..."`: A human-readable description, used for documentation and JSON Schema generation.

### Example

```elixir
defmodule UserProfile do
  use Exdantic.Schema

  defschema do
    field :id, :integer, required: true
    field :username, :string, required: true, description: "Must be unique."
    field :age, :integer, optional: true
    field :role, :atom, default: :user, description: "User role, e.g., :user or :admin."
    field :tags, {:array, :string}, default: [], description: "A list of user tags."
  end
end
```

## 2. Validating Data

The primary way to use a schema is to validate data against it.

### `Exdantic.validate/2`

Validates a map against a schema.

**Signature**: `validate(schema_module, data_map)`

**Returns**:
*   `{:ok, validated_data}`: If validation is successful. `validated_data` is a map with all defaults applied.
*   `{:error, [errors]}`: If validation fails. Returns a list of `Exdantic.Error` structs.

```elixir
data = %{id: 1, username: "alice"}

case Exdantic.validate(UserProfile, data) do
  {:ok, validated_user} ->
    # validated_user is %{id: 1, username: "alice", role: :user, tags: []}
    IO.inspect(validated_user)

  {:error, errors} ->
    # errors is a list of Exdantic.Error structs
    IO.inspect(errors)
end
```

### `Exdantic.validate!/2`

Same as `validate/2`, but raises an `Exdantic.ValidationError` on failure.

```elixir
data = %{id: 1} # Missing required :username field
# This will raise Exdantic.ValidationError
validated_user = Exdantic.validate!(UserProfile, data)
```
