# LLM and DSPy Workflows

Exdantic includes explicit support for structured-output workflows targeting providers like OpenAI and Anthropic, plus DSPy-style validation patterns.

## Building an LLM Output Contract

You can define output contracts with either compile-time or runtime schemas.

Compile-time example:

```elixir
defmodule LLMOutput do
  use Exdantic

  schema "Structured LLM output" do
    field :answer, :string do
      required()
      min_length(1)
    end

    field :confidence, :float do
      required()
      gteq(0.0)
      lteq(1.0)
    end

    field :sources, {:array, :string} do
      optional()
    end

    config do
      strict(true)
    end
  end
end
```

## Validate and Generate Provider Schema in One Flow

Use `Exdantic.EnhancedValidator` for integrated pipelines:

```elixir
{:ok, validated, provider_schema} =
  Exdantic.EnhancedValidator.validate_for_llm(
    LLMOutput,
    %{
      answer: "42",
      confidence: 0.93,
      sources: ["paper-a", "paper-b"]
    },
    :openai
  )
```

## Provider Optimization APIs

Use JSON Schema resolver utilities directly:

```elixir
base = Exdantic.JsonSchema.from_schema(LLMOutput)
openai = Exdantic.JsonSchema.Resolver.enforce_structured_output(base, provider: :openai)
anthropic = Exdantic.JsonSchema.Resolver.enforce_structured_output(base, provider: :anthropic)
```

For higher-level metadata and optimization:

```elixir
enhanced =
  Exdantic.JsonSchema.EnhancedResolver.resolve_enhanced(
    LLMOutput,
    optimize_for_provider: :openai,
    flatten_for_llm: true
  )
```

## DSPy-Oriented Metadata

Field metadata can carry DSPy-style annotations with `extra/2`:

```elixir
field :question, :string do
  extra("__dspy_field_type", "input")
  extra("prefix", "Question:")
end

field :answer, :string do
  extra("__dspy_field_type", "output")
  extra("prefix", "Answer:")
end
```

This metadata is useful when adapting Exdantic schemas into DSPy-style prompt/signature tooling.

## DSPy Optimization API

Use:

```elixir
dspy_schema =
  Exdantic.JsonSchema.EnhancedResolver.optimize_for_dspy(
    LLMOutput,
    signature_mode: true,
    strict_types: true,
    field_descriptions: true
  )
```

Common effects:

- flattening and strictness for predictable output parsing
- additional DSPy metadata flags
- optional computed-field removal for input contracts

## End-to-End Validation Reporting

For deployment checks and diagnostics:

```elixir
report =
  Exdantic.EnhancedValidator.comprehensive_validation_report(
    LLMOutput,
    %{answer: "x", confidence: 0.8},
    test_providers: [:openai, :anthropic],
    include_performance_analysis: true,
    include_dspy_analysis: true
  )
```

Report includes validation result, generated schema, provider compatibility, performance metrics, and recommendations.

## Runtime Contracts for Multi-Stage LLM Pipelines

When stage outputs change dynamically, use runtime schemas:

```elixir
stage_schema = Exdantic.Runtime.create_schema(fields, strict: true)
{:ok, validated} = Exdantic.Runtime.validate(stage_output, stage_schema)
```

Or use enhanced runtime schemas for staged transforms and computed enrichment.

## Recommended Production Pattern

1. Define strict schema contracts (`strict(true)` or strict runtime config)
2. Validate raw model output before business logic
3. Generate provider-specific schema in CI checks
4. Keep provider optimization deterministic and versioned
5. Use comprehensive reports to monitor contract drift

## Next Guides

- `guides/08_configuration_and_settings.md`
- `guides/09_errors_reports_and_operations.md`
