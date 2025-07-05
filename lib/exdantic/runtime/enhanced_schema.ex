defmodule Exdantic.Runtime.EnhancedSchema do
  @moduledoc """
  Enhanced runtime schema with model validators and computed fields support.

  This module extends DynamicSchema with support for:
  - Model validators with both named and anonymous functions
  - Computed fields with both named and anonymous functions
  - Full validation pipeline execution
  - JSON Schema generation with enhanced metadata
  """

  alias Exdantic.JsonSchema.TypeMapper
  alias Exdantic.Runtime.DynamicSchema
  alias Exdantic.{ComputedFieldMeta, Error}

  @enforce_keys [:base_schema, :model_validators, :computed_fields]
  defstruct [
    # DynamicSchema.t()
    :base_schema,
    # [{module(), atom()} | {atom(), function()}]
    :model_validators,
    # [{atom(), ComputedFieldMeta.t() | {atom(), function()}}]
    :computed_fields,
    # Map of generated functions
    :runtime_functions,
    # Additional runtime metadata
    :metadata
  ]

  @type validator_spec :: {module(), atom()} | function()
  @type computed_field_spec :: {atom(), Exdantic.Types.type_definition(), validator_spec}

  @type t :: %__MODULE__{
          base_schema: DynamicSchema.t(),
          model_validators: [validator_spec()],
          computed_fields: [computed_field_spec()],
          runtime_functions: %{atom() => function()},
          metadata: map()
        }

  @doc """
  Creates an enhanced runtime schema with model validators and computed fields.

  ## Parameters
    * `field_definitions` - List of field definitions
    * `opts` - Enhanced schema options

  ## Options
    * `:model_validators` - List of model validator functions or {module, function} tuples
    * `:computed_fields` - List of computed field specifications
    * `:title`, `:description`, `:strict` - Standard schema options
    * `:name` - Schema name for references

  ## Examples

      iex> fields = [{:name, :string, [required: true]}, {:age, :integer, [optional: true]}]
      iex> validators = [fn data -> {:ok, %{data | name: String.trim(data.name)}} end]
      iex> computed = [{:display_name, :string, fn data -> {:ok, String.upcase(data.name)} end}]
      iex> schema = Exdantic.Runtime.EnhancedSchema.create(fields,
      ...>   model_validators: validators,
      ...>   computed_fields: computed
      ...> )
      %Exdantic.Runtime.EnhancedSchema{...}
  """
  @spec create([term()], keyword()) :: t()
  def create(field_definitions, opts \\ []) do
    # Extract enhanced options
    model_validators = Keyword.get(opts, :model_validators, [])
    computed_fields = Keyword.get(opts, :computed_fields, [])

    # Remove enhanced options from base schema opts
    base_opts = Keyword.drop(opts, [:model_validators, :computed_fields])

    # Create base schema
    base_schema = Exdantic.Runtime.create_schema(field_definitions, base_opts)

    # Process model validators and computed fields
    {processed_validators, runtime_functions} = process_model_validators(model_validators)

    {processed_computed_fields, updated_runtime_functions} =
      process_computed_fields(computed_fields, runtime_functions)

    # Create enhanced schema
    %__MODULE__{
      base_schema: base_schema,
      model_validators: processed_validators,
      computed_fields: processed_computed_fields,
      runtime_functions: updated_runtime_functions,
      metadata: %{
        created_at: DateTime.utc_now(),
        validator_count: length(processed_validators),
        computed_field_count: length(processed_computed_fields)
      }
    }
  end

  @doc """
  Validates data against an enhanced runtime schema.

  ## Parameters
    * `data` - The data to validate (map)
    * `enhanced_schema` - An EnhancedSchema struct
    * `opts` - Validation options

  ## Returns
    * `{:ok, validated_data}` on success (includes computed fields)
    * `{:error, errors}` on validation failure

  ## Examples

      iex> data = %{name: "  John  ", age: 30}
      iex> Exdantic.Runtime.EnhancedSchema.validate(data, schema)
      {:ok, %{name: "John", age: 30, display_name: "JOHN"}}
  """
  @spec validate(map(), t(), keyword()) :: {:ok, map()} | {:error, [Error.t()]}
  def validate(data, %__MODULE__{} = enhanced_schema, opts \\ []) do
    path = Keyword.get(opts, :path, [])

    # Step 1: Base field validation
    case Exdantic.Runtime.validate(data, enhanced_schema.base_schema, opts) do
      {:ok, validated_fields} ->
        # Step 2: Model validation
        case apply_model_validators(enhanced_schema, validated_fields, path) do
          {:ok, model_validated_data} ->
            # Step 3: Computed field execution
            apply_computed_fields(enhanced_schema, model_validated_data, path)

          {:error, errors} ->
            {:error, errors}
        end

      {:error, errors} ->
        {:error, errors}
    end
  end

  @doc """
  Generates JSON Schema for an enhanced runtime schema.

  ## Parameters
    * `enhanced_schema` - An EnhancedSchema struct
    * `opts` - JSON Schema generation options

  ## Returns
    * JSON Schema map including computed field metadata

  ## Examples

      iex> json_schema = Exdantic.Runtime.EnhancedSchema.to_json_schema(schema)
      %{
        "type" => "object",
        "properties" => %{
          "name" => %{"type" => "string"},
          "display_name" => %{"type" => "string", "readOnly" => true}
        }
      }
  """
  @spec to_json_schema(t(), keyword()) :: map()
  def to_json_schema(%__MODULE__{} = enhanced_schema, opts \\ []) do
    # Get base schema JSON
    base_json = Exdantic.Runtime.to_json_schema(enhanced_schema.base_schema, opts)

    # Add computed fields to properties
    computed_properties = generate_computed_field_properties(enhanced_schema)

    # Merge computed fields into properties
    updated_properties =
      Map.get(base_json, "properties", %{})
      |> Map.merge(computed_properties)

    # Update the schema
    base_json
    |> Map.put("properties", updated_properties)
    |> add_enhanced_metadata(enhanced_schema)
  end

  @doc """
  Returns information about the enhanced schema.

  ## Parameters
    * `enhanced_schema` - An EnhancedSchema struct

  ## Returns
    * Map with enhanced schema information
  """
  @spec info(t()) :: map()
  def info(%__MODULE__{} = enhanced_schema) do
    base_info = DynamicSchema.summary(enhanced_schema.base_schema)

    %{
      base_schema: base_info,
      model_validator_count: length(enhanced_schema.model_validators),
      computed_field_count: length(enhanced_schema.computed_fields),
      runtime_function_count: map_size(enhanced_schema.runtime_functions),
      total_field_count: base_info.field_count + length(enhanced_schema.computed_fields),
      metadata: enhanced_schema.metadata
    }
  end

  @doc """
  Adds a model validator to an existing enhanced schema.

  ## Parameters
    * `enhanced_schema` - An EnhancedSchema struct
    * `validator` - Validator function or {module, function} tuple

  ## Returns
    * Updated EnhancedSchema struct
  """
  @spec add_model_validator(t(), validator_spec()) :: t()
  def add_model_validator(%__MODULE__{} = enhanced_schema, validator) do
    {processed_validator, updated_functions} =
      process_single_model_validator(validator, enhanced_schema.runtime_functions)

    updated_validators = enhanced_schema.model_validators ++ [processed_validator]

    updated_metadata =
      Map.put(enhanced_schema.metadata, :validator_count, length(updated_validators))

    %{
      enhanced_schema
      | model_validators: updated_validators,
        runtime_functions: updated_functions,
        metadata: updated_metadata
    }
  end

  @doc """
  Adds a computed field to an existing enhanced schema.

  ## Parameters
    * `enhanced_schema` - An EnhancedSchema struct
    * `field_name` - Name of the computed field
    * `field_type` - Type specification for the field
    * `computation` - Computation function or {module, function} tuple

  ## Returns
    * Updated EnhancedSchema struct
  """
  @spec add_computed_field(t(), atom(), term(), validator_spec()) :: t()
  def add_computed_field(%__MODULE__{} = enhanced_schema, field_name, field_type, computation) do
    computed_field_spec = {field_name, field_type, computation}

    {processed_field, updated_functions} =
      process_single_computed_field(computed_field_spec, enhanced_schema.runtime_functions)

    updated_fields = enhanced_schema.computed_fields ++ [processed_field]

    updated_metadata =
      Map.put(enhanced_schema.metadata, :computed_field_count, length(updated_fields))

    %{
      enhanced_schema
      | computed_fields: updated_fields,
        runtime_functions: updated_functions,
        metadata: updated_metadata
    }
  end

  # Private helper functions

  @doc """
  Processes model validators and converts anonymous functions to named references.

  ## Parameters
    * `validators` - List of validator specifications (module/function tuples or functions)

  ## Returns
    * Tuple of `{processed_validators, runtime_functions}` where runtime_functions
      contains any anonymous functions converted to named references

  ## Examples

      iex> validators = [{MyModule, :my_validator}, fn x -> x.valid end]
      iex> {processed, functions} = process_model_validators(validators)
      {[{MyModule, :my_validator}, {:runtime, :generated_name}], %{generated_name: #Function<...>}}
  """
  @spec process_model_validators([validator_spec()]) ::
          {[validator_spec()], %{atom() => function()}}
  def process_model_validators(validators) do
    Enum.reduce(validators, {[], %{}}, fn validator, {acc_validators, acc_functions} ->
      {processed_validator, updated_functions} =
        process_single_model_validator(validator, acc_functions)

      {acc_validators ++ [processed_validator], updated_functions}
    end)
  end

  @spec process_single_model_validator(validator_spec(), %{atom() => function()}) ::
          {validator_spec(), %{atom() => function()}}
  defp process_single_model_validator({module, function_name}, functions)
       when is_atom(module) and is_atom(function_name) do
    # Named function reference - use as-is
    {{module, function_name}, functions}
  end

  defp process_single_model_validator(validator_fn, functions)
       when is_function(validator_fn, 1) do
    # Anonymous function - generate unique name and store
    function_name = generate_function_name("model_validator")
    updated_functions = Map.put(functions, function_name, validator_fn)

    {{:runtime, function_name}, updated_functions}
  end

  @doc """
  Processes computed field specifications and converts anonymous functions to named references.

  ## Parameters
    * `computed_fields` - List of computed field specifications
    * `initial_functions` - Map of existing runtime functions to extend

  ## Returns
    * Tuple of `{processed_fields, updated_functions}` where updated_functions
      contains both initial and any new anonymous functions converted to named references

  ## Examples

      iex> fields = [%{name: :full_name, function: fn x -> x.first <> " " <> x.last end}]
      iex> {processed, functions} = process_computed_fields(fields, %{})
      {[%{name: :full_name, function: {:runtime, :generated_name}}], %{generated_name: #Function<...>}}
  """
  @spec process_computed_fields([computed_field_spec()], %{atom() => function()}) ::
          {[computed_field_spec()], %{atom() => function()}}
  def process_computed_fields(computed_fields, initial_functions) do
    Enum.reduce(computed_fields, {[], initial_functions}, fn field_spec,
                                                             {acc_fields, acc_functions} ->
      {processed_field, updated_functions} =
        process_single_computed_field(field_spec, acc_functions)

      {acc_fields ++ [processed_field], updated_functions}
    end)
  end

  @spec process_single_computed_field(computed_field_spec(), %{atom() => function()}) ::
          {{atom(), ComputedFieldMeta.t()}, %{atom() => function()}}
  defp process_single_computed_field({field_name, field_type, {module, function_name}}, functions)
       when is_atom(module) and is_atom(function_name) do
    # Named function reference
    computed_meta = %ComputedFieldMeta{
      name: field_name,
      type: Exdantic.Types.normalize_type(field_type),
      function_name: function_name,
      module: module,
      readonly: true
    }

    {{field_name, computed_meta}, functions}
  end

  defp process_single_computed_field({field_name, field_type, computation_fn}, functions)
       when is_function(computation_fn, 1) do
    # Anonymous function
    function_name = generate_function_name("computed_field", field_name)
    updated_functions = Map.put(functions, function_name, computation_fn)

    computed_meta = %ComputedFieldMeta{
      name: field_name,
      type: Exdantic.Types.normalize_type(field_type),
      function_name: function_name,
      module: :runtime,
      readonly: true
    }

    {{field_name, computed_meta}, updated_functions}
  end

  @spec apply_model_validators(t(), map(), [atom()]) :: {:ok, map()} | {:error, [Error.t()]}
  defp apply_model_validators(%__MODULE__{} = enhanced_schema, data, path) do
    Enum.reduce_while(enhanced_schema.model_validators, {:ok, data}, fn
      validator, {:ok, current_data} ->
        case execute_model_validator(
               validator,
               current_data,
               enhanced_schema.runtime_functions,
               path
             ) do
          {:ok, new_data} -> {:cont, {:ok, new_data}}
          {:error, errors} -> {:halt, {:error, errors}}
        end
    end)
  end

  @spec execute_model_validator(validator_spec(), map(), %{atom() => function()}, [atom()]) ::
          {:ok, map()} | {:error, [Error.t()]}
  defp execute_model_validator({:runtime, function_name}, data, functions, path) do
    # Runtime function execution
    case Map.get(functions, function_name) do
      nil ->
        {:error,
         [Error.new(path, :model_validation, "Runtime function #{function_name} not found")]}

      validator_fn ->
        try do
          case validator_fn.(data) do
            {:ok, new_data} when is_map(new_data) ->
              {:ok, new_data}

            {:error, reason} ->
              {:error, [Error.new(path, :model_validation, reason)]}

            other ->
              {:error, [Error.new(path, :model_validation, "Invalid return: #{inspect(other)}")]}
          end
        rescue
          e ->
            {:error, [Error.new(path, :model_validation, "Exception: #{Exception.message(e)}")]}
        end
    end
  end

  defp execute_model_validator({module, function_name}, data, _functions, path)
       when is_atom(module) and is_atom(function_name) do
    # Named function execution
    case apply(module, function_name, [data]) do
      {:ok, new_data} when is_map(new_data) ->
        {:ok, new_data}

      {:error, reason} ->
        {:error, [Error.new(path, :model_validation, reason)]}

      other ->
        {:error, [Error.new(path, :model_validation, "Invalid return: #{inspect(other)}")]}
    end
  rescue
    e -> {:error, [Error.new(path, :model_validation, "Exception: #{Exception.message(e)}")]}
  end

  @spec apply_computed_fields(t(), map(), [atom()]) :: {:ok, map()} | {:error, [Error.t()]}
  defp apply_computed_fields(%__MODULE__{} = enhanced_schema, data, path) do
    Enum.reduce_while(enhanced_schema.computed_fields, {:ok, data}, fn
      {field_name, computed_meta}, {:ok, current_data} ->
        field_path = path ++ [field_name]

        case execute_computed_field(
               computed_meta,
               current_data,
               enhanced_schema.runtime_functions,
               field_path
             ) do
          {:ok, computed_value} ->
            # Validate computed value against its type
            case Exdantic.Validator.validate(computed_meta.type, computed_value, field_path) do
              {:ok, validated_value} ->
                updated_data = Map.put(current_data, field_name, validated_value)
                {:cont, {:ok, updated_data}}

              {:error, errors} ->
                {:halt, {:error, List.wrap(errors)}}
            end

          {:error, errors} ->
            {:halt, {:error, errors}}
        end
    end)
  end

  @spec execute_computed_field(ComputedFieldMeta.t(), map(), %{atom() => function()}, [atom()]) ::
          {:ok, term()} | {:error, [Error.t()]}
  defp execute_computed_field(
         %ComputedFieldMeta{module: :runtime, function_name: function_name},
         data,
         functions,
         path
       ) do
    # Runtime function execution
    case Map.get(functions, function_name) do
      nil ->
        {:error,
         [Error.new(path, :computed_field, "Runtime function #{function_name} not found")]}

      computation_fn ->
        try do
          case computation_fn.(data) do
            {:ok, value} ->
              {:ok, value}

            {:error, reason} ->
              {:error, [Error.new(path, :computed_field, reason)]}

            other ->
              {:error, [Error.new(path, :computed_field, "Invalid return: #{inspect(other)}")]}
          end
        rescue
          e -> {:error, [Error.new(path, :computed_field, "Exception: #{Exception.message(e)}")]}
        end
    end
  end

  defp execute_computed_field(
         %ComputedFieldMeta{module: module, function_name: function_name},
         data,
         _functions,
         path
       ) do
    # Named function execution
    case apply(module, function_name, [data]) do
      {:ok, value} -> {:ok, value}
      {:error, reason} -> {:error, [Error.new(path, :computed_field, reason)]}
      other -> {:error, [Error.new(path, :computed_field, "Invalid return: #{inspect(other)}")]}
    end
  rescue
    e -> {:error, [Error.new(path, :computed_field, "Exception: #{Exception.message(e)}")]}
  end

  @spec generate_computed_field_properties(t()) :: %{String.t() => map()}
  defp generate_computed_field_properties(%__MODULE__{} = enhanced_schema) do
    enhanced_schema.computed_fields
    |> Enum.map(fn {field_name, computed_meta} ->
      field_schema = TypeMapper.to_json_schema(computed_meta.type)

      enhanced_field_schema =
        field_schema
        |> Map.put("readOnly", true)
        |> maybe_add_description(computed_meta.description)
        |> maybe_add_example(computed_meta.example)

      {Atom.to_string(field_name), enhanced_field_schema}
    end)
    |> Map.new()
  end

  @spec add_enhanced_metadata(map(), t()) :: map()
  defp add_enhanced_metadata(json_schema, %__MODULE__{} = enhanced_schema) do
    json_schema
    |> Map.put("x-model-validators", length(enhanced_schema.model_validators))
    |> Map.put("x-computed-fields", length(enhanced_schema.computed_fields))
    |> Map.put("x-enhanced-schema", true)
  end

  @spec maybe_add_description(map(), String.t() | nil) :: map()
  defp maybe_add_description(schema, nil), do: schema
  defp maybe_add_description(schema, description), do: Map.put(schema, "description", description)

  @spec maybe_add_example(map(), term() | nil) :: map()
  defp maybe_add_example(schema, nil), do: schema
  defp maybe_add_example(schema, example), do: Map.put(schema, "examples", [example])

  @spec generate_function_name(String.t(), atom() | nil) :: atom()
  defp generate_function_name(prefix, suffix \\ nil) do
    base_name = if suffix, do: "#{prefix}_#{suffix}", else: prefix
    unique_id = System.unique_integer([:positive])
    timestamp = System.system_time(:nanosecond)

    :"__runtime_#{base_name}_#{unique_id}_#{timestamp}"
  end
end
