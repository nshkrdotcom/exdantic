Excellent. Based on the strategic report and your choices, we now have a clear vision and the "gift" libraries to build it. We will devise a code structure for `Alembic` that leverages `simdjsone` for parsing and sets the stage for `Estructura` to be used in the client application (`ds_ex`).

The goal is to create a clean, logical, and scalable directory and module structure for `Alembic`.

---

### **Part 1: The Architectural Blueprint**

Before diving into the file structure, let's solidify the architectural roles and data flow. This blueprint will directly inform the code structure.

1.  **Ingestion Layer (The "Gift"):**
    *   **Responsibility:** Take a raw JSON string and parse it into a native Elixir map as fast as possible.
    *   **Chosen Library:** `simdjsone`.
    *   **How it fits:** `Alembic` will be configured to use `simdjsone` as its JSON decoder. This is a pluggable dependency.

2.  **Schema Definition Layer (Alembic's Ergonomic Core):**
    *   **Responsibility:** Provide a beautiful, Elixir-native DSL for developers to define their data contracts (schemas).
    *   **Alembic Module:** `Alembic.Schema`.
    *   **Output:** This layer produces a single, standardized internal representation of a schema—a map that is compatible with `ExJsonSchema`'s expectations.

3.  **Validation Engine (The "Gift"):**
    *   **Responsibility:** Take a data map and a schema map and perform spec-compliant JSON Schema validation.
    *   **Chosen Library:** `ExJsonSchema` (from your earlier codebase analysis).
    *   **How it fits:** This is the internal engine that `Alembic` will call to do the heavy lifting of validation.

4.  **Orchestration & Coercion Layer (Alembic's "Smart" Core):**
    *   **Responsibility:** Orchestrate the end-to-end validation process, manage type coercion, and format errors.
    *   **Alembic Module:** `Alembic.Validator`.
    *   **Data Flow:**
        a. Receives raw data and an `Alembic.Schema` struct.
        b. Performs a pre-validation pass to **coerce** types (e.g., `"123"` -> `123`).
        c. Passes the coerced data and the schema's internal map to the `ExJsonSchema` engine.
        d. Catches errors from the engine and translates them into clean `Alembic.Error` structs.
        e. Runs the single `:post_validate` hook.

5.  **Client Application (`ds_ex`):**
    *   **Responsibility:** Handle complex business logic and data transformations.
    *   **Chosen Library:** `Estructura`.
    *   **Data Flow:**
        a. Receives validated data from `Alembic.Validator.validate`.
        b. Uses `Estructura` to perform complex transformations, create different data representations, etc.

This blueprint creates a clean, multi-stage pipeline where each library has a distinct and focused job.

---

### **Part 2: The Detailed Integration Structure (Code & Files)**

Here is the proposed file structure and key code snippets for `Alembic`.

#### **1. Directory Structure**

This structure is organized by responsibility, making it easy to navigate and maintain.

```
alembic/
├── lib/
│   ├── alembic/
│   │   ├── schema/
│   │   │   ├── builder.ex        # The internal logic for the `use_schema` DSL.
│   │   │   └── type_mapper.ex    # Maps Elixir types to JSON Schema map representations.
│   │   │
│   │   ├── validator/
│   │   │   ├── coercer.ex        # Handles the pre-validation type coercion logic.
│   │   │   └── error_translator.ex # Translates ExJsonSchema errors to Alembic.Error.
│   │   │
│   │   ├── json_schema_generator.ex  # The JSON Schema generator (replaces Alembic.JsonSchema).
│   │   ├── schema.ex                 # The core schema definition module (define/2, use_schema).
│   │   ├── validator.ex              # The core validation orchestrator.
│   │   └── error.ex                  # Defines Alembic.Error and ValidationError.
│   │
│   └── alembic.ex                    # The top-level facade with helper functions.
│
├── config/
│   ├── config.exs                  # Configuration for the pluggable JSON parser.
│   └── test.exs
│
├── mix.exs                         # Dependencies: simdjsone, ex_json_schema.
└── README.md
```

#### **2. Key Module Implementations (Abbreviated)**

##### `mix.exs`

This is where we declare our "gifts" as dependencies.

```elixir
def deps do
  [
    {:simdjsone, "~> 0.5.0"},
    # We will vendor or fork ExJsonSchema into our project to have full control,
    # or add it as a git dependency if it's in a private repo. For this example,
    # let's assume it's vendored into `lib/alembic/vendor/ex_json_schema`.
    # Alternatively:
    # {:ex_json_schema, git: "https://github.com/path/to/your/ex_json_schema.git"}
  ]
end
```

##### `config/config.exs`

Here, we make the JSON parser pluggable and default to our "blazing fast" choice.

```elixir
import Config

config :alembic, :json_decoder, {Simdjsone, :decode}

# In test environment, you might want to use a pure Elixir one for simplicity
# if NIFs cause issues in CI.
if Mix.env() == :test do
  config :alembic, :json_decoder, {Jason, :decode}
end
```

##### `lib/alembic/schema.ex` (The Ergonomic Core)

This is the beautiful DSL layer. Its job is to build the schema map.

```elixir
defmodule Alembic.Schema do
  @doc "The internal representation of a compiled schema."
  defstruct [:definition, :config] # :definition is the JSON Schema map for ExJsonSchema

  defmacro use_schema(do: block) do
    quote do
      import Alembic.SchemaBuilder # The DSL helpers live here

      # The block builds the schema_map and config at compile time
      {schema_map, config} = Alembic.SchemaBuilder.build_from_dsl(unquote(block))

      @alembic_schema %Alembic.Schema{definition: schema_map, config: config}

      def schema, do: @alembic_schema
    end
  end

  def define(fields, opts \\ []) do
    # The runtime equivalent
    {schema_map, config} = Alembic.SchemaBuilder.build_from_fields(fields, opts)
    %Alembic.Schema{definition: schema_map, config: config}
  end
end
```

##### `lib/alembic/validator.ex` (The Orchestration Core)

This module orchestrates the entire validation pipeline.

```elixir
defmodule Alembic.Validator do
  # We will use our vendored/forked version of ExJsonSchema
  alias Alembic.Vendor.ExJsonSchema

  def validate(%Alembic.Schema{definition: schema_map, config: schema_config}, data, opts \\ []) do
    with {:ok, coerced_data} <- Alembic.Validator.Coercer.coerce(data, schema_map, opts),
         :ok <- ExJsonSchema.validate(schema_map, coerced_data) do

      run_post_validate(schema_config, coerced_data)
    else
      # ExJsonSchema returns a list of its own error structs
      {:error, ex_json_errors} when is_list(ex_json_errors) ->
        # Translate into clean Alembic.Error structs
        errors = Alembic.Validator.ErrorTranslator.translate(ex_json_errors)
        {:error, errors}

      # Handle post-validate or coercion errors
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp run_post_validate(schema_config, data) do
    case schema_config[:post_validate] do
      nil -> {:ok, data}
      fun -> fun.(data) # Expected to return {:ok, data} or {:error, reason}
    end
  end
end
```

#### **3. The `ds_ex` Client Application Integration**

Now, the `ds_ex` code becomes cleaner.

**Before (in `ds_ex`):** The code was complex, trying to figure out which `Exdantic` tool to use.

**After (in `ds_ex`):** The code follows a clear, two-stage process: **Validate, then Transform.**

```elixir
defmodule DSPEx.MyProgram do
  alias Alembic
  alias Estructura # The transformation "gift"

  # 1. Define the validation contract using Alembic
  defmodule OutputSchema do
    import Alembic.Schema
    use_schema do
      field :first_name, :string
      field :last_name, :string
      field :birth_date, :string, [format: ~r/^\d{4}-\d{2}-\d{2}$/]
    end
  end

  # 2. Define the transformation rules using Estructura
  defmodule OutputTransformer do
    use Estructura.Nested # Estructura's DSL

    # This defines how to transform the *validated* data
    shape %{
      full_name: :string,
      age: :integer
    }

    # Estructura's way of defining transformations
    def coerce(:full_name, data), do: {:ok, "#{data.first_name} #{data.last_name}"}
    def coerce(:age, data), do: {:ok, calculate_age(data.birth_date)}
    # ... helpers
  end

  # 3. The ds_ex program orchestrates the two steps
  def run(input) do
    with # Assume llm_call returns a map with :first_name, :last_name, etc.
         {:ok, llm_output} <- llm_call(input),

         # Step A: VALIDATE the raw LLM output with Alembic
         {:ok, validated_data} <- Alembic.Validator.validate(OutputSchema.schema(), llm_output, coerce: true),

         # Step B: TRANSFORM the now-guaranteed-valid data with Estructura
         {:ok, transformed_data} <- Estructura.cast(OutputTransformer, validated_data)
    do
      # Now we have a fully validated and transformed struct
      # transformed_data = %OutputTransformer{full_name: "John Doe", age: 34}
      {:ok, transformed_data}
    end
  end
end
```

This structure is the embodiment of the architectural principles we've discussed. It is clean, maintainable, and highly scalable because each library is doing exactly what it was designed for.