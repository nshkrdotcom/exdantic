# Configuration and Settings

This guide covers runtime configuration behavior (`Exdantic.Config`) and environment-driven schema loading (`Exdantic.Settings`).

## Exdantic.Config

`Exdantic.Config` centralizes validation and schema-generation behavior.

### Create config

```elixir
config = Exdantic.Config.create(
  strict: true,
  extra: :forbid,
  coercion: :safe,
  error_format: :detailed
)
```

Key fields:

- `strict`: strict validation mode
- `extra`: `:allow | :forbid | :ignore`
- `coercion`: `:none | :safe | :aggressive`
- `frozen`: immutable config guard
- `validate_assignment`
- `case_sensitive`
- `error_format`: `:detailed | :simple | :minimal`
- `use_enum_values`
- `allow_population_by_field_name`: support field name aliases (default `true`)
- `max_anyof_union_len`
- optional generator functions (`title_generator`, `description_generator`)

### Merge configs

```elixir
base = Exdantic.Config.create(strict: true)
next = Exdantic.Config.merge(base, %{coercion: :none})
```

If config is frozen and overrides are non-empty, merge raises.

### Presets

Available presets:

- `:strict`
- `:lenient`
- `:api`
- `:json_schema`
- `:development`
- `:production`

```elixir
api_config = Exdantic.Config.preset(:api)
```

### Convert to option lists

```elixir
validation_opts = Exdantic.Config.to_validation_opts(config)
json_opts = Exdantic.Config.to_json_schema_opts(config)
```

### Enhanced and DSPy configs

```elixir
enhanced = Exdantic.Config.create_enhanced(
  llm_provider: :openai,
  dspy_compatible: true,
  performance_mode: :balanced
)

signature_cfg = Exdantic.Config.for_dspy(:signature, provider: :openai)
```

## Config Builder API

`Exdantic.Config.Builder` provides fluent config composition.

```elixir
config =
  Exdantic.Config.builder()
  |> Exdantic.Config.Builder.strict(true)
  |> Exdantic.Config.Builder.forbid_extra()
  |> Exdantic.Config.Builder.safe_coercion()
  |> Exdantic.Config.Builder.detailed_errors()
  |> Exdantic.Config.Builder.build()
```

Builder includes conditional helpers (`when_true/3`, `when_false/3`) and scenario helpers (`for_api/1`, `for_production/1`, etc.).

## Using Config with EnhancedValidator

```elixir
config = Exdantic.Config.create(strict: true, coercion: :safe)

{:ok, validated} =
  Exdantic.EnhancedValidator.validate(
    MySchema,
    input,
    config: config
  )
```

## Environment-Driven Settings (`Exdantic.Settings`)

`Exdantic.Settings` loads env values, merges optional explicit input, normalizes keys, then validates through standard Exdantic pipeline.

### Basic usage

```elixir
{:ok, settings} =
  Exdantic.Settings.from_system_env(MySettingsSchema,
    env_prefix: "APP_",
    env_nested_delimiter: "__"
  )
```

### Explicit env map + input override

```elixir
{:ok, settings} =
  Exdantic.Settings.load(MySettingsSchema,
    env: %{"APP_HOST" => "localhost", "APP_PORT" => "4000"},
    input: %{port: 4001}
  )
```

### Supported settings options

- `input: map()`
- `env: map()`
- `env_prefix: String.t()`
- `env_nested_delimiter: String.t()` (default `"__"`)
- `case_sensitive: boolean()`
- `ignore_empty: boolean()`
- `allow_atoms: false | :existing`
- `bool_numeric: boolean()`

## Field-Level Env Override

A field can declare an absolute env key that bypasses prefix derivation:

```elixir
schema do
  field :db_url, :string, required: true, extra: %{"env" => "DATABASE_URL"}
end
```

When both the override key and the derived key exist in the environment, the override wins. The prefix is **not** applied to the override key.

## Env Decoding Behavior

Scalar types are decoded from their string env representation:

- `:string` — passed through as-is
- `:integer` — parsed with `Integer.parse/1`; must consume entire string
- `:float` — parsed with `Float.parse/1`; must consume entire string
- `:boolean` — accepts `"true"` / `"false"` (case-insensitive); when `bool_numeric: true` (default), also accepts `"1"` / `"0"`
- `:atom` — disabled by default; set `allow_atoms: :existing` to allow `String.to_existing_atom/1`
- `:any` — passed through as-is

Structured types (`{:array, _}`, `{:map, _, _}`, `{:object, _}`, schema module refs) must be provided as JSON strings:

```elixir
# env: %{"TAGS" => "[1,2,3]"}
# decodes to [1, 2, 3]
```

Invalid JSON returns an `:env_json` error. Invalid scalar parsing returns an `:env_cast` error.

Union decoding is conservative:

- If the union contains structured members and the value starts with `{` or `[`, JSON decoding is attempted.
- Otherwise the raw string is passed to the validator to resolve the union.

## Nested Exploded Env Keys

For nested schemas, the loader supports exploded env keys where the delimiter separates parent and child field names:

```elixir
# Schema: NestedSettings with a `database` field of type DatabaseSchema
# DatabaseSchema has `host` and `pool_size` fields

env = %{
  "APP_DATABASE__HOST" => "localhost",
  "APP_DATABASE__POOL_SIZE" => "10"
}

{:ok, settings} = Settings.load(NestedSettings,
  env: env,
  env_prefix: "APP_",
  env_nested_delimiter: "__"
)
# settings.database.host == "localhost"
# settings.database.pool_size == 10
```

When both a top-level JSON value and exploded keys exist for the same field, the exploded values are deep-merged over the JSON-decoded map, with exploded keys taking precedence:

```elixir
env = %{
  "APP_DATABASE" => ~s({"host":"a","pool_size":5}),
  "APP_DATABASE__POOL_SIZE" => "10"
}
# Result: host == "a", pool_size == 10
```

### Prefix-Based Matching for Underscore Fields

When using `"_"` as the nested delimiter, field names containing underscores (e.g., `pool_size`) create ambiguity. The loader resolves this with a prefix-based matching strategy that sorts fields by name length (longest first), ensuring `POOL_SIZE` matches the `pool_size` field before `POOL` could match a hypothetical `pool` field.

### Limitations

Exploded addressing into arrays is not supported in v1. For example, `APP_ITEMS__0` will not set the first element of an `items` array field. Arrays must be provided as JSON strings.

## Key Normalization and Merge Semantics

Settings loader performs:

1. Env normalization (`case_sensitive` rules + collision checks)
2. Field candidate key lookup (override key first, then derived key)
3. Decode + exploded nested decode merge
4. Deep merge of env values with `input` (`input` wins)
5. Key normalization by schema field definitions
6. Final validation through `Exdantic.StructValidator`

Case-insensitive mode (default) uppercases all env keys and detects collisions. If two env keys normalize to the same uppercase key (e.g., `app_port` and `APP_PORT`), an `:env_key_conflict` error is returned.

## When to Use Settings Loader

Use `Exdantic.Settings` when:

- You want schema-validated application configuration
- You need explicit typing/coercion over env values
- You need nested config with controlled delimiter and prefixing

## Next Guide

- `guides/09_errors_reports_and_operations.md`
