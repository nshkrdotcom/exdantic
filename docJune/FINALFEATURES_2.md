Of course. Here is a detailed technical document outlining the implementation plan for the three key features required to enhance `Exdantic` for a robust port of DSPy.

---

## Technical Implementation Plan for Exdantic Feature Enhancements

### 1. Introduction

This document details the technical implementation strategy for three critical features in the `Exdantic` library:

1.  **A Formalized Struct-based Pattern:** Integrating `struct` definitions with schemas to create stateful, validated data containers.
2.  **Model-level Validators:** Introducing a mechanism for cross-field validation after individual field validation succeeds.
3.  **Computed Fields:** Adding support for fields whose values are derived from other fields, included in serialization.

These features are essential for achieving functional parity with Pydantic and enabling a robust Elixir port of the DSPy framework.

### 2. Feature 1: A Formalized Struct-based Pattern

**Objective:** Automatically define an Elixir `struct` alongside the schema definition. This `struct` will serve as the type-safe container for validated data, making `Exdantic` schemas behave more like Pydantic's stateful `BaseModel` instances. The primary `validate/1` function will return an instance of this struct on success.

#### 2.1. User-facing API

The `use Exdantic` macro will be enhanced with an option to automatically define a struct.

```elixir
defmodule UserSchema do
  use Exdantic, define_struct: true # New option

  schema "User account information" do
    field :name, :string, required: true
    field :age, :integer, optional: true
    field :tags, {:array, :string}, default: []
  end
end

# The above will automatically generate:
# defstruct [:name, :age, :tags]
# @type t :: %__MODULE__{name: String.t(), age: integer() | nil, tags: [String.t()]}
```

The validation function will now return an instance of this struct:

```elixir
iex> UserSchema.validate(%{name: "Alice"})
{:ok, %UserSchema{name: "Alice", age: nil, tags: []}}
```

#### 2.2. Technical Implementation

This feature will be implemented within the `Exdantic` module's `__using__` and `__before_compile__` macros.

##### **Step 1: Modify `Exdantic.__using__/1`**

The `__using__` macro in `exdantic.ex` will parse the new `:define_struct` option.

```elixir
# in exdantic.ex
defmacro __using__(opts) do
  define_struct? = Keyword.get(opts, :define_struct, false)

  quote do
    import Exdantic.Schema
    # ... other attributes
    @exdantic_define_struct unquote(define_struct?) # Store option in module attribute
    @before_compile Exdantic
  end
end
```

##### **Step 2: Modify `Exdantic.__before_compile__/1`**

This is where the struct definition will be injected into the user's module at compile time.

```elixir
# in exdantic.ex
defmacro __before_compile__(env) do
  define_struct? = Module.get_attribute(env.module, :exdantic_define_struct)

  # Extract field names from the @fields attribute
  fields = Module.get_attribute(env.module, :fields)
  field_names = Enum.map(fields, fn {name, _meta} -> name end)

  struct_def =
    if define_struct? do
      quote do
        # Define the struct with all field names
        defstruct unquote(field_names)

        # Define the @type t for the struct (optional but good practice)
        # This part is more complex and requires generating typespecs
        # from field metadata.
        @type t :: %__MODULE__{} # Placeholder for now
      end
    else
      quote do
        # Do nothing if the option is not set
      end
    end

  quote do
    # Inject struct definition
    unquote(struct_def)

    # Define __schema__ functions
    def __schema__(:description), do: @schema_description
    def __schema__(:fields), do: @fields
    # ... other __schema__ functions
  end
end
```

##### **Step 3: Update `Exdantic.Validator.validate_schema/3`**

The validator must be updated to return the newly defined struct instead of a plain map.

```elixir
# in exdantic/validator.ex
def validate_schema(schema_module, data, path \\ []) when is_atom(schema_module) do
  # ... existing checks
  with :ok <- validate_required_fields(fields, data, path),
       {:ok, validated_map} <- validate_fields(fields, data, path), # returns a map
       :ok <- validate_strict(config, validated_map, data, path) do

    # NEW: Conditionally create a struct
    if function_exported?(schema_module, :__struct__, 1) do
      # The module has a struct defined, so create an instance of it.
      # `struct!/2` is safe here because we've already validated the keys.
      validated_struct = struct!(schema_module, validated_map)
      {:ok, validated_struct}
    else
      # Fallback for schemas without structs
      {:ok, validated_map}
    end
  end
end
```

