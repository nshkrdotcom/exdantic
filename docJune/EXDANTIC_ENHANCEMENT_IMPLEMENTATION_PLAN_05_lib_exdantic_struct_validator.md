# lib/exdantic/struct_validator.ex - New module for struct pattern support

defmodule Exdantic.StructValidator do
  @moduledoc """
  Validator that optionally returns struct instances instead of maps.
  
  This module extends the existing validation logic to support returning
  struct instances when a schema is defined with `define_struct: true`.
  
  It acts as a thin wrapper around the existing `Exdantic.Validator` module,
  adding struct creation logic while preserving all existing validation
  behavior and error handling.
  """

  alias Exdantic.{Error, Validator}

  @doc """
  Validates data against a schema, returning struct or map based on schema configuration.

  This function performs the same validation as `Exdantic.Validator.validate_schema/3`,
  but conditionally wraps the result in a struct if the schema was defined with
  `define_struct: true`.

  ## Parameters
    * `schema_module` - The schema module to validate against
    * `data` - The data to validate (must be a map)
    * `path` - Current validation path for error reporting (defaults to `[]`)

  ## Returns
    * `{:ok, validated_data}` - where `validated_data` is a struct if the schema
      defines one, otherwise a map
    * `{:error, errors}` - list of validation errors

  ## Examples

      # Schema without struct
      defmodule MapSchema do
        use Exdantic
        schema do
          field :name, :string
        end
      end

      iex> Exdantic.StructValidator.validate_schema(MapSchema, %{name: "test"})
      {:ok, %{name: "test"}}

      # Schema with struct
      defmodule StructSchema do
        use Exdantic, define_struct: true
        schema do
          field :name, :string
        end
      end

      iex> Exdantic.StructValidator.validate_schema(StructSchema, %{name: "test"})
      {:ok, %StructSchema{name: "test"}}

  ## Error Handling

  All validation errors from the underlying validator are preserved exactly.
  Additional errors may be added if struct creation fails (which should be rare
  and indicates a bug in field extraction logic).

      iex> Exdantic.StructValidator.validate_schema(StructSchema, %{})
      {:error, [%Exdantic.Error{path: [:name], code: :required, message: "field is required"}]}
  """
  @spec validate_schema(module(), map(), [atom() | String.t() | integer()]) :: 
          {:ok, map() | struct()} | {:error, [Error.t()]}
  def validate_schema(schema_module, data, path \\ []) when is_atom(schema_module) do
    # Delegate to existing validator for all validation logic
    case Validator.validate_schema(schema_module, data, path) do
      {:ok, validated_map} ->
        # Check if schema defines a struct and create one if so
        maybe_create_struct(schema_module, validated_map, path)
      
      {:error, errors} ->
        # Pass through validation errors unchanged
        {:error, errors}
    end
  end

  # Private function to conditionally create struct instance
  @spec maybe_create_struct(module(), map(), [atom() | String.t() | integer()]) ::
          {:ok, map() | struct()} | {:error, [Error.t()]}
  defp maybe_create_struct(schema_module, validated_map, path) do
    if struct_enabled?(schema_module) do
      create_struct_instance(schema_module, validated_map, path)
    else
      {:ok, validated_map}
    end
  end

  # Check if schema has struct support enabled
  @spec struct_enabled?(module()) :: boolean()
  defp struct_enabled?(schema_module) do
    function_exported?(schema_module, :__struct_enabled__?, 0) and 
    schema_module.__struct_enabled__?()
  end

  # Create struct instance with error handling
  @spec create_struct_instance(module(), map(), [atom() | String.t() | integer()]) ::
          {:ok, struct()} | {:error, [Error.t()]}
  defp create_struct_instance(schema_module, validated_map, path) do
    try do
      # Use struct!/2 to create the struct instance
      # This should always succeed if our field extraction logic is correct
      validated_struct = struct!(schema_module, validated_map)
      {:ok, validated_struct}
    rescue
      e in ArgumentError ->
        # This should be extremely rare and indicates a bug in our implementation
        # Log the error for debugging while providing a helpful error message
        error_message = """
        Failed to create struct #{inspect(schema_module)} from validated data.
        This indicates a mismatch between struct fields and validation output.
        
        Struct fields: #{inspect(get_struct_fields(schema_module))}
        Validated data keys: #{inspect(Map.keys(validated_map))}
        
        Original error: #{Exception.message(e)}
        """
        
        error = Error.new(path, :struct_creation, String.trim(error_message))
        {:error, [error]}
      
      e ->
        # Handle any other unexpected errors during struct creation
        error_message = "Unexpected error creating struct: #{Exception.message(e)}"
        error = Error.new(path, :struct_creation, error_message)
        {:error, [error]}
    end
  end

  # Get struct field names for debugging
  @spec get_struct_fields(module()) :: [atom()]
  defp get_struct_fields(schema_module) do
    if function_exported?(schema_module, :__struct_fields__, 0) do
      schema_module.__struct_fields__()
    else
      [:unknown]
    end
  end
end
