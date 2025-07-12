# Exdantic: Runtime and Integration API

This document covers Exdantic's APIs for runtime schema creation and its integration into the broader DSPEx ecosystem.

## 1. Runtime Schema Creation

While `defschema` is the preferred method for defining schemas, Exdantic provides a runtime API for dynamic use cases, such as when a schema's structure is only known at runtime.

### `Exdantic.create_schema/2`

Creates a schema definition dynamically.

**Signature**: `create_schema(field_definitions, opts \\ [])`

*   `field_definitions`: A list of field tuples, e.g., `[{:name, :string, [required: true]}]`.
*   `opts`: A keyword list for schema-level options like `:title` or `:description`.

**Returns**: An opaque schema struct that can be used with `Exdantic.validate/2`.

**Example**:
```elixir
# Define fields at runtime
fields = [
  {:question, :string, [required: true]},
  {:answer, :string, [required: true]}
]

# Create a schema dynamically
runtime_schema = Exdantic.create_schema(fields, title: "Dynamic QA Schema")

# Use it for validation
data = %{question: "What is Elixir?", answer: "A functional language."}
{:ok, validated} = Exdantic.validate(runtime_schema, data)
```

This is particularly useful for generating schemas based on external sources, like database tables or API responses.

## 2. JSON Schema Generation

Exdantic can generate standard JSON Schema drafts from any schema, which is useful for API documentation, client-side validation, or integration with other tools.

### `Exdantic.to_json_schema/1`

**Signature**: `to_json_schema(schema_module_or_runtime_schema)`

**Example**:
```elixir
defmodule User do
  use Exdantic.Schema
  defschema do
    field :name, :string
    field :age, :integer
  end
end

json_schema = Exdantic.to_json_schema(User)
# json_schema will be:
# %{
#   "type" => "object",
#   "properties" => %{
#     "name" => %{"type" => "string"},
#     "age" => %{"type" => "integer"}
#   },
#   "required" => ["name", "age"]
# }
```

## 3. Integration with DSPEx

Exdantic is the backbone of DSPEx's configuration and data validation.

### Program Configuration

DSPEx `Program`s use Exdantic schemas to define their configuration, especially for declaring tunable variables.

```elixir
defmodule MyRAG.Program do
  use DSPEx.Program

  # Define the configuration schema with variables
  defmodule ConfigSchema do
    use Exdantic.Schema
    defschema do
      variable :retriever,
        type: :module,
        choices: [DSPEx.Retrievers.BM25, DSPEx.Retrievers.Chroma]

      variable :top_k, type: :range, range: {1, 10}, default: 3
    end
  end

  # The program holds a reference to its config schema
  defstruct config_schema: ConfigSchema

  def forward(program, inputs, opts \\ []) do
    # An optimizer would have provided a concrete configuration
    config = Keyword.get(opts, :config)

    # The program can now use the validated configuration
    retriever_module = config.retriever
    k = config.top_k
    # ...
  end
end
```

### Teleprompter (Optimizer) Integration

Optimizers like `SIMBA` and `BEACON` use Exdantic's APIs to discover and tune programs.

**The Optimization Loop**:

1.  **Extract Space**: The optimizer calls `Exdantic.Variables.extract_space(program.config_schema)` to discover the tunable parameters (`:retriever` and `:top_k` in the example above).

2.  **Generate Candidates**: The optimizer samples the variable space to create a set of candidate configurations.
    ```elixir
    # Example candidate configuration
    candidate_config = %{retriever: DSPEx.Retrievers.Chroma, top_k: 5}
    ```

3.  **Evaluate**: The optimizer executes the program with each candidate configuration and evaluates the performance using a metric function.
    ```elixir
    # Execute the program with a specific configuration
    DSPEx.Program.forward(program, inputs, config: candidate_config)
    ```
4.  **Select Best**: After multiple trials, the optimizer selects the configuration with the best performance. The final, optimized program is then configured with these winning variable values.
```