### 3. Feature 2: Model-level Validators

**Objective:** Introduce a mechanism for defining validation functions that operate on the entire data structure after individual field validations have passed. This is equivalent to Pydantic's `@model_validator`.

#### 3.1. User-facing API

A new macro, `model_validator/1`, will be added to the `Exdantic.Schema` DSL. It can accept a 1-arity or 2-arity function.

```elixir
defmodule UserSchema do
  use Exdantic, define_struct: true

  schema do
    field :password, :string
    field :password_confirmation, :string

    # 1-arity function: receives the validated data (struct or map)
    model_validator fn data ->
      if data.password == data.password_confirmation do
        {:ok, data}
      else
        {:error, "passwords do not match"}
      end
    end
  end
end
```

#### 3.2. Technical Implementation

##### **Step 1: Create `model_validator/1` Macro**

This macro will capture the validation function and store it in a new module attribute.

```elixir
# in exdantic/schema.ex
defmacro model_validator(do: block) do
  quote do
    # The block should contain a function literal (fn ... end)
    # We store the AST of the function to be used at compile time.
    @after_compile {__ENV__.module, :__apply_model_validators__}
    @model_validators {unquote(block), __ENV__}
  end
end
```

##### **Step 2: Define `after_compile` Hook**

The `after_compile` hook will process the stored validator functions and weave them into the `validate/1` function.

```elixir
# in exdantic/schema.ex

def __apply_model_validators__(module, _binary) do
  validators = Module.get_attribute(module, :model_validators)
  
  # For simplicity, we will override the existing `validate/1` function.
  # A more robust solution might involve generating a private validation function
  # and calling it from the public `validate/1`.
  
  if Enum.any?(validators) do
    # Generate the chain of validator calls
    validator_calls = 
      Enum.reduce(validators, quote do {_, data} -> {:ok, data} end, fn {validator_ast, env}, acc ->
        # The validator_ast is the `fn ... end` block
        # We need to resolve it in its original environment
        validator_fn = Code.eval_quoted(validator_ast, [], env) |> elem(0)

        quote do
          fn {:ok, data}, _ -> unquote(validator_fn).(data)
             {:error, _} = error, _ -> error
          end
        end
      end)
      
    # Override the `validate/1` function
    Module.create(
      module,
      quote do
        def validate(data) do
          # Call the original field-level validation
          case super(data) do
            {:ok, validated_data} ->
              # Pipe through the model validators
              unquote(validator_calls).({:ok, validated_data})
            {:error, _} = error ->
              error
          end
        end
      end,
      [line: __ENV__.line, file: __ENV__.file]
    )
  end
end
```
**Correction/Refinement:** A cleaner approach than overriding `validate/1` via an `after_compile` hook is to handle this directly within `Exdantic.Validator.validate_schema/3`.

##### **Revised Step 2: Update `validate_schema/3`**
1.  The `model_validator` macro will store the function in a `@model_validators` module attribute.
2.  `Exdantic.Validator.validate_schema/3` will be modified to apply these validators.

```elixir
# in exdantic/validator.ex

def validate_schema(schema_module, data, path \\ []) when is_atom(schema_module) do
  # ... existing logic ...
  with :ok <- validate_required_fields(fields, data, path),
       {:ok, validated_data} <- validate_fields(fields, data, path),
       :ok <- validate_strict(config, validated_data, data, path) do

    # Apply model validators
    apply_model_validators(schema_module, validated_data)
  end
end

defp apply_model_validators(schema_module, validated_data) do
  model_validators = schema_module.__schema__(:validations) # Assuming it's stored here

  Enum.reduce_while(model_validators, {:ok, validated_data}, fn validator_fn, {:ok, current_data} ->
    case validator_fn.(current_data) do
      {:ok, new_data} -> {:cont, {:ok, new_data}}
      {:error, reason} -> 
        error = Error.new([], :model_validation, reason)
        {:halt, {:error, [error]}}
    end
  end)
end
```

### 4. Feature 3: Computed Fields

**Objective:** Allow the definition of fields that are computed *after* validation and are included in the model's `struct` and serialization output.

#### 4.1. User-facing API

A new `computed_field/3` macro is introduced. It requires a type annotation for JSON Schema generation.

