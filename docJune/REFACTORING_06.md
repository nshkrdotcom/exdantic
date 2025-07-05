Of course. This is a critical step, and doing it right will set `ds_ex` up for long-term success. A migration guide needs to be clear, pragmatic, and respectful of the work already completed.

Here is a detailed migration guide to transition your stable but complex `Exdantic`-based `ds_ex` implementation to the new, simplified `Alembic` architecture.

---

## Migration Guide: From Exdantic to Alembic

### **Overview: The Strategic "Why"**

The goal of this migration is not to discard the work already done, but to **refine and distill** it. Your current `Exdantic` library is a powerful and feature-complete Pydantic port. However, its comprehensive nature has introduced several overlapping APIs (`Runtime`, `Wrapper`, `TypeAdapter`, compile-time macros) which are already causing architectural friction in the `ds_ex` codebase, most notably in the configuration system (`dspex/config/exdantic_schemas.ex`).

This migration replaces that complexity with **Alembic**, a focused, unified architecture designed for the dynamic, runtime-centric needs of a DSPy-style framework.

**Key Benefits of this Migration:**

1.  **Unified API:** One way to define schemas, one way to validate, one way to generate JSON Schema.
2.  **Architectural Clarity:** Eliminates the need for complex adapter modules like `dspex/config/exdantic_schemas.ex` and its legacy fallbacks.
3.  **Decoupling:** Separates the responsibility of **validation** (Alembic's job) from **data transformation** (the `ds_ex` program's job), removing features like `computed_field`.
4.  **Velocity:** Radically simplifies the foundation, making it faster and easier to build the remaining 89% of DSPy features (Retrieval, Assertions, Advanced Teleprompters).

---

### **Prerequisites & Initial Setup**

This is the "rip the band-aid off" step. It's best to do this first to reveal all the areas that need updating.

1.  **Rename the Library:** In your file system, rename the `exdantic/` directory to `alembic/`.
2.  **Project-Wide Find & Replace:**
    *   Find `Exdantic` and replace with `Alembic`.
    *   Find `exdantic` and replace with `alembic`.
3.  **Update `mix.exs`:** Change the dependency name from `{:exdantic, ...}` to `{:alembic, ...}`.

Your project will now be broken. This is expected. The following steps will fix it piece by piece.

---

### **Step-by-Step Migration Plan**

#### **Step 1: Refactor the Core Library (`alembic/`)**

This is the most significant step. We are refactoring the library itself to match the new, unified `Alembic` API specification.

**1.1. Unify Schema Definition:**
*   Create `lib/alembic/schema.ex`. This module will house `define/2` and the `use_schema/1` macro.
*   The new `Alembic.Schema.define/2` function will be the core engine. It takes a list of field specs and returns a schema struct. This logic can be extracted and refactored from the current `Exdantic.Runtime.create_schema/2`.
*   Rewrite the `use Exdantic` macro (now `use Alembic`) to be a simple wrapper. It should parse the DSL block into the same field spec data structure that `define/2` expects and then call `define/2` at compile time.

**1.2. Decouple Transformation from Validation:**
*   **Remove `computed_field`:** Delete all code related to `computed_field` from the schema definition and validation pipeline. This logic belongs in your `ds_ex` programs, not the validation library.
*   **Simplify `model_validator`:** Replace the logic for a *list* of validators with a single `:post_validate` option in `Alembic.Schema.define/2`. The validator will now only call this one optional function at the end of the pipeline.

**1.3. Consolidate Modules:**
*   **Merge Validators:** Move all validation logic from `Exdantic.EnhancedValidator`, `Exdantic.Runtime`, and the old `Exdantic.Validator` into a single, new `lib/alembic/validator.ex`.
*   **Merge JSON Schema:** Merge all logic from `Exdantic.JsonSchema`, `JsonSchema.Resolver`, and `JsonSchema.EnhancedResolver` into a single `lib/alembic/json_schema.ex`. The new `generate/2` function will take an `opts` map for provider optimization.
*   **Deprecate `TypeAdapter` and `Wrapper`:** Delete these modules entirely. Their functionality will be replaced by simple helper functions.

**1.4. Create Top-Level Helpers:**
*   In `lib/alembic.ex`, create the new helper functions `validate_type/3` and `validate_value/4`. These will internally use `Alembic.Schema.define/2` and `Alembic.Validator.validate/3` to perform their tasks.

#### **Step 2: Drastically Simplify Configuration (`dspex/config/`)**

This is where you will see the biggest immediate payoff. The complex and brittle configuration validation system will be replaced with something clean and data-driven.

**2.1. Delete the Old Abstraction:**
*   **Delete the file `dspex/config/exdantic_schemas.ex`**. We no longer need this complex path-to-module mapping.
*   **Delete the individual schema files** in `dspex/config/schemas/`. Their definitions will be centralized.

**2.2. Create the New, Centralized Schema Store:**
*   Create a new file, e.g., `dspex/config/schema_definitions.ex`.
*   In this file, define your configuration schemas as pure data.

**Before (`dspex/config/schemas/client_configuration.ex`):**
```elixir
defmodule ClientConfiguration do
  use Exdantic
  schema do
    field :timeout, :integer, [gteq: 1]
    # ...
  end
end
```

