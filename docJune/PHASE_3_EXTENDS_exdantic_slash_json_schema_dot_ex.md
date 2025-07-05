# This code extends exdantic/json_schema.ex to support computed fields

# Add this to the existing from_schema/1 function:

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

# Update the generate_schema/2 function to include computed fields:

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

  # Process computed fields (NEW)
  schema_with_computed_fields =
    Enum.reduce(computed_fields, schema_with_fields, fn {name, computed_field_meta}, schema_acc ->
      # Add computed field to properties
      properties = Map.get(schema_acc, "properties", %{})

      # Convert computed field type and add readOnly marker
      computed_field_schema =
        TypeMapper.to_json_schema(computed_field_meta.type, store)
        |> Map.merge(convert_computed_field_metadata(computed_field_meta))
        |> Map.put("readOnly", true)  # Always mark computed fields as readOnly
        |> Map.reject(fn {_, v} -> is_nil(v) end)

      updated_properties = Map.put(properties, Atom.to_string(name), computed_field_schema)
      Map.put(schema_acc, "properties", updated_properties)

      # Note: Computed fields are never added to "required" since they're generated
    end)

  # Store complete schema if referenced
  if ReferenceStore.has_reference?(store, schema) do
    ReferenceStore.add_definition(store, schema, schema_with_computed_fields)
  end

  schema_with_computed_fields
end

# Add new function to convert computed field metadata:

@spec convert_computed_field_metadata(Exdantic.ComputedFieldMeta.t()) :: map()
defp convert_computed_field_metadata(computed_field_meta) do
  base = %{
    "description" => computed_field_meta.description,
    "readOnly" => true  # Computed fields are always read-only
  }

  # Handle examples - computed fields may have examples of expected output
  base =
    if computed_field_meta.example do
      Map.put(base, "examples", [computed_field_meta.example])
    else
      base
    end

  # Add computed field specific metadata for documentation
  base =
    Map.put(base, "x-computed-field", %{
      "function" => Exdantic.ComputedFieldMeta.function_reference(computed_field_meta),
      "module" => computed_field_meta.module,
      "function_name" => computed_field_meta.function_name
    })

  Map.reject(base, fn {_, v} -> is_nil(v) end)
end

# Update existing convert_field_metadata to distinguish from computed fields:

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

# Add helper function to get computed fields for a schema:

@spec get_computed_fields_for_schema(module()) :: [{atom(), Exdantic.ComputedFieldMeta.t()}]
defp get_computed_fields_for_schema(schema_module) do
  if function_exported?(schema_module, :__schema__, 1) do
    schema_module.__schema__(:computed_fields) || []
  else
    []
  end
end

# Add validation function for computed field JSON schema generation:

@doc """
Validates that all computed fields in a schema have valid function references.

This function checks that all computed field functions exist and are callable
before generating JSON schema, helping catch configuration errors early.

## Parameters
  * `schema` - The schema module to validate

## Returns
  * `:ok` if all computed fields are valid
  * `{:error, reasons}` if any computed fields have issues

## Examples

    iex> Exdantic.JsonSchema.validate_computed_fields(ValidSchema)
    :ok

    iex> Exdantic.JsonSchema.validate_computed_fields(InvalidSchema)
    {:error, ["Function InvalidSchema.missing_function/1 is not defined"]}
"""
@spec validate_computed_fields(module()) :: :ok | {:error, [String.t()]}
def validate_computed_fields(schema) when is_atom(schema) do
  computed_fields = get_computed_fields_for_schema(schema)
  
  errors =
    computed_fields
    |> Enum.map(fn {_name, computed_field_meta} ->
      case Exdantic.ComputedFieldMeta.validate_function(computed_field_meta) do
        :ok -> nil
        {:error, reason} -> reason
      end
    end)
    |> Enum.reject(&is_nil/1)

  case errors do
    [] -> :ok
    reasons -> {:error, reasons}
  end
end

@doc """
Generates JSON Schema with computed field validation.

This is an enhanced version of from_schema/1 that also validates computed
field function references before generating the schema.

## Parameters
  * `schema` - The schema module to convert
  * `opts` - Options for schema generation

## Options
  * `:validate_computed_fields` - Whether to validate computed field functions (default: true)
  * `:include_computed_metadata` - Whether to include x-computed-field metadata (default: true)

## Returns
  * JSON Schema map if successful
  * Raises ArgumentError if computed field validation fails

## Examples

    iex> Exdantic.JsonSchema.from_schema_validated(SchemaWithMissingFunction)
    ** (ArgumentError) Invalid computed fields: ["Function MySchema.missing_function/1 is not defined"]
"""
@spec from_schema_validated(module(), keyword()) :: json_schema()
def from_schema_validated(schema, opts \\ []) when is_atom(schema) do
  validate_computed = Keyword.get(opts, :validate_computed_fields, true)
  
  if validate_computed do
    case validate_computed_fields(schema) do
      :ok -> 
        from_schema(schema)
      {:error, reasons} -> 
        raise ArgumentError, "Invalid computed fields: #{inspect(reasons)}"
    end
  else
    from_schema(schema)
  end
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
      },
      %{
        name: "email_domain", 
        type: %{"type" => "string"},
        function: "UserSchema.extract_email_domain/1",
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
      type: field_schema |> Map.drop(["x-computed-field", "readOnly", "description", "examples"]),
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

    iex> simple_schema = %{"type" => "object", "properties" => %{"name" => %{"type" => "string"}}}
    iex> Exdantic.JsonSchema.has_computed_fields?(simple_schema)
    false
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
    # input_schema will not contain computed fields like full_name, email_domain
"""
@spec remove_computed_fields(json_schema()) :: json_schema()
def remove_computed_fields(%{"properties" => properties} = json_schema) when is_map(properties) do
  filtered_properties =
    properties
    |> Enum.reject(fn {_name, field_schema} ->
      is_map(field_schema) and Map.get(field_schema, "readOnly") == true
    end)
    |> Map.new()

  # Also update required fields to remove any computed fields
  updated_required =
    case Map.get(json_schema, "required") do
      nil -> nil
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

@doc """
Generates separate input and output JSON schemas for a schema with computed fields.

This function creates two schemas:
- Input schema: For validation of incoming data (excludes computed fields)
- Output schema: Complete schema including computed fields (for documentation)

## Parameters
  * `schema` - The schema module to process

## Returns
  * `{input_schema, output_schema}` tuple

## Examples

    iex> {input, output} = Exdantic.JsonSchema.input_output_schemas(UserSchema)
    iex> # input will not have computed fields
    iex> # output will have all fields including computed ones marked as readOnly
"""
@spec input_output_schemas(module()) :: {json_schema(), json_schema()}
def input_output_schemas(schema) when is_atom(schema) do
  full_schema = from_schema(schema)
  input_schema = remove_computed_fields(full_schema)
  
  {input_schema, full_schema}
end_validated(UserSchema)
    %{"type" => "object", "properties" => %{...}}

    iex> Exdantic.JsonSchema.from_schema
