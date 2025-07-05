# This code extends exdantic/struct_validator.ex to support computed fields

# Add this to the existing StructValidator module

@doc """
Validates data against a schema with full pipeline support including computed fields.

## Enhanced Validation Pipeline
1. **Field Validation**: Validates individual fields using existing logic
2. **Model Validation**: Executes model validators in sequence (Phase 2)  
3. **Computed Field Execution**: Executes computed fields to derive additional data (Phase 3)
4. **Struct Creation**: Optionally creates struct instance (Phase 1)

## Parameters
  * `schema_module` - The schema module to validate against
  * `data` - The data to validate (must be a map)
  * `path` - Current validation path for error reporting (defaults to `[]`)

## Returns
  * `{:ok, validated_data}` - where `validated_data` includes computed fields and is a struct if the schema defines one, otherwise a map
  * `{:error, errors}` - list of validation errors

## Computed Field Execution
Computed fields are executed after model validation succeeds. Each computed field function:
- Receives the validated data (including any transformations from model validators)
- Must return `{:ok, computed_value}` or `{:error, reason}`
- Has its return value validated against the declared field type
- Contributes to the final validated result

## Examples

    defmodule UserSchema do
      use Exdantic, define_struct: true
      
      schema do
        field :first_name, :string, required: true
        field :last_name, :string, required: true
        field :email, :string, required: true
        
        model_validator :normalize_names
        computed_field :full_name, :string, :generate_full_name
        computed_field :email_domain, :string, :extract_email_domain
      end
      
      def normalize_names(data) do
        normalized = %{
          data | 
          first_name: String.trim(data.first_name),
          last_name: String.trim(data.last_name)
        }
        {:ok, normalized}
      end
      
      def generate_full_name(data) do
        {:ok, "#{data.first_name} #{data.last_name}"}
      end
      
      def extract_email_domain(data) do
        {:ok, data.email |> String.split("@") |> List.last()}
      end
    end

    iex> UserSchema.validate(%{
    ...>   first_name: "  John  ",
    ...>   last_name: "  Doe  ", 
    ...>   email: "john@example.com"
    ...> })
    {:ok, %UserSchema{
      first_name: "John",      # normalized by model validator
      last_name: "Doe",       # normalized by model validator  
      email: "john@example.com",
      full_name: "John Doe",   # computed field
      email_domain: "example.com"  # computed field
    }}

## Error Handling
Computed field errors are handled gracefully:
- Function execution errors are caught and converted to validation errors
- Type validation errors for computed values are reported with field context
- Computed field errors include the field path and computation function reference
"""
@spec validate_schema(module(), map(), [atom() | String.t() | integer()]) ::
        {:ok, map() | struct()} | {:error, [Error.t()]}
def validate_schema(schema_module, data, path \\ []) when is_atom(schema_module) do
  # Step 1: Field validation (existing logic)
  case Validator.validate_schema(schema_module, data, path) do
    {:ok, validated_map} ->
      # Step 2: Model validation (Phase 2)
      case apply_model_validators(schema_module, validated_map, path) do
        {:ok, model_validated_data} ->
          # Step 3: Computed field execution (Phase 3 - NEW)
          case apply_computed_fields(schema_module, model_validated_data, path) do
            {:ok, computed_data} ->
              # Step 4: Struct creation (Phase 1)
              maybe_create_struct(schema_module, computed_data, path)

            {:error, errors} ->
              {:error, errors}
          end

        {:error, errors} ->
          {:error, errors}
      end

    {:error, errors} ->
      # Pass through field validation errors unchanged
      {:error, errors}
  end
end

# Apply computed fields to validated data
@spec apply_computed_fields(module(), map(), [atom() | String.t() | integer()]) ::
        {:ok, map()} | {:error, [Error.t()]}
defp apply_computed_fields(schema_module, validated_data, path) do
  computed_fields = get_computed_fields(schema_module)

  Enum.reduce_while(computed_fields, {:ok, validated_data}, fn
    {field_name, computed_field_meta}, {:ok, current_data} ->
      case execute_computed_field(computed_field_meta, current_data, path) do
        {:ok, computed_value} ->
          # Validate the computed value against its declared type
          field_path = path ++ [field_name]
          case validate_computed_value(computed_field_meta, computed_value, field_path) do
            {:ok, validated_computed_value} ->
              updated_data = Map.put(current_data, field_name, validated_computed_value)
              {:cont, {:ok, updated_data}}
            
            {:error, errors} ->
              {:halt, {:error, errors}}
          end

        {:error, errors} ->
          {:halt, {:error, errors}}
      end
  end)
end

# Get computed fields for a schema
@spec get_computed_fields(module()) :: [{atom(), Exdantic.ComputedFieldMeta.t()}]
defp get_computed_fields(schema_module) do
  if function_exported?(schema_module, :__schema__, 1) do
    schema_module.__schema__(:computed_fields) || []
  else
    []
  end
end

# Execute a single computed field with comprehensive error handling
@spec execute_computed_field(Exdantic.ComputedFieldMeta.t(), map(), [atom() | String.t() | integer()]) ::
        {:ok, term()} | {:error, [Error.t()]}
