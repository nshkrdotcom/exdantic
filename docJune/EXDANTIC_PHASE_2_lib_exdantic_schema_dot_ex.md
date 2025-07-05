# lib/exdantic/schema.ex - Add model_validator macro

# Add this macro to the existing Exdantic.Schema module:

@doc """
Defines a model-level validator that runs after field validation.

Model validators receive the validated data (as a map or struct) and can perform
cross-field validation, data transformation, or complex business logic validation.

## Parameters
  * `function_name` - Name of the function to call for model validation

## Function Signature
The referenced function must accept one parameter (the validated data) and return:
  * `{:ok, data}` - validation succeeds, optionally with transformed data
  * `{:error, message}` - validation fails with error message
  * `{:error, %Exdantic.Error{}}` - validation fails with detailed error

## Examples

    defmodule UserSchema do
      use Exdantic, define_struct: true

      schema do
        field :password, :string, required: true
        field :password_confirmation, :string, required: true

        model_validator :validate_passwords_match
      end

      def validate_passwords_match(data) do
        if data.password == data.password_confirmation do
          {:ok, data}
        else
          {:error, "passwords do not match"}
        end
      end
    end

## Multiple Validators
Multiple model validators can be defined and will execute in the order they are declared:

    schema do
      field :username, :string, required: true
      field :email, :string, required: true

      model_validator :validate_username_unique
      model_validator :validate_email_format
      model_validator :send_welcome_email
    end

## Data Transformation
Model validators can transform the data by returning modified data:

    def normalize_email(data) do
      normalized = %{data | email: String.downcase(data.email)}
      {:ok, normalized}
    end
"""
@spec model_validator(atom()) :: Macro.t()
defmacro model_validator(function_name) when is_atom(function_name) do
  quote do
    @model_validators {__MODULE__, unquote(function_name)}
  end
end

# lib/exdantic.ex - Add model_validators to __before_compile__

# Add this to the existing __before_compile__ macro in the quote block:

# Register model validators attribute (add this to __using__ macro)
Module.register_attribute(__MODULE__, :model_validators, accumulate: true)

# Add this to __schema__ function definitions in __before_compile__:
def __schema__(:model_validators), do: @model_validators || []

# lib/exdantic/struct_validator.ex - Enhanced to support model validators

