defmodule Exdantic.TypeAdapter do
  @moduledoc """
  Runtime type validation and serialization without a schema.

  This module provides the equivalent of Pydantic's TypeAdapter functionality,
  allowing validation and serialization of values against type specifications
  without requiring a full schema definition.

  Supports the DSPy pattern: `TypeAdapter(type(value)).validate_python(value)`
  """

  alias Exdantic.{JsonSchema, Types, Validator}
  alias Exdantic.JsonSchema.Resolver
  alias Exdantic.TypeAdapter.Instance

  @type type_spec :: Types.type_definition() | atom() | module() | term()
  @type validation_options :: [
          coerce: boolean(),
          strict: boolean(),
          path: [atom() | String.t()]
        ]
  @type dump_options :: [
          exclude_none: boolean(),
          exclude_defaults: boolean()
        ]

  @doc """
  Validates a value against a type specification.

  ## Parameters
    * `type_spec` - The type specification to validate against
    * `value` - The value to validate
    * `opts` - Validation options

  ## Options
    * `:coerce` - Enable type coercion (default: false)
    * `:strict` - Enable strict validation (default: false)
    * `:path` - Validation path for error reporting (default: [])

  ## Returns
    * `{:ok, validated_value}` on success
    * `{:error, errors}` on validation failure

  ## Examples

      iex> Exdantic.TypeAdapter.validate(:string, "hello")
      {:ok, "hello"}

      iex> Exdantic.TypeAdapter.validate(:integer, "123", coerce: true)
      {:ok, 123}

      iex> Exdantic.TypeAdapter.validate({:array, :string}, ["a", "b", "c"])
      {:ok, ["a", "b", "c"]}

      iex> Exdantic.TypeAdapter.validate(:integer, "not a number")
      {:error, [%Exdantic.Error{...}]}
  """
  @spec validate(type_spec(), term(), validation_options()) ::
          {:ok, term()} | {:error, [Exdantic.Error.t()]}
  def validate(type_spec, value, opts \\ []) do
    path = Keyword.get(opts, :path, [])
    coerce = Keyword.get(opts, :coerce, false)

    try do
      normalized_type = normalize_type_spec(type_spec)
      value_to_validate = maybe_coerce_value(normalized_type, value, coerce)
      perform_validation(normalized_type, value_to_validate, path)
    rescue
      _e in [FunctionClauseError, MatchError] ->
        reraise ArgumentError, "Invalid type specification: #{inspect(type_spec)}", __STACKTRACE__
    end
  end

  @spec maybe_coerce_value(Types.type_definition(), term(), boolean()) :: term()
  defp maybe_coerce_value(type, value, true) do
    case attempt_coercion(type, value) do
      {:ok, coerced} -> coerced
      {:error, _} -> value
    end
  end

  defp maybe_coerce_value(_type, value, false), do: value

  @spec perform_validation(Types.type_definition(), term(), [atom() | String.t() | integer()]) ::
          {:ok, term()} | {:error, [Exdantic.Error.t()]}
  defp perform_validation({:ref, schema_module}, value, _path) when is_atom(schema_module) do
    validate_schema_reference(schema_module, value)
  end

  defp perform_validation(type, value, path) do
    validate_basic_type(type, value, path)
  end

  @spec validate_schema_reference(module(), term()) ::
          {:ok, term()} | {:error, [Exdantic.Error.t()]}
  defp validate_schema_reference(schema_module, value) do
    case schema_module.validate(value) do
      {:ok, validated} -> {:ok, validated}
      {:error, error} when is_struct(error, Exdantic.Error) -> {:error, [error]}
      {:error, errors} when is_list(errors) -> {:error, errors}
      {:error, error} -> {:error, [error]}
    end
  end

  @spec validate_basic_type(Types.type_definition(), term(), [atom() | String.t() | integer()]) ::
          {:ok, term()} | {:error, [Exdantic.Error.t()]}
  defp validate_basic_type(type, value, path) do
    case Validator.validate(type, value, path) do
      {:ok, validated} -> {:ok, validated}
      {:error, error} when is_struct(error, Exdantic.Error) -> {:error, [error]}
      {:error, errors} when is_list(errors) -> {:error, errors}
      {:error, error} -> {:error, [error]}
    end
  end

  @doc """
  Serializes a value according to a type specification.

  ## Parameters
    * `type_spec` - The type specification to serialize according to
    * `value` - The value to serialize
    * `opts` - Serialization options

  ## Options
    * `:exclude_none` - Exclude nil values (default: false)
    * `:exclude_defaults` - Exclude default values (default: false)

  ## Returns
    * `{:ok, serialized_value}` on success
    * `{:error, reason}` on serialization failure

  ## Examples

      iex> Exdantic.TypeAdapter.dump(:string, "hello")
      {:ok, "hello"}

      iex> Exdantic.TypeAdapter.dump({:map, {:string, :any}}, %{name: "John", age: 30})
      {:ok, %{"name" => "John", "age" => 30}}
  """
  @spec dump(type_spec(), term(), dump_options()) :: {:ok, term()} | {:error, String.t()}
  def dump(type_spec, value, opts \\ []) do
    exclude_none = Keyword.get(opts, :exclude_none, false)
    exclude_defaults = Keyword.get(opts, :exclude_defaults, false)

    normalized_type = normalize_type_spec(type_spec)

    case serialize_value(normalized_type, value, exclude_none, exclude_defaults) do
      {:ok, serialized} -> {:ok, serialized}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Generates JSON Schema for a type specification.

  ## Parameters
    * `type_spec` - The type specification to generate schema for
    * `opts` - JSON Schema generation options

  ## Options
    * `:title` - Schema title
    * `:description` - Schema description
    * `:resolve_refs` - Resolve all references inline (default: false)

  ## Returns
    * JSON Schema map

  ## Examples

      iex> Exdantic.TypeAdapter.json_schema(:string)
      %{"type" => "string"}

      iex> Exdantic.TypeAdapter.json_schema({:array, :integer})
      %{"type" => "array", "items" => %{"type" => "integer"}}

      iex> Exdantic.TypeAdapter.json_schema({:union, [:string, :integer]})
      %{"oneOf" => [%{"type" => "string"}, %{"type" => "integer"}]}
  """
  @spec json_schema(type_spec(), keyword()) :: map()
  def json_schema(type_spec, opts \\ []) do
    normalized_type = normalize_type_spec(type_spec)

    {:ok, store} = JsonSchema.ReferenceStore.start_link()

    try do
      base_schema = JsonSchema.TypeMapper.to_json_schema(normalized_type, store)

      # Add optional metadata
      schema_with_metadata =
        base_schema
        |> maybe_add_title(Keyword.get(opts, :title))
        |> maybe_add_description(Keyword.get(opts, :description))

      # Add definitions if any references were created
      definitions = JsonSchema.ReferenceStore.get_definitions(store)

      final_schema =
        if map_size(definitions) > 0 do
          Map.put(schema_with_metadata, "definitions", definitions)
        else
          schema_with_metadata
        end

      # Resolve references if requested
      if Keyword.get(opts, :resolve_refs, false) do
        Resolver.resolve_references(final_schema)
      else
        final_schema
      end
    after
      JsonSchema.ReferenceStore.stop(store)
    end
  end

  @doc """
  Creates a TypeAdapter instance for reuse with the same type specification.

  ## Parameters
    * `type_spec` - The type specification to create an adapter for
    * `opts` - Configuration options for the adapter

  ## Returns
    * TypeAdapter struct

  ## Examples

      iex> adapter = Exdantic.TypeAdapter.create({:array, :string})
      %Exdantic.TypeAdapter.Instance{...}

      iex> Exdantic.TypeAdapter.Instance.validate(adapter, ["a", "b", "c"])
      {:ok, ["a", "b", "c"]}
  """
  @spec create(type_spec(), keyword()) :: Instance.t()
  def create(type_spec, opts \\ []) do
    Instance.new(type_spec, opts)
  end

  # Private helper functions

  @spec normalize_type_spec(type_spec()) :: Types.type_definition()
  defp normalize_type_spec(type_spec) do
    Types.normalize_type(type_spec)
  end

  @spec attempt_coercion(Types.type_definition(), term()) :: {:ok, term()} | {:error, String.t()}
  defp attempt_coercion({:type, base_type, _}, value) do
    Types.coerce(base_type, value)
  end

  defp attempt_coercion({:array, inner_type, _}, value) when is_list(value) do
    results =
      Enum.map(value, fn item ->
        attempt_coercion(inner_type, item)
      end)

    case Enum.split_with(results, &match?({:ok, _}, &1)) do
      {oks, []} ->
        coerced_values = Enum.map(oks, fn {:ok, val} -> val end)
        {:ok, coerced_values}

      {_, errors} ->
        first_error = hd(errors)
        {:error, "array coercion failed: #{elem(first_error, 1)}"}
    end
  end

  defp attempt_coercion({:map, {key_type, value_type}, _}, value) when is_map(value) do
    results =
      Enum.map(value, fn {k, v} ->
        with {:ok, coerced_key} <- attempt_coercion(key_type, k),
             {:ok, coerced_value} <- attempt_coercion(value_type, v) do
          {:ok, {coerced_key, coerced_value}}
        else
          error -> error
        end
      end)

    case Enum.split_with(results, &match?({:ok, _}, &1)) do
      {oks, []} ->
        coerced_map = Map.new(Enum.map(oks, fn {:ok, kv} -> kv end))
        {:ok, coerced_map}

      {_, errors} ->
        first_error = hd(errors)
        {:error, "map coercion failed: #{elem(first_error, 1)}"}
    end
  end

  defp attempt_coercion({:union, types, _}, value) do
    # Try coercion with each type in the union
    Enum.reduce_while(types, {:error, "no type in union could coerce value"}, fn type, acc ->
      case attempt_coercion(type, value) do
        {:ok, coerced} -> {:halt, {:ok, coerced}}
        {:error, _} -> {:cont, acc}
      end
    end)
  end

  defp attempt_coercion({:tuple, types}, value) when is_tuple(value) do
    value_list = Tuple.to_list(value)

    if length(value_list) == length(types) do
      results =
        Enum.zip(types, value_list)
        |> Enum.map(fn {type, val} ->
          attempt_coercion(type, val)
        end)

      case Enum.split_with(results, &match?({:ok, _}, &1)) do
        {oks, []} ->
          coerced_values = Enum.map(oks, fn {:ok, val} -> val end)
          {:ok, List.to_tuple(coerced_values)}

        {_, errors} ->
          first_error = hd(errors)
          {:error, "tuple coercion failed: #{elem(first_error, 1)}"}
      end
    else
      {:error, "tuple size mismatch"}
    end
  end

  defp attempt_coercion(_, value) do
    # No coercion needed/possible
    {:ok, value}
  end

  @spec serialize_value(Types.type_definition(), term(), boolean(), boolean()) ::
          {:ok, term()} | {:error, String.t()}
  defp serialize_value({:type, :string, _}, value, _, _) when is_binary(value) do
    {:ok, value}
  end

  defp serialize_value({:type, :integer, _}, value, _, _) when is_integer(value) do
    {:ok, value}
  end

  defp serialize_value({:type, :float, _}, value, _, _) when is_float(value) do
    {:ok, value}
  end

  defp serialize_value({:type, :boolean, _}, value, _, _) when is_boolean(value) do
    {:ok, value}
  end

  defp serialize_value({:type, :atom, _}, value, _, _) when is_atom(value) do
    {:ok, Atom.to_string(value)}
  end

  defp serialize_value({:type, :any, _}, value, _, _) do
    {:ok, value}
  end

  defp serialize_value({:array, inner_type, _}, value, exclude_none, exclude_defaults)
       when is_list(value) do
    results =
      Enum.map(value, fn item ->
        serialize_value(inner_type, item, exclude_none, exclude_defaults)
      end)

    case Enum.split_with(results, &match?({:ok, _}, &1)) do
      {oks, []} ->
        serialized_items = Enum.map(oks, fn {:ok, val} -> val end)

        filtered_items =
          if exclude_none do
            Enum.reject(serialized_items, &is_nil/1)
          else
            serialized_items
          end

        {:ok, filtered_items}

      {_, errors} ->
        first_error = hd(errors)
        {:error, "array serialization failed: #{elem(first_error, 1)}"}
    end
  end

  defp serialize_value({:map, {key_type, value_type}, _}, value, exclude_none, exclude_defaults)
       when is_map(value) do
    results =
      Enum.map(value, fn {k, v} ->
        with {:ok, serialized_key} <-
               serialize_value(key_type, k, exclude_none, exclude_defaults),
             {:ok, serialized_value} <-
               serialize_value(value_type, v, exclude_none, exclude_defaults) do
          {:ok, {serialized_key, serialized_value}}
        else
          error -> error
        end
      end)

    case Enum.split_with(results, &match?({:ok, _}, &1)) do
      {oks, []} ->
        serialized_map = Map.new(Enum.map(oks, fn {:ok, kv} -> kv end))

        filtered_map =
          if exclude_none do
            Map.reject(serialized_map, fn {_, v} -> is_nil(v) end)
          else
            serialized_map
          end

        {:ok, filtered_map}

      {_, errors} ->
        first_error = hd(errors)
        {:error, "map serialization failed: #{elem(first_error, 1)}"}
    end
  end

  defp serialize_value({:union, types, _}, value, exclude_none, exclude_defaults) do
    # Try serialization with each type until one succeeds
    Enum.reduce_while(types, {:error, "no type in union could serialize value"}, fn type, acc ->
      case serialize_value(type, value, exclude_none, exclude_defaults) do
        {:ok, serialized} -> {:halt, {:ok, serialized}}
        {:error, _} -> {:cont, acc}
      end
    end)
  end

  defp serialize_value({:tuple, types}, value, exclude_none, exclude_defaults)
       when is_tuple(value) do
    value_list = Tuple.to_list(value)

    if length(value_list) == length(types) do
      results =
        Enum.zip(types, value_list)
        |> Enum.map(fn {type, val} ->
          serialize_value(type, val, exclude_none, exclude_defaults)
        end)

      case Enum.split_with(results, &match?({:ok, _}, &1)) do
        {oks, []} ->
          serialized_items = Enum.map(oks, fn {:ok, val} -> val end)
          {:ok, serialized_items}

        {_, errors} ->
          first_error = hd(errors)
          {:error, "tuple serialization failed: #{elem(first_error, 1)}"}
      end
    else
      {:error, "tuple size mismatch"}
    end
  end

  defp serialize_value({:ref, schema}, value, exclude_none, exclude_defaults)
       when is_atom(schema) do
    # For schema references, validate and then serialize as map
    case validate(schema, value) do
      {:ok, validated} ->
        serialize_value({:type, :map, []}, validated, exclude_none, exclude_defaults)

      {:error, _} = error ->
        error
    end
  end

  defp serialize_value(_, value, _, _) do
    # Default: return value as-is
    {:ok, value}
  end

  @spec maybe_add_title(map(), String.t() | nil) :: map()
  defp maybe_add_title(schema, nil), do: schema
  defp maybe_add_title(schema, title), do: Map.put(schema, "title", title)

  @spec maybe_add_description(map(), String.t() | nil) :: map()
  defp maybe_add_description(schema, nil), do: schema
  defp maybe_add_description(schema, description), do: Map.put(schema, "description", description)
end
