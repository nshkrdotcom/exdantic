defmodule Exdantic.JsonSchema do
  @moduledoc """
  A module for converting Exdantic schema definitions into JSON Schema format.
  Handles field types, metadata, references, and definitions generation.
  """
  alias Exdantic.JsonSchema.{ReferenceStore, TypeMapper}

  @type json_schema :: %{String.t() => term()}

  @doc """
  Converts an Exdantic schema module to a JSON Schema representation.

  ## Parameters
    * `schema` - The schema module to convert

  ## Returns
    * A map representing the JSON Schema

  ## Examples

      iex> defmodule TestSchema do
      ...>   use Exdantic
      ...>   schema do
      ...>     field :name, :string
      ...>   end
      ...> end
      iex> Exdantic.JsonSchema.from_schema(TestSchema)
      %{"type" => "object", "properties" => %{"name" => %{"type" => "string"}}}
  """
  @spec from_schema(module()) :: json_schema()
  def from_schema(schema) when is_atom(schema) do
    {:ok, store} = ReferenceStore.start_link()

    try do
      # First, generate the main schema
      result = generate_schema(schema, store)

      # Process any referenced schemas
      process_referenced_schemas(store)

      # Add definitions to the result
      definitions = ReferenceStore.get_definitions(store)

      if map_size(definitions) > 0 do
        Map.put(result, "definitions", definitions)
      else
        result
      end
    after
      ReferenceStore.stop(store)
    end
  end

  @spec process_referenced_schemas(pid()) :: :ok
  defp process_referenced_schemas(store) do
    # Get all references that need to be processed
    references = ReferenceStore.get_references(store)

    # Generate schemas for each reference
    Enum.each(references, fn module ->
      if not ReferenceStore.has_definition?(store, module) do
        generate_schema(module, store)
      end
    end)
  end

  @spec generate_schema(module(), pid()) :: json_schema()
  defp generate_schema(schema, store) do
    # Check if the module has the required __schema__ function
    unless function_exported?(schema, :__schema__, 1) do
      raise ArgumentError, "Module #{inspect(schema)} is not a valid Exdantic schema"
    end

    # Get schema config
    config = schema.__schema__(:config) || %{}

    # Build base schema with config
    base_schema =
      %{
        "type" => "object",
        "title" => config[:title],
        "description" => config[:description] || schema.__schema__(:description),
        "properties" => %{},
        "required" => []
      }
      |> maybe_add_additional_properties(config[:strict])
      |> Map.reject(fn {_, v} -> is_nil(v) end)

    # Get regular fields and computed fields
    fields = schema.__schema__(:fields)
    computed_fields = schema.__schema__(:computed_fields) || []

    # Process regular fields first
    schema_with_fields =
      Enum.reduce(fields, base_schema, fn {name, field_meta}, schema_acc ->
        # Add to properties
        properties = Map.get(schema_acc, "properties", %{})

        # Convert type and merge with field metadata
        field_schema =
          TypeMapper.to_json_schema(field_meta.type, store)
          |> Map.merge(convert_field_metadata(field_meta))
          |> Map.reject(fn {_, v} -> is_nil(v) end)

        updated_properties = Map.put(properties, Atom.to_string(name), field_schema)
        schema_acc = Map.put(schema_acc, "properties", updated_properties)

        # Add to required if needed
        if field_meta.required do
          required = Map.get(schema_acc, "required", [])
          Map.put(schema_acc, "required", [Atom.to_string(name) | required])
        else
          schema_acc
        end
      end)

    # Process computed fields
    schema_with_computed_fields =
      Enum.reduce(computed_fields, schema_with_fields, fn {name, computed_field_meta},
                                                          schema_acc ->
        # Add computed field to properties
        properties = Map.get(schema_acc, "properties", %{})

        # Convert computed field type and add readOnly marker
        computed_field_schema =
          TypeMapper.to_json_schema(computed_field_meta.type, store)
          |> Map.merge(convert_computed_field_metadata(computed_field_meta))
          |> Map.reject(fn {_, v} -> is_nil(v) end)

        updated_properties = Map.put(properties, Atom.to_string(name), computed_field_schema)
        Map.put(schema_acc, "properties", updated_properties)
      end)

    # Store complete schema if referenced
    if ReferenceStore.has_reference?(store, schema) do
      ReferenceStore.add_definition(store, schema, schema_with_computed_fields)
    end

    schema_with_computed_fields
  end

  @spec maybe_add_additional_properties(json_schema(), term()) :: json_schema()
  defp maybe_add_additional_properties(schema, strict) when is_boolean(strict) do
    Map.put(schema, "additionalProperties", not strict)
  end

  defp maybe_add_additional_properties(schema, _), do: schema

  @spec convert_field_metadata(Exdantic.FieldMeta.t()) :: map()
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

  @spec convert_computed_field_metadata(Exdantic.ComputedFieldMeta.t()) :: map()
  defp convert_computed_field_metadata(computed_field_meta) do
    base = %{
      "description" => computed_field_meta.description,
      # Computed fields are always read-only
      "readOnly" => true
    }

    # Handle example
    base =
      if computed_field_meta.example do
        Map.put(base, "examples", [computed_field_meta.example])
      else
        base
      end

    # Add computed field specific metadata for documentation
    base =
      Map.put(base, "x-computed-field", %{
        "function" => format_computed_field_function_reference(computed_field_meta),
        "module" => computed_field_meta.module,
        "function_name" => computed_field_meta.function_name
      })

    Map.reject(base, fn {_, v} -> is_nil(v) end)
  end

  @doc """
  Extracts computed field information from a JSON schema.

  This function can parse a JSON schema generated by Exdantic and extract
  information about computed fields from the x-computed-field metadata.

  ## Parameters
    * `json_schema` - The JSON schema to analyze

  ## Returns
    * List of computed field information maps

  ## Examples

      iex> schema = Exdantic.JsonSchema.from_schema(UserSchema)
      iex> Exdantic.JsonSchema.extract_computed_field_info(schema)
      [
        %{
          name: "full_name",
          type: %{"type" => "string"},
          function: "UserSchema.generate_full_name/1",
          readonly: true
        }
      ]
  """
  @spec extract_computed_field_info(json_schema()) :: [map()]
  def extract_computed_field_info(%{"properties" => properties}) when is_map(properties) do
    properties
    |> Enum.filter(fn {_name, field_schema} ->
      is_map(field_schema) and Map.has_key?(field_schema, "x-computed-field")
    end)
    |> Enum.map(fn {name, field_schema} ->
      computed_metadata = field_schema["x-computed-field"]

      %{
        name: name,
        type:
          field_schema |> Map.drop(["x-computed-field", "readOnly", "description", "examples"]),
        function: computed_metadata["function"],
        module: computed_metadata["module"],
        function_name: computed_metadata["function_name"],
        readonly: field_schema["readOnly"],
        description: field_schema["description"],
        examples: field_schema["examples"]
      }
    end)
  end

  def extract_computed_field_info(_), do: []

  @doc """
  Checks if a JSON schema contains computed fields.

  ## Parameters
    * `json_schema` - The JSON schema to check

  ## Returns
    * `true` if the schema contains computed fields, `false` otherwise

  ## Examples

      iex> schema = Exdantic.JsonSchema.from_schema(UserSchema)
      iex> Exdantic.JsonSchema.has_computed_fields?(schema)
      true
  """
  @spec has_computed_fields?(json_schema()) :: boolean()
  def has_computed_fields?(json_schema) do
    extract_computed_field_info(json_schema) |> length() > 0
  end

  @doc """
  Removes computed fields from a JSON schema.

  This can be useful when you want to generate a schema for input validation
  that excludes computed fields, since computed fields are output-only.

  ## Parameters
    * `json_schema` - The JSON schema to process

  ## Returns
    * JSON schema with computed fields removed

  ## Examples

      iex> schema = Exdantic.JsonSchema.from_schema(UserSchema)
      iex> input_schema = Exdantic.JsonSchema.remove_computed_fields(schema)
      # input_schema will not contain computed fields
  """
  @spec remove_computed_fields(json_schema()) :: json_schema()
  def remove_computed_fields(%{"properties" => properties} = json_schema)
      when is_map(properties) do
    filtered_properties =
      properties
      |> Enum.reject(fn {_name, field_schema} ->
        is_map(field_schema) and Map.get(field_schema, "readOnly") == true
      end)
      |> Map.new()

    # Also update required fields to remove any computed fields
    updated_required =
      case Map.get(json_schema, "required") do
        nil ->
          nil

        required when is_list(required) ->
          computed_field_names =
            properties
            |> Enum.filter(fn {_name, field_schema} ->
              is_map(field_schema) and Map.get(field_schema, "readOnly") == true
            end)
            |> Enum.map(fn {name, _} -> name end)

          Enum.reject(required, fn field_name -> field_name in computed_field_names end)
      end

    json_schema
    |> Map.put("properties", filtered_properties)
    |> maybe_update_required(updated_required)
  end

  def remove_computed_fields(json_schema), do: json_schema

  # Helper function to update required fields
  @spec maybe_update_required(json_schema(), [String.t()] | nil) :: json_schema()
  defp maybe_update_required(schema, nil), do: schema
  defp maybe_update_required(schema, []), do: Map.delete(schema, "required")
  defp maybe_update_required(schema, required), do: Map.put(schema, "required", required)

  # Helper function for enhanced computed field function reference formatting
  @spec format_computed_field_function_reference(Exdantic.ComputedFieldMeta.t()) :: String.t()
  defp format_computed_field_function_reference(computed_field_meta) do
    module_name =
      computed_field_meta.module
      |> to_string()
      |> String.replace_prefix("Elixir.", "")

    function_str = Atom.to_string(computed_field_meta.function_name)

    # Check if it's a generated function name
    if String.starts_with?(function_str, "__generated_computed_field_") do
      field_name = computed_field_meta.name
      "#{module_name}.<anonymous computed field :#{field_name}>/1"
    else
      "#{module_name}.#{function_str}/1"
    end
  end
end
