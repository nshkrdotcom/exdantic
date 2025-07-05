defmodule Exdantic.JsonSchema.TypeMapper do
  @moduledoc """
  Converts Exdantic type definitions to JSON Schema type definitions.

  This module handles the conversion between Exdantic's internal type system
  and JSON Schema representations, including complex types and constraints.
  """

  alias Exdantic.JsonSchema.ReferenceStore

  @spec to_json_schema(Exdantic.Types.type_definition() | module(), pid() | nil) :: map()
  def to_json_schema(type, store \\ nil)

  def to_json_schema({:ref, _} = type, store), do: handle_schema_reference(type, store)

  def to_json_schema(type, store) when is_atom(type) do
    cond do
      schema_module?(type) ->
        handle_schema_reference({:ref, type}, store)

      custom_type?(type) ->
        apply_type_module(type)

      true ->
        normalized_type = normalize_type(type)
        convert_normalized_type(normalized_type, store)
    end
  end

  def to_json_schema({:__aliases__, _, _} = type, store) do
    module = Macro.expand(type, __ENV__)

    if schema_module?(module) do
      handle_schema_reference({:ref, module}, store)
    else
      apply_type_module(module)
    end
  end

  def to_json_schema({:tuple, _} = type, store) do
    # Handle tuple type directly since it doesn't fit the standard normalization pattern
    convert_type(type, store)
  end

  def to_json_schema(type, store) do
    normalized_type = normalize_type(type)
    convert_normalized_type(normalized_type, store)
  end

  @spec schema_module?(module()) :: boolean()
  defp schema_module?(module) when is_atom(module) do
    Code.ensure_loaded?(module) and function_exported?(module, :__schema__, 1)
  end

  @spec handle_schema_reference({:ref, atom()}, pid()) :: %{String.t() => String.t()}
  defp handle_schema_reference({:ref, module}, store) when is_atom(module) do
    if schema_module?(module) do
      if store do
        ReferenceStore.add_reference(store, module)
        %{"$ref" => ReferenceStore.ref_path(module)}
      else
        raise "Schema reference #{inspect(module)} requires a reference store"
      end
    else
      raise ArgumentError, "Module #{inspect(module)} is not a valid Exdantic schema"
    end
  end

  @spec apply_type_module(module()) :: map()
  defp apply_type_module(module) do
    if custom_type?(module) do
      module.json_schema()
    else
      raise "Module #{inspect(module)} is not a valid Exdantic type"
    end
  end

  @spec custom_type?(module()) :: boolean()
  defp custom_type?(module) when is_atom(module) do
    Code.ensure_loaded?(module) and function_exported?(module, :json_schema, 0)
  end

  # Normalize type definitions
  @spec normalize_type(term()) :: Exdantic.Types.type_definition()
  defp normalize_type(type) when is_atom(type) do
    cond do
      # Check for basic types first
      type in [:string, :integer, :float, :boolean, :any, :atom, :map] ->
        {:type, type, []}

      schema_module?(type) ->
        {:ref, type}

      true ->
        {:type, type, []}
    end
  end

  defp normalize_type({:array, type}) do
    normalized =
      if is_atom(type) and schema_module?(type), do: {:ref, type}, else: normalize_type(type)

    {:array, normalized, []}
  end

  defp normalize_type({:array, type, constraints}) do
    normalized =
      if is_atom(type) and schema_module?(type), do: {:ref, type}, else: normalize_type(type)

    {:array, normalized, constraints}
  end

  defp normalize_type({:map, {key_type, value_type}}) do
    {:map, {normalize_type(key_type), normalize_type(value_type)}, []}
  end

  defp normalize_type({:union, types}) when is_list(types) do
    {:union, Enum.map(types, &normalize_type/1), []}
  end

  defp normalize_type({:tuple, types}) when is_list(types) do
    {:tuple, Enum.map(types, &normalize_type/1)}
  end

  defp normalize_type(type), do: type

  # Convert normalized types
  @spec convert_normalized_type(Exdantic.Types.type_definition(), pid() | nil) :: map()
  defp convert_normalized_type({:ref, mod}, store) when is_atom(mod) do
    if schema_module?(mod) do
      handle_schema_reference({:ref, mod}, store)
    else
      raise ArgumentError, "Invalid schema reference: #{inspect(mod)}"
    end
  end

  defp convert_normalized_type({:type, base_type, constraints} = type, store)
       when is_atom(base_type) and is_list(constraints) do
    convert_type(type, store)
  end

  defp convert_normalized_type({:array, _, _} = type, store), do: convert_type(type, store)
  defp convert_normalized_type({:map, {_, _}, _} = type, store), do: convert_type(type, store)
  defp convert_normalized_type({:union, _, _} = type, store), do: convert_type(type, store)

  defp convert_normalized_type(type, _store) do
    raise ArgumentError, "Invalid type definition: #{inspect(type)}"
  end

  # Convert type definitions to JSON Schema
  @spec convert_type(
          Exdantic.Types.type_definition() | {:tuple, [Exdantic.Types.type_definition()]},
          pid() | nil
        ) :: map()
  defp convert_type({:type, base_type, constraints}, _store)
       when base_type in [:string, :integer, :float, :boolean, :atom, :any, :map] do
    map_basic_type(base_type)
    |> apply_constraints(constraints)
  end

  defp convert_type({:type, base_type, _constraints}, store) when is_atom(base_type) do
    cond do
      schema_module?(base_type) -> handle_schema_reference({:ref, base_type}, store)
      custom_type?(base_type) -> apply_type_module(base_type)
      true -> raise "Module #{inspect(base_type)} is not a valid Exdantic type"
    end
  end

  defp convert_type({:array, inner_type, constraints}, store) do
    map_array_type(inner_type, constraints, store)
  end

  defp convert_type({:map, {key_type, value_type}, constraints}, store) do
    map_map_type(key_type, value_type, constraints, store)
  end

  defp convert_type({:union, types, constraints}, store) do
    map_union_type(types, constraints, store)
  end

  defp convert_type({:tuple, types}, store) do
    map_tuple_type(types, store)
  end

  # NOTE: All valid patterns for convert_type/2 are explicitly handled below.
  # If you add a new type, add a new function head for it here.
  # Unhandled patterns will raise a FunctionClauseError at runtime, making issues obvious during testing.

  # Basic type mapping
  @spec map_basic_type(:string | :integer | :float | :boolean | :atom | :any | :map) :: %{
          optional(String.t()) => String.t()
        }
  defp map_basic_type(:string), do: %{"type" => "string"}
  defp map_basic_type(:integer), do: %{"type" => "integer"}
  defp map_basic_type(:float), do: %{"type" => "number"}
  defp map_basic_type(:boolean), do: %{"type" => "boolean"}

  defp map_basic_type(:atom),
    do: %{"type" => "string", "description" => "Atom value (represented as string in JSON)"}

  defp map_basic_type(:any), do: %{}
  defp map_basic_type(:map), do: %{"type" => "object"}

  # Array type mapping
  @spec map_array_type(Exdantic.Types.type_definition(), [term()], pid() | nil) :: map()
  defp map_array_type(inner_type, constraints, store) do
    base = %{
      "type" => "array",
      "items" => to_json_schema(inner_type, store)
    }

    apply_constraints(base, constraints)
  end

  # Map type mapping
  @spec map_map_type(
          Exdantic.Types.type_definition(),
          Exdantic.Types.type_definition(),
          [term()],
          pid() | nil
        ) :: map()
  defp map_map_type(_key_type, value_type, constraints, store) do
    base = %{
      "type" => "object",
      "additionalProperties" => to_json_schema(value_type, store)
    }

    apply_constraints(base, constraints)
  end

  # Union type mapping
  @spec map_union_type([Exdantic.Types.type_definition()], [term()], pid() | nil) :: map()
  defp map_union_type(types, constraints, store) do
    base = %{
      "oneOf" => Enum.map(types, &to_json_schema(&1, store))
    }

    apply_constraints(base, constraints)
  end

  # Tuple type mapping
  @spec map_tuple_type([Exdantic.Types.type_definition()], pid() | nil) :: map()
  defp map_tuple_type(types, store) do
    %{
      "type" => "array",
      "items" => false,
      "prefixItems" => Enum.map(types, &to_json_schema(&1, store)),
      "minItems" => length(types),
      "maxItems" => length(types)
    }
  end

  # Constraint mapping
  @spec apply_constraints(map(), [term()]) :: map()
  defp apply_constraints(schema, constraints) do
    Enum.reduce(constraints, schema, fn
      {:min_length, value}, acc -> Map.put(acc, "minLength", value)
      {:max_length, value}, acc -> Map.put(acc, "maxLength", value)
      {:min_items, value}, acc -> Map.put(acc, "minItems", value)
      {:max_items, value}, acc -> Map.put(acc, "maxItems", value)
      {:gt, value}, acc -> Map.put(acc, "exclusiveMinimum", value)
      {:lt, value}, acc -> Map.put(acc, "exclusiveMaximum", value)
      {:gteq, value}, acc -> Map.put(acc, "minimum", value)
      {:lteq, value}, acc -> Map.put(acc, "maximum", value)
      {:format, %Regex{} = regex}, acc -> Map.put(acc, "pattern", Regex.source(regex))
      _, acc -> acc
    end)
  end
end
