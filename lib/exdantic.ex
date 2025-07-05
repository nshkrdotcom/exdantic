defmodule Exdantic do
  @moduledoc """
  Exdantic is a schema definition and validation library for Elixir.

  It provides a DSL for defining schemas with rich metadata, validation rules,
  and JSON Schema generation capabilities.

  For validating non-dictionary types at the root level (similar to Pydantic's RootModel),
  see `Exdantic.RootSchema`.

  ## Struct Pattern Support

  Exdantic now supports generating structs alongside validation schemas:

      defmodule UserSchema do
        use Exdantic, define_struct: true

        schema "User account information" do
          field :name, :string do
            required()
            min_length(2)
          end

          field :age, :integer do
            optional()
            gt(0)
          end
        end
      end

  The schema can then be used for validation and returns struct instances:

      # Returns {:ok, %UserSchema{name: "John", age: 30}}
      UserSchema.validate(%{name: "John", age: 30})

      # Serialize struct back to map
      {:ok, map} = UserSchema.dump(user_struct)

  ## Examples

      defmodule UserSchema do
        use Exdantic

        schema "User registration data" do
          field :name, :string do
            required()
            min_length(2)
          end

          field :age, :integer do
            optional()
            gt(0)
            lt(150)
          end

          field :email, Types.Email do
            required()
          end

          config do
            title("User Schema")
            strict(true)
          end
        end
      end

  The schema can then be used for validation and JSON Schema generation:

      # Validation (returns map by default)
      {:ok, user} = UserSchema.validate(%{
        name: "John Doe",
        email: "john@example.com",
        age: 30
      })

      # JSON Schema generation
      json_schema = UserSchema.json_schema()
  """

  alias Exdantic.JsonSchema.EnhancedResolver

  @doc """
  Configures a module to be an Exdantic schema.

  ## Options

    * `:define_struct` - Whether to generate a struct for validated data.
      When `true`, validation returns struct instances instead of maps.
      Defaults to `false` for backwards compatibility.

  ## Examples

      # Traditional map-based validation
      defmodule UserMapSchema do
        use Exdantic

        schema do
          field :name, :string
        end
      end

      # Struct-based validation
      defmodule UserStructSchema do
        use Exdantic, define_struct: true

        schema do
          field :name, :string
        end
      end
  """
  @spec __using__(keyword()) :: Macro.t()
  defmacro __using__(opts) do
    define_struct? = Keyword.get(opts, :define_struct, false)

    quote do
      import Exdantic.Schema

      # Register accumulating attributes
      Module.register_attribute(__MODULE__, :schema_description, [])
      Module.register_attribute(__MODULE__, :fields, accumulate: true)
      Module.register_attribute(__MODULE__, :validations, accumulate: true)
      Module.register_attribute(__MODULE__, :config, [])
      Module.register_attribute(__MODULE__, :model_validators, accumulate: true)
      Module.register_attribute(__MODULE__, :computed_fields, accumulate: true)

      # Store struct option for use in __before_compile__
      @exdantic_define_struct unquote(define_struct?)

      @before_compile Exdantic
    end
  end

  @doc """
  Phase 6 Enhancement: Enhanced schema information with complete feature analysis.

  ## Examples

      iex> UserSchema.__enhanced_schema_info__()
      %{
        exdantic_version: "Phase 6",
        phase_6_enhanced: true,
        compatibility: %{...},
        performance_profile: %{...},
        llm_optimization: %{...}
      }
  """
  @spec __before_compile__(Macro.Env.t()) :: Macro.t()
  # credo:disable-for-next-line Credo.Check.Refactor.CyclomaticComplexity
  defmacro __before_compile__(_env) do
    define_struct? = Module.get_attribute(__CALLER__.module, :exdantic_define_struct)
    fields = Module.get_attribute(__CALLER__.module, :fields) || []
    computed_fields = Module.get_attribute(__CALLER__.module, :computed_fields) || []

    # Extract field names for struct definition
    field_names = Enum.map(fields, fn {name, _meta} -> name end)
    computed_field_names = Enum.map(computed_fields, fn {name, _meta} -> name end)
    all_field_names = field_names ++ computed_field_names

    # Generate struct definition if requested
    struct_def =
      if define_struct? do
        quote do
          defstruct unquote(all_field_names)

          @type t :: %__MODULE__{}

          @doc """
          Returns the struct definition fields for this schema.
          Includes both regular fields and computed fields.
          """
          @spec __struct_fields__ :: [atom()]
          def __struct_fields__, do: unquote(all_field_names)

          @doc """
          Returns the regular (non-computed) struct fields for this schema.
          """
          @spec __regular_fields__ :: [atom()]
          def __regular_fields__, do: unquote(field_names)

          @doc """
          Returns the computed field names for this schema.
          """
          @spec __computed_field_names__ :: [atom()]
          def __computed_field_names__, do: unquote(computed_field_names)

          @doc """
          Returns whether this schema defines a struct.
          """
          @spec __struct_enabled__? :: true
          def __struct_enabled__?, do: true

          @doc """
          Serializes a struct instance back to a map.

          When serializing structs with computed fields, the computed fields
          are included in the resulting map since they are part of the struct.

          ## Parameters
            * `struct_or_map` - The struct instance or map to serialize

          ## Returns
            * `{:ok, map}` on success (includes computed fields)
            * `{:error, reason}` on failure

          ## Examples

              iex> user = %UserSchema{
              ...>   name: "John",
              ...>   email: "john@example.com",
              ...>   full_display: "John <john@example.com>"  # computed field
              ...> }
              iex> UserSchema.dump(user)
              {:ok, %{
                name: "John",
                email: "john@example.com",
                full_display: "John <john@example.com>"
              }}

              iex> UserSchema.dump(%{name: "John"})
              {:ok, %{name: "John"}}

              iex> UserSchema.dump("invalid")
              {:error, "Expected UserSchema struct or map, got: \"invalid\""}
          """
          @spec dump(struct() | map()) :: {:ok, map()} | {:error, String.t()}
          def dump(value), do: do_dump(__MODULE__, value)

          defp do_dump(module, %mod{} = struct) when mod == module,
            do: {:ok, Map.from_struct(struct)}

          defp do_dump(_module, map) when is_map(map), do: {:ok, map}

          defp do_dump(module, other),
            do: {:error, "Expected #{module} struct or map, got: #{inspect(other)}"}
        end
      else
        quote do
          @doc """
          Returns whether this schema defines a struct.
          """
          @spec __struct_enabled__? :: false
          def __struct_enabled__?, do: false

          @doc """
          Returns empty list since no struct is defined.
          """
          @spec __struct_fields__ :: []
          def __struct_fields__, do: []

          @doc """
          Returns the regular field names for this schema.
          """
          @spec __regular_fields__ :: [atom()]
          def __regular_fields__, do: unquote(field_names)

          @doc """
          Returns the computed field names for this schema.
          """
          @spec __computed_field_names__ :: [atom()]
          def __computed_field_names__, do: unquote(computed_field_names)
        end
      end

    quote do
      # Inject struct definition if requested
      unquote(struct_def)

      # Define __schema__ functions (updated to include computed_fields)
      def __schema__(:description), do: @schema_description
      def __schema__(:fields), do: @fields
      def __schema__(:validations), do: @validations
      def __schema__(:config), do: @config
      def __schema__(:model_validators), do: @model_validators || []
      def __schema__(:computed_fields), do: @computed_fields || []

      # Validation functions
      unquote(validation_functions())

      # Schema info functions
      unquote(schema_info_functions())

      # Phase 6 enhancements
      unquote(phase_6_functions())
    end
  end

  # Private helper functions for generating code blocks

  defp validation_functions do
    quote do
      @doc """
      Validates data against this schema with full pipeline support.
      """
      @spec validate(map()) :: {:ok, map() | struct()} | {:error, [Exdantic.Error.t()]}
      def validate(data) do
        Exdantic.StructValidator.validate_schema(__MODULE__, data)
      end

      @doc """
      Validates data against this schema, raising an exception on failure.
      """
      @spec validate!(map()) :: map() | struct()
      def validate!(data) do
        case validate(data) do
          {:ok, validated} -> validated
          {:error, errors} -> raise Exdantic.ValidationError, errors: errors
        end
      end
    end
  end

  defp schema_info_functions do
    quote do
      @doc """
      Returns information about the schema including computed fields.
      """
      @spec __schema_info__ :: map()
      def __schema_info__ do
        regular_fields = __schema__(:fields) |> Enum.map(fn {name, _} -> name end)
        computed_fields = __schema__(:computed_fields) |> Enum.map(fn {name, _} -> name end)
        model_validators = __schema__(:model_validators)

        %{
          has_struct: __struct_enabled__?(),
          field_count: length(regular_fields),
          computed_field_count: length(computed_fields),
          model_validator_count: length(model_validators),
          regular_fields: regular_fields,
          computed_fields: computed_fields,
          all_fields: regular_fields ++ computed_fields,
          model_validators: Enum.map(model_validators, fn {mod, fun} -> "#{mod}.#{fun}/1" end)
        }
      end
    end
  end

  defp phase_6_functions do
    quote do
      # Core Phase 6 functions
      unquote(phase_6_core_functions())

      # Analysis functions
      unquote(phase_6_analysis_functions())

      # Helper functions
      unquote(phase_6_helper_functions())
    end
  end

  defp phase_6_core_functions do
    quote do
      @doc """
      Returns enhanced schema information with Phase 6 features.
      """
      @spec __enhanced_schema_info__ :: map()
      def __enhanced_schema_info__ do
        basic_info = __schema_info__()

        # Add Phase 6 specific information
        enhanced_info = %{
          exdantic_version: "Phase 6",
          phase_6_enhanced: true,
          json_schema_enhanced: true,
          llm_compatible: true,
          dspy_ready: analyze_dspy_readiness(),
          performance_profile: analyze_performance_profile(),
          compatibility_matrix: analyze_compatibility_matrix()
        }

        Map.merge(basic_info, enhanced_info)
      end

      @doc """
      Validates data with Phase 6 enhanced pipeline and optional reporting.
      """
      @spec validate_enhanced(map(), keyword()) ::
              {:ok, map() | struct()}
              | {:ok, map() | struct(), map()}
              | {:error, [Exdantic.Error.t()]}
      def validate_enhanced(data, opts \\ []) do
        include_metrics = Keyword.get(opts, :include_performance_metrics, false)
        test_llm = Keyword.get(opts, :test_llm_compatibility, false)
        generate_schema = Keyword.get(opts, :generate_enhanced_schema, false)

        start_time = System.monotonic_time(:microsecond)

        case validate(data) do
          {:ok, validated_data} ->
            if include_metrics or test_llm or generate_schema do
              additional_info =
                build_enhanced_validation_result(
                  validated_data,
                  start_time,
                  include_metrics,
                  test_llm,
                  generate_schema
                )

              {:ok, validated_data, additional_info}
            else
              {:ok, validated_data}
            end

          {:error, errors} ->
            {:error, errors}
        end
      end
    end
  end

  defp phase_6_analysis_functions do
    quote do
      # Core analysis functions
      unquote(dspy_readiness_functions())
      unquote(performance_profile_functions())
      unquote(compatibility_matrix_functions())
    end
  end

  defp dspy_readiness_functions do
    quote do
      defp analyze_dspy_readiness do
        {model_validator_count, computed_field_count} = get_validator_and_field_counts()
        build_dspy_readiness_report(model_validator_count, computed_field_count)
      end

      defp build_dspy_readiness_report(model_validator_count, computed_field_count) do
        %{
          ready: dspy_ready?(model_validator_count, computed_field_count),
          model_validators: model_validator_count,
          computed_fields: computed_field_count,
          recommendations:
            generate_dspy_recommendations(model_validator_count, computed_field_count)
        }
      end

      defp get_validator_and_field_counts do
        model_validator_count = length(__schema__(:model_validators) || [])
        computed_field_count = length(__schema__(:computed_fields) || [])
        {model_validator_count, computed_field_count}
      end

      defp dspy_ready?(model_validator_count, computed_field_count) do
        model_validator_count <= 3 and computed_field_count <= 5
      end
    end
  end

  defp performance_profile_functions do
    quote do
      defp analyze_performance_profile do
        {field_count, model_validator_count, computed_field_count} = get_field_counts()
        build_performance_profile(field_count, model_validator_count, computed_field_count)
      end

      defp build_performance_profile(field_count, model_validator_count, computed_field_count) do
        complexity_score =
          calculate_complexity_score(field_count, model_validator_count, computed_field_count)

        build_performance_metrics(complexity_score, field_count, computed_field_count)
      end

      defp build_performance_metrics(complexity_score, field_count, computed_field_count) do
        %{
          complexity_score: complexity_score,
          estimated_validation_time: estimate_validation_time(complexity_score),
          memory_footprint: estimate_memory_footprint(field_count, computed_field_count),
          optimization_level: determine_optimization_level(complexity_score)
        }
      end

      defp get_field_counts do
        field_count = length(__schema__(:fields) || [])
        model_validator_count = length(__schema__(:model_validators) || [])
        computed_field_count = length(__schema__(:computed_fields) || [])
        {field_count, model_validator_count, computed_field_count}
      end

      defp calculate_complexity_score(field_count, model_validator_count, computed_field_count) do
        field_count + model_validator_count * 2 + computed_field_count * 3
      end
    end
  end

  defp compatibility_matrix_functions do
    quote do
      defp analyze_compatibility_matrix do
        {has_struct, has_validators, has_computed} = get_feature_flags()
        build_compatibility_matrix(has_struct, has_validators, has_computed)
      end

      defp build_compatibility_matrix(has_struct, has_validators, has_computed) do
        %{
          json_schema_generation: true,
          llm_providers: get_llm_provider_compatibility(),
          dspy_patterns: get_dspy_pattern_compatibility(has_computed, has_validators),
          struct_support: has_struct,
          enhanced_features: has_validators or has_computed
        }
      end

      defp get_feature_flags do
        has_struct = __struct_enabled__?()
        has_validators = length(__schema__(:model_validators) || []) > 0
        has_computed = length(__schema__(:computed_fields) || []) > 0
        {has_struct, has_validators, has_computed}
      end

      defp get_llm_provider_compatibility do
        %{
          openai: true,
          anthropic: true,
          generic: true
        }
      end

      defp get_dspy_pattern_compatibility(has_computed, has_validators) do
        %{
          signature: not has_computed,
          chain_of_thought: has_validators,
          input_output: true
        }
      end
    end
  end

  defp phase_6_helper_functions do
    quote do
      # Core helper functions
      unquote(validation_result_functions())
      unquote(recommendation_functions())
      unquote(estimation_functions())
    end
  end

  defp validation_result_functions do
    quote do
      # Result building functions
      unquote(result_builder_functions())

      # Metrics functions
      unquote(metrics_functions())

      # Feature addition functions
      unquote(feature_addition_functions())
    end
  end

  defp result_builder_functions do
    quote do
      defp build_enhanced_validation_result(
             validated_data,
             start_time,
             include_metrics,
             test_llm,
             generate_schema
           ) do
        build_result_with_features(start_time, include_metrics, test_llm, generate_schema)
      end

      defp build_result_with_features(start_time, include_metrics, test_llm, generate_schema) do
        %{}
        |> add_metrics(start_time, include_metrics)
        |> add_llm_compatibility(test_llm)
        |> add_enhanced_schema(generate_schema)
      end
    end
  end

  defp metrics_functions do
    quote do
      defp add_metrics(result, start_time, true) do
        metrics = calculate_performance_metrics(start_time)
        Map.put(result, :performance_metrics, metrics)
      end

      defp add_metrics(result, _start_time, false), do: result

      defp calculate_performance_metrics(start_time) do
        end_time = System.monotonic_time(:microsecond)
        duration = end_time - start_time
        build_metrics_map(duration)
      end

      defp build_metrics_map(duration) do
        %{
          validation_duration_microseconds: duration,
          validation_duration_milliseconds: duration / 1000,
          memory_used: :erlang.memory(:total)
        }
      end
    end
  end

  defp feature_addition_functions do
    quote do
      defp add_llm_compatibility(result, true) do
        compatibility = test_llm_provider_compatibility()
        Map.put(result, :llm_compatibility, compatibility)
      end

      defp add_llm_compatibility(result, false), do: result

      defp add_enhanced_schema(result, true) do
        enhanced_schema = EnhancedResolver.resolve_enhanced(__MODULE__)
        Map.put(result, :enhanced_schema, enhanced_schema)
      end

      defp add_enhanced_schema(result, false), do: result
    end
  end

  defp recommendation_functions do
    quote do
      defp generate_dspy_recommendations(model_validators, computed_fields) do
        []
        |> add_model_validator_recommendation(model_validators)
        |> add_computed_field_recommendation(computed_fields)
        |> finalize_recommendations()
      end

      defp add_model_validator_recommendation(recommendations, model_validators) do
        if model_validators > 3 do
          ["Consider reducing model validators for DSPy compatibility" | recommendations]
        else
          recommendations
        end
      end

      defp add_computed_field_recommendation(recommendations, computed_fields) do
        if computed_fields > 5 do
          ["Consider reducing computed fields for DSPy signatures" | recommendations]
        else
          recommendations
        end
      end

      defp finalize_recommendations([]), do: ["Schema is well-suited for DSPy usage"]
      defp finalize_recommendations(recommendations), do: recommendations
    end
  end

  defp estimation_functions do
    quote do
      # Time estimation functions
      unquote(time_estimation_functions())

      # Memory estimation functions
      unquote(memory_estimation_functions())

      # Optimization level functions
      unquote(optimization_level_functions())

      # Provider compatibility functions
      unquote(provider_compatibility_functions())
    end
  end

  defp time_estimation_functions do
    quote do
      defp estimate_validation_time(complexity_score) when complexity_score < 10, do: "< 1ms"
      defp estimate_validation_time(complexity_score) when complexity_score < 25, do: "1-5ms"
      defp estimate_validation_time(complexity_score) when complexity_score < 50, do: "5-15ms"
      defp estimate_validation_time(_complexity_score), do: "> 15ms"
    end
  end

  defp memory_estimation_functions do
    quote do
      defp estimate_memory_footprint(field_count, computed_field_count) do
        total = calculate_total_memory(field_count, computed_field_count)
        format_memory_size(total)
      end

      defp calculate_total_memory(field_count, computed_field_count) do
        base_memory = field_count * 100
        computed_memory = computed_field_count * 300
        base_memory + computed_memory
      end

      defp format_memory_size(total) when total < 1000, do: "< 1KB"
      defp format_memory_size(total) when total < 5000, do: "1-5KB"
      defp format_memory_size(total) when total < 10_000, do: "5-10KB"
      defp format_memory_size(_total), do: "> 10KB"
    end
  end

  defp optimization_level_functions do
    quote do
      defp determine_optimization_level(complexity_score) when complexity_score < 20, do: :high
      defp determine_optimization_level(complexity_score) when complexity_score < 50, do: :medium
      defp determine_optimization_level(_complexity_score), do: :low
    end
  end

  defp provider_compatibility_functions do
    quote do
      defp test_llm_provider_compatibility do
        %{
          openai: %{compatible: true, score: 85},
          anthropic: %{compatible: true, score: 80},
          generic: %{compatible: true, score: 90}
        }
      end
    end
  end
end
