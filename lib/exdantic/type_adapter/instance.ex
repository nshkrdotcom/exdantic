defmodule Exdantic.TypeAdapter.Instance do
  @moduledoc """
  A reusable TypeAdapter instance for efficient validation and serialization.

  This module provides a struct that encapsulates a type specification and
  configuration options, allowing for efficient reuse of the same type
  validation and serialization logic.
  """

  alias Exdantic.TypeAdapter

  @enforce_keys [:type_spec, :normalized_type]
  defstruct [
    # Original type specification
    :type_spec,
    # Normalized type definition
    :normalized_type,
    # Configuration options
    :config,
    # Cached JSON schema
    :json_schema
  ]

  @type t :: %__MODULE__{
          type_spec: TypeAdapter.type_spec(),
          normalized_type: Exdantic.Types.type_definition(),
          config: map(),
          json_schema: map() | nil
        }

  @doc """
  Creates a new TypeAdapter instance.

  ## Parameters
    * `type_spec` - The type specification to create an adapter for
    * `opts` - Configuration options

  ## Options
    * `:coerce` - Enable type coercion by default (default: false)
    * `:strict` - Enable strict validation by default (default: false)
    * `:cache_json_schema` - Pre-generate and cache JSON schema (default: true)

  ## Returns
    * TypeAdapter.Instance struct

  ## Examples

      iex> adapter = Exdantic.TypeAdapter.Instance.new(:string)
      %Exdantic.TypeAdapter.Instance{...}

      iex> adapter = Exdantic.TypeAdapter.Instance.new({:array, :integer}, coerce: true)
      %Exdantic.TypeAdapter.Instance{...}
  """
  @spec new(TypeAdapter.type_spec(), keyword()) :: t()
  def new(type_spec, opts \\ []) do
    config = %{
      coerce: Keyword.get(opts, :coerce, false),
      strict: Keyword.get(opts, :strict, false),
      cache_json_schema: Keyword.get(opts, :cache_json_schema, true)
    }

    normalized_type = Exdantic.Types.normalize_type(type_spec)

    json_schema =
      if config.cache_json_schema do
        TypeAdapter.json_schema(type_spec)
      else
        nil
      end

    %__MODULE__{
      type_spec: type_spec,
      normalized_type: normalized_type,
      config: config,
      json_schema: json_schema
    }
  end

  @doc """
  Validates a value using this TypeAdapter instance.

  ## Parameters
    * `instance` - The TypeAdapter instance
    * `value` - The value to validate
    * `opts` - Additional validation options (override instance defaults)

  ## Returns
    * `{:ok, validated_value}` on success
    * `{:error, errors}` on validation failure

  ## Examples

      iex> adapter = Exdantic.TypeAdapter.Instance.new(:string)
      iex> Exdantic.TypeAdapter.Instance.validate(adapter, "hello")
      {:ok, "hello"}

      iex> adapter = Exdantic.TypeAdapter.Instance.new(:integer, coerce: true)
      iex> Exdantic.TypeAdapter.Instance.validate(adapter, "123")
      {:ok, 123}
  """
  @spec validate(t(), term(), keyword()) :: {:ok, term()} | {:error, [Exdantic.Error.t()]}
  def validate(%__MODULE__{} = instance, value, opts \\ []) do
    validation_opts =
      instance.config
      |> Map.merge(Map.new(opts))
      |> Map.to_list()

    TypeAdapter.validate(instance.type_spec, value, validation_opts)
  end

  @doc """
  Serializes a value using this TypeAdapter instance.

  ## Parameters
    * `instance` - The TypeAdapter instance
    * `value` - The value to serialize
    * `opts` - Additional serialization options

  ## Returns
    * `{:ok, serialized_value}` on success
    * `{:error, reason}` on serialization failure

  ## Examples

      iex> adapter = Exdantic.TypeAdapter.Instance.new({:map, {:string, :any}})
      iex> Exdantic.TypeAdapter.Instance.dump(adapter, %{name: "John"})
      {:ok, %{"name" => "John"}}
  """
  @spec dump(t(), term(), keyword()) :: {:ok, term()} | {:error, String.t()}
  def dump(%__MODULE__{} = instance, value, opts \\ []) do
    TypeAdapter.dump(instance.type_spec, value, opts)
  end

  @doc """
  Gets the JSON schema for this TypeAdapter instance.

  If the schema was cached during creation, returns the cached version.
  Otherwise, generates it on demand.

  ## Parameters
    * `instance` - The TypeAdapter instance
    * `opts` - JSON schema generation options

  ## Returns
    * JSON Schema map

  ## Examples

      iex> adapter = Exdantic.TypeAdapter.Instance.new(:string)
      iex> Exdantic.TypeAdapter.Instance.json_schema(adapter)
      %{"type" => "string"}
  """
  @spec json_schema(t(), keyword()) :: map()
  def json_schema(%__MODULE__{json_schema: cached} = instance, opts \\ []) do
    if cached && Enum.empty?(opts) do
      cached
    else
      TypeAdapter.json_schema(instance.type_spec, opts)
    end
  end

  @doc """
  Updates the configuration of a TypeAdapter instance.

  ## Parameters
    * `instance` - The TypeAdapter instance
    * `new_config` - Configuration options to merge

  ## Returns
    * Updated TypeAdapter instance

  ## Examples

      iex> adapter = Exdantic.TypeAdapter.Instance.new(:string)
      iex> updated = Exdantic.TypeAdapter.Instance.update_config(adapter, %{coerce: true})
      %Exdantic.TypeAdapter.Instance{config: %{coerce: true, ...}}
  """
  @spec update_config(t(), map()) :: t()
  def update_config(%__MODULE__{} = instance, new_config) do
    %{instance | config: Map.merge(instance.config, new_config)}
  end

  @doc """
  Returns information about the TypeAdapter instance.

  ## Parameters
    * `instance` - The TypeAdapter instance

  ## Returns
    * Map with instance information

  ## Examples

      iex> adapter = Exdantic.TypeAdapter.Instance.new({:array, :string})
      iex> Exdantic.TypeAdapter.Instance.info(adapter)
      %{
        type_spec: {:array, :string},
        normalized_type: {:array, {:type, :string, []}, []},
        config: %{coerce: false, strict: false},
        has_cached_schema: true
      }
  """
  @spec info(t()) :: map()
  def info(%__MODULE__{} = instance) do
    %{
      type_spec: instance.type_spec,
      normalized_type: instance.normalized_type,
      config: instance.config,
      has_cached_schema: not is_nil(instance.json_schema)
    }
  end

  @doc """
  Validates multiple values efficiently using the same TypeAdapter instance.

  ## Parameters
    * `instance` - The TypeAdapter instance
    * `values` - List of values to validate
    * `opts` - Validation options

  ## Returns
    * `{:ok, validated_values}` if all values are valid
    * `{:error, errors_by_index}` if any validation fails

  ## Examples

      iex> adapter = Exdantic.TypeAdapter.Instance.new(:integer)
      iex> Exdantic.TypeAdapter.Instance.validate_many(adapter, [1, 2, 3])
      {:ok, [1, 2, 3]}

      iex> Exdantic.TypeAdapter.Instance.validate_many(adapter, [1, "bad", 3])
      {:error, %{1 => [%Exdantic.Error{...}]}}
  """
  @spec validate_many(t(), [term()], keyword()) ::
          {:ok, [term()]} | {:error, %{integer() => [Exdantic.Error.t()]}}
  def validate_many(%__MODULE__{} = instance, values, opts \\ []) do
    results =
      values
      |> Enum.with_index()
      |> Enum.map(fn {value, index} ->
        case validate(instance, value, opts) do
          {:ok, validated} -> {:ok, {index, validated}}
          {:error, errors} -> {:error, {index, errors}}
        end
      end)

    case Enum.split_with(results, &match?({:ok, _}, &1)) do
      {oks, []} ->
        validated_values =
          oks
          |> Enum.map(fn {:ok, {_index, value}} -> value end)

        {:ok, validated_values}

      {_, errors} ->
        error_map =
          errors
          |> Enum.map(fn {:error, {index, errs}} -> {index, errs} end)
          |> Map.new()

        {:error, error_map}
    end
  end

  @doc """
  Serializes multiple values efficiently using the same TypeAdapter instance.

  ## Parameters
    * `instance` - The TypeAdapter instance
    * `values` - List of values to serialize
    * `opts` - Serialization options

  ## Returns
    * `{:ok, serialized_values}` if all values serialize successfully
    * `{:error, errors_by_index}` if any serialization fails

  ## Examples

      iex> adapter = Exdantic.TypeAdapter.Instance.new(:string)
      iex> Exdantic.TypeAdapter.Instance.dump_many(adapter, ["a", "b", "c"])
      {:ok, ["a", "b", "c"]}
  """
  @spec dump_many(t(), [term()], keyword()) ::
          {:ok, [term()]} | {:error, %{integer() => String.t()}}
  def dump_many(%__MODULE__{} = instance, values, opts \\ []) do
    results =
      values
      |> Enum.with_index()
      |> Enum.map(fn {value, index} ->
        case dump(instance, value, opts) do
          {:ok, serialized} -> {:ok, {index, serialized}}
          {:error, reason} -> {:error, {index, reason}}
        end
      end)

    case Enum.split_with(results, &match?({:ok, _}, &1)) do
      {oks, []} ->
        serialized_values =
          oks
          |> Enum.map(fn {:ok, {_index, value}} -> value end)

        {:ok, serialized_values}

      {_, errors} ->
        error_map =
          errors
          |> Enum.map(fn {:error, {index, reason}} -> {index, reason} end)
          |> Map.new()

        {:error, error_map}
    end
  end
end
