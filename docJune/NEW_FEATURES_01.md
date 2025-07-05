# Exdantic Enhanced Features Implementation

## Design Overview

The three missing features will be implemented in a layered approach:

1. **Struct Pattern**: Modify `exdantic.ex` to optionally generate structs
2. **Model Validators**: Add `model_validator` macro to schema DSL  
3. **Computed Fields**: Add `computed_field` macro with post-validation execution

## Test Plan

```elixir
# test/enhanced_features_test.exs
defmodule ExdanticEnhancedFeaturesTest do
  use ExUnit.Case
  
  describe "struct pattern" do
    test "creates struct when define_struct: true"
    test "returns struct instance from validate/1"
    test "falls back to map when define_struct: false"
    test "struct has correct field types"
    test "handles optional fields in struct"
    test "handles default values in struct"
  end
  
  describe "model validators" do
    test "executes model validator after field validation"
    test "can modify validated data"
    test "returns error when model validation fails"
    test "chains multiple model validators"
    test "model validator receives struct when define_struct: true"
    test "model validator receives map when define_struct: false"
  end
  
  describe "computed fields" do
    test "executes computed field functions after validation"
    test "computed fields appear in struct"
    test "computed fields appear in JSON schema as readOnly"
    test "computed fields can reference other fields"
    test "computed fields handle errors gracefully"
    test "computed fields work with model validators"
  end
  
  describe "integration" do
    test "all features work together"
    test "struct + model validators + computed fields"
    test "runtime schemas support all features"
    test "JSON schema generation includes all fields"
  end
end
```

## Implementation

### 1. Enhanced Schema DSL (exdantic/schema.ex additions)

```elixir
# Add to exdantic/schema.ex

@doc """
Defines a model-level validator that runs after field validation.
"""
defmacro model_validator(validator_fn) do
  quote do
    @model_validators unquote(validator_fn)
  end
end

@doc """
Defines a computed field that is calculated after validation.
"""
defmacro computed_field(name, type, compute_fn) do
  quote do
    field_meta = %Exdantic.FieldMeta{
      name: unquote(name),
      type: unquote(handle_type(type)),
      required: false,  # Computed fields are never required in input
      constraints: []
    }
    
    @computed_fields {unquote(name), {field_meta, unquote(compute_fn)}}
  end
end
```

### 2. Enhanced Main Module (exdantic.ex)

```elixir
# Modify exdantic.ex

defmacro __using__(opts) do
  define_struct? = Keyword.get(opts, :define_struct, false)
  
  quote do
    import Exdantic.Schema

    # Register accumulating attributes
    Module.register_attribute(__MODULE__, :schema_description, [])
    Module.register_attribute(__MODULE__, :fields, accumulate: true)
    Module.register_attribute(__MODULE__, :validations, accumulate: true)
    Module.register_attribute(__MODULE__, :config, [])
    Module.register_attribute(__MODULE__, :model_validators, accumulate: true)
    Module.register_attribute(__MODULE__, :computed_fields, accumulate: true)
    
    # Store struct option
    @exdantic_define_struct unquote(define_struct?)

    @before_compile Exdantic
  end
end

defmacro __before_compile__(env) do
  define_struct? = Module.get_attribute(env.module, :exdantic_define_struct)
  fields = Module.get_attribute(env.module, :fields) || []
  computed_fields = Module.get_attribute(env.module, :computed_fields) || []
  
  # Extract field names for struct
  regular_field_names = Enum.map(fields, fn {name, _meta} -> name end)
  computed_field_names = Enum.map(computed_fields, fn {name, _} -> name end)
  all_field_names = regular_field_names ++ computed_field_names
  
  struct_def = if define_struct? do
    quote do
      defstruct unquote(all_field_names)
      
      @type t :: %__MODULE__{}
      
      @doc """
      Returns the struct definition for this schema.
      """
      def __struct_fields__, do: unquote(all_field_names)
    end
  else
    quote do
      # No struct definition
    end
  end
  
  quote do
    # Inject struct definition if requested
    unquote(struct_def)

    # Define __schema__ functions
    def __schema__(:description), do: @schema_description
    def __schema__(:fields), do: @fields
    def __schema__(:validations), do: @validations
    def __schema__(:config), do: @config
    def __schema__(:model_validators), do: @model_validators
    def __schema__(:computed_fields), do: @computed_fields
    
    # Enhanced validation function
    @doc """
    Validates data against this schema with enhanced features.
    """
    def validate(data) do
      Exdantic.EnhancedSchemaValidator.validate_schema(__MODULE__, data)
    end
    
    @doc """
    Validates data against this schema, raising an exception on failure.
    """
    def validate!(data) do
      case validate(data) do
        {:ok, validated} -> validated
        {:error, errors} -> raise Exdantic.ValidationError, errors: errors
      end
    end
    
    @doc """
    Serializes a validated struct back to a map.
    """
    def dump(struct_or_map) do
      Exdantic.EnhancedSchemaValidator.dump(__MODULE__, struct_or_map)
    end
  end
end
```

