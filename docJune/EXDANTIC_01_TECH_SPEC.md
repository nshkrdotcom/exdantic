# Exdantic Technical Specification

## 1. Overview

Exdantic is a powerful, Pydantic-inspired schema definition and validation library for Exdantic. It provides a comprehensive toolset for both compile-time and runtime data validation, serialization, and schema generation. The architecture is designed to be layered, modular, and extensible, with a strong focus on supporting dynamic programming patterns seen in libraries like Python's DSPy, making it ideal for AI and LLM-driven applications.

The system is composed of several key layers:
- **Unified Interface (`EnhancedValidator`)**: A single facade providing access to all validation and schema generation capabilities.
- **Core Features (`Runtime`, `TypeAdapter`, `Wrapper`)**: Modules that implement the primary user-facing, Pydantic-like features.
- **Validation Engine (`Validator`, `Types`)**: The low-level engine that performs the actual type and constraint checking.
- **Configuration System (`Config`, `Config.Builder`)**: Manages validation behavior and options.
- **Schema Generation (`JsonSchema`, `Resolver`, `TypeMapper`)**: Handles the conversion of Exdantic schemas into JSON Schema, with advanced optimization features.

---

## 2. Core Abstractions & Data Structures

### 2.1. Type System (`Exdantic.Types`)

Exdantic uses a normalized internal representation for all type definitions. This allows for consistent processing throughout the validation and schema generation pipelines.

**Normalized Type Format:**
- **Basic Type**: `{:type, base_type, constraints}`
  - `base_type`: An atom like `:string`, `:integer`, `:float`, `:boolean`, `:atom`, `:any`, `:map`.
  - `constraints`: A keyword list of validation rules, e.g., `[min_length: 2]`.
- **Array Type**: `{:array, inner_type, constraints}`
  - `inner_type`: A recursive `type_definition`.
- **Map Type**: `{:map, {key_type, value_type}, constraints}`
  - `key_type`, `value_type`: Recursive `type_definition`s.
- **Union Type**: `{:union, [type1, type2, ...], constraints}`
  - `[type1, ...]`: A list of recursive `type_definition`s.
- **Schema Reference**: `{:ref, module}`
  - `module`: The module name of a compiled Exdantic schema.

### 2.2. Field Metadata (`Exdantic.FieldMeta`)

The `%Exdantic.FieldMeta{}` struct is the canonical representation of a single field within a schema.

```elixir
%Exdantic.FieldMeta{
  name: atom(),               # Field name
  type: Types.type_definition(), # Normalized type specification
  required: boolean(),        # Required flag (true/false)
  constraints: [term()],      # Validation constraints attached to the field
  description: String.t(),    # Field documentation
  default: term(),            # Default value (implies field is optional)
  example: term(),            # A single example value
  examples: [term()]          # A list of multiple example values
}
```

### 2.3. Dynamic Schema (`Exdantic.Runtime.DynamicSchema`)

This struct represents a schema created at runtime.

```elixir
%Exdantic.Runtime.DynamicSchema{
  name: String.t(),           # Unique identifier (e.g., "Wrapper_score_123")
  fields: %{atom() => FieldMeta.t()}, # Map of field names to their metadata
  config: map(),              # Schema-level configuration (e.g., %{strict: true})
  metadata: map()             # Runtime metadata (e.g., %{created_at: ~U[...], coerce: true})
}
```

### 2.4. TypeAdapter Instance (`Exdantic.TypeAdapter.Instance`)

A pre-compiled, reusable struct for efficient, repeated validation against a single type specification.

```elixir
%Exdantic.TypeAdapter.Instance{
  type_spec: term(),          # The original user-provided type specification
  normalized_type: Types.type_definition(), # The normalized internal type
  config: map(),              # Configuration options (e.g., %{coerce: true})
  json_schema: map() | nil    # A cached version of the generated JSON schema
}
```

### 2.5. Configuration (`Exdantic.Config`)

The struct representing a complete validation configuration.

```elixir
%Exdantic.Config{
  strict: boolean(),          # If true, disallow extra fields
  extra: :allow | :forbid | :ignore, # Strategy for handling extra fields
  coercion: :none | :safe | :aggressive, # Coercion strategy
  frozen: boolean(),          # If true, the config is immutable
  # ... and other options
}
```

### 2.6. Structured Error (`Exdantic.Error`)

All validation failures produce a consistent, structured error.

```elixir
%Exdantic.Error{
  path: [:user, :address, :zip_code], # Path to the invalid field
  code: :format,                      # Machine-readable error code
  message: "invalid zip code format"  # Human-readable message
}
```

---

## 3. Module Breakdown and Responsibilities

