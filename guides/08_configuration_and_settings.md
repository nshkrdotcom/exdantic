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
- `use_enum_values`
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

## Env Decoding Behavior

- Scalar env values are decoded by expected type (`integer`, `float`, `boolean`, etc.)
- Structured types (`array`, maps, objects, refs) use JSON decoding for top-level values
- Union decoding is conservative for structured union members
- Field override via `extra: %{"env" => "CUSTOM_KEY"}` is supported
- Nested exploded env keys are supported for nested maps/objects (arrays are intentionally limited)

## Key Normalization and Merge Semantics

Settings loader performs:

1. Env normalization (`case_sensitive` rules + collision checks)
2. Field candidate key lookup
3. Decode + exploded nested decode merge
4. Deep merge of env values with `input` (`input` wins)
5. Key normalization by schema field definitions
6. Final validation through `Exdantic.StructValidator`

## When to Use Settings Loader

Use `Exdantic.Settings` when:

- You want schema-validated application configuration
- You need explicit typing/coercion over env values
- You need nested config with controlled delimiter and prefixing

## Next Guide

- `guides/09_errors_reports_and_operations.md`