### 3. Enhanced Schema Validator (exdantic/enhanced_schema_validator.ex)

```elixir
# New file: exdantic/enhanced_schema_validator.ex

defmodule Exdantic.EnhancedSchemaValidator do
  @moduledoc """
  Enhanced validation that supports struct pattern, model validators, and computed fields.
  """
  
  alias Exdantic.{Error, FieldMeta}
  
  @doc """
  Validates data against an enhanced schema with all new features.
  """
  def validate_schema(schema_module, data, path \\ []) when is_atom(schema_module) do
    # Get schema metadata
    fields = schema_module.__schema__(:fields) || []
    config = schema_module.__schema__(:config) || %{}
    model_validators = schema_module.__schema__(:model_validators) || []
    computed_fields = schema_module.__schema__(:computed_fields) || []
    
    with {:ok, validated_data} <- validate_basic_fields(fields, data, config, path),
         {:ok, model_validated_data} <- apply_model_validators(model_validators, validated_data, path),
         {:ok, final_data} <- apply_computed_fields(computed_fields, model_validated_data, path) do
      
      # Create struct if defined, otherwise return map
      if function_exported?(schema_module, :__struct__, 1) do
        {:ok, struct!(schema_module, final_data)}
      else
        {:ok, final_data}
      end
    end
  end
  
  @doc """
  Serializes a struct or map back to a plain map.
  """
  def dump(schema_module, struct_or_map) do
    case struct_or_map do
      %{__struct__: ^schema_module} = struct ->
        # Convert struct to map, excluding computed fields from serialization if desired
        {:ok, Map.from_struct(struct)}
      
      map when is_map(map) ->
        {:ok, map}
      
      _ ->
        {:error, "Expected struct of type #{schema_module} or map"}
    end
  end
  
  # Private helper functions
  
  defp validate_basic_fields(fields, data, config, path) do
    # Use existing field validation logic from Validator
    Exdantic.Validator.validate_schema_fields(fields, data, config, path)
  end
  
  defp apply_model_validators([], validated_data, _path) do
    {:ok, validated_data}
  end
  
  defp apply_model_validators(model_validators, validated_data, path) do
    Enum.reduce_while(model_validators, {:ok, validated_data}, fn validator_fn, {:ok, current_data} ->
      case validator_fn.(current_data) do
        {:ok, new_data} -> 
          {:cont, {:ok, new_data}}
        
        {:error, reason} when is_binary(reason) -> 
          error = Error.new(path, :model_validation, reason)
          {:halt, {:error, [error]}}
        
        {:error, %Error{} = error} ->
          # Update error path if not already set
          updated_error = %{error | path: path ++ error.path}
          {:halt, {:error, [updated_error]}}
        
        {:error, errors} when is_list(errors) ->
          {:halt, {:error, errors}}
        
        other ->
          error = Error.new(path, :model_validation, "Model validator returned invalid format: #{inspect(other)}")
          {:halt, {:error, [error]}}
      end
    end)
  end
  
  defp apply_computed_fields([], validated_data, _path) do
    {:ok, validated_data}
  end
  
  defp apply_computed_fields(computed_fields, validated_data, path) do
    try do
      computed_data = 
        Enum.reduce(computed_fields, validated_data, fn {name, {_field_meta, compute_fn}}, acc ->
          computed_value = compute_fn.(acc)
          Map.put(acc, name, computed_value)
        end)
      
      {:ok, computed_data}
    rescue
      error ->
        error_msg = "Computed field calculation failed: #{inspect(error)}"
        {:error, [Error.new(path, :computed_field, error_msg)]}
    end
  end
end
```

