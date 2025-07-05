defmodule Exdantic.StructValidator do
  @moduledoc """
  Validator that optionally returns struct instances and executes model validators.

  This module extends the existing validation logic to support:
  1. Returning struct instances when a schema is defined with `define_struct: true`
  2. Executing model validators after field validation succeeds
  3. Computing derived fields after model validation succeeds

  The validation pipeline:
  1. Field validation (existing logic)
  2. Model validation (Phase 2)
  3. Computed field execution (Phase 3)
  4. Struct creation (Phase 1)

  ## Phase 4 Enhancement: Anonymous Function Support

  Enhanced to properly handle both named functions and generated anonymous functions
  in model validators and computed fields. The validator can now execute:

  1. Named function model validators: `{MyModule, :validate_something}`
  2. Generated anonymous function validators: `{MyModule, :__generated_model_validator_123_456}`
  3. Named function computed fields: `{field_name, %ComputedFieldMeta{function_name: :my_function}}`
  4. Generated anonymous computed fields: `{field_name, %ComputedFieldMeta{function_name: :__generated_computed_field_name_123_456}}`

  All function types are handled uniformly through the same execution pipeline.
  """

  alias Exdantic.{Error, Validator}

  @doc """
  Validates data against a schema with full pipeline support including computed fields.

  ## Enhanced Validation Pipeline
  1. **Field Validation**: Validates individual fields using existing logic
  2. **Model Validation**: Executes model validators in sequence (Phase 2)
  3. **Computed Field Execution**: Executes computed fields to derive additional data (Phase 3)
  4. **Struct Creation**: Optionally creates struct instance (Phase 1)

  ## Parameters
    * `schema_module` - The schema module to validate against
    * `data` - The data to validate (must be a map)
    * `path` - Current validation path for error reporting (defaults to `[]`)

  ## Returns
    * `{:ok, validated_data}` - where `validated_data` includes computed fields and is a struct if the schema
      defines one, otherwise a map
    * `{:error, errors}` - list of validation errors

  ## Model Validator Execution
  Model validators are executed in the order they are declared in the schema.
  Note: The validators are stored in reverse order due to Elixir's accumulate attribute behavior,
  but they are reversed back during execution to maintain declaration order.
  If any model validator returns an error, execution stops and the error is returned.
  Model validators can transform data by returning modified data in the success case.

  ## Computed Field Execution
  Computed fields are executed after model validation succeeds. Each computed field function:
  - Receives the validated data (including any transformations from model validators)
  - Must return `{:ok, computed_value}` or `{:error, reason}`
  - Has its return value validated against the declared field type
  - Contributes to the final validated result

  ## Examples

      # Basic model validation with computed fields
      defmodule UserSchema do
        use Exdantic, define_struct: true

        schema do
          field :first_name, :string, required: true
          field :last_name, :string, required: true
          field :email, :string, required: true

          model_validator :normalize_names
          computed_field :full_name, :string, :generate_full_name
          computed_field :email_domain, :string, :extract_email_domain
        end

        def normalize_names(validated_data) do
          normalized = %{
            validated_data |
            first_name: String.trim(validated_data.first_name),
            last_name: String.trim(validated_data.last_name)
          }
          {:ok, normalized}
        end

        def generate_full_name(validated_data) do
          {:ok, "\#{validated_data.first_name} \#{validated_data.last_name}"}
        end

        def extract_email_domain(validated_data) do
          {:ok, validated_data.email |> String.split("@") |> List.last()}
        end
      end

      iex> UserSchema.validate(%{
      ...>   first_name: "  John  ",
      ...>   last_name: "  Doe  ",
      ...>   email: "john@example.com"
      ...> })
      {:ok, %UserSchema{
        first_name: "John",      # normalized by model validator
        last_name: "Doe",       # normalized by model validator
        email: "john@example.com",
        full_name: "John Doe",   # computed field
        email_domain: "example.com"  # computed field
      }}

  ## Error Handling
  Model validators can return errors in several formats:
  - `{:error, "string message"}` - converted to validation error
  - `{:error, %Exdantic.Error{}}` - used directly
  - Exception during execution - caught and converted to validation error

  Computed field errors are handled gracefully:
  - Function execution errors are caught and converted to validation errors
  - Type validation errors for computed values are reported with field context
  - Computed field errors include the field path and computation function reference
  """
  @spec validate_schema(module(), map(), [atom() | String.t() | integer()]) ::
          {:ok, map() | struct()} | {:error, [Error.t()]}
  def validate_schema(schema_module, data, path \\ []) when is_atom(schema_module) do
    # Step 1: Field validation (existing logic)
    case validate_schema_fields_only(schema_module, data, path) do
      {:ok, validated_map} ->
        # Step 2: Model validation (Phase 2)
        case apply_model_validators(schema_module, validated_map, path) do
          {:ok, model_validated_data} ->
            # Step 3: Computed field execution (Phase 3 - NEW)
            case apply_computed_fields(schema_module, model_validated_data, path) do
              {:ok, computed_data} ->
                # Step 4: Struct creation (Phase 1)
                maybe_create_struct(schema_module, computed_data, path)

              {:error, errors} ->
                {:error, errors}
            end

          {:error, errors} ->
            {:error, errors}
        end

      {:error, errors} ->
        # Pass through field validation errors unchanged
        {:error, errors}
    end
  end

  # Validate only the schema fields without computed fields or struct creation
  @spec validate_schema_fields_only(module(), map(), [atom() | String.t() | integer()]) ::
          {:ok, map()} | {:error, [Error.t()]}
  defp validate_schema_fields_only(schema_module, data, path) do
    # Schema validation only works with maps
    if is_map(data) do
      fields = schema_module.__schema__(:fields)
      config = schema_module.__schema__(:config) || %{}

      with :ok <- validate_required_fields_only(fields, data, path),
           {:ok, validated} <- validate_fields_only(fields, data, path),
           :ok <- validate_strict_mode_only(config, validated, data, path) do
        {:ok, validated}
      end
    else
      error = Error.new(path, :type, "expected map for schema validation, got #{inspect(data)}")
      {:error, [error]}
    end
  end

  # Field validation helpers (duplicated from Validator to avoid circular dependencies)
  @spec validate_required_fields_only([{atom(), Exdantic.FieldMeta.t()}], map(), [
          atom() | String.t() | integer()
        ]) ::
          :ok | {:error, [Error.t()]}
  defp validate_required_fields_only(fields, data, path) do
    required_fields = for {name, meta} <- fields, meta.required, do: name

    case Enum.find(required_fields, fn field ->
           not Map.has_key?(data, field) and not Map.has_key?(data, Atom.to_string(field))
         end) do
      nil ->
        :ok

      missing_field ->
        error = Error.new(path ++ [missing_field], :required, "field is required")
        {:error, [error]}
    end
  end

  @spec validate_fields_only([{atom(), Exdantic.FieldMeta.t()}], map(), [
          atom() | String.t() | integer()
        ]) ::
          {:ok, map()} | {:error, [Error.t()]}
  defp validate_fields_only(fields, data, path) do
    results = validate_individual_fields(fields, data, path)

    case collect_validation_errors(results) do
      [] ->
        validated_map = build_validated_map(results)
        {:ok, validated_map}

      errors ->
        {:error, errors}
    end
  end

  @spec validate_individual_fields([{atom(), Exdantic.FieldMeta.t()}], map(), [
          atom() | String.t() | integer()
        ]) ::
          [{atom(), {:ok, term()} | {:error, Error.t()} | :skip}]
  defp validate_individual_fields(fields, data, path) do
    Enum.map(fields, fn {name, meta} ->
      field_path = path ++ [name]
      validate_single_field(name, meta, data, field_path)
    end)
  end

  @spec validate_single_field(atom(), Exdantic.FieldMeta.t(), map(), [
          atom() | String.t() | integer()
        ]) ::
          {atom(), {:ok, term()} | {:error, Error.t()} | :skip}
  defp validate_single_field(name, meta, data, field_path) do
    case extract_field_value(data, name) do
      {:ok, value} ->
        {name, validate_field_value(meta, value, field_path)}

      {:error, :missing} when not meta.required ->
        handle_optional_field(name, meta)

      {:error, :missing} ->
        {name, {:error, Error.new(field_path, :required, "field is required")}}
    end
  end

  @spec validate_field_value(Exdantic.FieldMeta.t(), term(), [atom() | String.t() | integer()]) ::
          {:ok, term()} | {:error, Error.t()}
  defp validate_field_value(meta, value, field_path) do
    case Validator.validate(meta.type, value, field_path) do
      {:ok, validated} -> {:ok, validated}
      {:error, error} -> {:error, error}
    end
  end

  @spec handle_optional_field(atom(), Exdantic.FieldMeta.t()) :: {atom(), {:ok, term()} | :skip}
  defp handle_optional_field(name, meta) do
    case meta.default do
      nil -> {name, :skip}
      default -> {name, {:ok, default}}
    end
  end

  @spec collect_validation_errors([{atom(), {:ok, term()} | {:error, Error.t()} | :skip}]) :: [
          Error.t()
        ]
  defp collect_validation_errors(results) do
    results
    |> Enum.filter(fn {_name, result} -> match?({:error, _}, result) end)
    |> Enum.map(fn {_name, {:error, error}} -> error end)
  end

  @spec build_validated_map([{atom(), {:ok, term()} | {:error, Error.t()} | :skip}]) :: map()
  defp build_validated_map(results) do
    results
    |> Enum.reject(fn {_name, result} -> result == :skip end)
    |> Enum.map(fn {name, {:ok, value}} -> {name, value} end)
    |> Map.new()
  end

  @spec extract_field_value(map(), atom()) :: {:ok, term()} | {:error, :missing}
  defp extract_field_value(data, field_name) do
    cond do
      Map.has_key?(data, field_name) ->
        {:ok, Map.get(data, field_name)}

      Map.has_key?(data, Atom.to_string(field_name)) ->
        {:ok, Map.get(data, Atom.to_string(field_name))}

      true ->
        {:error, :missing}
    end
  end

  @spec validate_strict_mode_only(map(), map(), map(), [atom() | String.t() | integer()]) ::
          :ok | {:error, [Error.t()]}
  defp validate_strict_mode_only(%{strict: true}, validated, original, path) do
    extra_keys = Map.keys(original) -- Map.keys(validated)

    if extra_keys == [] do
      :ok
    else
      # Use the same error format as the original validator
      error = Error.new(path, :additional_properties, "unknown fields: #{inspect(extra_keys)}")
      {:error, [error]}
    end
  end

  defp validate_strict_mode_only(_, _, _, _), do: :ok

  # Apply model validators in sequence
  @spec apply_model_validators(module(), map(), [atom() | String.t() | integer()]) ::
          {:ok, map()} | {:error, [Error.t()]}
  defp apply_model_validators(schema_module, validated_data, path) do
    model_validators = get_model_validators(schema_module)

    Enum.reduce_while(model_validators, {:ok, validated_data}, fn
      {module, function_name}, {:ok, current_data} ->
        case execute_model_validator(module, function_name, current_data, path) do
          {:ok, new_data} ->
            {:cont, {:ok, new_data}}

          {:error, errors} ->
            {:halt, {:error, errors}}
        end
    end)
  end

  # Get model validators for a schema
  @spec get_model_validators(module()) :: [{module(), atom()}]
  defp get_model_validators(schema_module) do
    if function_exported?(schema_module, :__schema__, 1) do
      # Reverse the list to process model validators in the order they were defined
      (schema_module.__schema__(:model_validators) || []) |> Enum.reverse()
    else
      []
    end
  end

  # Execute a single model validator with comprehensive error handling
  @spec execute_model_validator(module(), atom(), map(), [atom() | String.t() | integer()]) ::
          {:ok, map()} | {:error, [Error.t()]}
  defp execute_model_validator(module, function_name, data, path) do
    case apply(module, function_name, [data]) do
      {:ok, new_data} when is_map(new_data) ->
        {:ok, new_data}

      {:error, reason} when is_binary(reason) ->
        error = create_model_validator_error(module, function_name, reason, path)
        {:error, [error]}

      {:error, %Error{} = error} ->
        # Update error path to include current path context
        updated_error = update_error_path(error, path)
        {:error, [updated_error]}

      {:error, errors} when is_list(errors) ->
        # Handle list of errors
        updated_errors = Enum.map(errors, &update_error_path(&1, path))
        {:error, updated_errors}

      other ->
        # Invalid return format from model validator
        function_display = format_function_display(module, function_name)

        error_msg =
          "Model validator #{function_display} returned invalid format: #{inspect(other)}. " <>
            "Expected {:ok, data} or {:error, reason}"

        error = Error.new(path, :model_validation, error_msg)
        {:error, [error]}
    end
  rescue
    _e in UndefinedFunctionError ->
      function_display = format_function_display(module, function_name)
      error_msg = "Model validator function #{function_display} is not defined"
      error = Error.new(path, :model_validation, error_msg)
      {:error, [error]}

    e ->
      # Catch any other exceptions during model validator execution
      function_display = format_function_display(module, function_name)

      error_msg =
        "Model validator #{function_display} execution failed: #{Exception.message(e)}"

      error = Error.new(path, :model_validation, error_msg)
      {:error, [error]}
  end

  # Update error path to include current validation context
  @spec update_error_path(Error.t(), [atom() | String.t() | integer()]) :: Error.t()
  defp update_error_path(%Error{path: error_path} = error, current_path) do
    # Only prepend current path if error path is empty or relative
    updated_path =
      case error_path do
        [] -> current_path
        _ -> current_path ++ error_path
      end

    %{error | path: updated_path}
  end

  # Check if schema has struct support enabled (from Phase 1)
  @spec struct_enabled?(module()) :: boolean()
  defp struct_enabled?(schema_module) do
    function_exported?(schema_module, :__struct_enabled__?, 0) and
      schema_module.__struct_enabled__?()
  end

  # Conditionally create struct instance (from Phase 1)
  @spec maybe_create_struct(module(), map(), [atom() | String.t() | integer()]) ::
          {:ok, map() | struct()} | {:error, [Error.t()]}
  defp maybe_create_struct(schema_module, validated_map, path) do
    if struct_enabled?(schema_module) do
      create_struct_instance(schema_module, validated_map, path)
    else
      {:ok, validated_map}
    end
  end

  # Enhanced struct creation with computed field support
  @spec create_struct_instance(module(), map(), [atom() | String.t() | integer()]) ::
          {:ok, struct()} | {:error, [Error.t()]}
  defp create_struct_instance(schema_module, validated_map, path) do
    validated_struct = struct!(schema_module, validated_map)
    {:ok, validated_struct}
  rescue
    e in ArgumentError ->
      # Get field information for better error messages
      regular_fields = get_struct_fields(schema_module)

      computed_fields =
        get_computed_fields(schema_module) |> Enum.map(fn {name, _meta} -> name end)

      all_expected_fields = regular_fields ++ computed_fields

      error_message = """
      Failed to create struct #{inspect(schema_module)} from validated data.
      This may be caused by computed fields adding unexpected fields or model validators
      adding fields not defined in the struct.

      Expected struct fields: #{inspect(all_expected_fields)}
      Validated data keys: #{inspect(Map.keys(validated_map))}
      Regular fields: #{inspect(regular_fields)}
      Computed fields: #{inspect(computed_fields)}

      Original error: #{Exception.message(e)}
      """

      error = Error.new(path, :struct_creation, String.trim(error_message))
      {:error, [error]}

    e ->
      error_message = "Unexpected error creating struct: #{Exception.message(e)}"
      error = Error.new(path, :struct_creation, error_message)
      {:error, [error]}
  end

  # Get struct field names for debugging (from Phase 1)
  @spec get_struct_fields(module()) :: [atom()]
  defp get_struct_fields(schema_module) do
    if function_exported?(schema_module, :__struct_fields__, 0) do
      schema_module.__struct_fields__()
    else
      [:unknown]
    end
  end

  # Apply computed fields to validated data
  @spec apply_computed_fields(module(), map(), [atom() | String.t() | integer()]) ::
          {:ok, map()} | {:error, [Error.t()]}
  defp apply_computed_fields(schema_module, validated_data, path) do
    computed_fields = get_computed_fields(schema_module)

    Enum.reduce_while(computed_fields, {:ok, validated_data}, fn
      {field_name, computed_field_meta}, {:ok, current_data} ->
        case execute_computed_field(computed_field_meta, current_data, path) do
          {:ok, computed_value} ->
            # Validate the computed value against its declared type
            field_path = path ++ [field_name]

            case validate_computed_value(computed_field_meta, computed_value, field_path) do
              {:ok, validated_computed_value} ->
                updated_data = Map.put(current_data, field_name, validated_computed_value)
                {:cont, {:ok, updated_data}}

              {:error, errors} ->
                {:halt, {:error, errors}}
            end

          {:error, errors} ->
            {:halt, {:error, errors}}
        end
    end)
  end

  # Get computed fields for a schema
  @spec get_computed_fields(module()) :: [{atom(), Exdantic.ComputedFieldMeta.t()}]
  defp get_computed_fields(schema_module) do
    if function_exported?(schema_module, :__schema__, 1) do
      # Reverse the list to process computed fields in the order they were defined
      (schema_module.__schema__(:computed_fields) || []) |> Enum.reverse()
    else
      []
    end
  end

  # Execute a single computed field with comprehensive error handling
  @spec execute_computed_field(Exdantic.ComputedFieldMeta.t(), map(), [
          atom() | String.t() | integer()
        ]) ::
          {:ok, term()} | {:error, [Error.t()]}
  defp execute_computed_field(computed_field_meta, data, path) do
    field_path = path ++ [computed_field_meta.name]

    try do
      case apply(computed_field_meta.module, computed_field_meta.function_name, [data]) do
        {:ok, computed_value} ->
          {:ok, computed_value}

        {:error, reason} when is_binary(reason) ->
          error = Error.new(field_path, :computed_field, reason)
          {:error, [error]}

        {:error, %Error{} = error} ->
          # Update error path to include computed field context
          updated_error = update_computed_field_error_path(error, field_path, computed_field_meta)
          {:error, [updated_error]}

        {:error, errors} when is_list(errors) ->
          # Handle list of errors
          updated_errors =
            Enum.map(
              errors,
              &update_computed_field_error_path(&1, field_path, computed_field_meta)
            )

          {:error, updated_errors}

        other ->
          # Invalid return format from computed field function
          function_ref = format_computed_field_function_reference(computed_field_meta)

          error_msg =
            "Computed field function #{function_ref} returned invalid format: #{inspect(other)}. " <>
              "Expected {:ok, value} or {:error, reason}"

          error = Error.new(field_path, :computed_field, error_msg)
          {:error, [error]}
      end
    rescue
      _e in UndefinedFunctionError ->
        function_ref = format_computed_field_function_reference(computed_field_meta)
        error_msg = "Computed field function #{function_ref} is not defined"
        error = Error.new(field_path, :computed_field, error_msg)
        {:error, [error]}

      e ->
        # Catch any other exceptions during computed field execution
        function_ref = format_computed_field_function_reference(computed_field_meta)

        error_msg =
          "Computed field function #{function_ref} execution failed: #{Exception.message(e)}"

        error = Error.new(field_path, :computed_field, error_msg)
        {:error, [error]}
    end
  end

  # Validate computed field return value against its declared type
  @spec validate_computed_value(Exdantic.ComputedFieldMeta.t(), term(), [
          atom() | String.t() | integer()
        ]) ::
          {:ok, term()} | {:error, [Error.t()]}
  defp validate_computed_value(computed_field_meta, computed_value, field_path) do
    case Exdantic.Validator.validate(computed_field_meta.type, computed_value, field_path) do
      {:ok, validated_value} ->
        {:ok, validated_value}

      {:error, errors} when is_list(errors) ->
        # Add context that this is a computed field type validation error
        contextualized_errors =
          Enum.map(errors, fn error ->
            enhanced_message =
              "Computed field type validation failed: #{error.message} " <>
                "(from #{Exdantic.ComputedFieldMeta.function_reference(computed_field_meta)})"

            %{error | message: enhanced_message, code: :computed_field_type}
          end)

        {:error, contextualized_errors}

      {:error, error} ->
        # Single error case
        enhanced_message =
          "Computed field type validation failed: #{error.message} " <>
            "(from #{Exdantic.ComputedFieldMeta.function_reference(computed_field_meta)})"

        enhanced_error = %{error | message: enhanced_message, code: :computed_field_type}
        {:error, [enhanced_error]}
    end
  end

  # Update error path to include computed field context
  @spec update_computed_field_error_path(
          Error.t(),
          [atom() | String.t() | integer()],
          Exdantic.ComputedFieldMeta.t()
        ) :: Error.t()
  defp update_computed_field_error_path(
         %Error{path: error_path} = error,
         field_path,
         computed_field_meta
       ) do
    # Enhance error message to include computed field context
    function_ref = format_computed_field_function_reference(computed_field_meta)

    enhanced_message =
      if String.contains?(error.message, function_ref) do
        error.message
      else
        "#{error.message} (in computed field #{function_ref})"
      end

    # Use field path if error path is empty, otherwise combine them
    updated_path =
      case error_path do
        [] -> field_path
        _ -> field_path ++ error_path
      end

    %{error | path: updated_path, message: enhanced_message}
  end

  # Private helper functions for enhanced error reporting

  @spec create_model_validator_error(module(), atom(), String.t(), [
          atom() | String.t() | integer()
        ]) :: Error.t()
  defp create_model_validator_error(module, function_name, reason, path) do
    function_display = format_function_display(module, function_name)
    message = format_model_validator_error_message(function_display, reason)
    Error.new(path, :model_validation, message)
  end

  @spec format_function_display(module(), atom()) :: String.t()
  defp format_function_display(module, function_name) do
    module_name = module |> to_string() |> String.replace_prefix("Elixir.", "")
    function_str = Atom.to_string(function_name)

    # Check if it's a generated function name
    if String.starts_with?(function_str, "__generated_") do
      # Extract the type from generated function name
      case String.split(function_str, "_", parts: 4) do
        ["", "generated", type, _rest] ->
          "#{module_name}.<anonymous #{type}>/1"

        _ ->
          "#{module_name}.#{function_str}/1"
      end
    else
      "#{module_name}.#{function_str}/1"
    end
  end

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

  @spec format_model_validator_error_message(String.t(), String.t()) :: String.t()
  defp format_model_validator_error_message(function_display, reason) do
    if String.contains?(function_display, "<anonymous") do
      "Anonymous model validator failed: #{reason}"
    else
      reason
    end
  end
end
