defmodule Exdantic.Config.Builder do
  @moduledoc """
  Fluent builder for creating Exdantic configurations.

  This module provides a chainable API for building complex configurations
  in a readable and intuitive way.
  """

  @enforce_keys []
  defstruct opts: %{}

  @type t :: %__MODULE__{
          opts: map()
        }

  @doc """
  Creates a new configuration builder.

  ## Returns
    * New ConfigBuilder instance

  ## Examples

      iex> builder = Exdantic.Config.Builder.new()
      %Exdantic.Config.Builder{opts: %{}}
  """
  @spec new() :: %__MODULE__{opts: %{}}
  def new do
    %__MODULE__{opts: %{}}
  end

  @doc """
  Sets strict validation mode.

  ## Parameters
    * `builder` - The builder instance
    * `enabled` - Whether to enable strict mode (default: true)

  ## Returns
    * Updated builder instance

  ## Examples

      iex> builder |> Exdantic.Config.Builder.strict()
      %Exdantic.Config.Builder{opts: %{strict: true}}

      iex> builder |> Exdantic.Config.Builder.strict(false)
      %Exdantic.Config.Builder{opts: %{strict: false}}
  """
  @spec strict(t(), boolean()) :: t()
  def strict(%__MODULE__{} = builder, enabled \\ true) do
    %{builder | opts: Map.put(builder.opts, :strict, enabled)}
  end

  @doc """
  Sets how extra fields should be handled.

  ## Parameters
    * `builder` - The builder instance
    * `strategy` - The extra field strategy (:allow, :forbid, :ignore)

  ## Returns
    * Updated builder instance

  ## Examples

      iex> builder |> Exdantic.Config.Builder.extra(:forbid)
      %Exdantic.Config.Builder{opts: %{extra: :forbid}}
  """
  @spec extra(t(), Exdantic.Config.extra_strategy()) :: t()
  def extra(%__MODULE__{} = builder, strategy) when strategy in [:allow, :forbid, :ignore] do
    %{builder | opts: Map.put(builder.opts, :extra, strategy)}
  end

  @doc """
  Convenience method to forbid extra fields.

  ## Parameters
    * `builder` - The builder instance

  ## Returns
    * Updated builder instance

  ## Examples

      iex> builder |> Exdantic.Config.Builder.forbid_extra()
      %Exdantic.Config.Builder{opts: %{extra: :forbid}}
  """
  def forbid_extra(%__MODULE__{} = builder) do
    extra(builder, :forbid)
  end

  @doc """
  Convenience method to allow extra fields.

  ## Parameters
    * `builder` - The builder instance

  ## Returns
    * Updated builder instance

  ## Examples

      iex> builder |> Exdantic.Config.Builder.allow_extra()
      %Exdantic.Config.Builder{opts: %{extra: :allow}}
  """
  def allow_extra(%__MODULE__{} = builder) do
    extra(builder, :allow)
  end

  @doc """
  Sets the coercion strategy.

  ## Parameters
    * `builder` - The builder instance
    * `strategy` - The coercion strategy (:none, :safe, :aggressive)

  ## Returns
    * Updated builder instance

  ## Examples

      iex> builder |> Exdantic.Config.Builder.coercion(:safe)
      %Exdantic.Config.Builder{opts: %{coercion: :safe}}
  """
  @spec coercion(t(), Exdantic.Config.coercion_strategy()) :: t()
  def coercion(%__MODULE__{} = builder, strategy) when strategy in [:none, :safe, :aggressive] do
    %{builder | opts: Map.put(builder.opts, :coercion, strategy)}
  end

  @doc """
  Convenience method to disable coercion.

  ## Parameters
    * `builder` - The builder instance

  ## Returns
    * Updated builder instance

  ## Examples

      iex> builder |> Exdantic.Config.Builder.no_coercion()
      %Exdantic.Config.Builder{opts: %{coercion: :none}}
  """
  def no_coercion(%__MODULE__{} = builder) do
    coercion(builder, :none)
  end

  @doc """
  Convenience method to enable safe coercion.

  ## Parameters
    * `builder` - The builder instance

  ## Returns
    * Updated builder instance

  ## Examples

      iex> builder |> Exdantic.Config.Builder.safe_coercion()
      %Exdantic.Config.Builder{opts: %{coercion: :safe}}
  """
  def safe_coercion(%__MODULE__{} = builder) do
    coercion(builder, :safe)
  end

  @doc """
  Convenience method to enable aggressive coercion.

  ## Parameters
    * `builder` - The builder instance

  ## Returns
    * Updated builder instance

  ## Examples

      iex> builder |> Exdantic.Config.Builder.aggressive_coercion()
      %Exdantic.Config.Builder{opts: %{coercion: :aggressive}}
  """
  def aggressive_coercion(%__MODULE__{} = builder) do
    coercion(builder, :aggressive)
  end

  @doc """
  Sets whether the configuration should be frozen (immutable).

  ## Parameters
    * `builder` - The builder instance
    * `enabled` - Whether to freeze the config (default: true)

  ## Returns
    * Updated builder instance

  ## Examples

      iex> builder |> Exdantic.Config.Builder.frozen()
      %Exdantic.Config.Builder{opts: %{frozen: true}}
  """
  @spec frozen(t(), boolean()) :: t()
  def frozen(%__MODULE__{} = builder, enabled \\ true) do
    %{builder | opts: Map.put(builder.opts, :frozen, enabled)}
  end

  @doc """
  Sets whether to validate field assignments.

  ## Parameters
    * `builder` - The builder instance
    * `enabled` - Whether to enable assignment validation (default: true)

  ## Returns
    * Updated builder instance

  ## Examples

      iex> builder |> Exdantic.Config.Builder.validate_assignment()
      %Exdantic.Config.Builder{opts: %{validate_assignment: true}}
  """
  @spec validate_assignment(t(), boolean()) :: t()
  def validate_assignment(%__MODULE__{} = builder, enabled \\ true) do
    %{builder | opts: Map.put(builder.opts, :validate_assignment, enabled)}
  end

  @doc """
  Sets the error format style.

  ## Parameters
    * `builder` - The builder instance
    * `format` - The error format (:detailed, :simple, :minimal)

  ## Returns
    * Updated builder instance

  ## Examples

      iex> builder |> Exdantic.Config.Builder.error_format(:simple)
      %Exdantic.Config.Builder{opts: %{error_format: :simple}}
  """
  @spec error_format(t(), Exdantic.Config.error_format()) :: t()
  def error_format(%__MODULE__{} = builder, format)
      when format in [:detailed, :simple, :minimal] do
    %{builder | opts: Map.put(builder.opts, :error_format, format)}
  end

  @doc """
  Convenience method to set detailed error format.

  ## Parameters
    * `builder` - The builder instance

  ## Returns
    * Updated builder instance

  ## Examples

      iex> builder |> Exdantic.Config.Builder.detailed_errors()
      %Exdantic.Config.Builder{opts: %{error_format: :detailed}}
  """
  def detailed_errors(%__MODULE__{} = builder) do
    error_format(builder, :detailed)
  end

  @doc """
  Convenience method to set simple error format.

  ## Parameters
    * `builder` - The builder instance

  ## Returns
    * Updated builder instance

  ## Examples

      iex> builder |> Exdantic.Config.Builder.simple_errors()
      %Exdantic.Config.Builder{opts: %{error_format: :simple}}
  """
  def simple_errors(%__MODULE__{} = builder) do
    error_format(builder, :simple)
  end

  @doc """
  Sets case sensitivity for field names.

  ## Parameters
    * `builder` - The builder instance
    * `enabled` - Whether to enable case sensitivity (default: true)

  ## Returns
    * Updated builder instance

  ## Examples

      iex> builder |> Exdantic.Config.Builder.case_sensitive()
      %Exdantic.Config.Builder{opts: %{case_sensitive: true}}

      iex> builder |> Exdantic.Config.Builder.case_sensitive(false)
      %Exdantic.Config.Builder{opts: %{case_sensitive: false}}
  """
  @spec case_sensitive(t(), boolean()) :: t()
  def case_sensitive(%__MODULE__{} = builder, enabled \\ true) do
    %{builder | opts: Map.put(builder.opts, :case_sensitive, enabled)}
  end

  @doc """
  Convenience method to disable case sensitivity.

  ## Parameters
    * `builder` - The builder instance

  ## Returns
    * Updated builder instance

  ## Examples

      iex> builder |> Exdantic.Config.Builder.case_insensitive()
      %Exdantic.Config.Builder{opts: %{case_sensitive: false}}
  """
  def case_insensitive(%__MODULE__{} = builder) do
    case_sensitive(builder, false)
  end

  @doc """
  Sets the maximum length for anyOf unions in JSON Schema.

  ## Parameters
    * `builder` - The builder instance
    * `max_length` - Maximum union length

  ## Returns
    * Updated builder instance

  ## Examples

      iex> builder |> Exdantic.Config.Builder.max_union_length(3)
      %Exdantic.Config.Builder{opts: %{max_anyof_union_len: 3}}
  """
  @spec max_union_length(t(), non_neg_integer()) :: t()
  def max_union_length(%__MODULE__{} = builder, max_length)
      when is_integer(max_length) and max_length > 0 do
    %{builder | opts: Map.put(builder.opts, :max_anyof_union_len, max_length)}
  end

  @doc """
  Sets a custom title generator function.

  ## Parameters
    * `builder` - The builder instance
    * `generator_fn` - Function that takes a field name and returns a title

  ## Returns
    * Updated builder instance

  ## Examples

      iex> title_fn = fn field -> field |> Atom.to_string() |> String.capitalize() end
      iex> builder |> Exdantic.Config.Builder.title_generator(title_fn)
      %Exdantic.Config.Builder{opts: %{title_generator: #Function<...>}}
  """
  @spec title_generator(t(), (atom() -> String.t())) :: t()
  def title_generator(%__MODULE__{} = builder, generator_fn) when is_function(generator_fn, 1) do
    %{builder | opts: Map.put(builder.opts, :title_generator, generator_fn)}
  end

  @doc """
  Sets a custom description generator function.

  ## Parameters
    * `builder` - The builder instance
    * `generator_fn` - Function that takes a field name and returns a description

  ## Returns
    * Updated builder instance

  ## Examples

      iex> desc_fn = fn field -> "Field for " <> Atom.to_string(field) end
      iex> builder |> Exdantic.Config.Builder.description_generator(desc_fn)
      %Exdantic.Config.Builder{opts: %{description_generator: #Function<...>}}
  """
  @spec description_generator(t(), (atom() -> String.t())) :: t()
  def description_generator(%__MODULE__{} = builder, generator_fn)
      when is_function(generator_fn, 1) do
    %{builder | opts: Map.put(builder.opts, :description_generator, generator_fn)}
  end

  @doc """
  Sets whether to use enum values instead of names.

  ## Parameters
    * `builder` - The builder instance
    * `enabled` - Whether to use enum values (default: true)

  ## Returns
    * Updated builder instance

  ## Examples

      iex> builder |> Exdantic.Config.Builder.use_enum_values()
      %Exdantic.Config.Builder{opts: %{use_enum_values: true}}
  """
  @spec use_enum_values(t(), boolean()) :: t()
  def use_enum_values(%__MODULE__{} = builder, enabled \\ true) do
    %{builder | opts: Map.put(builder.opts, :use_enum_values, enabled)}
  end

  @doc """
  Merges additional options into the builder.

  ## Parameters
    * `builder` - The builder instance
    * `opts` - Additional options to merge

  ## Returns
    * Updated builder instance

  ## Examples

      iex> builder |> Exdantic.Config.Builder.merge(%{strict: true, frozen: true})
      %Exdantic.Config.Builder{opts: %{strict: true, frozen: true}}
  """
  @spec merge(t(), map() | keyword()) :: t()
  def merge(%__MODULE__{} = builder, opts) do
    additional_opts =
      case opts do
        map when is_map(map) -> map
        keyword when is_list(keyword) -> Map.new(keyword)
      end

    %{builder | opts: Map.merge(builder.opts, additional_opts)}
  end

  @doc """
  Applies a preset configuration to the builder.

  ## Parameters
    * `builder` - The builder instance
    * `preset` - The preset name (same as Exdantic.Config.preset/1)

  ## Returns
    * Updated builder instance

  ## Examples

      iex> builder |> Exdantic.Config.Builder.apply_preset(:strict)
      %Exdantic.Config.Builder{opts: %{strict: true, extra: :forbid, ...}}
  """
  @spec apply_preset(t(), atom()) :: t()
  def apply_preset(%__MODULE__{} = builder, preset) do
    preset_config = Exdantic.Config.preset(preset)
    preset_opts = Map.from_struct(preset_config)

    %{builder | opts: Map.merge(builder.opts, preset_opts)}
  end

  @doc """
  Builds the final configuration from the builder.

  ## Parameters
    * `builder` - The builder instance

  ## Returns
    * Exdantic.Config struct with the configured options

  ## Examples

      iex> config = Exdantic.Config.Builder.new()
      ...> |> Exdantic.Config.Builder.strict()
      ...> |> Exdantic.Config.Builder.forbid_extra()
      ...> |> Exdantic.Config.Builder.build()
      %Exdantic.Config{strict: true, extra: :forbid, ...}
  """
  @spec build(t()) :: Exdantic.Config.t()
  def build(%__MODULE__{} = builder) do
    Exdantic.Config.create(builder.opts)
  end

  @doc """
  Validates the builder configuration before building.

  ## Parameters
    * `builder` - The builder instance

  ## Returns
    * `{:ok, config}` if valid
    * `{:error, reasons}` if invalid

  ## Examples

      iex> valid_builder = Exdantic.Config.Builder.new() |> Exdantic.Config.Builder.strict()
      iex> Exdantic.Config.Builder.validate_and_build(valid_builder)
      {:ok, %Exdantic.Config{...}}

      iex> invalid_builder = Exdantic.Config.Builder.new()
      ...> |> Exdantic.Config.Builder.strict()
      ...> |> Exdantic.Config.Builder.allow_extra()
      iex> Exdantic.Config.Builder.validate_and_build(invalid_builder)
      {:error, ["strict mode conflicts with extra: :allow"]}
  """
  @spec validate_and_build(t()) :: {:ok, Exdantic.Config.t()} | {:error, [String.t()]}
  def validate_and_build(%__MODULE__{} = builder) do
    config = build(builder)

    case Exdantic.Config.validate_config(config) do
      :ok -> {:ok, config}
      {:error, reasons} -> {:error, reasons}
    end
  end

  @doc """
  Conditionally applies a configuration based on a predicate.

  ## Parameters
    * `builder` - The builder instance
    * `condition` - Boolean condition or function that returns boolean
    * `config_fn` - Function to apply if condition is true

  ## Returns
    * Updated builder instance

  ## Examples

      iex> is_production = Application.get_env(:my_app, :env) == :prod
      iex> builder |> Exdantic.Config.Builder.when_true(is_production, &Exdantic.Config.Builder.frozen/1)
      %Exdantic.Config.Builder{...}

      iex> builder |> Exdantic.Config.Builder.when_true(true, fn b ->
      ...>   b |> Exdantic.Config.Builder.strict() |> Exdantic.Config.Builder.forbid_extra()
      ...> end)
      %Exdantic.Config.Builder{opts: %{strict: true, extra: :forbid}}
  """
  @spec when_true(t(), boolean() | (-> boolean()), (t() -> t())) :: t()
  def when_true(%__MODULE__{} = builder, condition, config_fn) when is_function(config_fn, 1) do
    should_apply =
      case condition do
        bool when is_boolean(bool) -> bool
        fun when is_function(fun, 0) -> fun.()
        _ -> false
      end

    if should_apply do
      config_fn.(builder)
    else
      builder
    end
  end

  @doc """
  Applies configuration only if a condition is false.

  ## Parameters
    * `builder` - The builder instance
    * `condition` - Boolean condition or function that returns boolean
    * `config_fn` - Function to apply if condition is false

  ## Returns
    * Updated builder instance

  ## Examples

      iex> is_development = Application.get_env(:my_app, :env) == :dev
      iex> builder |> Exdantic.Config.Builder.when_false(is_development, &Exdantic.Config.Builder.frozen/1)
      %Exdantic.Config.Builder{...}
  """
  @spec when_false(t(), boolean() | (-> boolean()), (t() -> t())) :: t()
  def when_false(%__MODULE__{} = builder, condition, config_fn) do
    negated_condition =
      case condition do
        bool when is_boolean(bool) -> not bool
        fun when is_function(fun, 0) -> not fun.()
        _ -> true
      end

    when_true(builder, negated_condition, config_fn)
  end

  @doc """
  Creates a configuration for API validation scenarios.

  ## Parameters
    * `builder` - The builder instance

  ## Returns
    * Updated builder instance with API-friendly settings

  ## Examples

      iex> builder |> Exdantic.Config.Builder.for_api()
      %Exdantic.Config.Builder{opts: %{strict: true, extra: :forbid, ...}}
  """
  def for_api(%__MODULE__{} = builder) do
    builder
    |> strict()
    |> forbid_extra()
    |> safe_coercion()
    |> validate_assignment()
    |> detailed_errors()
  end

  @doc """
  Creates a configuration for JSON Schema generation scenarios.

  ## Parameters
    * `builder` - The builder instance

  ## Returns
    * Updated builder instance with JSON Schema-friendly settings

  ## Examples

      iex> builder |> Exdantic.Config.Builder.for_json_schema()
      %Exdantic.Config.Builder{opts: %{use_enum_values: true, error_format: :minimal, ...}}
  """
  def for_json_schema(%__MODULE__{} = builder) do
    builder
    |> allow_extra()
    |> no_coercion()
    |> use_enum_values()
    |> error_format(:minimal)
    |> max_union_length(3)
  end

  @doc """
  Creates a configuration for development scenarios.

  ## Parameters
    * `builder` - The builder instance

  ## Returns
    * Updated builder instance with development-friendly settings

  ## Examples

      iex> builder |> Exdantic.Config.Builder.for_development()
      %Exdantic.Config.Builder{opts: %{strict: false, coercion: :aggressive, ...}}
  """
  def for_development(%__MODULE__{} = builder) do
    builder
    |> strict(false)
    |> allow_extra()
    |> aggressive_coercion()
    |> case_insensitive()
    |> detailed_errors()
    |> validate_assignment(false)
  end

  @doc """
  Creates a configuration for production scenarios.

  ## Parameters
    * `builder` - The builder instance

  ## Returns
    * Updated builder instance with production-ready settings

  ## Examples

      iex> builder |> Exdantic.Config.Builder.for_production()
      %Exdantic.Config.Builder{opts: %{strict: true, frozen: true, ...}}
  """
  def for_production(%__MODULE__{} = builder) do
    builder
    |> strict()
    |> forbid_extra()
    |> safe_coercion()
    |> validate_assignment()
    |> simple_errors()
    |> frozen()
  end

  @doc """
  Returns a summary of the current builder configuration.

  ## Parameters
    * `builder` - The builder instance

  ## Returns
    * Map with current configuration options

  ## Examples

      iex> builder = Exdantic.Config.Builder.new() |> Exdantic.Config.Builder.strict()
      iex> Exdantic.Config.Builder.summary(builder)
      %{options_set: [:strict], option_count: 1, ready_to_build: true}
  """
  @spec summary(t()) :: map()
  def summary(%__MODULE__{} = builder) do
    %{
      options_set: Map.keys(builder.opts),
      option_count: map_size(builder.opts),
      ready_to_build: true,
      current_options: builder.opts
    }
  end

  @doc """
  Resets the builder to an empty state.

  ## Parameters
    * `builder` - The builder instance

  ## Returns
    * Reset builder instance

  ## Examples

      iex> builder = Exdantic.Config.Builder.new() |> Exdantic.Config.Builder.strict()
      iex> reset_builder = Exdantic.Config.Builder.reset(builder)
      %Exdantic.Config.Builder{opts: %{}}
  """
  @spec reset(t()) :: t()
  def reset(%__MODULE__{}) do
    new()
  end

  @doc """
  Clones a builder instance.

  ## Parameters
    * `builder` - The builder instance to clone

  ## Returns
    * New builder instance with the same configuration

  ## Examples

      iex> original = Exdantic.Config.Builder.new() |> Exdantic.Config.Builder.strict()
      iex> cloned = Exdantic.Config.Builder.clone(original)
      %Exdantic.Config.Builder{opts: %{strict: true}}
  """
  @spec clone(t()) :: t()
  def clone(%__MODULE__{} = builder) do
    %__MODULE__{opts: Map.new(builder.opts)}
  end
end
