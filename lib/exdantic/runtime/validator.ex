defmodule Exdantic.Runtime.Validator do
  @moduledoc """
  Validation functions specifically for runtime schemas.

  This module provides validation logic that works with both DynamicSchema
  and EnhancedSchema, handling the full validation pipeline including
  model validators and computed fields.
  """

  alias Exdantic.Error
  alias Exdantic.Runtime.{DynamicSchema, EnhancedSchema}

  @doc """
  Validates data against a runtime schema (DynamicSchema or EnhancedSchema).

  ## Parameters
    * `data` - The data to validate
    * `schema` - DynamicSchema or EnhancedSchema struct
    * `opts` - Validation options

  ## Returns
    * `{:ok, validated_data}` on success
    * `{:error, errors}` on validation failure
  """
  @spec validate(map(), DynamicSchema.t() | EnhancedSchema.t(), keyword()) ::
          {:ok, map()} | {:error, [Error.t()]}
  def validate(data, schema, opts \\ [])

  def validate(data, %DynamicSchema{} = schema, opts) do
    Exdantic.Runtime.validate(data, schema, opts)
  end

  def validate(data, %EnhancedSchema{} = schema, opts) do
    EnhancedSchema.validate(data, schema, opts)
  end

  @doc """
  Validates data against a runtime schema, raising on failure.

  ## Parameters
    * `data` - The data to validate
    * `schema` - DynamicSchema or EnhancedSchema struct
    * `opts` - Validation options

  ## Returns
    * Validated data on success
    * Raises `Exdantic.ValidationError` on failure
  """
  @spec validate!(map(), DynamicSchema.t() | EnhancedSchema.t(), keyword()) :: map()
  def validate!(data, schema, opts \\ []) do
    case validate(data, schema, opts) do
      {:ok, validated} -> validated
      {:error, errors} -> raise Exdantic.ValidationError, errors: errors
    end
  end

  @doc """
  Generates JSON Schema for a runtime schema.

  ## Parameters
    * `schema` - DynamicSchema or EnhancedSchema struct
    * `opts` - JSON Schema generation options

  ## Returns
    * JSON Schema map
  """
  @spec to_json_schema(DynamicSchema.t() | EnhancedSchema.t(), keyword()) :: map()
  def to_json_schema(schema, opts \\ [])

  def to_json_schema(%DynamicSchema{} = schema, opts) do
    Exdantic.Runtime.to_json_schema(schema, opts)
  end

  def to_json_schema(%EnhancedSchema{} = schema, opts) do
    EnhancedSchema.to_json_schema(schema, opts)
  end

  @doc """
  Returns information about a runtime schema.

  ## Parameters
    * `schema` - DynamicSchema or EnhancedSchema struct

  ## Returns
    * Map with schema information
  """
  @spec schema_info(DynamicSchema.t() | EnhancedSchema.t()) :: map()
  def schema_info(%DynamicSchema{} = schema) do
    DynamicSchema.summary(schema)
    |> Map.put(:schema_type, :dynamic)
    |> Map.put(:enhanced, false)
  end

  def schema_info(%EnhancedSchema{} = schema) do
    EnhancedSchema.info(schema)
    |> Map.put(:schema_type, :enhanced)
    |> Map.put(:enhanced, true)
  end

  @doc """
  Checks if a schema supports enhanced features.

  ## Parameters
    * `schema` - DynamicSchema or EnhancedSchema struct

  ## Returns
    * `true` if schema supports enhanced features, `false` otherwise
  """
  @spec enhanced_schema?(DynamicSchema.t() | EnhancedSchema.t()) :: boolean()
  def enhanced_schema?(%EnhancedSchema{}), do: true
  def enhanced_schema?(%DynamicSchema{}), do: false

  @doc """
  Converts a DynamicSchema to an EnhancedSchema.

  ## Parameters
    * `dynamic_schema` - DynamicSchema to convert
    * `opts` - Options for enhancement

  ## Options
    * `:model_validators` - Model validators to add
    * `:computed_fields` - Computed fields to add

  ## Returns
    * EnhancedSchema struct
  """
  @spec enhance_schema(DynamicSchema.t(), keyword()) :: EnhancedSchema.t()
  def enhance_schema(%DynamicSchema{} = dynamic_schema, opts \\ []) do
    # Use the same processing logic as EnhancedSchema.create/2
    model_validators = Keyword.get(opts, :model_validators, [])
    computed_fields = Keyword.get(opts, :computed_fields, [])

    # Process model validators and computed fields properly
    {processed_validators, runtime_functions} =
      EnhancedSchema.process_model_validators(model_validators)

    {processed_computed_fields, updated_runtime_functions} =
      EnhancedSchema.process_computed_fields(computed_fields, runtime_functions)

    %EnhancedSchema{
      base_schema: dynamic_schema,
      model_validators: processed_validators,
      computed_fields: processed_computed_fields,
      runtime_functions: updated_runtime_functions,
      metadata: %{
        created_at: DateTime.utc_now(),
        enhanced_from_dynamic: true,
        validator_count: length(processed_validators),
        computed_field_count: length(processed_computed_fields)
      }
    }
  end
end
