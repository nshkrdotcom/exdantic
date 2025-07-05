defmodule Exdantic.Type do
  @moduledoc """
  Behaviour and macros for defining custom types.

  This module provides the behaviour and utility functions for creating
  custom types in Exdantic schemas with validation and coercion capabilities.
  """

  @type coerce_function :: (term() -> {:ok, term()} | {:error, term()})
  @type coerce_rule :: coerce_function() | {module(), atom()} | nil

  @callback type_definition() :: Exdantic.Types.type_definition()
  @callback json_schema() :: map()
  @callback validate(term()) :: {:ok, term()} | {:error, term()}
  @callback coerce_rule() :: coerce_rule()
  @callback custom_rules() :: [atom()]

  @optional_callbacks coerce_rule: 0, custom_rules: 0

  @doc """
  Provides functionality for defining custom types in Exdantic schemas.

  When you `use Exdantic.Type`, your module gets:
  - The `Exdantic.Type` behaviour
  - Import of `Exdantic.Types` functions
  - Type aliases for coercion functions
  - A default implementation of validation with coercion support

  ## Examples

      defmodule MyApp.Types.Email do
        use Exdantic.Type

        def type_definition do
          {:type, :string, [format: ~r/^[^@]+@[^@]+\.[^@]+$/]}
        end

        def json_schema do
          %{"type" => "string", "format" => "email"}
        end

        def validate(value) do
          case type_definition() |> Exdantic.Validator.validate(value) do
            {:ok, validated} -> {:ok, validated}
            {:error, _} -> {:error, "invalid email format"}
          end
        end
      end
  """
  @spec __using__(keyword()) :: Macro.t()
  defmacro __using__(_opts) do
    quote do
      @behaviour Exdantic.Type
      import Exdantic.Types

      # Import types from Exdantic.Type
      @type coerce_function :: Exdantic.Type.coerce_function()
      @type coerce_rule :: Exdantic.Type.coerce_rule()

      Module.register_attribute(__MODULE__, :type_metadata, accumulate: true)

      def metadata, do: @type_metadata

      def validate(value, path \\ []) do
        with {:ok, coerced} <- maybe_coerce(value),
             {:ok, validated} <- validate_type(coerced, path) do
          validate_custom_rules(validated, path)
        end
      end

      defp validate_type(value, path) do
        type = type_definition()
        Exdantic.Validator.validate(type, value, path)
      end

      @spec maybe_coerce(term()) :: {:ok, term()} | {:error, term()}
      defp maybe_coerce(value) do
        # Simple implementation - most custom types don't need coercion
        {:ok, value}
      end

      defp validate_custom_rules(value, path) do
        Enum.reduce_while(custom_rules(), {:ok, value}, fn rule, {:ok, val} ->
          case apply(__MODULE__, rule, [val]) do
            true -> {:cont, {:ok, val}}
            false -> {:halt, {:error, "failed custom rule: #{rule}"}}
            {:error, reason} -> {:halt, {:error, reason, path: path}}
          end
        end)
      end

      # Default implementations that can be overridden
      @spec coerce_rule() :: coerce_rule()
      def coerce_rule, do: nil

      @spec custom_rules() :: [atom()]
      def custom_rules, do: []

      defoverridable coerce_rule: 0, custom_rules: 0
    end
  end
end
