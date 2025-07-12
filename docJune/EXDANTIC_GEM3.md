# Exdantic: The Variable System API

The Variable System is Exdantic's most powerful feature. It enables the creation of self-optimizing programs by allowing any parameter—from LLM settings to module choices—to be declared as a tunable variable.

## 1. Declaring Variables

Variables are declared within a `defschema` block using the `variable` macro. This macro defines a parameter that optimizers can discover and tune.

**Signature**: `variable(name, options)`

*   `name`: An atom representing the variable's name (e.g., `:temperature`).
*   `options`: A keyword list specifying the variable's `type` and constraints.

### Variable Types

#### `:choice`

Defines a variable with a discrete set of possible values. Ideal for selecting from a list of options like adapters, models, or string prompts.

**Options**:
*   `choices`: A list of allowed values.
*   `default`: (Optional) The default value. Defaults to the first item in `choices`.
*   `description`: (Optional) A human-readable description.

**Example**:
```elixir
variable :adapter,
  type: :choice,
  choices: [DSPEx.Adapters.JSON, DSPEx.Adapters.Markdown, DSPEx.Adapters.Chat],
  description: "The adapter for formatting LLM responses."
```

#### `:range`

Defines a continuous variable within a numerical range. Ideal for parameters like `temperature` or `top_p`.

**Options**:
*   `range`: A two-element tuple `{min, max}` specifying the inclusive range.
*   `default`: (Optional) The default value.
*   `description`: (Optional) A human-readable description.

**Example**:
```elixir
variable :temperature,
  type: :range,
  range: {0.0, 2.0},
  default: 0.7,
  description: "Controls the randomness of the LLM's output."
```

#### `:module`

A specialized version of `:choice` for selecting between different Elixir modules. This is the key to automatic strategy selection (e.g., `Predict` vs. `ChainOfThought`).

**Options**:
*   `choices`: A list of valid module atoms.
*   `behavior`: (Optional) An Elixir behaviour that all module choices must implement. This ensures type safety at the architectural level.
*   `default`: (Optional) The default module.
*   `description`: (Optional) A human-readable description.

**Example**:
```elixir
variable :strategy,
  type: :module,
  choices: [DSPEx.Predict, DSPEx.ChainOfThought, DSPEx.ProgramOfThought],
  behavior: DSPEx.Strategy,
  description: "The reasoning strategy for the program."
```

## 2. The Variable Space

A schema containing variables defines an **optimization space**. Any optimizer can inspect this space to understand what parameters it can tune.

### `Exdantic.Variables.extract_space/1`

Extracts a map describing the optimization space from a schema. This is the primary API used by optimizers.

**Signature**: `extract_space(schema_module)`

**Returns**: A map where keys are variable names and values are maps containing the variable's definition (type, constraints, default, etc.).

```elixir
# In a teleprompter or optimizer...
def optimize(program) do
  # 1. Extract the optimization space from the program's config schema
  variable_space = Exdantic.Variables.extract_space(program.config_schema)
  # variable_space might look like:
  # %{
  #   temperature: %{type: :range, range: {0.0, 2.0}, ...},
  #   strategy: %{type: :module, choices: [...], ...}
  # }

  # 2. Use this space to generate and test configurations
  run_optimization_trials(variable_space)
end
```

## 3. Runtime Validation with Configurations

When a program is executed, it uses a single, concrete configuration. `Exdantic` can validate that a given set of data conforms to a schema *and* a specific variable configuration.

### `Exdantic.validate/3` with `:with_config`

**Signature**: `validate(schema_module, data_map, opts \\ [])`

*   `opts`: Use the `:with_config` option to provide the chosen variable configuration.

**How it works**:
1. It validates that the `data_map` contains the correct keys and types defined by the schema's `variable` fields.
2. For each variable field, it validates the provided value against the variable's constraints (e.g., is the temperature within the defined range? Is the adapter one of the allowed choices?).

```elixir
# A concrete configuration chosen by an optimizer
chosen_config = %{
  strategy: DSPEx.ChainOfThought,
  temperature: 0.85
}

# The runtime data for the program
program_data = %{
  strategy: DSPEx.ChainOfThought,
  temperature: 0.85
}

# Validate that the program_data is a valid instance of the schema
# given the chosen_config.
case Exdantic.validate(MyProgram.ConfigSchema, program_data, with_config: chosen_config) do
  {:ok, validated_config} ->
    # The configuration is valid
    :ok
  {:error, errors} ->
    # The provided temperature might be out of range, or the strategy
    # might not be a valid choice.
    IO.inspect(errors)
end
```
This ensures that programs are always executed with valid, type-safe configurations, even when those configurations are discovered automatically.