### 4. Enhanced JSON Schema Generation (exdantic/json_schema.ex modifications)

```elixir
# Add to exdantic/json_schema.ex

defp generate_schema(schema, store) do
  # ... existing logic ...
  
  # Get computed fields
  computed_fields = if function_exported?(schema, :__schema__, 1) do
    schema.__schema__(:computed_fields) || []
  else
    []
  end
  
  # Add computed fields to schema
  schema_with_computed = 
    Enum.reduce(computed_fields, schema_with_fields, fn {name, {field_meta, _compute_fn}}, acc ->
      # Convert computed field type to JSON schema
      field_schema = 
        TypeMapper.to_json_schema(field_meta.type, store)
        |> Map.put("readOnly", true)  # Mark as read-only
        |> Map.put("description", field_meta.description || "Computed field")
      
      # Add to properties
      properties = Map.get(acc, "properties", %{})
      updated_properties = Map.put(properties, Atom.to_string(name), field_schema)
      Map.put(acc, "properties", updated_properties)
    end)
  
  schema_with_computed
end
```

### 5. Enhanced Runtime Support (exdantic/runtime.ex modifications)

```elixir
# Add to exdantic/runtime.ex

@doc """
Creates a runtime schema with enhanced features support.
"""
def create_enhanced_schema(field_definitions, opts \\ []) do
  # Extract enhanced options
  model_validators = Keyword.get(opts, :model_validators, [])
  computed_fields = Keyword.get(opts, :computed_fields, [])
  
  # Create base schema
  base_schema = create_schema(field_definitions, opts)
  
  # Add enhanced metadata
  enhanced_metadata = Map.merge(base_schema.metadata, %{
    model_validators: model_validators,
    computed_fields: computed_fields,
    enhanced: true
  })
  
  %{base_schema | metadata: enhanced_metadata}
end

@doc """
Validates data against an enhanced runtime schema.
"""
def validate_enhanced(data, %DynamicSchema{} = schema, opts \\ []) do
  # Extract enhanced features from metadata
  model_validators = get_in(schema.metadata, [:model_validators]) || []
  computed_fields = get_in(schema.metadata, [:computed_fields]) || []
  
  path = Keyword.get(opts, :path, [])
  
  with {:ok, validated_data} <- validate(data, schema, opts),
       {:ok, model_validated} <- apply_runtime_model_validators(model_validators, validated_data, path),
       {:ok, final_data} <- apply_runtime_computed_fields(computed_fields, model_validated, path) do
    {:ok, final_data}
  end
end

# Private helpers for runtime enhanced features
defp apply_runtime_model_validators([], data, _path), do: {:ok, data}
defp apply_runtime_model_validators(validators, data, path) do
  # Similar to enhanced schema validator but for runtime
  Enum.reduce_while(validators, {:ok, data}, fn validator_fn, {:ok, current_data} ->
    case validator_fn.(current_data) do
      {:ok, new_data} -> {:cont, {:ok, new_data}}
      {:error, reason} -> 
        error = Error.new(path, :model_validation, reason)
        {:halt, {:error, [error]}}
    end
  end)
end

defp apply_runtime_computed_fields([], data, _path), do: {:ok, data}
defp apply_runtime_computed_fields(computed_fields, data, path) do
  try do
    computed_data = 
      Enum.reduce(computed_fields, data, fn {name, compute_fn}, acc ->
        computed_value = compute_fn.(acc)
        Map.put(acc, name, computed_value)
      end)
    
    {:ok, computed_data}
  rescue
    error ->
      error_msg = "Runtime computed field failed: #{inspect(error)}"
      {:error, [Error.new(path, :computed_field, error_msg)]}
  end
end
```

### 6. Integration with EnhancedValidator