| Module | Purpose & Key Responsibilities |
| :--- | :--- |
| **`EnhancedValidator`** | **Unified Facade**. Dispatches validation and schema generation calls to the appropriate underlying module based on the target type (runtime schema, compiled schema, type spec). Integrates `Config` to drive behavior. |
| **`Runtime`** | **Dynamic Schema Management**. `create_schema/2` parses field definitions into `DynamicSchema` structs. `validate/3` orchestrates validation for these dynamic schemas. `to_json_schema/2` generates JSON schema. |
| **`TypeAdapter`** | **Schemaless Validation**. `validate/3` validates a value against a raw type spec. `dump/3` serializes Elixir data to JSON-compatible types. `json_schema/2` generates a schema for a type spec. |
| **`Wrapper`** | **Temporary Schemas**. Uses `Runtime.create_schema` to build temporary single-field schemas. `validate_and_extract/3` handles the logic of wrapping raw data into a map, validating it, and extracting the result. |
| **`Validator`** | **Core Validation Engine**. `validate_schema/3` handles compiled schemas. `validate/3` is the recursive core that traverses type definitions. `apply_constraint/3` checks a single value against a constraint like `:min_length` or `:gt`. |
| **`Types`** | **Type System Foundation**. `normalize_type/1` converts various user inputs into the canonical internal format. Defines basic type constructors (`string/0`, `array/1`). `coerce/2` handles basic type-to-type conversions. |
| **`Config` / `Builder`** | **Configuration Management**. `Config.create/1` builds a config struct. `Config.preset/1` provides canned configurations. `Config.Builder` provides a fluent API for constructing `Config` structs. |
| **`JsonSchema`** | **Primary Schema Generation**. `from_schema/1` is the entry point for generating a JSON Schema from a compiled Exdantic schema. It orchestrates `TypeMapper` and manages references via `ReferenceStore`. |
| **`TypeMapper`** | **Type-to-JSON-Schema Conversion**. `to_json_schema/2` maps a normalized Exdantic type definition (e.g., `{:type, :string, [min_length: 2]}`) to its JSON Schema equivalent (e.g., `%{ "type" => "string", "minLength" => 2 }`). |
| **`Resolver`** | **Advanced Schema Post-Processing**. `resolve_references/2` flattens schemas by replacing `$ref`s. `enforce_structured_output/2` modifies a schema to match provider-specific rules (e.g., for OpenAI). `optimize_for_llm/2` applies performance optimizations. |

---

## 4. Key Workflows

### 4.1. Validation Workflow

A call to `EnhancedValidator.validate(target, data, opts)` follows this general path:

1.  **`EnhancedValidator`**:
    *   Determines the `target` type:
        *   If `%DynamicSchema{}`, calls `Runtime.validate/3`.
        *   If a compiled schema module, calls `Validator.validate_schema/3`.
        *   If any other term, assumes it's a `type_spec` and calls `TypeAdapter.validate/3`.
    *   Applies the `Config` from `opts` to the underlying call.

2.  **`Runtime` / `Validator` / `TypeAdapter`**:
    *   The chosen module begins the validation process. `Runtime` and `Validator` check for required fields and then validate each field against its `FieldMeta`. `TypeAdapter` directly validates the value against the `type_spec`.

3.  **Recursive Validation (`Validator.do_validate`)**:
    *   The core `Validator` recursively traverses the (normalized) type definition.
    *   For each value/type pair, it first performs a basic type check (e.g., `is_binary/1`).
    *   If the type check passes, it calls `apply_constraints/3`.

4.  **Constraint Application (`Validator.apply_constraint`)**:
    *   This function pattern-matches on the constraint name (e.g., `:min_length`, `:gt`) and the value type to apply the correct check.
    *   It returns `true` or `false`.

5.  **Error Aggregation**:
    *   If any check fails, an `%Exdantic.Error{}` struct is created with the current validation `path`. Errors are collected and returned in a list.

6.  **Result**:
    *   The final result is either `{:ok, validated_data}` (which may contain coerced values or applied defaults) or `{:error, [errors]}`.

### 4.2. JSON Schema Generation Workflow

1.  **Entry Point**: A call is made to a high-level function like `Runtime.to_json_schema/2` or `JsonSchema.from_schema/1`.
2.  **Orchestration (`JsonSchema` / `Runtime`)**:
    *   A `ReferenceStore` agent is started to track schema cross-references.
    *   The main schema structure is built (`type: "object"`, `title`, etc.).
    *   It iterates over each field in the schema.
3.  **Type Mapping (`TypeMapper.to_json_schema`)**:
    *   For each field, the `TypeMapper` is called with the field's `type_definition`.
    *   It recursively converts the Exdantic type into a JSON Schema map, mapping Exdantic constraints to their JSON Schema keywords (e.g., `:gt` -> `"exclusiveMinimum"`).
    *   If it encounters a schema reference (`{:ref, MySchema}`), it adds it to the `ReferenceStore` and inserts a `"$ref"` pointer.
4.  **Reference Processing**:
    *   After the main schema is processed, the orchestrator processes any pending references in the `ReferenceStore`, generating their schemas and adding them to a top-level `"definitions"` block.
5.  **Post-Processing (`Resolver`) (Optional)**:
    *   The generated schema can be passed to the `Resolver` module.
    *   `resolve_references/2`: Replaces all `"$ref"` pointers with the actual content from the `"definitions"` block.
    *   `enforce_structured_output/2`: Modifies the schema according to a provider's rules (e.g., sets `"additionalProperties": false` for OpenAI).

---

## 5. Extension Points

- **Custom Types**: Define a module that `use Exdantic.Type` and implement the required callbacks (`type_definition/0`, `json_schema/0`, `validate/1`). This allows for creating reusable, complex types like `Types.Email`.
- **Custom Constraints**: The `Validator.apply_constraint/3` function can be extended with new function heads to support new constraint keywords.
- **Provider-Specific Rules**: The `Resolver.apply_provider_rules/3` function can be extended with new function heads to add schema optimization logic for new LLM providers.

---

## 6. Performance & Optimization

- **TypeAdapter Instances**: For repeated validation against the same type, creating a `%TypeAdapter.Instance{}` is highly recommended. It normalizes the type and caches the JSON schema on creation, avoiding repeated work.
- **Batch Operations**: The `validate_many/3` functions in `EnhancedValidator` and `TypeAdapter.Instance` are optimized for validating lists of items against the same target.
- **Schema Reuse**: `Runtime.create_schema` can be computationally intensive. Runtime schemas should be created once and reused for many validation calls.
- **JSON Schema Caching**: Generated JSON Schemas, especially complex or resolved ones, should be cached by the application rather than regenerated on every request.
