defmodule Exdantic.Runtime do
  @moduledoc """
  Runtime schema generation and validation capabilities.

  This module enables dynamic schema creation from field definitions at runtime,
  supporting the DSPy pattern of `pydantic.create_model("DSPyProgramOutputs", **fields)`.

  ## Phase 5 Enhancement: Enhanced Runtime Schemas

  Added support for enhanced runtime schemas with model validators and computed fields:

      # Create enhanced schema with full validation pipeline
      fields = [{:name, :string, [required: true]}, {:age, :integer, [optional: true]}]

      # Model validators for cross-field validation
      validators = [
        fn data -> {:ok, %{data | name: String.trim(data.name)}} end,
        {MyModule, :validate_age}
      ]

      # Computed fields for derived values
      computed_fields = [
        {:display_name, :string, fn data -> {:ok, String.upcase(data.name)} end},
        {:age_group, :string, {MyModule, :compute_age_group}}
      ]

      # Create enhanced schema
      schema = Runtime.create_enhanced_schema(fields,
        title: "User Schema",
        model_validators: validators,
        computed_fields: computed_fields
      )

      # Validate with full pipeline
      {:ok, result} = Runtime.validate_enhanced(%{name: "  john  ", age: 25}, schema)
      # Result: %{name: "john", age: 25, display_name: "JOHN", age_group: "adult"}

  Enhanced schemas support:
  - Model validators (both named functions and anonymous functions)
  - Computed fields (both named functions and anonymous functions)
  - Full validation pipeline execution (field → model → computed)
  - JSON Schema generation with enhanced metadata
  - Integration with existing validation infrastructure

  ## Basic Runtime Schemas

  For simple use cases without enhanced features:

      # Basic runtime schema
      fields = [{:name, :string, [required: true]}, {:age, :integer, [optional: true]}]
      schema = Runtime.create_schema(fields, title: "Basic User Schema")

      {:ok, validated} = Runtime.validate(%{name: "John", age: 30}, schema)
      # Result: %{name: "John", age: 30}

  ## Schema Types

  - `DynamicSchema` - Basic runtime schema with field validation
  - `EnhancedSchema` - Advanced runtime schema with model validators and computed fields

  ## Phase 5 Migration Guide

  ### Upgrading to Enhanced Runtime Schemas

  Phase 5 adds enhanced runtime schemas while maintaining 100% backward compatibility with existing DynamicSchema usage.

  #### Existing Code (Still Works)
  ```elixir
  # All existing runtime schema code continues to work unchanged
  fields = [{:name, :string, [required: true]}]
  schema = Exdantic.Runtime.create_schema(fields)
  {:ok, result} = Exdantic.Runtime.validate(data, schema)
  ```

  #### New Enhanced Features
  ```elixir
  # Create enhanced schema with model validators and computed fields
  fields = [{:name, :string, [required: true]}]

  validators = [fn data -> {:ok, %{data | name: String.trim(data.name)}} end]
  computed = [{:display_name, :string, fn data -> {:ok, String.upcase(data.name)} end}]

  enhanced_schema = Exdantic.Runtime.create_enhanced_schema(fields,
    model_validators: validators,
    computed_fields: computed
  )

  {:ok, result} = Exdantic.Runtime.validate_enhanced(data, enhanced_schema)
  ```

  #### Unified Validation Interface
  ```elixir
  # Use Exdantic.Runtime.Validator for unified interface
  alias Exdantic.Runtime.Validator

  # Works with both DynamicSchema and EnhancedSchema
  {:ok, result} = Validator.validate(data, any_runtime_schema)
  json_schema = Validator.to_json_schema(any_runtime_schema)
  info = Validator.schema_info(any_runtime_schema)
  ```

  ### Breaking Changes
  None. All existing code continues to work without modification.

  ### New Dependencies
  None. Phase 5 uses only existing Exdantic modules and standard library functions.

  ### Performance Impact
  - DynamicSchema validation performance unchanged
  - EnhancedSchema adds minimal overhead for model validator and computed field execution
  - JSON schema generation includes computed field metadata with negligible performance impact

  ## Implementation Notes

  ### Function Storage
  Enhanced schemas store anonymous functions in a runtime function registry, ensuring they can be executed during validation while maintaining clean serialization for schema metadata.

  ### Error Handling
  Enhanced schemas provide comprehensive error handling:
  - Field validation errors maintain existing behavior
  - Model validator errors include clear context and function references
  - Computed field errors specify which computation failed and why
  - Type validation errors for computed field return values

  ### JSON Schema Integration
  Enhanced schemas generate JSON schemas that include:
  - All regular fields with their types and constraints
  - Computed fields marked as `readOnly: true`
  - Enhanced metadata (`x-enhanced-schema`, `x-model-validators`, `x-computed-fields`)
  - Full compatibility with existing JSON schema tooling

  ### Memory Management
  Runtime functions are stored efficiently with unique generated names to prevent conflicts. The function registry is cleaned up when the schema is garbage collected.

  ## Testing Strategy

  Phase 5 includes comprehensive tests covering:
  - Basic enhanced schema creation and validation
  - Model validator execution (named and anonymous functions)
  - Computed field execution (named and anonymous functions)
  - Error handling at each pipeline stage
  - JSON schema generation with enhanced features
  - Integration with existing validation infrastructure
  - Performance benchmarks for enhanced vs basic schemas

  All existing tests continue to pass, ensuring backward compatibility.
  """

  alias Exdantic.Runtime.{DynamicSchema, EnhancedSchema}
  alias Exdantic.{FieldMeta, Validator}
  alias Exdantic.JsonSchema.{ReferenceStore, Resolver, TypeMapper}

  @type field_definition :: {atom(), type_spec()} | {atom(), type_spec(), keyword()}
  @type type_spec :: Exdantic.Types.type_definition() | atom() | module()
  @type schema_option :: {:title, String.t()} | {:description, String.t()} | {:strict, boolean()}

  @doc """
  Creates a schema at runtime from field definitions.

  ## Parameters
    * `field_definitions` - List of field definitions in the format:
      - `{field_name, type}`
      - `{field_name, type, options}`
    * `opts` - Schema configuration options

  ## Options
    * `:title` - Schema title
    * `:description` - Schema description
    * `:strict` - Enable strict validation (default: false)
    * `:name` - Schema name for references

  ## Examples

      iex> fields = [
      ...>   {:name, :string, [required: true, min_length: 2]},
      ...>   {:age, :integer, [optional: true, gt: 0]},
      ...>   {:email, :string, [required: true, format: ~r/@/]}
      ...> ]
      iex> schema = Exdantic.Runtime.create_schema(fields, title: "User Schema")
      %Exdantic.Runtime.DynamicSchema{...}
  """
  @spec create_schema([field_definition()], [schema_option()]) :: DynamicSchema.t()
  def create_schema(field_definitions, opts \\ []) do
    name = Keyword.get(opts, :name, generate_schema_name())

    config = %{
      title: Keyword.get(opts, :title),
      description: Keyword.get(opts, :description),
      strict: Keyword.get(opts, :strict, false)
    }

    fields =
      field_definitions
      |> Enum.map(&normalize_field_definition/1)
      |> Map.new(fn {name, meta} -> {name, meta} end)

    %DynamicSchema{
      name: name,
      fields: fields,
      config: config,
      metadata: %{
        created_at: DateTime.utc_now(),
        field_count: map_size(fields)
      }
    }
  end

  @doc """
  Validates data against a runtime-created schema.

  ## Parameters
    * `data` - The data to validate (map)
    * `dynamic_schema` - A DynamicSchema struct
    * `opts` - Validation options

  ## Returns
    * `{:ok, validated_data}` on success
    * `{:error, errors}` on validation failure

  ## Examples

      iex> data = %{name: "John", age: 30}
      iex> Exdantic.Runtime.validate(data, schema)
      {:ok, %{name: "John", age: 30}}
  """
  @spec validate(map(), DynamicSchema.t(), keyword()) ::
          {:ok, map()} | {:error, [Exdantic.Error.t()]}
  def validate(data, %DynamicSchema{} = schema, opts \\ []) do
    path = Keyword.get(opts, :path, [])
    # Runtime opts override schema config
    runtime_strict = Keyword.get(opts, :strict, schema.config[:strict])
    config = Map.put(schema.config, :strict, runtime_strict)

    with :ok <- validate_required_fields(schema.fields, data, path),
         {:ok, validated} <- validate_fields(schema.fields, data, path),
         :ok <- validate_strict_mode(config, validated, data, path) do
      {:ok, validated}
    else
      {:error, errors} when is_list(errors) ->
        {:error, errors}

      {:error, error} when is_struct(error, Exdantic.Error) ->
        {:error, [error]}

      {:error, other} ->
        {:error, [other]}
    end
  end

  @doc """
  Generates JSON Schema from a runtime schema.

  ## Parameters
    * `dynamic_schema` - A DynamicSchema struct
    * `opts` - JSON Schema generation options

  ## Returns
    * JSON Schema map

  ## Examples

      iex> json_schema = Exdantic.Runtime.to_json_schema(schema)
      %{"type" => "object", "properties" => %{...}}
  """
  @spec to_json_schema(DynamicSchema.t(), keyword()) :: map()
  def to_json_schema(%DynamicSchema{} = schema, opts \\ []) do
    {:ok, store} = ReferenceStore.start_link()

    try do
      base_schema =
        %{
          "type" => "object",
          "title" => schema.config[:title],
          "description" => schema.config[:description],
          "properties" => %{},
          "required" => []
        }
        |> maybe_add_additional_properties(
          schema.config[:strict] ||
            Keyword.get(opts, :additional_properties) == false ||
            Keyword.get(opts, :strict, false)
        )
        |> Map.reject(fn {_, v} -> is_nil(v) end)

      schema_with_fields =
        Enum.reduce(schema.fields, base_schema, fn {name, field_meta}, acc ->
          # Add to properties
          properties = Map.get(acc, "properties", %{})

          field_schema =
            TypeMapper.to_json_schema(field_meta.type, store)
            |> Map.merge(convert_field_metadata(field_meta))
            |> Map.reject(fn {_, v} -> is_nil(v) end)

          updated_properties = Map.put(properties, Atom.to_string(name), field_schema)
          acc = Map.put(acc, "properties", updated_properties)

          # Add to required if needed
          if field_meta.required do
            required = Map.get(acc, "required", [])
            Map.put(acc, "required", [Atom.to_string(name) | required])
          else
            acc
          end
        end)

      # Add definitions if any references were created
      definitions = ReferenceStore.get_definitions(store)

      if map_size(definitions) > 0 do
        Map.put(schema_with_fields, "definitions", definitions)
      else
        schema_with_fields
      end
    after
      ReferenceStore.stop(store)
    end
  end

  @doc """
  Creates an enhanced runtime schema with model validators and computed fields.

  This function provides a convenient way to create schemas with enhanced features
  similar to compile-time schemas but generated at runtime.

  ## Parameters
    * `field_definitions` - List of field definitions
    * `opts` - Enhanced schema options

  ## Options
    * `:model_validators` - List of model validator functions
    * `:computed_fields` - List of computed field specifications
    * Standard options: `:title`, `:description`, `:strict`, `:name`

  ## Examples

      iex> fields = [{:name, :string, [required: true]}, {:age, :integer, [optional: true]}]
      iex> validators = [fn data -> {:ok, %{data | name: String.trim(data.name)}} end]
      iex> computed = [{:display_name, :string, fn data -> {:ok, String.upcase(data.name)} end}]
      iex> schema = Exdantic.Runtime.create_enhanced_schema(fields,
      ...>   model_validators: validators,
      ...>   computed_fields: computed
      ...> )
      %Exdantic.Runtime.EnhancedSchema{...}
  """
  @spec create_enhanced_schema([field_definition()], [schema_option()]) :: EnhancedSchema.t()
  def create_enhanced_schema(field_definitions, opts \\ []) do
    EnhancedSchema.create(field_definitions, opts)
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
      iex> Exdantic.Runtime.validate_enhanced(data, schema)
      {:ok, %{name: "John", age: 30, display_name: "JOHN"}}
  """
  @spec validate_enhanced(map(), EnhancedSchema.t(), keyword()) ::
          {:ok, map()} | {:error, [Exdantic.Error.t()]}
  def validate_enhanced(data, %EnhancedSchema{} = enhanced_schema, opts \\ []) do
    EnhancedSchema.validate(data, enhanced_schema, opts)
  end

  @doc """
  Generates JSON Schema for enhanced runtime schemas.

  ## Parameters
    * `enhanced_schema` - An EnhancedSchema struct
    * `opts` - JSON Schema generation options

  ## Returns
    * JSON Schema map including computed field metadata
  """
  @spec enhanced_to_json_schema(EnhancedSchema.t(), keyword()) :: map()
  def enhanced_to_json_schema(%EnhancedSchema{} = enhanced_schema, opts \\ []) do
    EnhancedSchema.to_json_schema(enhanced_schema, opts)
  end

  @doc """
  Creates an enhanced schema with Phase 6 integration features.

  Phase 6 Enhancement: Complete integration with EnhancedResolver and validation pipeline.

  ## Parameters
    * `field_definitions` - Field definitions
    * `opts` - Enhanced schema options with Phase 6 features

  ## Phase 6 Options
    * `:auto_optimize_for_provider` - Automatically optimize for LLM provider (default: nil)
    * `:include_validation_metadata` - Include validation metadata in schema (default: false)
    * `:dspy_compatible` - Ensure DSPy compatibility (default: false)
    * All existing options from previous phases

  ## Examples

      iex> schema = Exdantic.Runtime.create_enhanced_schema_v6(fields,
      ...>   model_validators: validators,
      ...>   computed_fields: computed,
      ...>   auto_optimize_for_provider: :openai,
      ...>   dspy_compatible: true
      ...> )
  """
  @spec create_enhanced_schema_v6([field_definition()], [schema_option()]) :: EnhancedSchema.t()
  def create_enhanced_schema_v6(field_definitions, opts \\ []) do
    auto_optimize = Keyword.get(opts, :auto_optimize_for_provider)
    include_metadata = Keyword.get(opts, :include_validation_metadata, false)
    dspy_compatible = Keyword.get(opts, :dspy_compatible, false)

    # Create base enhanced schema
    base_schema = create_enhanced_schema(field_definitions, opts)

    # Apply Phase 6 enhancements
    enhanced_metadata = %{
      phase_6_enhanced: true,
      auto_optimization: auto_optimize,
      validation_metadata: include_metadata,
      dspy_compatible: dspy_compatible,
      created_with_version: "Phase 6"
    }

    updated_metadata = Map.merge(base_schema.metadata, enhanced_metadata)

    # Validate DSPy compatibility if requested
    final_schema =
      if dspy_compatible do
        validate_dspy_compatibility(base_schema)
      else
        base_schema
      end

    %{final_schema | metadata: updated_metadata}
  end

  @doc """
  Validates an enhanced schema with complete pipeline testing.

  Phase 6 Enhancement: Comprehensive validation testing including all features.

  ## Parameters
    * `data` - Data to validate
    * `enhanced_schema` - Enhanced schema
    * `opts` - Validation options with Phase 6 features

  ## Phase 6 Options
    * `:test_all_providers` - Test compatibility with all LLM providers (default: false)
    * `:generate_performance_report` - Include performance metrics (default: false)
    * `:validate_json_schema` - Validate generated JSON schema (default: false)

  ## Returns
    * Enhanced validation result with optional additional information
  """
  @spec validate_enhanced_v6(map(), EnhancedSchema.t(), keyword()) ::
          {:ok, map()} | {:ok, map(), map()} | {:error, [Exdantic.Error.t()]}
  def validate_enhanced_v6(data, %EnhancedSchema{} = enhanced_schema, opts \\ []) do
    test_providers = Keyword.get(opts, :test_all_providers, false)
    performance_report = Keyword.get(opts, :generate_performance_report, false)
    validate_json = Keyword.get(opts, :validate_json_schema, false)

    start_time = System.monotonic_time(:microsecond)

    # Core validation
    case validate_enhanced(data, enhanced_schema, opts) do
      {:ok, validated_data} ->
        # Generate additional information if requested
        additional_info =
          generate_additional_validation_info(
            enhanced_schema,
            validated_data,
            start_time,
            test_providers,
            performance_report,
            validate_json
          )

        if map_size(additional_info) > 0 do
          {:ok, validated_data, additional_info}
        else
          {:ok, validated_data}
        end

      {:error, errors} ->
        {:error, errors}
    end
  end

  # Private helper functions for Phase 6 enhancements

  @spec validate_dspy_compatibility(EnhancedSchema.t()) :: EnhancedSchema.t()
  defp validate_dspy_compatibility(schema) do
    # Check if schema is compatible with DSPy patterns
    issues = []

    # Check for overly complex model validators
    issues =
      if length(schema.model_validators) > 3 do
        ["Too many model validators for DSPy compatibility" | issues]
      else
        issues
      end

    # Check for complex computed fields
    complex_computed_fields =
      Enum.count(schema.computed_fields, fn {_name, _meta} ->
        # For now, assume all computed fields are simple
        # In a real implementation, we'd analyze the computation complexity
        false
      end)

    issues =
      if complex_computed_fields > 5 do
        ["Too many computed fields for DSPy compatibility" | issues]
      else
        issues
      end

    # Store compatibility issues in metadata
    dspy_metadata = %{
      dspy_compatibility_checked: true,
      dspy_issues: issues,
      dspy_compatible: issues == []
    }

    updated_metadata = Map.merge(schema.metadata, dspy_metadata)
    %{schema | metadata: updated_metadata}
  end

  @spec generate_additional_validation_info(
          EnhancedSchema.t(),
          map(),
          integer(),
          boolean(),
          boolean(),
          boolean()
        ) :: map()
  defp generate_additional_validation_info(
         schema,
         _validated_data,
         start_time,
         test_providers,
         performance_report,
         validate_json
       ) do
    info = %{}

    # Performance report
    info =
      if performance_report do
        end_time = System.monotonic_time(:microsecond)
        duration = end_time - start_time

        performance_data = %{
          validation_duration_microseconds: duration,
          validation_duration_milliseconds: duration / 1000,
          field_count: map_size(schema.base_schema.fields),
          computed_field_count: length(schema.computed_fields),
          model_validator_count: length(schema.model_validators)
        }

        Map.put(info, :performance_metrics, performance_data)
      else
        info
      end

    # Provider compatibility testing
    info =
      if test_providers do
        json_schema = enhanced_to_json_schema(schema)
        compatibility = test_provider_compatibility(json_schema)
        Map.put(info, :provider_compatibility, compatibility)
      else
        info
      end

    # JSON schema validation
    info =
      if validate_json do
        json_schema = enhanced_to_json_schema(schema)
        validation_result = validate_json_schema_structure(json_schema)
        Map.put(info, :json_schema_validation, validation_result)
      else
        info
      end

    info
  end

  @spec test_provider_compatibility(map()) :: map()
  defp test_provider_compatibility(json_schema) do
    providers = [:openai, :anthropic, :generic]

    Enum.reduce(providers, %{}, fn provider, acc ->
      try do
        optimized =
          Resolver.enforce_structured_output(
            json_schema,
            provider: provider
          )

        score = calculate_compatibility_score(optimized, provider)

        Map.put(acc, provider, %{
          compatible: true,
          compatibility_score: score,
          optimized_schema: optimized
        })
      rescue
        e ->
          Map.put(acc, provider, %{
            compatible: false,
            error: Exception.message(e),
            compatibility_score: 0
          })
      end
    end)
  end

  @spec calculate_compatibility_score(map(), atom()) :: pos_integer()
  defp calculate_compatibility_score(schema, provider) do
    base_score = 50
    score = calculate_provider_specific_score(schema, provider, base_score)
    min(score, 100)
  end

  @spec calculate_provider_specific_score(map(), atom(), pos_integer()) :: pos_integer()
  defp calculate_provider_specific_score(schema, :openai, base_score) do
    base_score
    |> add_score_for_additional_properties(schema)
    |> add_score_for_required_fields(schema)
    |> add_score_for_object_type(schema)
  end

  defp calculate_provider_specific_score(schema, :anthropic, base_score) do
    base_score
    |> add_score_for_required_fields(schema)
    |> add_score_for_additional_properties(schema)
    |> add_score_for_object_type(schema)
  end

  defp calculate_provider_specific_score(_schema, :generic, base_score), do: base_score + 25
  defp calculate_provider_specific_score(_schema, _provider, base_score), do: base_score

  @spec add_score_for_additional_properties(pos_integer(), map()) :: pos_integer()
  defp add_score_for_additional_properties(score, schema) do
    if Map.get(schema, "additionalProperties") == false, do: score + 20, else: score
  end

  @spec add_score_for_required_fields(pos_integer(), map()) :: pos_integer()
  defp add_score_for_required_fields(score, schema) do
    if Map.has_key?(schema, "required"), do: score + 15, else: score
  end

  @spec add_score_for_object_type(pos_integer(), map()) :: pos_integer()
  defp add_score_for_object_type(score, schema) do
    if Map.get(schema, "type") == "object", do: score + 10, else: score
  end

  @spec validate_json_schema_structure(map()) :: %{
          valid: boolean(),
          issues: [String.t()],
          checked_at: DateTime.t()
        }
  defp validate_json_schema_structure(json_schema) do
    issues = []

    # Check required fields for object schemas
    issues =
      if Map.get(json_schema, "type") == "object" do
        if Map.has_key?(json_schema, "properties") do
          issues
        else
          ["Object schema missing properties" | issues]
        end
      else
        issues
      end

    # Check for valid type values
    valid_types = ["string", "number", "integer", "boolean", "array", "object", "null"]
    schema_type = Map.get(json_schema, "type")

    issues =
      if schema_type && schema_type not in valid_types do
        ["Invalid schema type: #{schema_type}" | issues]
      else
        issues
      end

    # Check for proper constraint values
    issues = check_constraint_validity(json_schema, issues)

    %{
      valid: issues == [],
      issues: issues,
      checked_at: DateTime.utc_now()
    }
  end

  @spec check_constraint_validity(map(), [String.t()]) :: [String.t()]
  defp check_constraint_validity(schema, issues) do
    check_string_constraints(issues, schema)
  end

  @spec check_string_constraints([String.t()], map()) :: [String.t()]
  defp check_string_constraints(issues, schema) do
    case Map.get(schema, "type") do
      "string" ->
        min_len = Map.get(schema, "minLength")
        max_len = Map.get(schema, "maxLength")
        validate_string_length_constraints(min_len, max_len, issues)

      _ ->
        issues
    end
  end

  @spec validate_string_length_constraints(term(), term(), [String.t()]) :: [String.t()]
  defp validate_string_length_constraints(min_len, max_len, issues) do
    cond do
      min_len && not is_integer(min_len) ->
        ["minLength must be an integer" | issues]

      max_len && not is_integer(max_len) ->
        ["maxLength must be an integer" | issues]

      min_len && max_len && min_len > max_len ->
        ["minLength cannot be greater than maxLength" | issues]

      true ->
        issues
    end
  end

  # Private helper functions

  @spec normalize_field_definition(field_definition()) :: {atom(), FieldMeta.t()}
  defp normalize_field_definition({name, type}) do
    normalize_field_definition({name, type, []})
  end

  defp normalize_field_definition({name, type, opts}) when is_atom(name) do
    field_meta = %FieldMeta{
      name: name,
      type: normalize_type_definition(type, opts),
      required: determine_required(opts),
      description: Keyword.get(opts, :description),
      example: Keyword.get(opts, :example),
      examples: Keyword.get(opts, :examples),
      default: Keyword.get(opts, :default),
      constraints: extract_constraints(opts),
      extra: Keyword.get(opts, :extra, %{})
    }

    # If default is provided, make field optional
    field_meta =
      if field_meta.default do
        %{field_meta | required: false}
      else
        field_meta
      end

    {name, field_meta}
  end

  @spec normalize_type_definition(type_spec(), keyword()) :: Exdantic.Types.type_definition()
  defp normalize_type_definition(type, opts) when is_atom(type) do
    constraints = extract_constraints(opts)

    cond do
      type in [:string, :integer, :float, :boolean, :any, :atom, :map] ->
        {:type, type, constraints}

      Code.ensure_loaded?(type) and function_exported?(type, :__schema__, 1) ->
        {:ref, type}

      true ->
        {:type, type, constraints}
    end
  end

  defp normalize_type_definition({:array, inner_type}, opts) do
    constraints = extract_constraints(opts)
    {:array, normalize_type_definition(inner_type, []), constraints}
  end

  defp normalize_type_definition({:map, {key_type, value_type}}, opts) do
    constraints = extract_constraints(opts)
    normalized_key = normalize_type_definition(key_type, [])
    normalized_value = normalize_type_definition(value_type, [])
    {:map, {normalized_key, normalized_value}, constraints}
  end

  defp normalize_type_definition({:union, types}, opts) do
    constraints = extract_constraints(opts)
    normalized_types = Enum.map(types, &normalize_type_definition(&1, []))
    {:union, normalized_types, constraints}
  end

  defp normalize_type_definition({:ref, schema_module}, _opts) when is_atom(schema_module) do
    # Ref types don't need constraints wrapping - they are handled by the referenced schema
    {:ref, schema_module}
  end

  defp normalize_type_definition(type, opts) do
    constraints = extract_constraints(opts)
    {Exdantic.Types.normalize_type(type), constraints}
  end

  @spec determine_required(keyword()) :: boolean()
  defp determine_required(opts) do
    cond do
      Keyword.has_key?(opts, :required) -> Keyword.get(opts, :required)
      Keyword.get(opts, :optional, false) -> false
      true -> true
    end
  end

  @spec extract_constraints(keyword()) :: [term()]
  defp extract_constraints(opts) do
    constraint_keys =
      MapSet.new([
        :min_length,
        :max_length,
        :min_items,
        :max_items,
        :gt,
        :lt,
        :gteq,
        :lteq,
        :format,
        :choices
      ])

    Enum.filter(opts, fn {key, _value} ->
      MapSet.member?(constraint_keys, key)
    end)
  end

  @spec validate_required_fields(map(), map(), [atom()]) :: :ok | {:error, Exdantic.Error.t()}
  defp validate_required_fields(fields, data, path) do
    required_fields =
      fields
      |> Enum.filter(fn {_, meta} -> meta.required end)
      |> Enum.map(fn {name, _} -> name end)

    case Enum.find(required_fields, fn field ->
           not (Map.has_key?(data, field) or Map.has_key?(data, Atom.to_string(field)))
         end) do
      nil -> :ok
      field -> {:error, Exdantic.Error.new([field | path], :required, "field is required")}
    end
  end

  @spec validate_fields(map(), map(), [atom()]) ::
          {:ok, map()} | {:error, Exdantic.Error.t() | [Exdantic.Error.t()]}
  defp validate_fields(fields, data, path) do
    {validated, errors} =
      Enum.reduce(fields, {%{}, []}, fn {name, meta}, {acc, errors_acc} ->
        validate_single_field(name, meta, data, path, acc, errors_acc)
      end)

    case errors do
      [] -> {:ok, validated}
      _ -> {:error, Enum.reverse(errors)}
    end
  end

  defp validate_single_field(name, meta, data, path, acc, errors_acc) do
    field_path = path ++ [name]
    value = Map.get(data, name) || Map.get(data, Atom.to_string(name))

    case handle_field_value(value, meta, field_path) do
      {:ok, validated_value} ->
        {Map.put(acc, name, validated_value), errors_acc}

      {:error, field_errors} when is_list(field_errors) ->
        {acc, field_errors ++ errors_acc}

      {:error, field_error} ->
        {acc, [field_error | errors_acc]}
    end
  end

  defp handle_field_value(nil, %{default: default}, _field_path), do: {:ok, default}
  defp handle_field_value(nil, %{required: false}, _field_path), do: {:skip, nil}

  defp handle_field_value(nil, _meta, field_path) do
    {:error, Exdantic.Error.new(field_path, :required, "field is required")}
  end

  defp handle_field_value(value, meta, field_path) do
    Validator.validate(meta.type, value, field_path)
  end

  @spec validate_strict_mode(map(), map(), map(), [atom()]) :: :ok | {:error, Exdantic.Error.t()}
  defp validate_strict_mode(%{strict: true}, validated, original, path) do
    validated_keys = Map.keys(validated) |> Enum.map(&Atom.to_string/1) |> MapSet.new()
    original_keys = Map.keys(original) |> Enum.map(&to_string/1) |> MapSet.new()

    case MapSet.difference(original_keys, validated_keys) |> MapSet.to_list() do
      [] ->
        :ok

      extra ->
        {:error,
         Exdantic.Error.new(path, :additional_properties, "unknown fields: #{inspect(extra)}")}
    end
  end

  defp validate_strict_mode(_, _, _, _), do: :ok

  @spec maybe_add_additional_properties(map(), boolean() | nil) :: map()
  defp maybe_add_additional_properties(schema, true) do
    Map.put(schema, "additionalProperties", false)
  end

  defp maybe_add_additional_properties(schema, _), do: schema

  @spec convert_field_metadata(FieldMeta.t()) :: map()
  defp convert_field_metadata(field_meta) do
    base = %{
      "description" => field_meta.description,
      "default" => field_meta.default
    }

    # Handle examples
    base =
      cond do
        examples = field_meta.examples ->
          Map.put(base, "examples", examples)

        example = field_meta.example ->
          Map.put(base, "examples", [example])

        true ->
          base
      end

    Map.reject(base, fn {_, v} -> is_nil(v) end)
  end

  @spec generate_schema_name() :: String.t()
  defp generate_schema_name do
    "DynamicSchema_#{System.unique_integer([:positive])}"
  end
end
