defmodule Exdantic.Config do
  @moduledoc """
  Advanced configuration with runtime modification support.

  This module provides functionality for creating and manipulating validation
  configuration at runtime, supporting the DSPy pattern of dynamic config
  modification like `ConfigDict(extra="forbid", frozen=True)`.
  """

  defstruct [
    # Enforce strict validation (no extra fields)
    strict: false,
    # How to handle extra fields (:allow, :forbid, :ignore)
    extra: :allow,
    # Type coercion strategy (:none, :safe, :aggressive)
    coercion: :safe,
    # Whether the config is immutable
    frozen: false,
    # Validate field assignments
    validate_assignment: false,
    # Use enum values instead of names
    use_enum_values: false,
    # Allow both field names and aliases
    allow_population_by_field_name: true,
    # Case sensitivity for field names
    case_sensitive: true,
    # Error format (:detailed, :simple, :minimal)
    error_format: :detailed,
    # Maximum length for anyOf unions
    max_anyof_union_len: 5,
    # Function to generate titles
    title_generator: nil,
    # Function to generate descriptions
    description_generator: nil
  ]

  alias Exdantic.Config.Builder

  @type extra_strategy :: :allow | :forbid | :ignore
  @type coercion_strategy :: :none | :safe | :aggressive
  @type error_format :: :detailed | :simple | :minimal

  @type t :: %__MODULE__{
          strict: boolean(),
          extra: extra_strategy(),
          coercion: coercion_strategy(),
          frozen: boolean(),
          validate_assignment: boolean(),
          use_enum_values: boolean(),
          allow_population_by_field_name: boolean(),
          case_sensitive: boolean(),
          error_format: error_format(),
          max_anyof_union_len: non_neg_integer(),
          title_generator: (atom() -> String.t()) | nil,
          description_generator: (atom() -> String.t()) | nil
        }

  @doc """
  Creates a new configuration with the specified options.

  ## Parameters
    * `opts` - Configuration options as keyword list or map

  ## Options
    * `:strict` - Enforce strict validation (default: false)
    * `:extra` - How to handle extra fields (default: :allow)
    * `:coercion` - Type coercion strategy (default: :safe)
    * `:frozen` - Whether the config is immutable (default: false)
    * `:validate_assignment` - Validate field assignments (default: false)
    * `:error_format` - Error format style (default: :detailed)

  ## Returns
    * New Config struct

  ## Examples

      iex> config = Exdantic.Config.create(strict: true, extra: :forbid)
      iex> config.strict
      true

      iex> config = Exdantic.Config.create(%{coercion: :aggressive, frozen: true})
      iex> config.coercion
      :aggressive
  """
  @spec create(keyword() | map()) :: t()
  def create(opts \\ []) do
    opts_map =
      case opts do
        map when is_map(map) -> map
        keyword when is_list(keyword) -> Map.new(keyword)
      end

    # Validate that all keys are valid struct fields
    valid_keys = __MODULE__.__struct__() |> Map.keys() |> MapSet.new()
    provided_keys = opts_map |> Map.keys() |> MapSet.new()

    case MapSet.difference(provided_keys, valid_keys) |> MapSet.to_list() do
      [] ->
        # Validate option values
        validate_option_values!(opts_map)
        struct!(__MODULE__, opts_map)

      invalid_keys ->
        raise ArgumentError, "Invalid configuration options: #{inspect(invalid_keys)}"
    end
  end

  @doc """
  Merges configuration options with an existing config.

  ## Parameters
    * `base_config` - The base configuration
    * `overrides` - Configuration options to merge/override

  ## Returns
    * New Config struct with merged options
    * Raises if base config is frozen and overrides are provided

  ## Examples

      iex> base = Exdantic.Config.create(strict: true)
      iex> merged = Exdantic.Config.merge(base, %{extra: :forbid, coercion: :none})
      %Exdantic.Config{strict: true, extra: :forbid, coercion: :none, ...}

      iex> frozen = Exdantic.Config.create(frozen: true)
      iex> Exdantic.Config.merge(frozen, %{strict: true})
      ** (RuntimeError) Cannot modify frozen configuration
  """
  @spec merge(t(), map() | keyword()) :: t()
  def merge(%__MODULE__{frozen: true} = config, overrides) do
    overrides_map =
      case overrides do
        map when is_map(map) -> map
        keyword when is_list(keyword) -> Map.new(keyword)
      end

    # Check if overrides is empty
    is_empty = map_size(overrides_map) == 0

    if is_empty do
      # Return the frozen config unchanged for empty overrides
      config
    else
      # Frozen configs cannot be modified - this is the expected behavior
      raise RuntimeError, "Cannot modify frozen configuration"
    end
  end

  def merge(%__MODULE__{} = base_config, overrides) do
    overrides_map =
      case overrides do
        map when is_map(map) -> map
        keyword when is_list(keyword) -> Map.new(keyword)
      end

    struct!(base_config, overrides_map)
  end

  @doc """
  Creates a preset configuration for common validation scenarios.

  ## Parameters
    * `preset` - The preset name

  ## Available Presets
    * `:strict` - Strict validation with no extra fields
    * `:lenient` - Lenient validation allowing extra fields
    * `:api` - Configuration suitable for API validation
    * `:json_schema` - Configuration optimized for JSON Schema generation
    * `:development` - Development-friendly configuration
    * `:production` - Production-ready configuration

  ## Returns
    * Pre-configured Config struct

  ## Examples

      iex> Exdantic.Config.preset(:strict)
      %Exdantic.Config{strict: true, extra: :forbid, coercion: :none, ...}

      iex> Exdantic.Config.preset(:lenient)
      %Exdantic.Config{strict: false, extra: :allow, coercion: :safe, ...}
  """
  @spec preset(:strict | :lenient | :api | :json_schema | :development | :production) :: t()
  def preset(:strict) do
    create(%{
      strict: true,
      extra: :forbid,
      coercion: :none,
      validate_assignment: true,
      case_sensitive: true,
      error_format: :detailed
    })
  end

  def preset(:lenient) do
    create(%{
      strict: false,
      extra: :allow,
      coercion: :safe,
      validate_assignment: false,
      case_sensitive: false,
      error_format: :simple
    })
  end

  def preset(:api) do
    create(%{
      strict: true,
      extra: :forbid,
      coercion: :safe,
      validate_assignment: true,
      case_sensitive: true,
      error_format: :detailed,
      frozen: true
    })
  end

  def preset(:json_schema) do
    create(%{
      strict: false,
      extra: :allow,
      coercion: :none,
      use_enum_values: true,
      error_format: :minimal,
      max_anyof_union_len: 3
    })
  end

  def preset(:development) do
    create(%{
      strict: false,
      extra: :allow,
      coercion: :aggressive,
      validate_assignment: false,
      case_sensitive: false,
      error_format: :detailed
    })
  end

  def preset(:production) do
    create(%{
      strict: true,
      extra: :forbid,
      coercion: :safe,
      validate_assignment: true,
      case_sensitive: true,
      error_format: :simple,
      frozen: true
    })
  end

  def preset(unknown) do
    raise ArgumentError, "Unknown preset: #{inspect(unknown)}"
  end

  @doc """
  Validates configuration options for consistency.

  ## Parameters
    * `config` - The configuration to validate

  ## Returns
    * `:ok` if configuration is valid
    * `{:error, reasons}` if configuration has issues

  ## Examples

      iex> config = Exdantic.Config.create(strict: true, extra: :allow)
      iex> Exdantic.Config.validate_config(config)
      {:error, ["strict mode conflicts with extra: :allow"]}

      iex> config = Exdantic.Config.create(strict: true, extra: :forbid)
      iex> Exdantic.Config.validate_config(config)
      :ok
  """
  @spec validate_config(t()) :: :ok | {:error, [String.t()]}
  def validate_config(%__MODULE__{} = config) do
    errors = []

    errors =
      if config.strict and config.extra == :allow do
        ["strict mode conflicts with extra: :allow" | errors]
      else
        errors
      end

    errors =
      if config.coercion == :aggressive and config.validate_assignment do
        ["aggressive coercion conflicts with validate_assignment" | errors]
      else
        errors
      end

    errors =
      if config.max_anyof_union_len < 1 do
        ["max_anyof_union_len must be at least 1" | errors]
      else
        errors
      end

    case errors do
      [] -> :ok
      reasons -> {:error, Enum.reverse(reasons)}
    end
  end

  @doc """
  Converts configuration to options suitable for validation functions.

  ## Parameters
    * `config` - The configuration to convert

  ## Returns
    * Keyword list of validation options

  ## Examples

      iex> config = Exdantic.Config.create(strict: true, coercion: :safe)
      iex> Exdantic.Config.to_validation_opts(config)
      [strict: true, coerce: true, error_format: :detailed, ...]
  """
  @spec to_validation_opts(t()) :: keyword()
  def to_validation_opts(%__MODULE__{} = config) do
    [
      strict: config.strict,
      coerce: config.coercion != :none,
      coercion_strategy: config.coercion,
      extra: config.extra,
      validate_assignment: config.validate_assignment,
      case_sensitive: config.case_sensitive,
      error_format: config.error_format,
      allow_population_by_field_name: config.allow_population_by_field_name
    ]
  end

  @doc """
  Converts configuration to options suitable for JSON Schema generation.

  ## Parameters
    * `config` - The configuration to convert

  ## Returns
    * Keyword list of JSON Schema options

  ## Examples

      iex> config = Exdantic.Config.create(strict: true, use_enum_values: true)
      iex> Exdantic.Config.to_json_schema_opts(config)
      [strict: true, use_enum_values: true, max_anyof_union_len: 5, ...]
  """
  @spec to_json_schema_opts(t()) :: keyword()
  def to_json_schema_opts(%__MODULE__{} = config) do
    [
      strict: config.strict,
      use_enum_values: config.use_enum_values,
      max_anyof_union_len: config.max_anyof_union_len,
      title_generator: config.title_generator,
      description_generator: config.description_generator
    ]
  end

  @doc """
  Checks if extra fields should be allowed based on configuration.

  ## Parameters
    * `config` - The configuration to check

  ## Returns
    * `true` if extra fields are allowed, `false` otherwise

  ## Examples

      iex> config = Exdantic.Config.create(extra: :allow)
      iex> Exdantic.Config.allow_extra_fields?(config)
      true

      iex> config = Exdantic.Config.create(extra: :forbid)
      iex> Exdantic.Config.allow_extra_fields?(config)
      false
  """
  @spec allow_extra_fields?(t()) :: boolean()
  def allow_extra_fields?(%__MODULE__{extra: :allow}), do: true
  def allow_extra_fields?(%__MODULE__{extra: :forbid}), do: false
  def allow_extra_fields?(%__MODULE__{extra: :ignore}), do: true

  @doc """
  Checks if type coercion should be performed based on configuration.

  ## Parameters
    * `config` - The configuration to check

  ## Returns
    * `true` if coercion should be performed, `false` otherwise

  ## Examples

      iex> config = Exdantic.Config.create(coercion: :safe)
      iex> Exdantic.Config.should_coerce?(config)
      true

      iex> config = Exdantic.Config.create(coercion: :none)
      iex> Exdantic.Config.should_coerce?(config)
      false
  """
  @spec should_coerce?(t()) :: boolean()
  def should_coerce?(%__MODULE__{coercion: :none}), do: false
  def should_coerce?(%__MODULE__{coercion: _}), do: true

  @doc """
  Gets the coercion aggressiveness level.

  ## Parameters
    * `config` - The configuration to check

  ## Returns
    * Coercion strategy atom

  ## Examples

      iex> config = Exdantic.Config.create(coercion: :aggressive)
      iex> Exdantic.Config.coercion_level(config)
      :aggressive
  """
  @spec coercion_level(t()) :: coercion_strategy()
  def coercion_level(%__MODULE__{coercion: level}), do: level

  @doc """
  Returns a summary of the configuration settings.

  ## Parameters
    * `config` - The configuration to summarize

  ## Returns
    * Map with configuration summary

  ## Examples

      iex> config = Exdantic.Config.create(strict: true, extra: :forbid)
      iex> Exdantic.Config.summary(config)
      %{
        validation_mode: "strict",
        extra_fields: "forbidden",
        coercion: "safe",
        frozen: false,
        features: ["validate_assignment", ...]
      }
  """
  @spec summary(t()) :: %{
          validation_mode: String.t(),
          extra_fields: String.t(),
          coercion: String.t(),
          frozen: boolean(),
          error_format: String.t(),
          features: [String.t()]
        }
  def summary(%__MODULE__{} = config) do
    %{
      validation_mode: if(config.strict, do: "strict", else: "lenient"),
      extra_fields:
        case config.extra do
          :allow -> "allowed"
          :forbid -> "forbidden"
          :ignore -> "ignored"
        end,
      coercion: Atom.to_string(config.coercion),
      frozen: config.frozen,
      error_format: Atom.to_string(config.error_format),
      features: enabled_features(config)
    }
  end

  @doc """
  Creates a builder for fluent configuration creation.

  ## Returns
    * ConfigBuilder struct for chaining configuration calls

  ## Examples

      iex> config = Exdantic.Config.builder()
      ...> |> Exdantic.Config.Builder.strict(true)
      ...> |> Exdantic.Config.Builder.forbid_extra()
      ...> |> Exdantic.Config.Builder.safe_coercion()
      ...> |> Exdantic.Config.Builder.build()
      %Exdantic.Config{strict: true, extra: :forbid, coercion: :safe, ...}
  """
  @spec builder() :: Builder.t()
  def builder do
    Builder.new()
  end

  @doc """
  Creates a configuration optimized for Phase 6 enhanced features.

  Phase 6 Enhancement: Configuration that supports all new features and LLM optimizations.

  ## Parameters
    * `opts` - Configuration options with Phase 6 enhancements

  ## Phase 6 Options
    * `:llm_provider` - Target LLM provider for optimization (:openai, :anthropic, :generic)
    * `:dspy_compatible` - Ensure DSPy compatibility (default: false)
    * `:enhanced_validation` - Enable enhanced validation pipeline (default: true)
    * `:include_metadata` - Include enhanced metadata in schemas (default: true)
    * `:performance_mode` - Optimize for performance (:speed, :memory, :balanced)

  ## Examples

      iex> config = Exdantic.Config.create_enhanced(%{
      ...>   llm_provider: :openai,
      ...>   dspy_compatible: true,
      ...>   performance_mode: :balanced
      ...> })
      %Exdantic.Config{...}
  """
  @spec create_enhanced(map() | keyword()) :: t()
  def create_enhanced(opts \\ []) do
    opts_map =
      case opts do
        map when is_map(map) -> map
        keyword when is_list(keyword) -> Map.new(keyword)
      end

    # Extract Phase 6 specific options
    llm_provider = Map.get(opts_map, :llm_provider, :generic)
    dspy_compatible = Map.get(opts_map, :dspy_compatible, false)
    enhanced_validation = Map.get(opts_map, :enhanced_validation, true)
    _include_metadata = Map.get(opts_map, :include_metadata, true)
    performance_mode = Map.get(opts_map, :performance_mode, :balanced)

    # Build base configuration based on provider and requirements
    base_config = build_provider_optimized_config(llm_provider, dspy_compatible)

    # Apply performance optimizations
    performance_config = apply_performance_optimizations(base_config, performance_mode)

    # Apply enhanced validation settings
    enhanced_config = apply_enhanced_validation_settings(performance_config, enhanced_validation)

    # Merge with user-provided options (user options take precedence)
    user_opts =
      Map.drop(opts_map, [
        :llm_provider,
        :dspy_compatible,
        :enhanced_validation,
        :include_metadata,
        :performance_mode
      ])

    final_config = Map.merge(enhanced_config, user_opts)

    create(final_config)
  end

  @doc """
  Creates a preset configuration for DSPy integration.

  Phase 6 Enhancement: Specialized configuration for DSPy patterns.

  ## Parameters
    * `dspy_mode` - DSPy usage pattern (:signature, :chain_of_thought, :input_output, :general)
    * `opts` - Additional configuration options

  ## Examples

      iex> config = Exdantic.Config.for_dspy(:signature, provider: :openai)
      %Exdantic.Config{strict: true, extra: :forbid, ...}
  """
  @spec for_dspy(:signature | :chain_of_thought | :input_output | :general, keyword()) :: t()
  def for_dspy(dspy_mode, opts \\ []) do
    provider = Keyword.get(opts, :provider, :openai)

    base_config =
      case dspy_mode do
        :signature ->
          %{
            strict: true,
            extra: :forbid,
            coercion: :safe,
            validate_assignment: true,
            case_sensitive: true,
            error_format: :detailed,
            use_enum_values: true
          }

        :chain_of_thought ->
          %{
            strict: true,
            extra: :forbid,
            coercion: :safe,
            validate_assignment: true,
            case_sensitive: true,
            error_format: :detailed,
            # Simpler unions for better reasoning
            max_anyof_union_len: 2
          }

        :input_output ->
          %{
            strict: true,
            extra: :forbid,
            # More flexible input processing
            coercion: :aggressive,
            validate_assignment: false,
            case_sensitive: false,
            error_format: :simple
          }

        :general ->
          %{
            strict: true,
            extra: :forbid,
            coercion: :safe,
            validate_assignment: true,
            error_format: :detailed
          }

        _ ->
          raise ArgumentError, "Unknown DSPy mode: #{inspect(dspy_mode)}"
      end

    # Apply provider-specific optimizations
    provider_optimized = apply_dspy_provider_optimizations(base_config, provider)

    # Merge with user options
    final_config = Map.merge(provider_optimized, Map.new(opts))

    create(final_config)
  end

  # Private helper functions for Phase 6 enhancements

  @spec build_provider_optimized_config(atom(), boolean()) :: map()
  defp build_provider_optimized_config(provider, dspy_compatible) do
    base =
      case provider do
        :openai ->
          %{
            strict: true,
            extra: :forbid,
            coercion: :safe,
            validate_assignment: true,
            error_format: :detailed,
            use_enum_values: true
          }

        :anthropic ->
          %{
            strict: true,
            extra: :forbid,
            coercion: :safe,
            validate_assignment: true,
            error_format: :detailed,
            case_sensitive: true
          }

        :generic ->
          %{
            strict: false,
            extra: :allow,
            coercion: :safe,
            validate_assignment: false,
            error_format: :simple
          }

        _ ->
          %{
            strict: false,
            extra: :allow,
            coercion: :safe,
            error_format: :simple
          }
      end

    if dspy_compatible do
      # Ensure DSPy compatibility
      base
      |> Map.put(:strict, true)
      |> Map.put(:extra, :forbid)
      |> Map.put(:use_enum_values, true)
      |> Map.put(:max_anyof_union_len, 3)
    else
      base
    end
  end

  @spec apply_performance_optimizations(map(), atom()) :: map()
  defp apply_performance_optimizations(config, performance_mode) do
    case performance_mode do
      :speed ->
        config
        |> Map.put(:validate_assignment, false)
        |> Map.put(:error_format, :minimal)
        # Skip coercion for speed
        |> Map.put(:coercion, :none)

      :memory ->
        config
        |> Map.put(:error_format, :minimal)
        # Reduce memory usage
        |> Map.put(:max_anyof_union_len, 2)

      :balanced ->
        config
        |> Map.put(:error_format, :simple)
        |> Map.put(:coercion, :safe)

      _ ->
        config
    end
  end

  @spec apply_enhanced_validation_settings(map(), boolean()) :: map()
  defp apply_enhanced_validation_settings(config, enhanced_validation) do
    if enhanced_validation do
      config
      |> Map.put(:validate_assignment, true)
      |> Map.put(:error_format, :detailed)
    else
      config
    end
  end

  @spec apply_dspy_provider_optimizations(map(), atom()) :: map()
  defp apply_dspy_provider_optimizations(config, provider) do
    case provider do
      :openai ->
        config
        |> Map.put(:frozen, true)
        |> Map.put(:use_enum_values, true)

      :anthropic ->
        config
        |> Map.put(:case_sensitive, true)
        |> Map.put(:allow_population_by_field_name, false)

      _ ->
        config
    end
  end

  # Private helper functions

  @spec validate_option_values!(map()) :: :ok
  defp validate_option_values!(opts_map) do
    Enum.each(opts_map, &validate_single_option/1)
  end

  @spec validate_single_option({atom(), term()}) :: :ok
  defp validate_single_option({key, value}) do
    case key do
      k
      when k in [
             :strict,
             :frozen,
             :validate_assignment,
             :use_enum_values,
             :allow_population_by_field_name,
             :case_sensitive
           ] ->
        validate_boolean_option(value, Atom.to_string(k))

      :extra ->
        validate_extra_option(value)

      :coercion ->
        validate_coercion_option(value)

      :error_format ->
        validate_error_format_option(value)

      :max_anyof_union_len ->
        validate_integer_option(value, "max_anyof_union_len")

      k when k in [:title_generator, :description_generator] ->
        validate_function_option(value, Atom.to_string(k))

      _ ->
        :ok
    end
  end

  defp validate_boolean_option(value, field_name) do
    unless is_boolean(value), do: raise(ArgumentError, "#{field_name} must be a boolean")
    :ok
  end

  defp validate_extra_option(value) do
    unless value in [:allow, :forbid, :ignore],
      do: raise(ArgumentError, "extra must be :allow, :forbid, or :ignore")

    :ok
  end

  defp validate_coercion_option(value) do
    unless value in [:none, :safe, :aggressive],
      do: raise(ArgumentError, "coercion must be :none, :safe, or :aggressive")

    :ok
  end

  defp validate_error_format_option(value) do
    unless value in [:detailed, :simple, :minimal],
      do: raise(ArgumentError, "error_format must be :detailed, :simple, or :minimal")

    :ok
  end

  defp validate_integer_option(value, field_name) do
    unless is_integer(value),
      do: raise(ArgumentError, "#{field_name} must be an integer")

    :ok
  end

  defp validate_function_option(value, field_name) do
    unless is_nil(value) or is_function(value, 1),
      do: raise(ArgumentError, "#{field_name} must be a function or nil")

    :ok
  end

  @spec enabled_features(t()) :: [String.t()]
  defp enabled_features(config) do
    features = []

    features =
      if config.validate_assignment, do: ["validate_assignment" | features], else: features

    features = if config.use_enum_values, do: ["use_enum_values" | features], else: features

    features =
      if config.allow_population_by_field_name,
        do: ["field_name_population" | features],
        else: features

    features = if config.case_sensitive, do: ["case_sensitive" | features], else: features
    features = if config.title_generator, do: ["title_generator" | features], else: features

    features =
      if config.description_generator, do: ["description_generator" | features], else: features

    Enum.reverse(features)
  end
end