defp execute_computed_field(computed_field_meta, data, path) do
  field_path = path ++ [computed_field_meta.name]
  
  case apply(computed_field_meta.module, computed_field_meta.function_name, [data]) do
    {:ok, computed_value} ->
      {:ok, computed_value}

    {:error, reason} when is_binary(reason) ->
      error = Error.new(field_path, :computed_field, reason)
      {:error, [error]}

    {:error, %Error{} = error} ->
      # Update error path to include computed field context
      updated_error = update_computed_field_error_path(error, field_path, computed_field_meta)
      {:error, [updated_error]}

    {:error, errors} when is_list(errors) ->
      # Handle list of errors
      updated_errors = Enum.map(errors, &update_computed_field_error_path(&1, field_path, computed_field_meta))
      {:error, updated_errors}

    other ->
      # Invalid return format from computed field function
      function_ref = Exdantic.ComputedFieldMeta.function_reference(computed_field_meta)
      error_msg = 
        "Computed field function #{function_ref} returned invalid format: #{inspect(other)}. " <>
        "Expected {:ok, value} or {:error, reason}"

      error = Error.new(field_path, :computed_field, error_msg)
      {:error, [error]}
  end
rescue
  _e in UndefinedFunctionError ->
    function_ref = Exdantic.ComputedFieldMeta.function_reference(computed_field_meta)
    error_msg = "Computed field function #{function_ref} is not defined"
    error = Error.new(field_path, :computed_field, error_msg)
    {:error, [error]}

  e ->
    # Catch any other exceptions during computed field execution
    function_ref = Exdantic.ComputedFieldMeta.function_reference(computed_field_meta)
    error_msg = 
      "Computed field function #{function_ref} execution failed: #{Exception.message(e)}"

    error = Error.new(field_path, :computed_field, error_msg)
    {:error, [error]}
end

# Validate computed field return value against its declared type
@spec validate_computed_value(Exdantic.ComputedFieldMeta.t(), term(), [atom() | String.t() | integer()]) ::
        {:ok, term()} | {:error, [Error.t()]}
defp validate_computed_value(computed_field_meta, computed_value, field_path) do
  case Exdantic.Validator.validate(computed_field_meta.type, computed_value, field_path) do
    {:ok, validated_value} ->
      {:ok, validated_value}

    {:error, errors} when is_list(errors) ->
      # Add context that this is a computed field type validation error
      contextualized_errors = 
        Enum.map(errors, fn error ->
          enhanced_message = 
            "Computed field type validation failed: #{error.message} " <>
            "(from #{Exdantic.ComputedFieldMeta.function_reference(computed_field_meta)})"
          %{error | message: enhanced_message, code: :computed_field_type}
        end)
      {:error, contextualized_errors}

    {:error, error} ->
      # Single error case
      enhanced_message = 
        "Computed field type validation failed: #{error.message} " <>
        "(from #{Exdantic.ComputedFieldMeta.function_reference(computed_field_meta)})"
      enhanced_error = %{error | message: enhanced_message, code: :computed_field_type}
      {:error, [enhanced_error]}
  end
end

# Update error path to include computed field context
@spec update_computed_field_error_path(Error.t(), [atom() | String.t() | integer()], Exdantic.ComputedFieldMeta.t()) :: Error.t()
defp update_computed_field_error_path(%Error{path: error_path} = error, field_path, computed_field_meta) do
  # Enhance error message to include computed field context
  function_ref = Exdantic.ComputedFieldMeta.function_reference(computed_field_meta)
  enhanced_message = 
    if String.contains?(error.message, function_ref) do
      error.message
    else
      "#{error.message} (in computed field #{function_ref})"
    end

  # Use field path if error path is empty, otherwise combine them
  updated_path = 
    case error_path do
      [] -> field_path
      _ -> field_path ++ error_path
    end

  %{error | path: updated_path, message: enhanced_message}
end

# Update struct creation to include computed fields (enhancement to Phase 1)
@spec maybe_create_struct(module(), map(), [atom() | String.t() | integer()]) ::
        {:ok, map() | struct()} | {:error, [Error.t()]}
defp maybe_create_struct(schema_module, validated_map, path) do
  if struct_enabled?(schema_module) do
    create_struct_instance(schema_module, validated_map, path)
  else
    {:ok, validated_map}
  end
end

# Enhanced struct creation with computed field support
@spec create_struct_instance(module(), map(), [atom() | String.t() | integer()]) ::
        {:ok, struct()} | {:error, [Error.t()]}
defp create_struct_instance(schema_module, validated_map, path) do
  validated_struct = struct!(schema_module, validated_map)
  {:ok, validated_struct}
rescue
  e in ArgumentError ->
    # Get field information for better error messages
    regular_fields = get_struct_fields(schema_module)
    computed_fields = get_computed_fields(schema_module) |> Enum.map(fn {name, _meta} -> name end)
    all_expected_fields = regular_fields ++ computed_fields
    
    error_message = """
    Failed to create struct #{inspect(schema_module)} from validated data.
    This may be caused by computed fields adding unexpected fields or model validators 
    adding fields not defined in the struct.

    Expected struct fields: #{inspect(all_expected_fields)}
    Validated data keys: #{inspect(Map.keys(validated_map))}
    Regular fields: #{inspect(regular_fields)}
    Computed fields: #{inspect(computed_fields)}

    Original error: #{Exception.message(e)}
    """

    error = Error.new(path, :struct_creation, String.trim(error_message))
    {:error, [error]}

  e ->
    error_message = "Unexpected error creating struct: #{Exception.message(e)}"
    error = Error.new(path, :struct_creation, error_message)
    {:error, [error]}
end
