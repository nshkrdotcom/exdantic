# JSON Schema and Resolvers

Exdantic provides multiple JSON Schema layers: direct generation, reference tracking, and post-processing for downstream consumers.

## Schema Generation APIs

Compile-time schema module:

```elixir
schema = Exdantic.JsonSchema.from_schema(MySchema)
```

Runtime dynamic schema:

```elixir
schema = Exdantic.Runtime.to_json_schema(dynamic_schema)
```

Runtime enhanced schema:

```elixir
schema = Exdantic.Runtime.enhanced_to_json_schema(enhanced_schema)
```

Type spec:

```elixir
schema = Exdantic.TypeAdapter.json_schema({:array, :integer})
```

## Type Mapping Behavior

`Exdantic.JsonSchema.TypeMapper` maps Exdantic types to JSON Schema:

- `:string`, `:integer`, `:float`, `:boolean`, `:map`, `:any`, `:atom`
- arrays, maps, unions, tuples
- schema references via `$ref`
- custom types via `json_schema/0`

Constraint mapping examples:

- `min_length` -> `minLength`
- `max_length` -> `maxLength`
- `gt` -> `exclusiveMinimum`
- `lteq` -> `maximum`
- regex `format(~r/...)` -> `pattern`

## References and Definitions

`Exdantic.JsonSchema.ReferenceStore` tracks references and emitted definitions during generation.

Generated schemas may contain `definitions` + `$ref` entries for nested schema modules.

## Computed Fields in JSON Schema

Compile-time computed fields are included as read-only properties.

Tools:

- `Exdantic.JsonSchema.extract_computed_field_info/1`
- `Exdantic.JsonSchema.has_computed_fields?/1`
- `Exdantic.JsonSchema.remove_computed_fields/1`

`remove_computed_fields/1` is useful when producing input-only schemas.

## Reference Resolution and Flattening

`Exdantic.JsonSchema.Resolver` supports:

- `resolve_references/2`: recursively expand `$ref`
- `flatten_schema/2`: flatten for consumers that dislike deep ref graphs
- `optimize_for_llm/2`: remove descriptions/simplify unions/limit properties

Example:

```elixir
resolved = Exdantic.JsonSchema.Resolver.resolve_references(schema, max_depth: 10)
flattened = Exdantic.JsonSchema.Resolver.flatten_schema(schema, max_depth: 5)
```

## Provider-Oriented Structured Output

Use `enforce_structured_output/2`:

```elixir
openai = Exdantic.JsonSchema.Resolver.enforce_structured_output(schema, provider: :openai)
anthropic = Exdantic.JsonSchema.Resolver.enforce_structured_output(schema, provider: :anthropic)
```

Provider rule examples:

- object structure normalization
- `additionalProperties` handling
- unsupported format stripping by provider profile

## Enhanced Resolver

`Exdantic.JsonSchema.EnhancedResolver` unifies schema generation for:

- compile-time schemas
- runtime `DynamicSchema`
- runtime `EnhancedSchema`
- type specifications

Main APIs:

- `resolve_enhanced/2`
- `comprehensive_analysis/3`
- `optimize_for_dspy/2`
- `validate_schema_compatibility/2`

Enhanced schema metadata includes `x-exdantic-enhanced`, schema-type flags, model-validator/computed-field counts, and provider compatibility analysis fields.

## Practical Pipeline

A practical JSON Schema workflow for external systems:

1. Generate schema from source contract
2. Resolve or flatten references if required
3. Enforce provider structured-output rules
4. Optionally optimize for token or reasoning constraints
5. Validate compatibility before deployment

## Next Guides

- `guides/07_llm_and_dspy_workflows.md`
- `guides/09_errors_reports_and_operations.md`
