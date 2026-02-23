# Errors, Reports, and Operations

This guide covers error handling contracts, validation reports, and practical operating patterns.

## Error Types

## `Exdantic.Error`

Every validation failure is represented as:

- `path` (`[atom() | String.t() | integer()]`)
- `code` (`atom()`)
- `message` (`String.t()`)

Create errors:

```elixir
error = Exdantic.Error.new([:user, :email], :format, "invalid email")
```

Format errors:

```elixir
Exdantic.Error.format(error)
# "user.email: invalid email"
```

## `Exdantic.ValidationError`

`validate!/1` style APIs raise `Exdantic.ValidationError` containing the collected `errors` list.

## Common Error Codes

Codes vary by operation, but common categories include:

- `:required`
- `:type`
- `:additional_properties`
- constraint codes like `:min_length`, `:gteq`, `:choices`
- `:model_validation`
- `:computed_field`
- `:computed_field_type`
- env-related settings codes like `:env_cast`, `:env_json`, `:env_key_conflict`

## Validation Entry Points

Compile-time schema:

- `MySchema.validate/1`
- `MySchema.validate!/1`
- `MySchema.validate_enhanced/2`

Runtime:

- `Exdantic.Runtime.validate/3`
- `Exdantic.Runtime.validate_enhanced/3`
- `Exdantic.Runtime.Validator.validate/3`

Universal:

- `Exdantic.EnhancedValidator.validate/3`

Type-only:

- `Exdantic.TypeAdapter.validate/3`

## Reporting APIs

### Quick report

```elixir
report = Exdantic.EnhancedValidator.validation_report(target, input)
```

Returns a lightweight summary: validation result, generated JSON Schema, target and input analysis, timing metrics, and config summary.

### Comprehensive report

```elixir
report =
  Exdantic.EnhancedValidator.comprehensive_validation_report(
    target,
    input,
    test_providers: [:openai, :anthropic],
    include_performance_analysis: true,
    include_dspy_analysis: true
  )
```

Adds provider compatibility, complexity metrics, and recommendations.

## Schema Introspection in Production

Compile-time schema helpers:

- `__schema_info__/0`
- `__enhanced_schema_info__/0`

Useful for diagnostics and contract inventory at runtime.

## Operational Patterns

## 1. Strict contracts at boundaries

At API or queue boundaries, prefer strict mode to catch unknown keys early.

## 2. Coercion strategy by trust level

- trusted/internal paths: can use `:safe` coercion
- external/untrusted paths: prefer strict, explicit typing

## 3. Separate input/output schemas when needed

If computed fields should not be accepted from input, generate output schema normally but derive input schemas with computed fields removed:

```elixir
output_schema = Exdantic.JsonSchema.from_schema(MySchema)
input_schema = Exdantic.JsonSchema.remove_computed_fields(output_schema)
```

## 4. Validate provider compatibility in CI

Use enhanced resolver compatibility checks before shipping schema changes:

```elixir
:ok = Exdantic.JsonSchema.EnhancedResolver.validate_schema_compatibility(MySchema)
```

## 5. Keep examples executable

Run example scripts as contract tests for documentation and onboarding quality.

## Testing Suggestions

- Unit-test custom validators and computed field functions directly
- Add integration tests for full schema pipelines (`validate` + `json_schema`)
- Include strict-mode tests for unknown key handling
- For settings schemas, test env decoding and nested exploded env paths
- For LLM contracts, test provider-shaped schema snapshots

## Documentation and Maintenance Workflow

When adding a new schema capability:

1. Add/adjust tests in `test/`
2. Update affected guide(s)
3. Update README entry points if API visibility changes
4. Validate docs build (`mix docs`) and examples as needed

## Final Note

Exdantic's strength is consistency across compile-time, runtime, and type-only validation.
Treat schemas as first-class contracts, and use the reporting and resolver tools to keep those contracts stable under change.
