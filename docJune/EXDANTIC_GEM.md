# Exdantic: The Schema & Configuration Engine for DSPEx

## 1. Vision & Philosophy

**Exdantic** is the configuration and data validation engine for the ElixirML/DSPEx ecosystem. It is designed from the ground up to be our 'super pydantic'—a powerful, type-safe, and intuitive library for defining, validating, and managing the data structures that power modern AI programs.

While inspired by libraries like `pydantic` and `Ecto.Changeset`, Exdantic is purpose-built for the unique challenges of building self-optimizing LLM systems in Elixir.

### Core Principles

*   **Declarative & Type-Safe**: Define the *what*, not the *how*. Schemas are the single source of truth for data structure, validation, and types, enforced at compile-time wherever possible.
*   **Immutable & Composable**: Schemas and their validated data are immutable, promoting functional purity and predictable data flows, aligning with Elixir's core principles.
*   **Optimization-First Design**: The revolutionary **Variable System** is a first-class citizen, not an afterthought. Exdantic is designed to declaratively define optimization spaces for any parameter.
*   **Excellent Developer Experience**: A clean, intuitive DSL (`defschema`) makes defining complex schemas simple and readable. Error messages are precise, contextual, and designed to guide the developer to a solution.
*   **Extensible**: A robust type system allows for the definition of custom, domain-specific types (e.g., `:embedding`, `:model_response`) that are treated as first-class citizens.

## 2. Key Features

### a. The `defschema` DSL
A simple, powerful macro for defining schemas directly in your modules.

```elixir
defmodule MyProgram.OutputSchema do
  use Exdantic.Schema

  defschema do
    field :answer, :string, required: true, description: "The final answer."
    field :confidence, :probability, description: "The model's confidence from 0.0 to 1.0"
    field :reasoning_steps, {:array, :string}, description: "The chain of thought."
  end
end
```

### b. The Variable System
The cornerstone of DSPEx's auto-optimization capabilities. Declare tunable parameters directly within your schemas.

```elixir
defmodule MyProgram.ConfigSchema do
  use Exdantic.Schema

  defschema do
    # A discrete choice between different adapters
    variable :adapter,
      type: :choice,
      choices: [DSPEx.Adapters.JSON, DSPEx.Adapters.Markdown, DSPEx.Adapters.Chat]

    # A continuous parameter for the LLM
    variable :temperature,
      type: :range,
      range: {0.1, 1.5},
      default: 0.7

    # A choice between different reasoning modules
    variable :strategy,
      type: :module,
      choices: [DSPEx.Predict, DSPEx.ChainOfThought, DSPEx.ProgramOfThought],
      behavior: DSPEx.Strategy,
      default: DSPEx.Predict
  end
end
```
Any optimizer (`SIMBA`, `BEACON`, `GridSearch`) can then inspect this schema, understand the optimization space, and automatically find the best configuration.

### c. Rich Type System & Constraints
Exdantic comes with a powerful set of built-in types and constraints, including ML-specific types like `:embedding`, `:probability`, and `:model_response`, with the ability to easily add your own.

### d. Runtime Validation with Configuration
Validate data at runtime against a schema, applying a specific set of variable choices to ensure correctness.

```elixir
# The optimizer has chosen this configuration
chosen_config = %{
  adapter: DSPEx.Adapters.JSON,
  temperature: 0.85,
  strategy: DSPEx.ChainOfThought
}

# The data to be used by the program
program_data = %{
  adapter: DSPEx.Adapters.JSON,
  temperature: 0.85,
  strategy: DSPEx.ChainOfThought
}

# Validate the runtime data against the schema and the chosen variable config
{:ok, validated_data} = Exdantic.validate(ConfigSchema, program_data, with_config: chosen_config)
```
