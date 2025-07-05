defmodule Exdantic.EnhancedValidator do
  @moduledoc """
  Enhanced validation functionality that integrates all new Exdantic features.

  This module provides a unified interface for validation using the new runtime
  capabilities, TypeAdapter functionality, advanced configuration, and wrapper
  support.
  """

  alias Exdantic.{Config, JsonSchema, Runtime, TypeAdapter, Wrapper}
  alias Exdantic.JsonSchema.EnhancedResolver
  alias Exdantic.Runtime.{DynamicSchema, EnhancedSchema}

  @type validation_input :: map() | term()
  @type validation_target :: DynamicSchema.t() | module() | TypeAdapter.type_spec()
  @type validation_result :: {:ok, term()} | {:error, [Exdantic.Error.t()]}
  @type validation_result_with_skip :: validation_result() | {:skip, term()}
  @type enhanced_options :: [
          config: Config.t(),
          wrapper_field: atom(),
          json_schema_opts: keyword(),
          type_adapter_opts: keyword()
        ]

  @doc """
  Universal validation function that handles all types of validation targets.

  ## Parameters
    * `target` - What to validate against (schema, type spec, etc.)
    * `input` - The data to validate
    * `opts` - Enhanced validation options

  ## Options
    * `:config` - Exdantic.Config for validation behavior
    * `:wrapper_field` - Field name if using wrapper validation
    * `:json_schema_opts` - Options for JSON schema operations
    * `:type_adapter_opts` - Options for TypeAdapter operations

  ## Returns
    * `{:ok, validated_data}` on success
    * `{:error, errors}` on validation failure

  ## Examples

      # Validate against a compiled schema
      iex> Exdantic.EnhancedValidator.validate(MySchema, %{name: "John"})
      {:ok, %{name: "John"}}

      # Validate against a runtime schema
      iex> schema = Exdantic.Runtime.create_schema([{:name, :string}])
      iex> Exdantic.EnhancedValidator.validate(schema, %{name: "John"})
      {:ok, %{name: "John"}}

      # Validate against a type specification
      iex> Exdantic.EnhancedValidator.validate({:array, :string}, ["a", "b"])
      {:ok, ["a", "b"]}

      # Validate with custom configuration
      iex> config = Exdantic.Config.create(strict: true, coercion: :safe)
      iex> Exdantic.EnhancedValidator.validate(:integer, "123", config: config)
      {:ok, 123}
  """
  @spec validate(validation_target(), validation_input(), enhanced_options()) ::
          validation_result()
  def validate(target, input, opts \\ [])

  # Handle DynamicSchema validation
  def validate(%DynamicSchema{} = schema, input, opts) do
    config = Keyword.get(opts, :config, Config.create())
    validation_opts = Config.to_validation_opts(config)

    if Keyword.get(validation_opts, :coerce, false) do
      # Use field-by-field TypeAdapter validation for coercion
      validate_dynamic_schema_with_coercion(schema, input, validation_opts)
    else
      # Use normal Runtime validation
      Runtime.validate(input, schema, validation_opts)
    end
  end

  # Handle compiled schema module validation
  def validate(schema_module, input, opts) when is_atom(schema_module) do
    if function_exported?(schema_module, :__schema__, 1) do
      config = Keyword.get(opts, :config, Config.create())
      validation_opts = Config.to_validation_opts(config)

      case Exdantic.StructValidator.validate_schema(
             schema_module,
             input,
             validation_opts[:path] || []
           ) do
        {:ok, validated} -> {:ok, validated}
        {:error, errors} -> {:error, List.wrap(errors)}
      end
    else
      # Treat as type specification (atoms like :integer, :string are valid types)
      validate_type_spec(schema_module, input, opts)
    end
  end

  # Handle type specification validation
  def validate(type_spec, input, opts) do
    validate_type_spec(type_spec, input, opts)
  end

  @doc """
  Validates data and wraps it in a temporary schema if needed.

  ## Parameters
    * `field_name` - Name for the wrapper field
    * `type_spec` - Type specification for the field
    * `input` - Data to validate
    * `opts` - Enhanced validation options

  ## Returns
    * `{:ok, extracted_value}` on success
    * `{:error, errors}` on validation failure

  ## Examples

      iex> Exdantic.EnhancedValidator.validate_wrapped(:result, :integer, "123",
      ...>   config: Exdantic.Config.create(coercion: :safe))
      {:ok, 123}

      iex> Exdantic.EnhancedValidator.validate_wrapped(:items, {:array, :string}, ["a", "b"])
      {:ok, ["a", "b"]}
  """
  @spec validate_wrapped(atom(), TypeAdapter.type_spec(), term(), enhanced_options()) ::
          {:error, [Exdantic.Error.t()]}
  def validate_wrapped(field_name, type_spec, input, opts \\ []) do
    config = Keyword.get(opts, :config, Config.create())

    wrapper_opts =
      Config.to_validation_opts(config)
      |> Keyword.take([:required, :coerce])
      |> Keyword.merge(Keyword.take(opts, [:constraints, :required, :coerce]))

    try do
      case Wrapper.wrap_and_validate(field_name, type_spec, input, wrapper_opts) do
        {:ok, result} ->
          {:ok, result}

        {:error, errors} when is_list(errors) ->
          {:error, errors}

        other ->
          {:error,
           [Exdantic.Error.new([], :validation_error, "unexpected result: #{inspect(other)}")]}
      end
    rescue
      exception ->
        {:error,
         [Exdantic.Error.new([], :exception, Exception.format(:error, exception, __STACKTRACE__))]}
    end
  end

  @doc """
  Validates multiple values efficiently against the same target.

  ## Parameters
    * `target` - What to validate against
    * `inputs` - List of data to validate
    * `opts` - Enhanced validation options

  ## Returns
    * `{:ok, validated_list}` if all validations succeed
    * `{:error, errors_by_index}` if any validation fails

  ## Examples

      iex> Exdantic.EnhancedValidator.validate_many(:string, ["a", "b", "c"])
      {:ok, ["a", "b", "c"]}

      iex> Exdantic.EnhancedValidator.validate_many(:integer, [1, "bad", 3])
      {:error, %{1 => [%Exdantic.Error{...}]}}
  """
  @spec validate_many(validation_target(), [validation_input()], enhanced_options()) ::
          {:ok, [term()]} | {:error, %{integer() => [Exdantic.Error.t()]}}
  def validate_many(target, inputs, opts \\ []) when is_list(inputs) do
    # For type specifications, use TypeAdapter for efficiency
    if type_spec?(target) do
      config = Keyword.get(opts, :config, Config.create())
      type_adapter_opts = Config.to_validation_opts(config)

      adapter = TypeAdapter.create(target, type_adapter_opts)
      TypeAdapter.Instance.validate_many(adapter, inputs)
    else
      # For schemas, validate each individually
      results =
        inputs
        |> Enum.with_index()
        |> Enum.map(fn {input, index} ->
          case validate(target, input, opts) do
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
  end

  @doc """
  Validates data and generates a JSON schema for the validation target.

  ## Parameters
    * `target` - What to validate against
    * `input` - Data to validate
    * `opts` - Enhanced validation options

  ## Returns
    * `{:ok, validated_data, json_schema}` on success
    * `{:error, errors}` on validation failure

  ## Examples

      iex> schema = Exdantic.Runtime.create_schema([{:name, :string}])
      iex> Exdantic.EnhancedValidator.validate_with_schema(schema, %{name: "John"})
      {:ok, %{name: "John"}, %{"type" => "object", ...}}
  """
  @spec validate_with_schema(validation_target(), validation_input(), enhanced_options()) ::
          {:ok, term(), map()} | {:error, [Exdantic.Error.t()]}
  def validate_with_schema(target, input, opts \\ []) do
    case validate(target, input, opts) do
      {:ok, validated_data} ->
        json_schema = generate_json_schema(target, opts)
        {:ok, validated_data, json_schema}

      {:error, errors} ->
        {:error, errors}
    end
  end

  @doc """
  Validates data and resolves all JSON schema references.

  ## Parameters
    * `target` - What to validate against
    * `input` - Data to validate
    * `opts` - Enhanced validation options

  ## Returns
    * `{:ok, validated_data, resolved_schema}` on success
    * `{:error, errors}` on validation failure

  ## Examples

      iex> Exdantic.EnhancedValidator.validate_with_resolved_schema(MySchema, data)
      {:ok, validated_data, %{"type" => "object", ...}}
  """
  @spec validate_with_resolved_schema(validation_target(), validation_input(), enhanced_options()) ::
          {:ok, term(), map()} | {:error, [Exdantic.Error.t()]}
  def validate_with_resolved_schema(target, input, opts \\ []) do
    case validate_with_schema(target, input, opts) do
      {:ok, validated_data, json_schema} ->
        resolver_opts = Keyword.get(opts, :json_schema_opts, [])
        resolved_schema = JsonSchema.Resolver.resolve_references(json_schema, resolver_opts)
        {:ok, validated_data, resolved_schema}

      {:error, errors} ->
        {:error, errors}
    end
  end

  @doc """
  Validates data for a specific LLM provider's structured output requirements.

  ## Parameters
    * `target` - What to validate against
    * `input` - Data to validate
    * `provider` - LLM provider (:openai, :anthropic, :generic)
    * `opts` - Enhanced validation options

  ## Returns
    * `{:ok, validated_data, provider_schema}` on success
    * `{:error, errors}` on validation failure

  ## Examples

      iex> Exdantic.EnhancedValidator.validate_for_llm(schema, data, :openai)
      {:ok, validated_data, %{"type" => "object", "additionalProperties" => false}}
  """
  @spec validate_for_llm(validation_target(), validation_input(), atom(), enhanced_options()) ::
          {:ok, term(), map()} | {:error, [Exdantic.Error.t()]}
  def validate_for_llm(target, input, provider, opts \\ []) do
    case validate_with_schema(target, input, opts) do
      {:ok, validated_data, json_schema} ->
        provider_schema =
          JsonSchema.Resolver.enforce_structured_output(json_schema, provider: provider)

        {:ok, validated_data, provider_schema}

      {:error, errors} ->
        {:error, errors}
    end
  end

  @doc """
  Creates a basic validation pipeline for simple sequential validation.

  ## Parameters
    * `steps` - List of validation steps to execute in order
    * `input` - The data to validate through the pipeline
    * `opts` - Enhanced validation options

  ## Returns
    * `{:ok, final_validated_data}` if all steps succeed
    * `{:error, {step_index, errors}}` if any step fails

  ## Examples

      iex> steps = [:string, fn s -> {:ok, String.upcase(s)} end, :string]
      iex> Exdantic.EnhancedValidator.pipeline(steps, "hello", [])
      {:ok, "HELLO"}
  """
  @spec pipeline([term()], term(), enhanced_options()) ::
          {:ok, term()} | {:error, {integer(), [Exdantic.Error.t()]}}
  def pipeline(steps, input, opts \\ []) do
    steps
    |> Enum.with_index()
    |> Enum.reduce_while({:ok, input}, fn {step, index}, {:ok, current_value} ->
      case execute_pipeline_step(step, current_value, opts) do
        {:ok, validated} -> {:cont, {:ok, validated}}
        {:error, errors} -> {:halt, {:error, {index, errors}}}
      end
    end)
  end

  @doc """
  Validates data with enhanced JSON schema generation.

  Phase 6 Enhancement: Integrates with EnhancedResolver for complete pipeline.

  ## Parameters
    * `target` - What to validate against
    * `input` - Data to validate
    * `opts` - Enhanced validation options

  ## Phase 6 Options
    * `:generate_enhanced_schema` - Include enhanced JSON schema in result (default: false)
    * `:optimize_for_provider` - LLM provider optimization (default: :generic)
    * `:include_metadata` - Include validation metadata in result (default: false)

  ## Returns
    * `{:ok, validated_data}` or `{:ok, validated_data, enhanced_schema}` on success
    * `{:error, errors}` on validation failure

  ## Examples

      iex> Exdantic.EnhancedValidator.validate_with_enhanced_schema(
      ...>   MySchema,
      ...>   data,
      ...>   generate_enhanced_schema: true,
      ...>   optimize_for_provider: :openai
      ...> )
      {:ok, validated_data, %{
        "type" => "object",
        "x-exdantic-enhanced" => true,
        "x-openai-optimized" => true,
        ...
      }}
  """
  @spec validate_with_enhanced_schema(validation_target(), validation_input(), enhanced_options()) ::
          {:ok, term()} | {:ok, term(), map()} | {:error, [Exdantic.Error.t()]}
  def validate_with_enhanced_schema(target, input, opts \\ []) do
    generate_schema = Keyword.get(opts, :generate_enhanced_schema, false)
    provider = Keyword.get(opts, :optimize_for_provider, :generic)
    include_metadata = Keyword.get(opts, :include_metadata, false)

    case validate(target, input, opts) do
      {:ok, validated_data} ->
        if generate_schema do
          enhanced_schema =
            EnhancedResolver.resolve_enhanced(target,
              optimize_for_provider: provider,
              include_model_validators: true,
              include_computed_fields: true
            )

          if include_metadata do
            metadata = %{
              validation_time: System.monotonic_time(:microsecond),
              target_type: determine_target_type(target),
              enhanced_features: extract_enhanced_features(target),
              provider_optimization: provider
            }

            {:ok, validated_data, enhanced_schema, metadata}
          else
            {:ok, validated_data, enhanced_schema}
          end
        else
          {:ok, validated_data}
        end

      {:error, errors} ->
        {:error, errors}
    end
  end

  @doc """
  Comprehensive validation report with enhanced schema analysis.

  Phase 6 Enhancement: Complete integration testing and analysis.

  ## Parameters
    * `target` - What to validate against
    * `input` - Data to validate
    * `opts` - Enhanced validation options

  ## Returns
    * Comprehensive validation and schema analysis report

  ## Examples

      iex> report = Exdantic.EnhancedValidator.comprehensive_validation_report(
      ...>   MySchema,
      ...>   sample_data,
      ...>   test_providers: [:openai, :anthropic],
      ...>   include_performance_analysis: true
      ...> )
      %{
        validation_result: {:ok, validated_data},
        enhanced_schema: %{...},
        provider_compatibility: %{...},
        performance_metrics: %{...},
        recommendations: [...]
      }
  """
  @spec comprehensive_validation_report(
          validation_target(),
          validation_input(),
          enhanced_options()
        ) :: %{
          validation_result: validation_result(),
          enhanced_schema: map(),
          schema_analysis: %{
            computed_field_count: non_neg_integer(),
            field_count: non_neg_integer(),
            has_config: boolean(),
            model_validator_count: non_neg_integer(),
            struct_support: boolean()
          },
          provider_compatibility: map(),
          performance_metrics:
            %{
              validation_duration_microseconds: integer(),
              validation_duration_milliseconds: float(),
              memory_usage: non_neg_integer(),
              complexity_analysis: map()
            }
            | nil,
          dspy_analysis:
            %{
              signature_compatible: boolean(),
              recommendations: [binary()]
            }
            | nil,
          recommendations: [binary()],
          generated_at: DateTime.t()
        }
  def comprehensive_validation_report(target, input, opts \\ []) do
    test_providers = Keyword.get(opts, :test_providers, [:openai, :anthropic, :generic])
    include_performance = Keyword.get(opts, :include_performance_analysis, true)
    include_dspy_analysis = Keyword.get(opts, :include_dspy_analysis, false)

    start_time = System.monotonic_time(:microsecond)

    # Core validation
    validation_result = validate(target, input, opts)

    # Enhanced schema analysis
    enhanced_analysis =
      EnhancedResolver.comprehensive_analysis(
        target,
        input,
        include_validation_test: false,
        test_llm_providers: test_providers
      )

    # DSPy analysis if requested
    dspy_analysis =
      if include_dspy_analysis do
        # Basic DSPy compatibility info
        features = extract_enhanced_features(target)

        %{
          signature_compatible: features.computed_fields < 3,
          recommendations:
            if features.computed_fields > 2 do
              ["Consider reducing computed fields for DSPy compatibility"]
            else
              ["Schema appears suitable for DSPy usage"]
            end
        }
      else
        nil
      end

    # Performance metrics
    end_time = System.monotonic_time(:microsecond)
    validation_duration = end_time - start_time

    performance_metrics =
      if include_performance do
        %{
          validation_duration_microseconds: validation_duration,
          validation_duration_milliseconds: validation_duration / 1000,
          memory_usage: :erlang.memory(:total),
          complexity_analysis: enhanced_analysis.performance_metrics
        }
      else
        nil
      end

    %{
      validation_result: validation_result,
      enhanced_schema: enhanced_analysis.json_schema,
      schema_analysis: enhanced_analysis.features,
      provider_compatibility: enhanced_analysis.llm_compatibility,
      performance_metrics: performance_metrics,
      dspy_analysis: dspy_analysis,
      recommendations: enhanced_analysis.recommendations,
      generated_at: DateTime.utc_now()
    }
  end

  # Private helper functions for Phase 6 enhancements

  @spec determine_target_type(module() | DynamicSchema.t() | EnhancedSchema.t()) ::
          :compiled_schema | :dynamic_schema | :enhanced_schema | :type_specification
  defp determine_target_type(target) when is_atom(target) do
    if function_exported?(target, :__schema__, 1) do
      :compiled_schema
    else
      :type_specification
    end
  end

  defp determine_target_type(%DynamicSchema{}), do: :dynamic_schema
  defp determine_target_type(%EnhancedSchema{}), do: :enhanced_schema

  @spec extract_enhanced_features(
          module()
          | DynamicSchema.t()
          | EnhancedSchema.t()
        ) :: %{
          struct_support: boolean(),
          model_validators: non_neg_integer(),
          computed_fields: non_neg_integer()
        }
  defp extract_enhanced_features(target) when is_atom(target) do
    if function_exported?(target, :__schema__, 1) do
      %{
        struct_support:
          function_exported?(target, :__struct_enabled__?, 0) and target.__struct_enabled__?(),
        model_validators: length(target.__schema__(:model_validators) || []),
        computed_fields: length(target.__schema__(:computed_fields) || [])
      }
    else
      %{struct_support: false, model_validators: 0, computed_fields: 0}
    end
  end

  defp extract_enhanced_features(%EnhancedSchema{} = schema) do
    %{
      struct_support: false,
      model_validators: length(schema.model_validators),
      computed_fields: length(schema.computed_fields)
    }
  end

  defp extract_enhanced_features(_) do
    %{struct_support: false, model_validators: 0, computed_fields: 0}
  end

  # Private helper functions

  @spec validate_dynamic_schema_with_coercion(DynamicSchema.t(), map(), keyword()) ::
          validation_result()
  defp validate_dynamic_schema_with_coercion(%DynamicSchema{} = schema, input, validation_opts) do
    path = Keyword.get(validation_opts, :path, [])

    # Handle nil or non-map input
    if is_map(input) do
      # Validate each field with coercion using TypeAdapter
      case validate_schema_fields_with_coercion(schema.fields, input, path) do
        {:ok, validated_fields} ->
          # Check for extra fields if strict mode is enabled
          if Keyword.get(validation_opts, :strict, false) do
            validate_strict_mode_enhanced(schema, validated_fields, input, path)
          else
            {:ok, validated_fields}
          end

        {:error, errors} ->
          {:error, errors}
      end
    else
      error = Exdantic.Error.new(path, :type, "expected a map, got: #{inspect(input)}")
      {:error, [error]}
    end
  end

  @spec validate_schema_fields_with_coercion(map(), map(), [atom()]) ::
          validation_result()
  defp validate_schema_fields_with_coercion(fields, input, path) do
    Enum.reduce_while(fields, {:ok, %{}}, fn {field_name, field_meta}, {:ok, acc} ->
      field_path = path ++ [field_name]
      field_value = Map.get(input, field_name) || Map.get(input, Atom.to_string(field_name))

      case validate_single_field_with_coercion(field_value, field_meta, field_path) do
        {:ok, validated_value} ->
          {:cont, {:ok, Map.put(acc, field_name, validated_value)}}

        {:skip, default_value} ->
          {:cont, {:ok, Map.put(acc, field_name, default_value)}}

        {:error, errors} ->
          {:halt, {:error, errors}}
      end
    end)
  end

  @spec validate_single_field_with_coercion(term(), Exdantic.FieldMeta.t(), [atom()]) ::
          validation_result_with_skip()
  defp validate_single_field_with_coercion(field_value, field_meta, field_path) do
    case {field_value, field_meta} do
      {nil, %{default: default}} when not is_nil(default) ->
        {:skip, default}

      {nil, %{required: false}} ->
        {:skip, nil}

      {nil, _meta} ->
        {:error, [Exdantic.Error.new(field_path, :required, "field is required")]}

      {value, meta} ->
        TypeAdapter.validate(meta.type, value, coerce: true, path: field_path)
    end
  end

  @spec validate_strict_mode_enhanced(DynamicSchema.t(), map(), map(), [atom()]) ::
          validation_result()
  defp validate_strict_mode_enhanced(
         %DynamicSchema{} = schema,
         validated_fields,
         original_input,
         path
       ) do
    allowed_keys = Map.keys(schema.fields) |> Enum.map(&Atom.to_string/1) |> MapSet.new()
    input_keys = Map.keys(original_input) |> Enum.map(&to_string/1) |> MapSet.new()

    case MapSet.difference(input_keys, allowed_keys) |> MapSet.to_list() do
      [] ->
        {:ok, validated_fields}

      extra_keys ->
        error =
          Exdantic.Error.new(
            path,
            :additional_properties,
            "unknown fields: #{inspect(extra_keys)}"
          )

        {:error, [error]}
    end
  end

  @spec execute_pipeline_step(term(), term(), enhanced_options()) ::
          validation_result()
  defp execute_pipeline_step(step, value, opts) do
    case step do
      # Function transformation
      fun when is_function(fun, 1) ->
        case fun.(value) do
          {:ok, transformed} -> {:ok, transformed}
          {:error, error} -> {:error, [error]}
          # Assume direct transformation
          other -> {:ok, other}
        end

      # Type validation
      type_spec ->
        validate(type_spec, value, opts)
    end
  end

  @spec validate_type_spec(TypeAdapter.type_spec(), validation_input(), enhanced_options()) ::
          validation_result()
  defp validate_type_spec(type_spec, input, opts) do
    # Check if it's a non-existent module being treated as a type spec
    if is_atom(type_spec) do
      atom_str = Atom.to_string(type_spec)
      normalized = Exdantic.Types.normalize_type(type_spec)

      # If normalize_type returns the atom unchanged (not a known type or schema),
      # and it looks like a module name, it's likely invalid
      if is_atom(normalized) and normalized == type_spec and String.match?(atom_str, ~r/^[A-Z]/) do
        # Double-check: if it's an atom that normalize_type didn't transform,
        # and it starts with a capital letter, check if it's a valid module
        unless Code.ensure_loaded?(type_spec) and function_exported?(type_spec, :__schema__, 1) do
          raise ArgumentError, "Module #{inspect(type_spec)} does not exist"
        end
      end
    end

    config = Keyword.get(opts, :config, Config.create())

    type_adapter_opts =
      Config.to_validation_opts(config)
      |> Keyword.merge(Keyword.get(opts, :type_adapter_opts, []))

    TypeAdapter.validate(type_spec, input, type_adapter_opts)
  end

  @spec generate_json_schema(validation_target(), enhanced_options()) :: map()
  defp generate_json_schema(%DynamicSchema{} = schema, opts) do
    config = Keyword.get(opts, :config, Config.create())
    json_schema_opts = Keyword.get(opts, :json_schema_opts, [])

    # Extract config settings that should influence JSON schema generation
    schema_opts =
      json_schema_opts
      |> Keyword.put_new(:strict, config.strict)
      |> Keyword.put_new(
        :additional_properties,
        if config.strict do
          false
        else
          json_schema_opts[:additional_properties]
        end
      )

    Runtime.to_json_schema(schema, schema_opts)
  end

  defp generate_json_schema(schema_module, opts) when is_atom(schema_module) do
    if function_exported?(schema_module, :__schema__, 1) do
      JsonSchema.from_schema(schema_module)
    else
      # Type specification
      json_schema_opts = Keyword.get(opts, :json_schema_opts, [])
      TypeAdapter.json_schema(schema_module, json_schema_opts)
    end
  end

  defp generate_json_schema(type_spec, opts) do
    json_schema_opts = Keyword.get(opts, :json_schema_opts, [])
    TypeAdapter.json_schema(type_spec, json_schema_opts)
  end

  @spec type_spec?(term()) :: boolean()
  defp type_spec?(%DynamicSchema{}), do: false

  defp type_spec?(atom) when is_atom(atom) do
    not (Code.ensure_loaded?(atom) and function_exported?(atom, :__schema__, 1))
  end

  defp type_spec?(_), do: true

  @doc """
  Creates a comprehensive validation report for debugging purposes.

  ## Parameters
    * `target` - What to validate against
    * `input` - Data to validate
    * `opts` - Enhanced validation options

  ## Returns
    * Map with detailed validation information

  ## Examples

      iex> report = Exdantic.EnhancedValidator.validation_report(schema, data)
      %{
        validation_result: {:ok, validated_data},
        json_schema: %{...},
        target_info: %{...},
        input_analysis: %{...},
        performance_metrics: %{...}
      }
  """
  @spec validation_report(validation_target(), validation_input(), enhanced_options()) :: map()
  def validation_report(target, input, opts \\ []) do
    start_time = System.monotonic_time(:microsecond)

    validation_result = validate(target, input, opts)

    end_time = System.monotonic_time(:microsecond)
    duration_us = end_time - start_time

    %{
      validation_result: validation_result,
      json_schema: generate_json_schema(target, opts),
      target_info: analyze_target(target),
      input_analysis: analyze_input(input),
      performance_metrics: %{
        duration_microseconds: duration_us,
        duration_milliseconds: duration_us / 1000
      },
      configuration: Keyword.get(opts, :config, Config.create()) |> Config.summary(),
      timestamp: DateTime.utc_now()
    }
  end

  defp analyze_target(%DynamicSchema{} = schema) do
    %{
      type: :dynamic_schema,
      name: schema.name,
      field_count: map_size(schema.fields),
      summary: Runtime.DynamicSchema.summary(schema)
    }
  end

  defp analyze_target(schema_module) when is_atom(schema_module) do
    if function_exported?(schema_module, :__schema__, 1) do
      %{
        type: :compiled_schema,
        module: schema_module,
        fields: schema_module.__schema__(:fields) |> length()
      }
    else
      %{
        type: :type_specification,
        spec: schema_module
      }
    end
  end

  defp analyze_target(type_spec) do
    %{
      type: :type_specification,
      spec: type_spec,
      normalized: Exdantic.Types.normalize_type(type_spec)
    }
  end

  defp analyze_input(input) when is_map(input) do
    %{
      type: :map,
      key_count: map_size(input),
      keys: Map.keys(input),
      size_bytes: :erlang.external_size(input)
    }
  end

  defp analyze_input(input) when is_list(input) do
    %{
      type: :list,
      length: length(input),
      size_bytes: :erlang.external_size(input)
    }
  end

  defp analyze_input(input) when is_tuple(input) do
    %{
      type: :tuple,
      size: tuple_size(input),
      element_types: input |> Tuple.to_list() |> Enum.map(&get_type/1),
      size_bytes: :erlang.external_size(input)
    }
  end

  defp analyze_input(input) when is_binary(input) do
    %{
      type: :string,
      length: String.length(input),
      size_bytes: :erlang.external_size(input)
    }
  end

  defp analyze_input(input) when is_integer(input) do
    %{
      type: :integer,
      value: input,
      size_bytes: :erlang.external_size(input)
    }
  end

  defp analyze_input(input) when is_float(input) do
    %{
      type: :float,
      value: input,
      size_bytes: :erlang.external_size(input)
    }
  end

  defp analyze_input(input) when is_boolean(input) do
    %{
      type: :boolean,
      value: input,
      size_bytes: :erlang.external_size(input)
    }
  end

  defp analyze_input(input) when is_atom(input) do
    %{
      type: :atom,
      value: input,
      size_bytes: :erlang.external_size(input)
    }
  end

  defp analyze_input(input) do
    %{
      type: :unknown,
      erlang_type: input |> elem(0) |> to_string(),
      size_bytes: :erlang.external_size(input)
    }
  rescue
    # If elem/2 fails, it's not a tuple
    _ ->
      %{
        type: :unknown,
        size_bytes: :erlang.external_size(input)
      }
  end

  defp get_type(value) when is_binary(value), do: :string
  defp get_type(value) when is_integer(value), do: :integer
  defp get_type(value) when is_float(value), do: :float
  defp get_type(value) when is_boolean(value), do: :boolean
  defp get_type(value) when is_atom(value), do: :atom
  defp get_type(value) when is_list(value), do: :list
  defp get_type(value) when is_map(value), do: :map
  defp get_type(value) when is_tuple(value), do: :tuple
  defp get_type(_), do: :unknown
end
