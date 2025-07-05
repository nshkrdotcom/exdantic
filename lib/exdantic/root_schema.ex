defmodule Exdantic.RootSchema do
  @moduledoc """
  RootSchema allows validation of non-dictionary types at the top level.

  Similar to Pydantic's RootModel, this enables validation of values that are not
  maps/objects, such as arrays, primitives, or other structured data at the root level.

  ## Examples

      # Validate a list of integers
      defmodule IntegerListSchema do
        use Exdantic.RootSchema, root: {:array, :integer}
      end

      {:ok, [1, 2, 3]} = IntegerListSchema.validate([1, 2, 3])

      # Validate a single string with constraints
      defmodule EmailSchema do
        use Exdantic.RootSchema,
          root: {:type, :string, [format: ~r/^[^\s@]+@[^\s@]+\.[^\s@]+$/]}
      end

      {:ok, "user@example.com"} = EmailSchema.validate("user@example.com")

      # Validate a union type
      defmodule StringOrNumberSchema do
        use Exdantic.RootSchema, root: {:union, [:string, :integer]}
      end

      {:ok, "hello"} = StringOrNumberSchema.validate("hello")
      {:ok, 42} = StringOrNumberSchema.validate(42)
  """

  alias Exdantic.JsonSchema
  alias Exdantic.Validator

  @doc """
  Configures a module to be a RootSchema for validating non-dictionary types.

  ## Options

    * `:root` - The type definition for the root value. This can be any valid
      Exdantic type definition including basic types, arrays, maps, unions, etc.

  ## Examples

      # Simple array validation
      defmodule NumberListSchema do
        use Exdantic.RootSchema, root: {:array, :integer}
      end

      # Complex nested structure
      defmodule NestedSchema do
        use Exdantic.RootSchema,
          root: {:array, {:map, {:string, {:union, [:string, :integer]}}}}
      end

      # Reference to another schema
      defmodule UserListSchema do
        use Exdantic.RootSchema, root: {:array, UserSchema}
      end
  """
  @spec __using__(keyword()) :: Macro.t()
  defmacro __using__(opts) do
    root_type = Keyword.get(opts, :root)

    if is_nil(root_type) do
      raise ArgumentError, "RootSchema requires a :root option specifying the root type"
    end

    quote do
      @root_type unquote(root_type)

      @doc """
      Validates data against the root type definition.

      ## Parameters
        * `data` - The data to validate (can be any type)

      ## Returns
        * `{:ok, validated_data}` on success
        * `{:error, errors}` on validation failures

      ## Examples

          {:ok, validated} = MyRootSchema.validate(input_data)
      """
      @spec validate(term()) ::
              {:ok, term()} | {:error, Exdantic.Error.t() | [Exdantic.Error.t()]}
      def validate(data) do
        Exdantic.RootSchema.validate_root(@root_type, data)
      end

      @doc """
      Validates data against the root type definition, raising on error.

      ## Parameters
        * `data` - The data to validate (can be any type)

      ## Returns
        * `validated_data` on success
        * Raises `Exdantic.ValidationError` on validation failures

      ## Examples

          validated = MyRootSchema.validate!(input_data)
      """
      @spec validate!(term()) :: term() | no_return()
      def validate!(data) do
        case validate(data) do
          {:ok, validated} -> validated
          {:error, errors} -> raise Exdantic.ValidationError, errors: List.wrap(errors)
        end
      end

      @doc """
      Returns the root type definition for this schema.

      ## Returns
        * The type definition used for validation

      ## Examples

          root_type = MyRootSchema.root_type()
      """
      @spec root_type() :: term()
      def root_type, do: @root_type

      @doc """
      Generates a JSON Schema representation of the root type.

      ## Returns
        * A map representing the JSON Schema

      ## Examples

          json_schema = MyRootSchema.json_schema()
      """
      @spec json_schema() :: map()
      def json_schema do
        Exdantic.RootSchema.to_json_schema(@root_type)
      end

      @doc """
      Returns schema metadata for introspection.

      ## Returns
        * A map containing schema information

      ## Examples

          info = MyRootSchema.__schema__(:info)
      """
      @spec __schema__(atom()) :: term()
      def __schema__(:root_type), do: @root_type
      def __schema__(:type), do: :root_schema
      def __schema__(:json_schema), do: json_schema()
      def __schema__(_), do: nil
    end
  end

  @doc """
  Validates data against a root type definition.

  This is the core validation function used by RootSchema modules.

  ## Parameters
    * `root_type` - The type definition to validate against
    * `data` - The data to validate

  ## Returns
    * `{:ok, validated_data}` on success
    * `{:error, errors}` on validation failures
  """
  @spec validate_root(term(), term()) ::
          {:ok, term()} | {:error, Exdantic.Error.t() | [Exdantic.Error.t()]}
  def validate_root(root_type, data) do
    normalized_type = normalize_root_type(root_type)
    Validator.validate(normalized_type, data, [])
  end

  # Normalize root types to the format expected by the validator
  @spec normalize_root_type(term()) :: term()
  defp normalize_root_type({:array, inner_type}) do
    {:array, normalize_root_type(inner_type), []}
  end

  defp normalize_root_type({:array, inner_type, constraints}) do
    {:array, normalize_root_type(inner_type), constraints}
  end

  defp normalize_root_type({:map, {key_type, value_type}}) do
    {:map, {normalize_root_type(key_type), normalize_root_type(value_type)}, []}
  end

  defp normalize_root_type({:map, {key_type, value_type}, constraints}) do
    {:map, {normalize_root_type(key_type), normalize_root_type(value_type)}, constraints}
  end

  defp normalize_root_type({:union, types}) when is_list(types) do
    {:union, Enum.map(types, &normalize_root_type/1), []}
  end

  defp normalize_root_type({:union, types, constraints}) when is_list(types) do
    {:union, Enum.map(types, &normalize_root_type/1), constraints}
  end

  defp normalize_root_type({:tuple, types}) when is_list(types) do
    {:tuple, Enum.map(types, &normalize_root_type/1)}
  end

  defp normalize_root_type({:type, type, constraints}) do
    {:type, type, constraints}
  end

  defp normalize_root_type(type) when is_atom(type) do
    cond do
      # Check if it's a basic type
      type in [:string, :integer, :float, :boolean, :any, :atom, :map] ->
        {:type, type, []}

      # Check if it's a schema module
      Code.ensure_loaded?(type) and function_exported?(type, :__schema__, 1) ->
        {:ref, type}

      # Otherwise, treat as a type reference
      true ->
        {:type, type, []}
    end
  end

  defp normalize_root_type(type), do: type

  @doc """
  Converts a root type definition to a JSON Schema.

  ## Parameters
    * `root_type` - The type definition to convert

  ## Returns
    * A map representing the JSON Schema
  """
  @spec to_json_schema(term()) :: map()
  def to_json_schema(root_type) do
    # Create a reference store for schema references
    {:ok, store} = JsonSchema.ReferenceStore.start_link()

    try do
      # Normalize the type first
      normalized_type = normalize_root_type(root_type)

      # Use TypeMapper to convert the root type
      result = JsonSchema.TypeMapper.to_json_schema(normalized_type, store)

      # Add definitions if there are any references
      definitions = JsonSchema.ReferenceStore.get_definitions(store)

      if map_size(definitions) > 0 do
        Map.put(result, "definitions", definitions)
      else
        result
      end
    after
      JsonSchema.ReferenceStore.stop(store)
    end
  end
end