**After (`dspex/config/schema_definitions.ex`):**
```elixir
defmodule DSPEx.Config.SchemaDefinitions do
  @doc "Central store for all configuration schemas."
  def schemas do
    %{
      client: [
        {:timeout, :integer, [gteq: 1, description: "Request timeout in ms"]},
        {:retry_attempts, :integer, [gteq: 0]},
        {:backoff_factor, :float, [gt: 0.0]}
      ],
      prediction: [
        {:default_provider, :atom, [choices: [:gemini, :openai]]},
        {:default_temperature, :float, [gteq: 0.0, lteq: 2.0]}
      ]
      # ... all other schemas defined as data here
    }
  end

  def get_field_spec(path) do
    # Simple logic to traverse the map and find the field definition
    # e.g., get_in(@schemas, [:client, :timeout])
    ...
  end
end
```

**2.3. Refactor `dspex/config/validator.ex`:**
*   The `validate_value/2` function becomes incredibly simple.
*   It no longer needs a legacy fallback or complex path mapping.

**Before (`dspex/config/validator.ex`):**
```elixir
def validate_value(path, value) do
  case ExdanticSchemas.validate_config_value(path, value) do
    # ... complex logic with legacy fallback
  end
end
```

**After (`dspex/config/validator.ex`):**
```elixir
# No more ExdanticSchemas module needed
alias DSPEx.Config.SchemaDefinitions

def validate_value(path, value) do
  case SchemaDefinitions.get_field_spec(path) do
    nil ->
      {:error, {:unknown_path, path}}
    field_spec ->
      # Use the new, simple Alembic helper for one-off validation
      {_name, type, opts} = field_spec
      Alembic.validate_value(List.last(path), type, value, opts)
      |> case do
           {:ok, _} -> :ok
           {:error, errors} -> {:error, {List.last(path), hd(errors).message}}
         end
  end
end
```

#### **Step 3: Update the Signature System (`dspex/signature/`)**

**3.1. `DSPEx.Signature.Exdantic` -> `DSPEx.Signature.AlembicBridge`:**
*   Rename this module to reflect its new, simpler purpose.
*   The `signature_to_schema/1` function now calls `Alembic.Schema.define/2` with the parsed fields.
*   The `to_json_schema/2` function now calls `Alembic.JsonSchema.generate/2`.
*   The `validate_with_exdantic/3` function now calls `Alembic.Validator.validate/3`.

**3.2. `DSPEx.Signature.__using__` macro:**
*   This macro in `dspex/signature.ex` will now use the simplified `AlembicBridge` to generate a schema at compile-time. The core parsing logic remains, but its output now feeds the unified `Alembic` engine.

#### **Step 4: Update Application Code (Predictors, Adapters, etc.)**

This is mostly a search-and-replace for function calls.

*   Everywhere you see `SomeSchemaModule.validate(data)`, it should be replaced with a call that uses the central validator, for instance: `Alembic.Validator.validate(SomeSchemaModule.schema(), data)`. (Assuming you add a `schema()` function to your `use_schema` macro that returns the compiled schema struct).
*   In `DSPEx.Adapters.InstructorLiteGemini`, the `build_json_schema` function will now call `Alembic.JsonSchema.generate/2` on the schema derived from the signature.

---

### **Summary of Changes: Before vs. After**

| Area | Before (Current `Exdantic` Integration) | After (Refactored `Alembic` Integration) |
| :--- | :--- | :--- |
| **Validation Lib** | `exdantic` | `alembic` |
| **Schema Definition** | `use Exdantic`, `Runtime.create_schema`, `Wrapper`, `TypeAdapter` | Unified `Alembic.Schema.define/2` and `use_schema` macro. |
| **Validation Call** | `SomeSchema.validate`, `EnhancedValidator.validate`, `Runtime.validate` | `Alembic.Validator.validate(schema, data)` |
| **Config Validation** | `dspex/config/exdantic_schemas.ex` with complex logic and legacy fallbacks. | Centralized map of field specs in one file; simple validation calls. |
| **Data Transformation** | Handled implicitly by `computed_field` and `model_validator` chains. | **Removed from the library.** Now an explicit responsibility of the `ds_ex` program logic. |
| **JSON Schema** | Multiple modules (`Resolver`, `EnhancedResolver`). | Single `Alembic.JsonSchema.generate/2` function with an `opts` map. |
| **Overall Architecture**| Layered, multiple parallel systems for similar tasks. | A single, unified core engine with thin, convenient facades. |

---

### **Post-Migration Benefits: Unlocking Future Velocity**

Once this migration is complete, you will have a rock-solid, conceptually simple foundation. Building the remaining 89% of DSPy's features will be significantly easier:

*   **Implementing `MIPRO`:** Will be straightforward. Your optimizer can now dynamically generate a list of fields and call `Alembic.Schema.define/2` to create new program signatures on the fly.
*   **Building the Retrieval System:** You can define schemas for your vector search results (e.g., a list of `Document` structs) and validate them with `Alembic.Validator.validate_many/3`.
*   **Implementing Assertions:** The `dspy.Assert` logic can be built on top of `Alembic`. An assertion is just a runtime-defined schema that is checked at a specific point in the program.

This refactoring is a strategic investment. It addresses the architectural debt early, ensuring that `ds_ex` can evolve into the powerful, dynamic, and maintainable framework you envision it to be.