defmodule Exdantic.StructValidator do
  @moduledoc """
  Validator that optionally returns struct instances and executes model validators.
  
  This module extends the existing validation logic to support:
  1. Returning struct instances when a schema is defined with `define_struct: true`
  2. Executing model validators after field validation succeeds
  
  The validation pipeline:
  1. Field validation (existing logic)
  2. Model validation (new)
  3. Struct creation (Phase 1)
  """

  alias Exdantic.{Error, Validator}

  @doc """
  Validates data against a schema with model validator support.

  ## Validation Pipeline
  1. **Field Validation**: Validates individual fields using existing logic
  2. **Model Validation**: Executes model validators in sequence
  3. **Struct Creation**: Optionally creates struct instance

  ## Parameters
    * `schema_module` - The schema module to validate against
    * `data` - The data to validate (must be a map)
    * `path` - Current validation path for error reporting (defaults to `[]`)

  ## Returns
    * `{:ok, validated_data}` - where `validated_data` is a struct if the schema
      defines one, otherwise a map
    * `{:error, errors}` - list of validation errors

  ## Model Validator Execution
  Model validators are executed in the order they are declared in the schema.
  If any model validator returns an error, execution stops and the error is returned.
  Model validators can transform data by returning modified data in the success case.

  ## Examples

      # Basic model validation
      defmodule UserSchema do
        use Exdantic, define_struct: true
        
        schema do
          field :password, :string, required: true
          field :confirmation, :string, required: true
          model_validator :check_passwords
        end
        
        def check_passwords(data) do
          if data.password == data.confirmation do
            {:ok, data}
          else
            {:error, "passwords do not match"}
          end
        end
      end

      iex> UserSchema.validate(%{password: "secret", confirmation: "secret"})
      {:ok, %UserSchema{password: "secret", confirmation: "secret"}}

      iex> UserSchema.validate(%{password: "secret", confirmation: "different"})
      {:error, [%Exdantic.Error{code: :model_validation, message: "passwords do not match"}]}

  ## Error Handling
  Model validators can return errors in several formats:
  - `{:error, "string message"}` - converted to validation error
  - `{:error, %Exdantic.Error{}}` - used directly
  - Exception during execution - caught and converted to validation error
  """
  @spec validate_schema(module(), map(), [atom() | String.t() | integer()]) :: 
          {:ok, map() | struct()} | {:error, [Error.t()]}
  def validate_schema(schema_module, data, path \\ []) when is_atom(schema_module) do
    # Step 1: Field validation (existing logic)
    case Validator.validate_schema(schema_module, data, path) do
      {:ok, validated_map} ->
        # Step 2: Model validation (new)
        case apply_model_validators(schema_module, validated_map, path) do
          {:ok, model_validated_data} ->
            # Step 3: Struct creation (Phase 1)
            maybe_create_struct(schema_module, model_validated_data, path)
          
          {:error, errors} ->
            {:error, errors}
        end
      
      {:error, errors} ->
        # Pass through field validation errors unchanged
        {:error, errors}
    end
  end

  # Apply model validators in sequence
  @spec apply_model_validators(module(), map(), [atom() | String.t() | integer()]) ::
          {:ok, map()} | {:error, [Error.t()]}
  defp apply_model_validators(schema_module, validated_data, path) do
    model_validators = get_model_validators(schema_module)
    
    Enum.reduce_while(model_validators, {:ok, validated_data}, fn 
      {module, function_name}, {:ok, current_data} ->
        case execute_model_validator(module, function_name, current_data, path) do
          {:ok, new_data} -> 
            {:cont, {:ok, new_data}}
          
          {:error, errors} ->
            {:halt, {:error, errors}}
        end
    end)
  end

  # Get model validators for a schema
  @spec get_model_validators(module()) :: [{module(), atom()}]
  defp get_model_validators(schema_module) do
    if function_exported?(schema_module, :__schema__, 1) do
      schema_module.__schema__(:model_validators) || []
    else
      []
    end
  end

  # Execute a single model validator with comprehensive error handling
  @spec execute_model_validator(module(), atom(), map(), [atom() | String.t() | integer()]) ::
          {:ok, map()} | {:error, [Error.t()]}
  defp execute_model_validator(module, function_name, data, path) do
    try do
      case apply(module, function_name, [data]) do
        {:ok, new_data} when is_map(new_data) ->
          {:ok, new_data}
        
        {:error, reason} when is_binary(reason) ->
          error = Error.new(path, :model_validation, reason)
          {:error, [error]}
        
        {:error, %Error{} = error} ->
          # Update error path to include current path context
          updated_error = update_error_path(error, path)
          {:error, [updated_error]}
        
        {:error, errors} when is_list(errors) ->
          # Handle list of errors
          updated_errors = Enum.map(errors, &update_error_path(&1, path))
          {:error, updated_errors}
        
        other ->
          # Invalid return format from model validator
          error_msg = "Model validator #{module}.#{function_name}/1 returned invalid format: #{inspect(other)}. Expected {:ok, data} or {:error, reason}"
          error = Error.new(path, :model_validation, error_msg)
          {:error, [error]}
      end
    rescue
      e in UndefinedFunctionError ->
        error_msg = "Model validator function #{module}.#{function_name}/1 is not defined"
        error = Error.new(path, :model_validation, error_msg)
        {:error, [error]}
      
      e ->
        # Catch any other exceptions during model validator execution
        error_msg = "Model validator #{module}.#{function_name}/1 execution failed: #{Exception.message(e)}"
        error = Error.new(path, :model_validation, error_msg)
        {:error, [error]}
    end
  end

  # Update error path to include current validation context
  @spec update_error_path(Error.t(), [atom() | String.t() | integer()]) :: Error.t()
  defp update_error_path(%Error{path: error_path} = error, current_path) do
    # Only prepend current path if error path is empty or relative
    updated_path = case error_path do
      [] -> current_path
      _ -> current_path ++ error_path
    end
    
    %{error | path: updated_path}
  end

  # Check if schema has struct support enabled (from Phase 1)
  @spec struct_enabled?(module()) :: boolean()
  defp struct_enabled?(schema_module) do
    function_exported?(schema_module, :__struct_enabled__?, 0) and 
    schema_module.__struct_enabled__?()
  end

  # Conditionally create struct instance (from Phase 1)
  @spec maybe_create_struct(module(), map(), [atom() | String.t() | integer()]) ::
          {:ok, map() | struct()} | {:error, [Error.t()]}
  defp maybe_create_struct(schema_module, validated_map, path) do
    if struct_enabled?(schema_module) do
      create_struct_instance(schema_module, validated_map, path)
    else
      {:ok, validated_map}
    end
  end

  # Create struct instance with error handling (from Phase 1)
  @spec create_struct_instance(module(), map(), [atom() | String.t() | integer()]) ::
          {:ok, struct()} | {:error, [Error.t()]}
  defp create_struct_instance(schema_module, validated_map, path) do
    try do
      validated_struct = struct!(schema_module, validated_map)
      {:ok, validated_struct}
    rescue
      e in ArgumentError ->
        error_message = """
        Failed to create struct #{inspect(schema_module)} from validated data.
        This may be caused by model validators adding fields not defined in the struct.
        
        Struct fields: #{inspect(get_struct_fields(schema_module))}
        Validated data keys: #{inspect(Map.keys(validated_map))}
        
        Original error: #{Exception.message(e)}
        """
        
        error = Error.new(path, :struct_creation, String.trim(error_message))
        {:error, [error]}
      
      e ->
        error_message = "Unexpected error creating struct: #{Exception.message(e)}"
        error = Error.new(path, :struct_creation, error_message)
        {:error, [error]}
    end
  end

  # Get struct field names for debugging (from Phase 1)
  @spec get_struct_fields(module()) :: [atom()]
  defp get_struct_fields(schema_module) do
    if function_exported?(schema_module, :__struct_fields__, 0) do
      schema_module.__struct_fields__()
    else
      [:unknown]
    end
  end
end
