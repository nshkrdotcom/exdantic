defmodule Exdantic.JsonSchema.EnhancedResolver do
  @moduledoc """
  Enhanced JSON Schema resolution with full computed field and model validator metadata.

  This module extends the basic resolver functionality to handle:
  - Enhanced runtime schemas with model validators and computed fields
  - Dynamic schema references with runtime resolution
  - Cross-schema dependency resolution for complex validation pipelines
  - LLM provider-specific optimizations with enhanced metadata

  Phase 6 Enhancement: Complete Integration
  - Seamlessly integrates all Exdantic features (struct patterns, model validators, computed fields)
  - Provides unified JSON Schema generation for all schema types
  - Optimizes for various LLM providers with enhanced metadata
  - Maintains backward compatibility with existing resolvers
  """

  alias Exdantic.{EnhancedValidator, Runtime}
  alias Exdantic.JsonSchema.Resolver
  alias Exdantic.Runtime.{DynamicSchema, EnhancedSchema}

  @type enhanced_resolution_options :: [
          include_model_validators: boolean(),
          include_computed_fields: boolean(),
          optimize_for_provider: :openai | :anthropic | :generic,
          resolve_runtime_refs: boolean(),
          max_depth: non_neg_integer(),
          flatten_for_llm: boolean()
        ]

  @doc """
  Resolves JSON Schema with full enhanced schema support.

  Handles all Exdantic schema types:
  - Compile-time schemas (with struct support, model validators, computed fields)
  - Runtime DynamicSchema instances
  - Runtime EnhancedSchema instances with full features
  - Mixed references between schema types

  ## Parameters
    * `schema_or_spec` - Schema module, runtime schema, or type specification
    * `opts` - Enhanced resolution options

  ## Options
    * `:include_model_validators` - Include model validator metadata (default: true)
    * `:include_computed_fields` - Include computed field metadata (default: true)
    * `:optimize_for_provider` - Optimize for specific LLM provider (default: :generic)
    * `:resolve_runtime_refs` - Resolve references to runtime schemas (default: true)
    * `:max_depth` - Maximum resolution depth (default: 10)
    * `:flatten_for_llm` - Flatten complex structures for LLM consumption (default: false)

  ## Returns
    * Enhanced JSON Schema with full metadata

  ## Examples

      # Basic usage with a module
      iex> defmodule TestSchema do
      ...>   use Exdantic
      ...>   schema do
      ...>     field :name, :string, required: true
      ...>   end
      ...> end
      iex> schema = Exdantic.JsonSchema.EnhancedResolver.resolve_enhanced(TestSchema)
      iex> schema["type"]
      "object"
      iex> schema["x-exdantic-enhanced"]
      true
  """
  @spec resolve_enhanced(
          module() | DynamicSchema.t() | EnhancedSchema.t(),
          enhanced_resolution_options()
        ) ::
          map()
  def resolve_enhanced(schema_or_spec, opts \\ []) do
    include_model_validators = Keyword.get(opts, :include_model_validators, true)
    include_computed_fields = Keyword.get(opts, :include_computed_fields, true)
    optimize_for_provider = Keyword.get(opts, :optimize_for_provider, :generic)
    resolve_runtime_refs = Keyword.get(opts, :resolve_runtime_refs, true)
    max_depth = Keyword.get(opts, :max_depth, 10)
    flatten_for_llm = Keyword.get(opts, :flatten_for_llm, false)

    # Generate base schema based on type
    base_schema = generate_base_enhanced_schema(schema_or_spec, opts)

    # Apply enhanced metadata
    enhanced_schema =
      base_schema
      |> maybe_add_model_validator_metadata(schema_or_spec, include_model_validators)
      |> maybe_add_computed_field_metadata(schema_or_spec, include_computed_fields)
      |> add_exdantic_enhanced_metadata(schema_or_spec)

    # Apply provider-specific optimizations
    provider_optimized = optimize_for_provider(enhanced_schema, optimize_for_provider)

    # Resolve runtime references if enabled
    runtime_resolved =
      if resolve_runtime_refs do
        resolve_runtime_references(provider_optimized, max_depth)
      else
        provider_optimized
      end

    # Flatten for LLM if requested
    if flatten_for_llm do
      Resolver.flatten_schema(runtime_resolved, max_depth: max_depth)
    else
      runtime_resolved
    end
  end

  @doc """
  Creates a comprehensive validation and schema generation report.

  Useful for debugging, documentation, and understanding complex schema interactions.

  ## Parameters
    * `schema_or_spec` - Schema to analyze
    * `sample_data` - Optional sample data for validation testing
    * `opts` - Analysis options

  ## Returns
    * Comprehensive report with validation results, schema analysis, and metadata

  ## Examples

      iex> defmodule AnalysisTestSchema do
      ...>   use Exdantic
      ...>   schema do
      ...>     field :name, :string, required: true
      ...>   end
      ...> end
      iex> report = Exdantic.JsonSchema.EnhancedResolver.comprehensive_analysis(AnalysisTestSchema)
      iex> report.schema_type
      :compiled_schema
      iex> is_map(report.performance_metrics)
      true
  """
  @spec comprehensive_analysis(
          module() | DynamicSchema.t() | EnhancedSchema.t(),
          map() | nil,
          keyword()
        ) ::
          map()
  def comprehensive_analysis(schema_or_spec, sample_data \\ nil, opts \\ []) do
    include_validation_test = Keyword.get(opts, :include_validation_test, false)
    test_llm_providers = Keyword.get(opts, :test_llm_providers, [:openai, :anthropic, :generic])

    # Analyze schema structure
    schema_analysis = analyze_schema_structure(schema_or_spec)

    # Generate enhanced JSON schema
    # Filter opts to only include valid resolution options
    resolution_opts =
      Keyword.take(opts, [
        :include_model_validators,
        :include_computed_fields,
        :optimize_for_provider,
        :resolve_runtime_refs,
        :max_depth,
        :flatten_for_llm
      ])

    enhanced_schema = resolve_enhanced(schema_or_spec, resolution_opts)

    # Test validation if sample data provided
    validation_result =
      if include_validation_test and sample_data do
        test_validation_pipeline(schema_or_spec, sample_data)
      else
        nil
      end

    # Test LLM provider compatibility
    llm_compatibility = test_llm_provider_compatibility(enhanced_schema, test_llm_providers)

    # Performance analysis
    performance_metrics = analyze_performance_characteristics(schema_or_spec)

    %{
      schema_type: determine_schema_type(schema_or_spec),
      features: schema_analysis,
      json_schema: enhanced_schema,
      validation_test: validation_result,
      llm_compatibility: llm_compatibility,
      performance_metrics: performance_metrics,
      recommendations: generate_recommendations(schema_analysis, performance_metrics),
      generated_at: DateTime.utc_now()
    }
  rescue
    _ ->
      # Return a minimal error report if analysis fails
      %{
        schema_type: :unknown,
        features: %{
          type: :unknown,
          error: "Failed to analyze schema"
        },
        json_schema: %{
          error: "Failed to generate enhanced schema"
        },
        validation_test: nil,
        llm_compatibility: %{},
        performance_metrics: %{
          complexity: :unknown,
          estimated_tokens: 0
        },
        recommendations: ["Schema analysis failed - unable to provide recommendations"],
        generated_at: DateTime.utc_now()
      }
  end

  @doc """
  Optimizes schemas specifically for DSPy and structured LLM output patterns.

  DSPy requires specific JSON Schema patterns for reliable structured output.
  This function ensures schemas work optimally with DSPy's validation patterns.

  ## Parameters
    * `schema_or_spec` - Schema to optimize
    * `dspy_opts` - DSPy-specific options

  ## DSPy Options
    * `:signature_mode` - Generate schema for DSPy signature patterns (default: false)
    * `:strict_types` - Enforce strict type constraints (default: true)
    * `:remove_computed_fields` - Remove computed fields for input validation (default: false)
    * `:field_descriptions` - Include field descriptions for better LLM understanding (default: true)

  ## Returns
    * DSPy-optimized JSON Schema

  ## Examples

      iex> defmodule DSPyTestSchema do
      ...>   use Exdantic
      ...>   schema do
      ...>     field :input, :string, required: true
      ...>   end
      ...> end
      iex> dspy_schema = Exdantic.JsonSchema.EnhancedResolver.optimize_for_dspy(DSPyTestSchema)
      iex> dspy_schema["x-dspy-optimized"]
      true
  """
  @spec optimize_for_dspy(module() | DynamicSchema.t() | EnhancedSchema.t(), keyword()) :: map()
  def optimize_for_dspy(schema_or_spec, dspy_opts \\ []) do
    signature_mode = Keyword.get(dspy_opts, :signature_mode, false)
    strict_types = Keyword.get(dspy_opts, :strict_types, true)
    remove_computed_fields = Keyword.get(dspy_opts, :remove_computed_fields, false)
    field_descriptions = Keyword.get(dspy_opts, :field_descriptions, true)

    # Generate base schema
    base_schema =
      resolve_enhanced(schema_or_spec,
        # DSPy works well with OpenAI patterns
        optimize_for_provider: :openai,
        flatten_for_llm: true
      )

    # Apply DSPy-specific transformations
    base_schema
    |> maybe_remove_computed_fields_for_dspy(remove_computed_fields)
    |> enforce_strict_types_for_dspy(strict_types)
    |> enhance_field_descriptions_for_dspy(field_descriptions)
    |> apply_signature_mode_optimizations(signature_mode)
    |> add_dspy_metadata()
  end

  @doc """
  Validates that a schema is compatible with enhanced validation pipeline.

  Checks for common issues that might cause problems with the full validation pipeline
  including model validators and computed fields.

  ## Parameters
    * `schema_or_spec` - Schema to validate
    * `opts` - Validation options

  ## Returns
    * `:ok` if schema is valid
    * `{:error, issues}` if problems are found

  ## Examples

      iex> defmodule CompatibilityTestSchema do
      ...>   use Exdantic
      ...>   schema do
      ...>     field :name, :string, required: true
      ...>   end
      ...> end
      iex> Exdantic.JsonSchema.EnhancedResolver.validate_schema_compatibility(CompatibilityTestSchema)
      :ok
  """
  @spec validate_schema_compatibility(
          module() | DynamicSchema.t() | EnhancedSchema.t(),
          keyword()
        ) ::
          :ok | {:error, [String.t()]}
  def validate_schema_compatibility(schema_or_spec, opts \\ []) do
    include_performance_check = Keyword.get(opts, :include_performance_check, false)

    issues = []

    # Check basic schema structure
    issues = issues ++ check_basic_schema_structure(schema_or_spec)

    # Check model validators
    issues = issues ++ check_model_validator_compatibility(schema_or_spec)

    # Check computed fields
    issues = issues ++ check_computed_field_compatibility(schema_or_spec)

    # Check type consistency
    issues = issues ++ check_type_consistency(schema_or_spec)

    # Optional performance check
    issues =
      if include_performance_check do
        issues ++ check_performance_characteristics(schema_or_spec)
      else
        issues
      end

    case issues do
      [] -> :ok
      problems -> {:error, problems}
    end
  end

  # Private implementation functions

  @spec generate_base_enhanced_schema(
          module() | DynamicSchema.t() | EnhancedSchema.t(),
          keyword()
        ) :: map()
  defp generate_base_enhanced_schema(schema_module, _opts) when is_atom(schema_module) do
    if function_exported?(schema_module, :__schema__, 1) do
      Exdantic.JsonSchema.from_schema(schema_module)
    else
      # Type specification
      Exdantic.TypeAdapter.json_schema(schema_module)
    end
  end

  defp generate_base_enhanced_schema(%DynamicSchema{} = schema, _opts) do
    Runtime.to_json_schema(schema)
  end

  defp generate_base_enhanced_schema(%EnhancedSchema{} = schema, _opts) do
    Runtime.EnhancedSchema.to_json_schema(schema)
  end

  defp generate_base_enhanced_schema(_invalid_schema, _opts) do
    %{
      "type" => "object",
      "properties" => %{},
      "additionalProperties" => false
    }
  end

  @spec maybe_add_model_validator_metadata(
          map(),
          module() | DynamicSchema.t() | EnhancedSchema.t(),
          boolean()
        ) :: map()
  defp maybe_add_model_validator_metadata(schema, schema_source, true) do
    validator_count = count_model_validators(schema_source)

    if validator_count > 0 do
      schema
      |> Map.put("x-model-validators", validator_count)
      |> Map.put("x-has-model-validation", true)
    else
      schema
    end
  end

  defp maybe_add_model_validator_metadata(schema, _schema_source, false), do: schema

  @spec maybe_add_computed_field_metadata(
          map(),
          module() | DynamicSchema.t() | EnhancedSchema.t(),
          boolean()
        ) :: map()
  defp maybe_add_computed_field_metadata(schema, schema_source, true) do
    computed_field_count = count_computed_fields(schema_source)

    if computed_field_count > 0 do
      schema
      |> Map.put("x-computed-fields", computed_field_count)
      |> Map.put("x-has-computed-fields", true)
    else
      schema
    end
  end

  defp maybe_add_computed_field_metadata(schema, _schema_source, false), do: schema

  @spec add_exdantic_enhanced_metadata(map(), module() | DynamicSchema.t() | EnhancedSchema.t()) ::
          map()
  defp add_exdantic_enhanced_metadata(schema, schema_source) do
    schema
    |> Map.put("x-exdantic-enhanced", true)
    |> Map.put("x-exdantic-version", get_exdantic_version())
    |> Map.put("x-schema-type", determine_schema_type(schema_source))
    |> Map.put("x-supports-struct", supports_struct?(schema_source))
  end

  @spec optimize_for_provider(map(), atom()) :: map()
  defp optimize_for_provider(schema, :openai) do
    Resolver.enforce_structured_output(schema, provider: :openai, remove_unsupported: true)
  end

  defp optimize_for_provider(schema, :anthropic) do
    Resolver.enforce_structured_output(schema, provider: :anthropic, remove_unsupported: true)
  end

  defp optimize_for_provider(schema, :generic), do: schema
  defp optimize_for_provider(schema, _invalid_provider), do: schema

  @spec resolve_runtime_references(map(), non_neg_integer()) :: map()
  defp resolve_runtime_references(schema, max_depth) do
    # For now, use the standard resolver
    # Future enhancement: Add runtime schema reference resolution
    Resolver.resolve_references(schema, max_depth: max_depth)
  end

  @spec analyze_schema_structure(term()) :: %{
          struct_support: boolean(),
          field_count: non_neg_integer(),
          computed_field_count: non_neg_integer(),
          model_validator_count: non_neg_integer(),
          has_config: boolean()
        }
  defp analyze_schema_structure(schema_module) when is_atom(schema_module) do
    if function_exported?(schema_module, :__schema__, 1) do
      fields = schema_module.__schema__(:fields) || []
      computed_fields = schema_module.__schema__(:computed_fields) || []
      model_validators = schema_module.__schema__(:model_validators) || []

      %{
        struct_support:
          function_exported?(schema_module, :__struct_enabled__?, 0) and
            schema_module.__struct_enabled__?(),
        field_count: length(fields),
        computed_field_count: length(computed_fields),
        model_validator_count: length(model_validators),
        has_config: not is_nil(schema_module.__schema__(:config))
      }
    else
      %{
        struct_support: false,
        field_count: 0,
        computed_field_count: 0,
        model_validator_count: 0,
        has_config: false
      }
    end
  end

  defp analyze_schema_structure(%DynamicSchema{} = schema) do
    %{
      struct_support: false,
      field_count: map_size(schema.fields),
      computed_field_count: 0,
      model_validator_count: 0,
      has_config: true
    }
  end

  defp analyze_schema_structure(%EnhancedSchema{} = schema) do
    %{
      # Runtime schemas don't support structs (yet)
      struct_support: false,
      field_count: map_size(schema.base_schema.fields),
      computed_field_count: length(schema.computed_fields),
      model_validator_count: length(schema.model_validators),
      has_config: true
    }
  end

  defp analyze_schema_structure(_invalid_schema) do
    %{
      struct_support: false,
      field_count: 0,
      computed_field_count: 0,
      model_validator_count: 0,
      has_config: false
    }
  end

  @spec test_validation_pipeline(module() | DynamicSchema.t() | EnhancedSchema.t(), map()) ::
          {:ok, term()} | {:error, term()}
  defp test_validation_pipeline(schema_or_spec, sample_data) do
    EnhancedValidator.validate(schema_or_spec, sample_data)
  rescue
    e -> {:error, "Validation pipeline failed: #{Exception.message(e)}"}
  end

  @spec test_llm_provider_compatibility(map(), [atom()]) :: map()
  defp test_llm_provider_compatibility(schema, providers) do
    Enum.reduce(providers, %{}, fn provider, acc ->
      try do
        optimized = optimize_for_provider(schema, provider)
        compatibility_score = calculate_compatibility_score(optimized, provider)

        Map.put(acc, provider, %{
          compatible: true,
          score: compatibility_score,
          optimized_schema: optimized
        })
      rescue
        e ->
          Map.put(acc, provider, %{
            compatible: false,
            error: Exception.message(e),
            score: 0
          })
      end
    end)
  end

  @spec analyze_performance_characteristics(module() | DynamicSchema.t() | EnhancedSchema.t()) ::
          %{
            complexity_score: non_neg_integer(),
            estimated_validation_time: String.t(),
            memory_overhead: String.t(),
            optimization_suggestions: [String.t()]
          }
  defp analyze_performance_characteristics(schema_or_spec) do
    # Estimate performance based on schema complexity
    structure = analyze_schema_structure(schema_or_spec)

    # Computed fields are more expensive
    # Model validators add overhead
    complexity_score =
      structure.field_count +
        structure.computed_field_count * 3 +
        structure.model_validator_count * 2

    %{
      complexity_score: complexity_score,
      estimated_validation_time: estimate_validation_time(complexity_score),
      memory_overhead: estimate_memory_overhead(structure),
      optimization_suggestions: generate_performance_suggestions(structure)
    }
  end

  defp generate_recommendations(schema_analysis, performance_metrics) do
    recommendations = []

    # Performance recommendations
    recommendations =
      if performance_metrics.complexity_score > 50 do
        ["Consider reducing schema complexity for better performance" | recommendations]
      else
        recommendations
      end

    # Feature recommendations
    recommendations =
      if schema_analysis.computed_field_count > 5 do
        ["Consider whether all computed fields are necessary" | recommendations]
      else
        recommendations
      end

    # Struct recommendations
    recommendations =
      if not schema_analysis.struct_support and schema_analysis.field_count > 3 do
        ["Consider enabling struct support for better type safety" | recommendations]
      else
        recommendations
      end

    recommendations
  end

  # DSPy optimization helpers

  @spec maybe_remove_computed_fields_for_dspy(map(), boolean()) :: map()
  defp maybe_remove_computed_fields_for_dspy(schema, true) do
    Exdantic.JsonSchema.remove_computed_fields(schema)
  end

  defp maybe_remove_computed_fields_for_dspy(schema, false), do: schema

  @spec enforce_strict_types_for_dspy(map(), boolean()) :: map()
  defp enforce_strict_types_for_dspy(schema, true) do
    schema
    |> Map.put("additionalProperties", false)
    |> deep_remove_optional_properties()
  end

  defp enforce_strict_types_for_dspy(schema, false), do: schema

  @spec enhance_field_descriptions_for_dspy(map(), boolean()) :: map()
  defp enhance_field_descriptions_for_dspy(schema, true) do
    case Map.get(schema, "properties") do
      nil ->
        schema

      properties ->
        enhanced_properties =
          Enum.reduce(properties, %{}, fn {field_name, field_schema}, acc ->
            enhanced_field =
              if Map.has_key?(field_schema, "description") do
                field_schema
              else
                Map.put(
                  field_schema,
                  "description",
                  generate_auto_description(field_name, field_schema)
                )
              end

            Map.put(acc, field_name, enhanced_field)
          end)

        Map.put(schema, "properties", enhanced_properties)
    end
  end

  defp enhance_field_descriptions_for_dspy(schema, false), do: schema

  @spec apply_signature_mode_optimizations(map(), boolean()) :: map()
  defp apply_signature_mode_optimizations(schema, true) do
    schema
    |> Map.put("x-dspy-signature-mode", true)
    |> ensure_all_fields_documented()
    |> optimize_field_ordering_for_llm()
  end

  defp apply_signature_mode_optimizations(schema, false), do: schema

  @spec add_dspy_metadata(map()) :: map()
  defp add_dspy_metadata(schema) do
    Map.put(schema, "x-dspy-optimized", true)
  end

  # Validation helpers

  @spec check_basic_schema_structure(module() | DynamicSchema.t() | EnhancedSchema.t()) :: [
          String.t()
        ]
  defp check_basic_schema_structure(schema_module) when is_atom(schema_module) do
    if function_exported?(schema_module, :__schema__, 1) do
      []
    else
      ["Schema module #{schema_module} does not implement __schema__/1"]
    end
  end

  defp check_basic_schema_structure(%DynamicSchema{fields: fields}) do
    if map_size(fields) == 0 do
      ["Dynamic schema has no fields defined"]
    else
      []
    end
  end

  defp check_basic_schema_structure(%EnhancedSchema{}), do: []
  defp check_basic_schema_structure(_), do: ["Invalid schema type"]

  @spec check_model_validator_compatibility(module() | DynamicSchema.t() | EnhancedSchema.t()) ::
          [String.t()]
  defp check_model_validator_compatibility(schema_module) when is_atom(schema_module) do
    if function_exported?(schema_module, :__schema__, 1) do
      model_validators = schema_module.__schema__(:model_validators) || []

      Enum.flat_map(model_validators, fn {module, function_name} ->
        if function_exported?(module, function_name, 1) do
          []
        else
          ["Model validator function missing: #{module}.#{function_name}/1"]
        end
      end)
    else
      []
    end
  end

  defp check_model_validator_compatibility(_), do: []

  @spec check_computed_field_compatibility(module() | DynamicSchema.t() | EnhancedSchema.t()) :: [
          String.t()
        ]
  defp check_computed_field_compatibility(schema_module) when is_atom(schema_module) do
    if function_exported?(schema_module, :__schema__, 1) do
      computed_fields = schema_module.__schema__(:computed_fields) || []

      Enum.flat_map(computed_fields, fn {_field_name, computed_meta} ->
        if function_exported?(computed_meta.module, computed_meta.function_name, 1) do
          []
        else
          [
            "Computed field function missing: #{computed_meta.module}.#{computed_meta.function_name}/1"
          ]
        end
      end)
    else
      []
    end
  end

  defp check_computed_field_compatibility(_), do: []

  @spec check_type_consistency(module() | DynamicSchema.t() | EnhancedSchema.t()) :: [String.t()]
  defp check_type_consistency(_schema_or_spec) do
    # Future enhancement: Add sophisticated type consistency checking
    []
  end

  @spec check_performance_characteristics(module() | DynamicSchema.t() | EnhancedSchema.t()) :: [
          String.t()
        ]
  defp check_performance_characteristics(schema_or_spec) do
    metrics = analyze_performance_characteristics(schema_or_spec)

    if metrics.complexity_score > 30 do
      ["Schema complexity very high (#{metrics.complexity_score}), consider optimization"]
    else
      []
    end
  end

  # Utility functions

  @spec count_model_validators(module() | DynamicSchema.t() | EnhancedSchema.t()) ::
          non_neg_integer()
  defp count_model_validators(schema_module) when is_atom(schema_module) do
    if function_exported?(schema_module, :__schema__, 1) do
      length(schema_module.__schema__(:model_validators) || [])
    else
      0
    end
  end

  defp count_model_validators(%EnhancedSchema{model_validators: validators}),
    do: length(validators)

  defp count_model_validators(_), do: 0

  @spec count_computed_fields(module() | DynamicSchema.t() | EnhancedSchema.t()) ::
          non_neg_integer()
  defp count_computed_fields(schema_module) when is_atom(schema_module) do
    if function_exported?(schema_module, :__schema__, 1) do
      length(schema_module.__schema__(:computed_fields) || [])
    else
      0
    end
  end

  defp count_computed_fields(%EnhancedSchema{computed_fields: fields}), do: length(fields)
  defp count_computed_fields(_), do: 0

  defp determine_schema_type(schema_module) when is_atom(schema_module) do
    if function_exported?(schema_module, :__schema__, 1) do
      :compiled_schema
    else
      :type_specification
    end
  end

  defp determine_schema_type(%DynamicSchema{}), do: :dynamic_schema
  defp determine_schema_type(%EnhancedSchema{}), do: :enhanced_schema
  defp determine_schema_type(_), do: :unknown

  @spec supports_struct?(term()) :: boolean()
  defp supports_struct?(schema_module) when is_atom(schema_module) do
    function_exported?(schema_module, :__struct_enabled__?, 0) and
      schema_module.__struct_enabled__?()
  end

  defp supports_struct?(_), do: false

  @spec get_exdantic_version() :: String.t()
  defp get_exdantic_version do
    case Application.spec(:exdantic, :vsn) do
      nil -> "unknown"
      vsn -> to_string(vsn)
    end
  end

  @spec calculate_compatibility_score(map(), :openai | :anthropic | :generic) ::
          50 | 60 | 65 | 70 | 80 | 100
  defp calculate_compatibility_score(schema, provider) do
    base_score = 50

    # Adjust based on provider-specific features
    score =
      case provider do
        :openai ->
          score = base_score
          score = if Map.get(schema, "additionalProperties") == false, do: score + 20, else: score
          score = if Map.has_key?(schema, "required"), do: score + 10, else: score
          score

        :anthropic ->
          score = base_score
          score = if Map.has_key?(schema, "required"), do: score + 15, else: score
          score = if Map.get(schema, "type") == "object", do: score + 15, else: score
          score

        :generic ->
          base_score + 10
      end

    min(score, 100)
  end

  @spec estimate_validation_time(non_neg_integer()) :: String.t()
  defp estimate_validation_time(complexity_score) do
    cond do
      complexity_score < 10 -> "< 1ms"
      complexity_score < 30 -> "1-5ms"
      complexity_score < 60 -> "5-15ms"
      true -> "> 15ms"
    end
  end

  @spec estimate_memory_overhead(%{
          field_count: non_neg_integer(),
          computed_field_count: non_neg_integer(),
          model_validator_count: non_neg_integer(),
          struct_support: boolean(),
          has_config: boolean()
        }) :: String.t()
  defp estimate_memory_overhead(structure) do
    # bytes
    base_overhead = structure.field_count * 100
    computed_overhead = structure.computed_field_count * 300
    validator_overhead = structure.model_validator_count * 200

    total = base_overhead + computed_overhead + validator_overhead

    cond do
      total < 1000 -> "< 1KB"
      total < 5000 -> "1-5KB"
      total < 10_000 -> "5-10KB"
      true -> "> 10KB"
    end
  end

  @spec generate_performance_suggestions(%{
          computed_field_count: non_neg_integer(),
          model_validator_count: non_neg_integer(),
          struct_support: boolean(),
          field_count: non_neg_integer(),
          has_config: boolean()
        }) :: [String.t()]
  defp generate_performance_suggestions(structure) do
    suggestions = []

    suggestions =
      if structure.computed_field_count > 3 do
        ["Consider caching computed field results" | suggestions]
      else
        suggestions
      end

    suggestions =
      if structure.model_validator_count > 2 do
        ["Consider combining model validators for efficiency" | suggestions]
      else
        suggestions
      end

    suggestions
  end

  @spec deep_remove_optional_properties(map()) :: map()
  defp deep_remove_optional_properties(schema) do
    case Map.get(schema, "properties") do
      nil ->
        schema

      properties ->
        strict_properties =
          Enum.reduce(properties, %{}, fn {key, prop}, acc ->
            strict_prop =
              prop
              |> Map.delete("default")
              |> deep_remove_optional_properties()

            Map.put(acc, key, strict_prop)
          end)

        Map.put(schema, "properties", strict_properties)
    end
  end

  @spec generate_auto_description(String.t(), map()) :: String.t()
  defp generate_auto_description(field_name, field_schema) do
    base_desc = "The #{field_name} field"

    case Map.get(field_schema, "type") do
      "string" -> "#{base_desc} (text value)"
      "integer" -> "#{base_desc} (whole number)"
      "number" -> "#{base_desc} (numeric value)"
      "boolean" -> "#{base_desc} (true/false)"
      "array" -> "#{base_desc} (list of values)"
      "object" -> "#{base_desc} (structured data)"
      _ -> base_desc
    end
  end

  @spec ensure_all_fields_documented(map()) :: map()
  defp ensure_all_fields_documented(schema) do
    case Map.get(schema, "properties") do
      nil ->
        schema

      properties ->
        documented_properties =
          Enum.reduce(properties, %{}, fn {key, prop}, acc ->
            documented_prop =
              if Map.has_key?(prop, "description") do
                prop
              else
                Map.put(prop, "description", generate_auto_description(key, prop))
              end

            Map.put(acc, key, documented_prop)
          end)

        Map.put(schema, "properties", documented_properties)
    end
  end

  @spec optimize_field_ordering_for_llm(map()) :: map()
  defp optimize_field_ordering_for_llm(schema) do
    # For LLMs, ordering fields by importance can help
    # Keep the schema as-is for now, but this could be enhanced
    schema
  end
end
