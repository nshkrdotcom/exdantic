# Exdantic Examples

This directory contains runnable examples for the full Exdantic surface area: core validation, runtime schema generation, model-level logic, and LLM/DSPy integration workflows.

## Prerequisites

1. Run commands from the repository root.
2. Install dependencies once:
   ```bash
   mix deps.get
   ```
3. Optional (faster repeated runs):
   ```bash
   mix compile
   ```

## Running Examples

Run a single example:

```bash
# Mix-based example
mix run examples/basic_usage.exs

# Standalone example that uses Mix.install
elixir examples/runtime_schema.exs
```

Execution rule:

- If a script contains `Mix.install(...)`, run it with `elixir`.
- Otherwise, run it with `mix run`.

Run everything:

```bash
bash examples/run_all.sh
```

Useful flags:

```bash
# Run only examples whose filename contains "llm"
bash examples/run_all.sh --match llm

# Stop immediately on first failure
bash examples/run_all.sh --fail-fast
```

## Complete Example Catalog

| Script | Focus | Runner |
|---|---|---|
| `advanced_config.exs` | Configuration presets, merging, builder pattern, and validation behavior tuning | `elixir` |
| `advanced_features.exs` | Advanced type modeling, nested object validation, and integration-style patterns | `mix run` |
| `basic_usage.exs` | Core Exdantic concepts: primitive/complex types, constraints, and errors | `mix run` |
| `computed_fields.exs` | Computed fields with dependencies, transformations, and JSON Schema behavior | `mix run` |
| `conditional_recursive_validation.exs` | Conditional logic, recursive schemas, dynamic schema selection, and validation pipelines | `mix run` |
| `custom_validation.exs` | Custom validator functions for business rules and value transformation | `mix run` |
| `dspy_integration.exs` | End-to-end DSPy-style patterns (runtime models, wrappers, retries, provider schema handling) | `elixir` |
| `enhanced_validator.exs` | Universal validation interface across compiled schemas, runtime schemas, and type specs | `elixir` |
| `field_metadata_dspy.exs` | Field metadata annotations and DSPy-style input/output field processing | `mix run` |
| `json_schema_resolver.exs` | `$ref` resolution, flattening, and provider-oriented schema optimization | `elixir` |
| `llm_integration.exs` | Structured LLM output validation, signatures, quality checks, and dynamic schema selection | `mix run` |
| `llm_pipeline_orchestration.exs` | Multi-stage LLM validation pipeline design, error handling, and quality assessment | `mix run` |
| `model_validators.exs` | Cross-field and model-level validation with complex domain rules | `mix run` |
| `readme_examples.exs` | Verifies README snippets by executing them as a consistency check | `mix run` |
| `root_schema.exs` | Root-level validation for non-map data (arrays, unions, primitives) | `mix run` |
| `runtime_schema.exs` | Dynamic schema creation and validation at runtime | `elixir` |
| `type_adapter.exs` | TypeAdapter-based runtime validation, coercion, dumping, and batch use | `elixir` |
| `wrapper_models.exs` | Wrapper model patterns for single-field validation and reuse | `elixir` |

## Suggested Learning Order

1. `basic_usage.exs`
2. `advanced_features.exs`
3. `custom_validation.exs`
4. `model_validators.exs`
5. `computed_fields.exs`
6. `runtime_schema.exs`
7. `type_adapter.exs`
8. `wrapper_models.exs`
9. `root_schema.exs`
10. `enhanced_validator.exs`
11. `json_schema_resolver.exs`
12. `dspy_integration.exs`
13. `llm_integration.exs`
14. `llm_pipeline_orchestration.exs`
15. `field_metadata_dspy.exs`
16. `conditional_recursive_validation.exs`
17. `advanced_config.exs`
18. `readme_examples.exs`

## Notes

- Many scripts intentionally print extensive output and benchmark-style timings.
- Some examples compile temporary modules at runtime; repeated runs are expected to be noisy.
- `run_all.sh` reports pass/fail per file and returns a non-zero exit code if any example fails.
