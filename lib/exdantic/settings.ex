defmodule Exdantic.Settings do
  @moduledoc """
  Env-based settings loader for Exdantic schemas.

  This module builds schema input from environment variables and explicit input,
  then delegates validation to the existing Exdantic validation pipeline.

  v1 behavior:
  - Field names derive env keys as `snake_case -> UPPER_SNAKE`, joined by
    `env_nested_delimiter` (default `"__"`), with `env_prefix` prepended.
  - Field override `extra: %{"env" => "KEY"}` is absolute; prefix is not applied.
    If both override and derived key exist, override wins.
  - Structured values (`array`, maps/objects, nested schema refs) are JSON-only.
  - Union decoding is conservative: JSON is attempted only for JSON-like strings
    (`{` or `[`) when the union includes structured members; otherwise raw strings
    are passed to validation.
  - Exploded nested env keys do not address arrays in v1 (`APP_ITEMS__0` is ignored).
  """

  alias Exdantic.Settings.{DeepMerge, Env, Loader, NormalizeKeys}
  alias Exdantic.{StructValidator, ValidationError}

  @type load_option ::
          {:input, map()}
          | {:env, map()}
          | {:env_prefix, String.t()}
          | {:env_nested_delimiter, String.t()}
          | {:case_sensitive, boolean()}
          | {:ignore_empty, boolean()}
          | {:allow_atoms, false | :existing}
          | {:bool_numeric, boolean()}

  @spec load(module(), [load_option()]) ::
          {:ok, map() | struct()} | {:error, [Exdantic.Error.t()]}
  def load(schema_module, opts \\ []) when is_atom(schema_module) do
    with :ok <- ensure_schema_module(schema_module),
         {:ok, env_map} <-
           Env.normalize_env_map(
             resolve_env(opts),
             Keyword.get(opts, :case_sensitive, false)
           ),
         {:ok, env_values} <-
           Loader.load_env_values(schema_module, env_map, opts) do
      input = Keyword.get(opts, :input, %{})

      merged =
        env_values
        |> DeepMerge.deep_merge(input)
        |> then(&NormalizeKeys.normalize_for_schema(schema_module, &1))

      StructValidator.validate_schema(schema_module, merged)
    end
  end

  @spec load!(module(), [load_option()]) :: map() | struct()
  def load!(schema_module, opts \\ []) do
    case load(schema_module, opts) do
      {:ok, result} -> result
      {:error, errors} -> raise ValidationError, errors: errors
    end
  end

  @spec from_system_env(module(), [load_option()]) ::
          {:ok, map() | struct()} | {:error, [Exdantic.Error.t()]}
  def from_system_env(schema_module, opts \\ []) do
    load(schema_module, Keyword.put(opts, :env, System.get_env()))
  end

  defp resolve_env(opts) do
    case Keyword.get(opts, :env, System.get_env()) do
      map when is_map(map) -> map
      _ -> %{}
    end
  end

  defp ensure_schema_module(schema_module) do
    if Code.ensure_loaded?(schema_module) and function_exported?(schema_module, :__schema__, 1) do
      :ok
    else
      {:error,
       [
         Exdantic.Error.new(
           [],
           :type,
           "expected Exdantic schema module, got #{inspect(schema_module)}"
         )
       ]}
    end
  end
end
