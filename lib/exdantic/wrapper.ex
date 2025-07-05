defmodule Exdantic.Wrapper do
  @moduledoc """
  Temporary validation schemas for type coercion patterns.

  This module supports the DSPy pattern of creating temporary, single-field
  validation schemas for complex type coercion, equivalent to Pydantic's:
  `create_model("Wrapper", value=(target_type, ...))`

  Wrapper schemas are useful when you need to:
  - Validate a single value against a complex type specification
  - Apply field-level constraints and coercion
  - Extract and unwrap validated values
  - Perform temporary schema-based validation without defining a full schema
  """

  alias Exdantic.{Runtime, TypeAdapter}
  alias Exdantic.Runtime.DynamicSchema

  @type wrapper_schema :: DynamicSchema.t()
  @type wrapper_options :: [
          required: boolean(),
          coerce: boolean(),
          constraints: [term()],
          description: String.t(),
          example: term(),
          default: term()
        ]

  @doc """
  Creates a temporary wrapper schema for validating a single value.

  ## Parameters
    * `field_name` - The name for the wrapper field (atom)
    * `type_spec` - The type specification for the field
    * `opts` - Wrapper configuration options

  ## Options
    * `:required` - Whether the field is required (default: true)
    * `:coerce` - Enable type coercion (default: false)
    * `:constraints` - Additional field constraints (default: [])
    * `:description` - Field description for documentation
    * `:example` - Example value for the field
    * `:default` - Default value if field is missing

  ## Returns
    * Wrapper schema that can be used for validation

  ## Examples

      iex> wrapper = Exdantic.Wrapper.create_wrapper(:result, :integer, coerce: true, constraints: [gt: 0])
      %Exdantic.Runtime.DynamicSchema{...}

      iex> wrapper = Exdantic.Wrapper.create_wrapper(:email, :string,
      ...>   constraints: [format: ~r/@/], description: "Email address")
      %Exdantic.Runtime.DynamicSchema{...}
  """
  @spec create_wrapper(atom(), TypeAdapter.type_spec(), wrapper_options()) :: wrapper_schema()
  def create_wrapper(field_name, type_spec, opts \\ [])

  def create_wrapper(nil, _type_spec, _opts) do
    raise ArgumentError, "field_name cannot be nil"
  end

  def create_wrapper(field_name, type_spec, opts) when is_atom(field_name) do
    # Note: Type specification validation is handled during schema creation and validation
    do_create_wrapper(field_name, type_spec, opts)
  end

  @spec do_create_wrapper(atom(), TypeAdapter.type_spec(), wrapper_options()) :: wrapper_schema()
  defp do_create_wrapper(field_name, type_spec, opts) when is_atom(field_name) do
    # Extract wrapper options
    required = Keyword.get(opts, :required, true)
    description = Keyword.get(opts, :description)
    example = Keyword.get(opts, :example)
    default = Keyword.get(opts, :default)
    constraints = Keyword.get(opts, :constraints, [])
    coerce = Keyword.get(opts, :coerce, false)

    # Create field definition with constraints
    field_definition = {
      field_name,
      type_spec,
      [
        required: required,
        description: description,
        example: example,
        default: default
      ] ++ constraints
    }

    # Generate unique wrapper name
    wrapper_name = "Wrapper_#{field_name}_#{System.unique_integer([:positive])}"

    # Create runtime schema with single field
    schema =
      Runtime.create_schema(
        [field_definition],
        name: wrapper_name,
        title: "Wrapper for #{field_name}",
        description: "Temporary validation schema for #{field_name}"
      )

    # Store coercion setting in metadata for later use
    %{schema | metadata: Map.put(schema.metadata, :coerce, coerce)}
  end

  @doc """
  Validates data using a wrapper schema and extracts the field value.

  ## Parameters
    * `wrapper_schema` - The wrapper schema created by create_wrapper/3
    * `data` - The data to validate (can be the raw value or a map)
    * `field_name` - The field name to extract from the validated result

  ## Returns
    * `{:ok, extracted_value}` on successful validation and extraction
    * `{:error, errors}` on validation failure

  ## Examples

      iex> wrapper = Exdantic.Wrapper.create_wrapper(:count, :integer, coerce: true)
      iex> Exdantic.Wrapper.validate_and_extract(wrapper, %{count: "42"}, :count)
      {:ok, 42}

      iex> Exdantic.Wrapper.validate_and_extract(wrapper, "42", :count)  # Auto-wrap
      {:ok, 42}

      iex> Exdantic.Wrapper.validate_and_extract(wrapper, %{count: "abc"}, :count)
      {:error, [%Exdantic.Error{...}]}
  """
  @spec validate_and_extract(wrapper_schema(), term(), atom()) ::
          {:ok, term()} | {:error, [Exdantic.Error.t()]}
  def validate_and_extract(%DynamicSchema{} = wrapper_schema, data, field_name) do
    # Get field metadata to check the expected type
    field_meta = Map.get(wrapper_schema.fields, field_name)

    # Normalize data to map format if needed
    normalized_data = normalize_wrapper_data(data, field_name, field_meta)

    # Check if coercion is enabled for this wrapper
    coerce_enabled = Map.get(wrapper_schema.metadata, :coerce, false)

    if coerce_enabled do
      # Use TypeAdapter for coercion-enabled validation
      validate_with_coercion(wrapper_schema, normalized_data, field_name)
    else
      # Use normal Runtime validation
      case Runtime.validate(normalized_data, wrapper_schema) do
        {:ok, validated_map} ->
          # Extract the field value
          case Map.get(validated_map, field_name) do
            nil ->
              {:error,
               [Exdantic.Error.new([field_name], :missing, "field not found in validated result")]}

            value ->
              {:ok, value}
          end

        {:error, errors} ->
          {:error, errors}
      end
    end
  end

  @doc """
  Validates data using a wrapper schema and extracts the value in one step.

  This is a convenience function that combines create_wrapper/3 and validate_and_extract/3.

  ## Parameters
    * `field_name` - The name for the wrapper field
    * `type_spec` - The type specification for the field
    * `input` - The data to validate
    * `opts` - Wrapper configuration options (same as create_wrapper/3)

  ## Returns
    * `{:ok, validated_value}` on successful validation
    * `{:error, errors}` on validation failure

  ## Examples

      iex> Exdantic.Wrapper.wrap_and_validate(:score, :integer, "85", coerce: true, constraints: [gteq: 0, lteq: 100])
      {:ok, 85}

      iex> Exdantic.Wrapper.wrap_and_validate(:email, :string, "invalid", constraints: [format: ~r/@/])
      {:error, [%Exdantic.Error{...}]}

      iex> Exdantic.Wrapper.wrap_and_validate(:items, {:array, :string}, ["a", "b", "c"])
      {:ok, ["a", "b", "c"]}
  """
  @spec wrap_and_validate(atom(), TypeAdapter.type_spec(), term(), wrapper_options()) ::
          {:ok, term()} | {:error, [Exdantic.Error.t()]}
  def wrap_and_validate(field_name, type_spec, input, opts \\ []) when is_atom(field_name) do
    wrapper_schema = create_wrapper(field_name, type_spec, opts)
    validate_and_extract(wrapper_schema, input, field_name)
  end

  @doc """
  Creates multiple wrapper schemas for batch validation.

  ## Parameters
    * `field_specs` - List of {field_name, type_spec, opts} tuples
    * `global_opts` - Options applied to all wrappers

  ## Returns
    * Map of field_name => wrapper_schema

  ## Examples

      iex> specs = [
      ...>   {:name, :string, [constraints: [min_length: 1]]},
      ...>   {:age, :integer, [constraints: [gt: 0]]},
      ...>   {:email, :string, [constraints: [format: ~r/@/]]}
      ...> ]
      iex> wrappers = Exdantic.Wrapper.create_multiple_wrappers(specs)
      %{name: %DynamicSchema{...}, age: %DynamicSchema{...}, email: %DynamicSchema{...}}
  """
  @spec create_multiple_wrappers(
          [{atom(), TypeAdapter.type_spec(), wrapper_options()}],
          wrapper_options()
        ) ::
          %{atom() => wrapper_schema()}
  def create_multiple_wrappers(field_specs, global_opts \\ []) do
    mapper_fn = fn {field_name, type_spec, opts} ->
      merged_opts = Keyword.merge(global_opts, opts)
      wrapper = create_wrapper(field_name, type_spec, merged_opts)
      {field_name, wrapper}
    end

    field_specs
    |> Enum.map(mapper_fn)
    |> Map.new()
  end

  @doc """
  Validates multiple values using their respective wrapper schemas.

  ## Parameters
    * `wrappers` - Map of field_name => wrapper_schema
    * `data` - Map of field_name => value to validate

  ## Returns
    * `{:ok, validated_values}` if all validations succeed
    * `{:error, errors_by_field}` if any validation fails

  ## Examples

      iex> wrappers = %{
      ...>   name: Exdantic.Wrapper.create_wrapper(:name, :string),
      ...>   age: Exdantic.Wrapper.create_wrapper(:age, :integer)
      ...> }
      iex> data = %{name: "John", age: 30}
      iex> Exdantic.Wrapper.validate_multiple(wrappers, data)
      {:ok, %{name: "John", age: 30}}
  """
  @spec validate_multiple(%{atom() => wrapper_schema()}, %{atom() => term()}) ::
          {:ok, %{atom() => term()}} | {:error, %{atom() => [Exdantic.Error.t()]}}
  def validate_multiple(wrappers, data) when is_map(wrappers) and is_map(data) do
    results =
      wrappers
      |> Enum.map(fn {field_name, wrapper_schema} ->
        case Map.get(data, field_name) do
          nil ->
            {field_name,
             {:error, [Exdantic.Error.new([field_name], :missing, "field not provided")]}}

          value ->
            case validate_and_extract(wrapper_schema, value, field_name) do
              {:ok, validated} -> {field_name, {:ok, validated}}
              {:error, errors} -> {field_name, {:error, errors}}
            end
        end
      end)

    case Enum.split_with(results, fn {_, result} -> match?({:ok, _}, result) end) do
      {oks, []} ->
        validated_map =
          oks
          |> Enum.map(fn {field_name, {:ok, value}} -> {field_name, value} end)
          |> Map.new()

        {:ok, validated_map}

      {_, errors} ->
        error_map =
          errors
          |> Enum.map(fn {field_name, {:error, errs}} -> {field_name, errs} end)
          |> Map.new()

        {:error, error_map}
    end
  end

  @doc """
  Creates a reusable wrapper factory for a specific type and constraints.

  ## Parameters
    * `type_spec` - The type specification for the wrapper
    * `base_opts` - Base options applied to all wrappers created by this factory

  ## Returns
    * Function that creates wrappers with the specified type and base options

  ## Examples

      iex> email_wrapper_factory = Exdantic.Wrapper.create_wrapper_factory(
      ...>   :string,
      ...>   constraints: [format: ~r/@/],
      ...>   description: "Email address"
      ...> )
      iex> user_email_wrapper = email_wrapper_factory.(:user_email)
      iex> admin_email_wrapper = email_wrapper_factory.(:admin_email, required: false)
  """
  @spec create_wrapper_factory(TypeAdapter.type_spec(), wrapper_options()) ::
          (atom() -> wrapper_schema())
  def create_wrapper_factory(type_spec, base_opts \\ []) do
    wrapper_fn = fn field_name ->
      create_wrapper(field_name, type_spec, base_opts)
    end

    wrapper_fn
  end

  @doc """
  Converts a wrapper schema back to its JSON Schema representation.

  ## Parameters
    * `wrapper_schema` - The wrapper schema to convert
    * `opts` - JSON Schema generation options

  ## Returns
    * JSON Schema map representation of the wrapper

  ## Examples

      iex> wrapper = Exdantic.Wrapper.create_wrapper(:count, :integer, constraints: [gt: 0])
      iex> Exdantic.Wrapper.to_json_schema(wrapper)
      %{
        "type" => "object",
        "properties" => %{
          "count" => %{"type" => "integer", "exclusiveMinimum" => 0}
        },
        "required" => ["count"]
      }
  """
  @spec to_json_schema(wrapper_schema(), keyword()) :: map()
  def to_json_schema(%DynamicSchema{} = wrapper_schema, opts \\ []) do
    Runtime.to_json_schema(wrapper_schema, opts)
  end

  @doc """
  Unwraps a validated result, extracting just the field value.

  Utility function for extracting values from wrapper validation results.

  ## Parameters
    * `validated_result` - Result from wrapper validation (map)
    * `field_name` - The field name to extract

  ## Returns
    * The unwrapped field value

  ## Examples

      iex> validated = %{score: 85}
      iex> Exdantic.Wrapper.unwrap_result(validated, :score)
      85
  """
  @spec unwrap_result(map(), atom()) :: term()
  def unwrap_result(validated_result, field_name) when is_map(validated_result) do
    Map.get(validated_result, field_name)
  end

  @doc """
  Checks if a schema is a wrapper schema created by this module.

  ## Parameters
    * `schema` - The schema to check

  ## Returns
    * `true` if it's a wrapper schema, `false` otherwise

  ## Examples

      iex> wrapper = Exdantic.Wrapper.create_wrapper(:test, :string)
      iex> Exdantic.Wrapper.wrapper_schema?(wrapper)
      true

      iex> regular_schema = Exdantic.Runtime.create_schema([{:name, :string}])
      iex> Exdantic.Wrapper.wrapper_schema?(regular_schema)
      false
  """
  @spec wrapper_schema?(term()) :: boolean()
  def wrapper_schema?(%DynamicSchema{name: name}) when is_binary(name) do
    String.starts_with?(name, "Wrapper_")
  end

  def wrapper_schema?(_), do: false

  @doc """
  Gets metadata about a wrapper schema.

  ## Parameters
    * `wrapper_schema` - The wrapper schema to inspect

  ## Returns
    * Map with wrapper metadata

  ## Examples

      iex> wrapper = Exdantic.Wrapper.create_wrapper(:email, :string, description: "User email")
      iex> Exdantic.Wrapper.wrapper_info(wrapper)
      %{
        is_wrapper: true,
        field_name: :email,
        field_count: 1,
        wrapper_type: :single_field,
        created_at: ~U[...]
      }
  """
  @spec wrapper_info(wrapper_schema()) :: map()
  def wrapper_info(%DynamicSchema{} = wrapper_schema) do
    field_names = Runtime.DynamicSchema.field_names(wrapper_schema)

    %{
      is_wrapper: wrapper_schema?(wrapper_schema),
      field_name: List.first(field_names),
      field_count: length(field_names),
      wrapper_type: if(length(field_names) == 1, do: :single_field, else: :multi_field),
      created_at: Map.get(wrapper_schema.metadata, :created_at),
      schema_name: wrapper_schema.name
    }
  end

  @doc """
  Creates a wrapper schema that can handle multiple input formats.

  This wrapper can accept:
  - The raw value directly
  - A map with the field name as key
  - A map with string keys

  ## Parameters
    * `field_name` - The field name for the wrapper
    * `type_spec` - The type specification
    * `opts` - Wrapper options

  ## Examples

      iex> wrapper = Exdantic.Wrapper.create_flexible_wrapper(:age, :integer, coerce: true)
      iex> Exdantic.Wrapper.validate_flexible(wrapper, 25, :age)        # Raw value
      {:ok, 25}
      iex> Exdantic.Wrapper.validate_flexible(wrapper, %{age: 25}, :age) # Map with atom key
      {:ok, 25}
      iex> Exdantic.Wrapper.validate_flexible(wrapper, %{"age" => 25}, :age) # Map with string key
      {:ok, 25}
  """
  @spec create_flexible_wrapper(atom(), TypeAdapter.type_spec(), wrapper_options()) ::
          wrapper_schema()
  def create_flexible_wrapper(field_name, type_spec, opts \\ []) when is_atom(field_name) do
    create_wrapper(field_name, type_spec, opts)
  end

  @doc """
  Validates data against a flexible wrapper that can handle multiple input formats.

  ## Parameters
    * `wrapper_schema` - The wrapper schema
    * `data` - The input data (raw value, or map with atom/string keys)
    * `field_name` - The field name to extract

  ## Returns
    * `{:ok, validated_value}` on success
    * `{:error, errors}` on failure
  """
  @spec validate_flexible(wrapper_schema(), term(), atom()) ::
          {:ok, term()} | {:error, [Exdantic.Error.t()]}
  def validate_flexible(%DynamicSchema{} = wrapper_schema, data, field_name) do
    normalized_data = normalize_flexible_data(data, field_name)
    validate_and_extract(wrapper_schema, normalized_data, field_name)
  end

  # Private helper functions

  @spec validate_with_coercion(wrapper_schema(), map(), atom()) ::
          {:ok, term()} | {:error, [Exdantic.Error.t()]}
  defp validate_with_coercion(%DynamicSchema{} = wrapper_schema, normalized_data, field_name) do
    # Get the field metadata
    field_meta = Map.get(wrapper_schema.fields, field_name)

    if field_meta do
      # Extract the value to validate
      value = Map.get(normalized_data, field_name)

      # Use TypeAdapter for validation with coercion
      case TypeAdapter.validate(field_meta.type, value, coerce: true, path: [field_name]) do
        {:ok, validated_value} ->
          {:ok, validated_value}

        {:error, errors} ->
          {:error, errors}
      end
    else
      {:error, [Exdantic.Error.new([field_name], :missing, "field not found in wrapper schema")]}
    end
  end

  @spec normalize_wrapper_data(term(), atom(), Exdantic.FieldMeta.t() | nil) :: map()
  defp normalize_wrapper_data(data, field_name, field_meta) when is_map(data) do
    # If data is already a map, check if the field exists with atom or string key
    case {Map.get(data, field_name), Map.get(data, Atom.to_string(field_name))} do
      {nil, nil} ->
        # Field not found in map - decide whether to treat map as field value or report missing
        if should_treat_map_as_value?(data, field_meta) do
          # Field type is compatible with maps, treat entire map as the field value
          %{field_name => data}
        else
          # Field type is not map-compatible, leave empty so validation reports missing field
          %{}
        end

      # Atom key found
      {value, nil} ->
        %{field_name => value}

      # String key found
      {nil, value} ->
        %{field_name => value}

      # Prefer atom key
      {atom_value, _} ->
        %{field_name => atom_value}
    end
  end

  defp normalize_wrapper_data(data, field_name, _field_meta) do
    # For non-map data, wrap it in a map with the field name
    %{field_name => data}
  end

  @spec normalize_flexible_data(term(), atom()) :: map()
  defp normalize_flexible_data(data, field_name) when is_map(data) do
    # Try different key formats
    cond do
      Map.has_key?(data, field_name) ->
        data

      Map.has_key?(data, Atom.to_string(field_name)) ->
        # Convert string key to atom key
        value = Map.get(data, Atom.to_string(field_name))
        %{field_name => value}

      true ->
        # If no matching key found, treat the entire map as the field value
        %{field_name => data}
    end
  end

  defp normalize_flexible_data(data, field_name) do
    # For non-map data, wrap it
    %{field_name => data}
  end

  @spec should_treat_map_as_value?(map(), Exdantic.FieldMeta.t() | nil) :: boolean()
  defp should_treat_map_as_value?(_data, nil), do: false

  defp should_treat_map_as_value?(_data, field_meta) do
    map_compatible_type?(field_meta.type)
  end

  @spec map_compatible_type?(term()) :: boolean()
  defp map_compatible_type?(type) do
    case type do
      # Map and any types
      type when type in [:map, :any] -> true
      {:type, type, _} when type in [:map, :any] -> true
      # Map with additional type info
      {:map, _} -> true
      {:map, _, _} -> true
      # Reference types (schemas accept map data)
      {:ref, _} -> true
      {:type, :ref, _} -> true
      # All other types
      _ -> false
    end
  end
end