```elixir
defmodule User do
  use Exdantic, define_struct: true

  schema do
    field :first_name, :string
    field :last_name, :string

    computed_field :full_name, :string, fn data ->
      "#{data.first_name} #{data.last_name}"
    end
  end
end

# Struct will be `defstruct [:first_name, :last_name, :full_name]`
# `full_name` will be populated after validation.

iex> {:ok, user} = User.validate(%{first_name: "Jane", last_name: "Doe"})
%User{first_name: "Jane", last_name: "Doe", full_name: "Jane Doe"}

# It should also appear in the JSON Schema
iex> User.json_schema()
%{
  "type" => "object",
  "properties" => %{
    "first_name" => %{"type" => "string"},
    "last_name" => %{"type" => "string"},
    "full_name" => %{"type" => "string", "readOnly" => true} # Mark as readOnly
  },
  ...
}
```

#### 4.2. Technical Implementation

This feature requires significant changes to the compilation and validation flow.

##### **Step 1: New `computed_field/3` Macro**

This macro will store computed field definitions in a new module attribute, `@computed_fields`.

```elixir
# in exdantic/schema.ex
defmacro computed_field(name, type, function) do
  quote do
    # Store the name, type, and function AST
    @computed_fields {unquote(name), {unquote(type), unquote(function)}}
  end
end
```

##### **Step 2: Update Struct Generation in `__before_compile__/1`**

The `defstruct` injection must now include both regular and computed fields.

```elixir
# in exdantic.ex
defmacro __before_compile__(env) do
  # ... existing struct logic
  regular_fields = Module.get_attribute(env.module, :fields)
  computed_fields = Module.get_attribute(env.module, :computed_fields, [])

  all_field_names = 
    (Enum.map(regular_fields, fn {name, _} -> name end)) ++
    (Enum.map(computed_fields, fn {name, _} -> name end))
    |> Enum.uniq()
  
  # ... generate `defstruct` with `all_field_names`
end
```

##### **Step 3: Update `validate_schema/3` to Populate Computed Fields**

The core validator needs to execute the computed field functions after the main validation is successful.

```elixir
# in exdantic/validator.ex
def validate_schema(schema_module, data, path \\ []) when is_atom(schema_module) do
  # ... existing with block
  with :ok <- ...,
       {:ok, validated_data} <- ...,
       :ok <- ... do

    # Apply model validators first
    case apply_model_validators(schema_module, validated_data) do
      {:ok, data_after_model_validators} ->
        # NEW: Populate computed fields
        computed_fields = schema_module.__schema__(:computed_fields) # Assuming this
        
        final_data = 
          Enum.reduce(computed_fields, data_after_model_validators, fn {name, {_type, func}}, acc ->
            computed_value = func.(acc)
            Map.put(acc, name, computed_value)
          end)

        # Create struct with all fields
        if function_exported?(schema_module, :__struct__, 1) do
          {:ok, struct!(schema_module, final_data)}
        else
          {:ok, final_data}
        end
      
      {:error, _} = error ->
        error
    end
  end
end
```

##### **Step 4: Update JSON Schema Generation**

The `Exdantic.JsonSchema` module must be updated to include computed fields in the schema's properties, marking them as `readOnly`.

```elixir
# in exdantic/json_schema.ex (inside generate_schema/2)

defp generate_schema(schema, store) do
  # ... existing logic for regular fields ...
  schema_with_fields = ...

  computed_fields = schema.__schema__(:computed_fields)
  
  # Process computed fields and add them to the schema
  Enum.reduce(computed_fields, schema_with_fields, fn {name, {type, _func}}, acc ->
    field_schema = 
      TypeMapper.to_json_schema(type, store)
      |> Map.put("readOnly", true) # Mark as read-only
      
    # Use Access to safely update nested properties
    put_in(acc, ["properties", Atom.to_string(name)], field_schema)
  end)
end
```

---

### 5. Summary and Dependencies

-   **Feature 1 (Struct Pattern)** is the foundational change. It shifts `Exdantic` from a pure validator to a data modeling tool, which is a prerequisite for the other features to feel natural.
-   **Feature 2 (Model Validators)** builds on this by allowing logic to be applied to the complete, validated `struct` or `map`.
-   **Feature 3 (Computed Fields)** is the most complex, as it touches compilation, validation, and JSON schema generation. It depends on the struct pattern to have a container to populate the computed values into.

Implementing these features in the order presented will provide a logical progression and ensure that dependencies are met, transforming `Exdantic` into a library fully capable of supporting an idiomatic Elixir port of DSPy.