```elixir
# Add to exdantic/enhanced_validator.ex

def validate(schema_module, input, opts) when is_atom(schema_module) do
  if function_exported?(schema_module, :__schema__, 1) do
    # Check if it's an enhanced schema (has new features)
    has_enhanced_features = 
      function_exported?(schema_module, :__schema__, 1) and
      (length(schema_module.__schema__(:model_validators) || []) > 0 or
       length(schema_module.__schema__(:computed_fields) || []) > 0)
    
    if has_enhanced_features do
      # Use enhanced validator
      config = Keyword.get(opts, :config, Config.create())
      EnhancedSchemaValidator.validate_schema(schema_module, input)
    else
      # Use standard validator
      config = Keyword.get(opts, :config, Config.create())
      validation_opts = Config.to_validation_opts(config)
      Validator.validate_schema(schema_module, input, validation_opts[:path] || [])
    end
  else
    # Handle as type spec
    validate_type_spec(schema_module, input, opts)
  end
end
```

### 7. Usage Examples

```elixir
# Example 1: Basic struct pattern
defmodule UserSchema do
  use Exdantic, define_struct: true
  
  schema do
    field :name, :string, required: true
    field :age, :integer, required: true
  end
end

# Returns: {:ok, %UserSchema{name: "John", age: 30}}
UserSchema.validate(%{name: "John", age: 30})

# Example 2: Model validator
defmodule PasswordSchema do
  use Exdantic, define_struct: true
  
  schema do
    field :password, :string, required: true
    field :password_confirmation, :string, required: true
    
    model_validator fn data ->
      if data.password == data.password_confirmation do
        {:ok, data}
      else
        {:error, "passwords do not match"}
      end
    end
  end
end

# Example 3: Computed fields
defmodule PersonSchema do
  use Exdantic, define_struct: true
  
  schema do
    field :first_name, :string, required: true
    field :last_name, :string, required: true
    
    computed_field :full_name, :string, fn data ->
      "#{data.first_name} #{data.last_name}"
    end
    
    computed_field :initials, :string, fn data ->
      first_initial = String.first(data.first_name)
      last_initial = String.first(data.last_name) 
      "#{first_initial}.#{last_initial}."
    end
  end
end

# Returns: {:ok, %PersonSchema{first_name: "John", last_name: "Doe", full_name: "John Doe", initials: "J.D."}}
PersonSchema.validate(%{first_name: "John", last_name: "Doe"})

# Example 4: All features together
defmodule DSPyOutputSchema do
  use Exdantic, define_struct: true
  
  schema "DSPy program output with validation" do
    field :reasoning, :string, required: true, min_length: 10
    field :answer, :string, required: true
    field :confidence, :float, required: true
    
    # Cross-field validation
    model_validator fn data ->
      if data.confidence >= 0.0 and data.confidence <= 1.0 do
        {:ok, data}
      else
        {:error, "confidence must be between 0.0 and 1.0"}
      end
    end
    
    # Computed quality score
    computed_field :quality_score, :float, fn data ->
      reasoning_score = min(String.length(data.reasoning) / 100.0, 1.0)
      answer_score = min(String.length(data.answer) / 50.0, 1.0)
      (reasoning_score + answer_score + data.confidence) / 3.0
    end
    
    # Computed metadata
    computed_field :metadata, :map, fn data ->
      %{
        reasoning_length: String.length(data.reasoning),
        answer_length: String.length(data.answer),
        generated_at: DateTime.utc_now()
      }
    end
  end
end

# Runtime usage with enhanced features
enhanced_schema = Exdantic.Runtime.create_enhanced_schema([
  {:input, :string, [required: true]},
  {:output, :string, [required: true]}
], 
  model_validators: [
    fn data -> 
      if String.length(data.input) > 0, do: {:ok, data}, else: {:error, "input required"}
    end
  ],
  computed_fields: [
    {:processing_time, fn _data -> System.monotonic_time(:millisecond) end}
  ]
)

Exdantic.Runtime.validate_enhanced(%{input: "test", output: "result"}, enhanced_schema)
```

## Migration Strategy

1. **Phase 1**: Implement struct pattern (backward compatible)
2. **Phase 2**: Add model validators to DSL
3. **Phase 3**: Add computed fields support  
4. **Phase 4**: Integrate with runtime schemas
5. **Phase 5**: Update JSON schema generation

All existing code remains functional - these are additive enhancements.
