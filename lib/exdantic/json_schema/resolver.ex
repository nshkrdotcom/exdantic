defmodule Exdantic.JsonSchema.Resolver do
  @moduledoc """
  Advanced JSON schema reference resolution and manipulation.

  This module provides functionality for resolving $ref entries, flattening
  nested schemas, and enforcing structured output requirements for various
  LLM providers (OpenAI, Anthropic, etc.).
  """

  @type schema :: map()
  @type resolution_options :: [
          max_depth: non_neg_integer(),
          preserve_titles: boolean(),
          preserve_descriptions: boolean()
        ]

  @doc """
  Recursively resolves all $ref entries in a schema.

  ## Parameters
    * `schema` - The JSON schema to resolve references in
    * `opts` - Resolution options

  ## Options
    * `:max_depth` - Maximum resolution depth to prevent infinite recursion (default: 10)
    * `:preserve_titles` - Keep original titles when resolving (default: true)
    * `:preserve_descriptions` - Keep original descriptions when resolving (default: true)

  ## Returns
    * Resolved JSON schema with all references expanded

  ## Examples

      iex> schema = %{
      ...>   "type" => "object",
      ...>   "properties" => %{
      ...>     "user" => %{"$ref" => "#/definitions/User"}
      ...>   },
      ...>   "definitions" => %{
      ...>     "User" => %{"type" => "object", "properties" => %{"name" => %{"type" => "string"}}}
      ...>   }
      ...> }
      iex> Exdantic.JsonSchema.Resolver.resolve_references(schema)
      %{
        "type" => "object",
        "properties" => %{
          "user" => %{"type" => "object", "properties" => %{"name" => %{"type" => "string"}}}
        }
      }
  """
  @spec resolve_references(schema(), resolution_options()) :: schema()
  def resolve_references(schema, opts \\ []) do
    max_depth = Keyword.get(opts, :max_depth, 10)
    preserve_titles = Keyword.get(opts, :preserve_titles, true)
    preserve_descriptions = Keyword.get(opts, :preserve_descriptions, true)

    definitions = extract_definitions(schema)

    context = %{
      definitions: definitions,
      max_depth: max_depth,
      preserve_titles: preserve_titles,
      preserve_descriptions: preserve_descriptions,
      visited: MapSet.new()
    }

    resolve_schema_part(schema, context, 0)
    |> remove_definitions()
  end

  @doc """
  Flattens nested schemas by expanding all references inline.

  This is useful for LLM providers that don't support complex reference structures.

  ## Parameters
    * `schema` - The JSON schema to flatten
    * `opts` - Flattening options

  ## Options
    * `:max_depth` - Maximum flattening depth (default: 5)
    * `:inline_simple_refs` - Inline simple type references (default: true)
    * `:preserve_complex_refs` - Keep complex object references as-is (default: false)

  ## Returns
    * Flattened JSON schema

  ## Examples

      iex> schema = %{
      ...>   "type" => "object",
      ...>   "properties" => %{
      ...>     "items" => %{
      ...>       "type" => "array",
      ...>       "items" => %{"$ref" => "#/definitions/Item"}
      ...>     }
      ...>   },
      ...>   "definitions" => %{
      ...>     "Item" => %{"type" => "string", "minLength" => 1}
      ...>   }
      ...> }
      iex> Exdantic.JsonSchema.Resolver.flatten_schema(schema)
      %{
        "type" => "object",
        "properties" => %{
          "items" => %{
            "type" => "array",
            "items" => %{"type" => "string", "minLength" => 1}
          }
        }
      }
  """
  @spec flatten_schema(schema(), keyword()) :: schema()
  def flatten_schema(schema, opts \\ []) do
    max_depth = Keyword.get(opts, :max_depth, 5)
    inline_simple_refs = Keyword.get(opts, :inline_simple_refs, true)
    preserve_complex_refs = Keyword.get(opts, :preserve_complex_refs, false)

    resolve_opts = [
      max_depth: max_depth,
      preserve_titles: false,
      preserve_descriptions: true
    ]

    resolved = resolve_references(schema, resolve_opts)

    if inline_simple_refs do
      inline_simple_types(resolved, preserve_complex_refs)
    else
      resolved
    end
  end

  @doc """
  Enforces structured output requirements for specific LLM providers.

  ## Parameters
    * `schema` - The JSON schema to enforce requirements on
    * `opts` - Provider-specific options

  ## Options
    * `:provider` - Target provider (:openai, :anthropic, :generic) (default: :generic)
    * `:remove_unsupported` - Remove unsupported features (default: true)
    * `:add_required_fields` - Add required fields for provider (default: true)

  ## Returns
    * JSON schema compatible with the specified provider

  ## Examples

      iex> schema = %{"type" => "object", "additionalProperties" => true}
      iex> Exdantic.JsonSchema.Resolver.enforce_structured_output(schema, provider: :openai)
      %{"type" => "object", "additionalProperties" => false}
  """
  @spec enforce_structured_output(schema(), keyword()) :: schema()
  def enforce_structured_output(schema, opts \\ []) do
    provider = Keyword.get(opts, :provider, :generic)
    remove_unsupported = Keyword.get(opts, :remove_unsupported, true)
    add_required_fields = Keyword.get(opts, :add_required_fields, true)

    schema
    |> apply_provider_rules(provider, remove_unsupported)
    |> maybe_add_required_fields(provider, add_required_fields)
    |> validate_structured_output(provider)
  end

  @doc """
  Optimizes a JSON schema for better LLM performance.

  ## Parameters
    * `schema` - The JSON schema to optimize
    * `opts` - Optimization options

  ## Options
    * `:remove_descriptions` - Remove verbose descriptions (default: false)
    * `:simplify_unions` - Simplify complex union types (default: true)
    * `:max_properties` - Maximum properties per object (default: nil)

  ## Returns
    * Optimized JSON schema

  ## Examples

      iex> schema = %{"type" => "object", "properties" => %{"a" => %{"type" => "string", "description" => "very long description..."}}}
      iex> Exdantic.JsonSchema.Resolver.optimize_for_llm(schema, remove_descriptions: true)
      %{"type" => "object", "properties" => %{"a" => %{"type" => "string"}}}
  """
  @spec optimize_for_llm(schema(), keyword()) :: schema()
  def optimize_for_llm(schema, opts \\ []) do
    remove_descriptions = Keyword.get(opts, :remove_descriptions, false)
    simplify_unions = Keyword.get(opts, :simplify_unions, true)
    max_properties = Keyword.get(opts, :max_properties)

    schema
    |> maybe_remove_descriptions(remove_descriptions)
    |> maybe_simplify_unions(simplify_unions)
    |> maybe_limit_properties(max_properties)
  end

  # Private helper functions

  @spec extract_definitions(schema()) :: map()
  defp extract_definitions(schema) do
    Map.get(schema, "definitions", %{})
    |> Map.merge(Map.get(schema, "$defs", %{}))
  end

  @spec resolve_schema_part(schema(), map(), non_neg_integer()) :: schema()
  defp resolve_schema_part(schema, context, depth) when depth > context.max_depth do
    # Prevent infinite recursion
    schema
  end

  defp resolve_schema_part(%{"$ref" => ref} = schema, context, depth) do
    case resolve_reference(ref, context, depth + 1) do
      {:ok, resolved} ->
        # Merge any additional properties from the reference
        additional_props = Map.delete(schema, "$ref")
        merge_schema_properties(resolved, additional_props, context)

      {:error, _} ->
        # Keep original if resolution fails
        schema
    end
  end

  defp resolve_schema_part(
         %{"type" => "object", "properties" => properties} = schema,
         context,
         depth
       ) do
    resolved_properties =
      properties
      |> Enum.map(fn {key, prop_schema} ->
        {key, resolve_schema_part(prop_schema, context, depth + 1)}
      end)
      |> Map.new()

    %{schema | "properties" => resolved_properties}
  end

  defp resolve_schema_part(%{"type" => "array", "items" => items} = schema, context, depth) do
    resolved_items = resolve_schema_part(items, context, depth + 1)
    %{schema | "items" => resolved_items}
  end

  defp resolve_schema_part(%{"oneOf" => schemas} = schema, context, depth) do
    resolved_schemas =
      Enum.map(schemas, fn s -> resolve_schema_part(s, context, depth + 1) end)

    %{schema | "oneOf" => resolved_schemas}
  end

  defp resolve_schema_part(%{"anyOf" => schemas} = schema, context, depth) do
    resolved_schemas =
      Enum.map(schemas, fn s -> resolve_schema_part(s, context, depth + 1) end)

    %{schema | "anyOf" => resolved_schemas}
  end

  defp resolve_schema_part(%{"allOf" => schemas} = schema, context, depth) do
    resolved_schemas =
      Enum.map(schemas, fn s -> resolve_schema_part(s, context, depth + 1) end)

    %{schema | "allOf" => resolved_schemas}
  end

  defp resolve_schema_part(schema, _context, _depth) when is_map(schema) do
    # Base case: return schema as-is
    schema
  end

  defp resolve_schema_part(schema, _context, _depth) do
    # Handle non-map schemas
    schema
  end

  @spec resolve_reference(String.t(), map(), non_neg_integer()) ::
          {:ok, schema()} | {:error, String.t()}
  defp resolve_reference("#/definitions/" <> def_name, context, depth) do
    case Map.get(context.definitions, def_name) do
      nil ->
        {:error, "Definition not found: #{def_name}"}

      definition ->
        if MapSet.member?(context.visited, def_name) do
          {:error, "Circular reference detected: #{def_name}"}
        else
          visited_context = %{context | visited: MapSet.put(context.visited, def_name)}
          resolved = resolve_schema_part(definition, visited_context, depth)
          {:ok, resolved}
        end
    end
  end

  defp resolve_reference("#/$defs/" <> def_name, context, depth) do
    resolve_reference("#/definitions/#{def_name}", context, depth)
  end

  defp resolve_reference(ref, _context, _depth) do
    {:error, "Unsupported reference format: #{ref}"}
  end

  defp merge_schema_properties(resolved, additional_props, context) do
    resolved
    |> merge_if_preserve_titles(additional_props, context)
    |> merge_if_preserve_descriptions(additional_props, context)
  end

  defp merge_if_preserve_titles(schema, additional_props, context) do
    if context.preserve_titles and Map.has_key?(additional_props, "title") do
      Map.put(schema, "title", additional_props["title"])
    else
      schema
    end
  end

  defp merge_if_preserve_descriptions(schema, additional_props, context) do
    if context.preserve_descriptions and Map.has_key?(additional_props, "description") do
      Map.put(schema, "description", additional_props["description"])
    else
      schema
    end
  end

  @spec remove_definitions(schema()) :: schema()
  defp remove_definitions(schema) do
    schema
    |> Map.delete("definitions")
    |> Map.delete("$defs")
  end

  @spec inline_simple_types(schema(), boolean()) :: schema()
  defp inline_simple_types(
         %{"type" => "object", "properties" => properties} = schema,
         preserve_complex
       ) do
    inlined_properties =
      properties
      |> Enum.map(fn {key, prop_schema} ->
        {key, inline_simple_types(prop_schema, preserve_complex)}
      end)
      |> Map.new()

    %{schema | "properties" => inlined_properties}
  end

  defp inline_simple_types(%{"type" => "array", "items" => items} = schema, preserve_complex) do
    %{schema | "items" => inline_simple_types(items, preserve_complex)}
  end

  defp inline_simple_types(%{"oneOf" => schemas} = schema, preserve_complex) do
    inlined_schemas = Enum.map(schemas, &inline_simple_types(&1, preserve_complex))
    %{schema | "oneOf" => inlined_schemas}
  end

  defp inline_simple_types(schema, _preserve_complex) do
    schema
  end

  @spec apply_provider_rules(schema(), atom(), boolean()) :: schema()
  defp apply_provider_rules(schema, :openai, remove_unsupported) do
    schema
    |> maybe_remove_additional_properties_true(remove_unsupported)
    |> maybe_remove_unsupported_formats(remove_unsupported, [:date, :time, :email])
    |> ensure_object_has_properties()
  end

  defp apply_provider_rules(schema, :anthropic, remove_unsupported) do
    schema
    |> maybe_set_additional_properties_false_anthropic(remove_unsupported)
    |> maybe_remove_unsupported_formats(remove_unsupported, [:uri, :uuid])
    |> ensure_required_array_exists()
  end

  defp apply_provider_rules(schema, :generic, _remove_unsupported) do
    schema
  end

  defp apply_provider_rules(schema, _provider, _remove_unsupported) do
    schema
  end

  @spec maybe_remove_additional_properties_true(schema(), boolean()) :: schema()
  defp maybe_remove_additional_properties_true(schema, true) do
    case Map.get(schema, "additionalProperties") do
      true -> Map.put(schema, "additionalProperties", false)
      _ -> schema
    end
  end

  defp maybe_remove_additional_properties_true(schema, false), do: schema

  @spec maybe_set_additional_properties_false_anthropic(schema(), boolean()) :: schema()
  defp maybe_set_additional_properties_false_anthropic(schema, true) do
    case Map.get(schema, "additionalProperties") do
      nil -> schema
      _ -> Map.put(schema, "additionalProperties", false)
    end
  end

  defp maybe_set_additional_properties_false_anthropic(schema, false), do: schema

  @spec maybe_remove_unsupported_formats(schema(), boolean(), [atom()]) :: schema()
  defp maybe_remove_unsupported_formats(schema, true, unsupported_formats) do
    case Map.get(schema, "format") do
      format when is_binary(format) ->
        if String.to_atom(format) in unsupported_formats do
          Map.delete(schema, "format")
        else
          schema
        end

      _ ->
        schema
    end
    |> remove_formats_recursively(unsupported_formats)
  end

  defp maybe_remove_unsupported_formats(schema, false, _), do: schema

  defp remove_formats_recursively(
         %{"type" => "object", "properties" => properties} = schema,
         unsupported
       ) do
    cleaned_properties =
      properties
      |> Enum.map(fn {key, prop_schema} ->
        {key, maybe_remove_unsupported_formats(prop_schema, true, unsupported)}
      end)
      |> Map.new()

    %{schema | "properties" => cleaned_properties}
  end

  defp remove_formats_recursively(%{"type" => "array", "items" => items} = schema, unsupported) do
    %{schema | "items" => maybe_remove_unsupported_formats(items, true, unsupported)}
  end

  defp remove_formats_recursively(schema, _unsupported), do: schema

  @spec ensure_object_has_properties(schema()) :: schema()
  defp ensure_object_has_properties(%{"type" => "object"} = schema) do
    if Map.has_key?(schema, "properties") do
      schema
    else
      Map.put(schema, "properties", %{})
    end
  end

  defp ensure_object_has_properties(schema), do: schema

  @spec ensure_required_array_exists(schema()) :: schema()
  defp ensure_required_array_exists(%{"type" => "object"} = schema) do
    if Map.has_key?(schema, "required") do
      schema
    else
      Map.put(schema, "required", [])
    end
  end

  defp ensure_required_array_exists(schema), do: schema

  @spec maybe_add_required_fields(schema(), atom(), boolean()) :: schema()
  defp maybe_add_required_fields(schema, :openai, true) do
    # OpenAI requires specific structure for function calling
    case Map.get(schema, "type") do
      "object" ->
        schema
        |> Map.put_new("additionalProperties", false)
        |> ensure_object_has_properties()

      _ ->
        schema
    end
  end

  defp maybe_add_required_fields(schema, :anthropic, true) do
    # Anthropic has specific requirements for tool use
    case Map.get(schema, "type") do
      "object" ->
        schema
        |> Map.put_new("additionalProperties", false)
        |> ensure_required_array_exists()

      _ ->
        schema
    end
  end

  defp maybe_add_required_fields(schema, _provider, _add_required) do
    schema
  end

  @spec validate_structured_output(schema(), atom()) :: schema()
  defp validate_structured_output(schema, provider) do
    case validate_schema_constraints(schema, provider) do
      {:ok, validated_schema} -> validated_schema
      # Return original if validation fails
      {:error, _reason} -> schema
    end
  end

  @spec validate_schema_constraints(schema(), atom()) :: {:ok, schema()} | {:error, String.t()}
  defp validate_schema_constraints(%{"type" => "object"} = schema, :openai) do
    # OpenAI specific validations
    cond do
      Map.get(schema, "additionalProperties", false) == true ->
        {:error, "OpenAI does not support additionalProperties: true"}

      not Map.has_key?(schema, "properties") ->
        {:error, "OpenAI requires object schemas to have properties"}

      true ->
        {:ok, schema}
    end
  end

  defp validate_schema_constraints(%{"type" => "array", "items" => items} = schema, provider) do
    case validate_schema_constraints(items, provider) do
      {:ok, validated_items} -> {:ok, %{schema | "items" => validated_items}}
      {:error, reason} -> {:error, reason}
    end
  end

  defp validate_schema_constraints(schema, _provider) do
    {:ok, schema}
  end

  @spec maybe_remove_descriptions(schema(), boolean()) :: schema()
  defp maybe_remove_descriptions(schema, true) do
    remove_descriptions_recursive(schema)
  end

  defp maybe_remove_descriptions(schema, false), do: schema

  @spec remove_descriptions_recursive(schema()) :: schema()
  defp remove_descriptions_recursive(%{"type" => "object", "properties" => properties} = schema) do
    cleaned_properties =
      properties
      |> Enum.map(fn {key, prop_schema} ->
        {key, remove_descriptions_recursive(prop_schema)}
      end)
      |> Map.new()

    schema
    |> Map.delete("description")
    |> Map.put("properties", cleaned_properties)
  end

  defp remove_descriptions_recursive(%{"type" => "array", "items" => items} = schema) do
    schema
    |> Map.delete("description")
    |> Map.put("items", remove_descriptions_recursive(items))
  end

  defp remove_descriptions_recursive(schema) when is_map(schema) do
    Map.delete(schema, "description")
  end

  defp remove_descriptions_recursive(schema), do: schema

  @spec maybe_simplify_unions(schema(), boolean()) :: schema()
  defp maybe_simplify_unions(schema, true) do
    simplify_unions_recursive(schema)
  end

  defp maybe_simplify_unions(schema, false), do: schema

  @spec simplify_unions_recursive(schema()) :: schema()
  defp simplify_unions_recursive(%{"oneOf" => schemas} = schema) when length(schemas) > 3 do
    # Simplify large unions by keeping only the most common types
    simplified = Enum.take(schemas, 3)
    %{schema | "oneOf" => simplified}
  end

  defp simplify_unions_recursive(%{"type" => "object", "properties" => properties} = schema) do
    simplified_properties =
      properties
      |> Enum.map(fn {key, prop_schema} ->
        {key, simplify_unions_recursive(prop_schema)}
      end)
      |> Map.new()

    %{schema | "properties" => simplified_properties}
  end

  defp simplify_unions_recursive(schema), do: schema

  @spec maybe_limit_properties(schema(), non_neg_integer() | nil) :: schema()
  defp maybe_limit_properties(schema, nil), do: schema

  defp maybe_limit_properties(
         %{"type" => "object", "properties" => properties} = schema,
         max_props
       )
       when map_size(properties) > max_props do
    # Keep only the first N properties (in key order)
    limited_properties =
      properties
      |> Enum.take(max_props)
      |> Map.new()

    %{schema | "properties" => limited_properties}
  end

  defp maybe_limit_properties(schema, _max_props), do: schema
end
