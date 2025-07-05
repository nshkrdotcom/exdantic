defmodule Exdantic.Validator do
  @moduledoc """
  Validates values against type definitions and schemas.

  This module provides the core validation logic for Exdantic schemas,
  handling field validation, constraints, and error reporting.
  """

  alias Exdantic.Error

  @type validation_result :: {:ok, term()} | {:error, Error.t() | [Error.t()]}
  @type validation_path :: [atom() | String.t() | integer()]

  @doc """
  Validates data against a schema module, checking for required fields,
  field-level validations, and strict mode constraints if enabled.

  ## Parameters
    * `schema` - Schema module to validate against
    * `data` - Data to validate (map)
    * `path` - Current validation path for error messages (defaults to `[]`)

  ## Returns
    * `{:ok, validated_data}` on success
    * `{:error, errors}` on validation failures

  ## Examples

      iex> defmodule TestSchema do
      ...>   use Exdantic
      ...>   schema do
      ...>     field :name, :string
      ...>   end
      ...> end
      iex> Exdantic.Validator.validate_schema(TestSchema, %{name: "John"})
      {:ok, %{name: "John"}}
  """
  @spec validate_schema(module(), map(), validation_path()) :: validation_result()
  def validate_schema(schema, data, path \\ []) when is_atom(schema) do
    # Schema validation only works with maps
    if is_map(data) do
      fields = schema.__schema__(:fields)
      config = schema.__schema__(:config) || %{}

      with :ok <- validate_required_fields(fields, data, path),
           {:ok, validated} <- validate_fields(fields, data, path),
           :ok <- validate_strict(config, validated, data, path) do
        {:ok, validated}
      end
    else
      {:error, Error.new(path, :type, "expected map for schema validation, got #{inspect(data)}")}
    end
  end

  # Helper function to check if a schema has computed fields
  @spec has_computed_fields?(module()) :: boolean()
  defp has_computed_fields?(schema) do
    if function_exported?(schema, :__schema__, 1) do
      computed_fields = schema.__schema__(:computed_fields) || []
      length(computed_fields) > 0
    else
      false
    end
  end

  @spec validate_required_fields([{atom(), Exdantic.FieldMeta.t()}], map(), validation_path()) ::
          :ok | {:error, Error.t()}
  defp validate_required_fields(fields, data, path) do
    required_fields = for {name, meta} <- fields, meta.required, do: name

    case Enum.find(required_fields, fn field ->
           not (Map.has_key?(data, field) or Map.has_key?(data, Atom.to_string(field)))
         end) do
      nil -> :ok
      field -> {:error, Error.new([field | path], :required, "field is required")}
    end
  end

  @spec validate_fields([{atom(), Exdantic.FieldMeta.t()}], map(), validation_path()) ::
          {:ok, map()} | {:error, Error.t()}
  defp validate_fields(fields, data, path) do
    Enum.reduce_while(fields, {:ok, %{}}, fn {name, meta}, {:ok, acc} ->
      field_path = path ++ [name]
      value = Map.get(data, name) || Map.get(data, Atom.to_string(name))

      case {value, meta} do
        {nil, %{default: default}} ->
          {:cont, {:ok, Map.put(acc, name, default)}}

        {nil, %{required: false}} ->
          {:cont, {:ok, acc}}

        {nil, _} ->
          {:halt, {:error, Error.new(field_path, :required, "field is required")}}

        {value, _} ->
          case validate(meta.type, value, field_path) do
            {:ok, validated} -> {:cont, {:ok, Map.put(acc, name, validated)}}
            {:error, errors} -> {:halt, {:error, errors}}
          end
      end
    end)
  end

  @spec validate_strict(map(), map(), map(), validation_path()) :: :ok | {:error, Error.t()}
  defp validate_strict(%{strict: true}, validated, original, path) do
    case Map.keys(original) -- Map.keys(validated) do
      [] ->
        :ok

      extra ->
        {:error, Error.new(path, :additional_properties, "unknown fields: #{inspect(extra)}")}
    end
  end

  defp validate_strict(_, _, _, _), do: :ok

  @doc """
  Validates a value against a type definition.

  ## Parameters
    * `type` - The type definition or schema module to validate against
    * `value` - The value to validate
    * `path` - Current validation path for error messages (defaults to `[]`)

  ## Returns
    * `{:ok, validated_value}` on success
    * `{:error, errors}` on validation failures

  ## Examples

      iex> Exdantic.Validator.validate({:type, :string, []}, "hello")
      {:ok, "hello"}

      iex> Exdantic.Validator.validate({:type, :integer, []}, "not a number")
      {:error, %Exdantic.Error{...}}
  """
  @spec validate(Exdantic.Types.type_definition() | module(), term(), validation_path()) ::
          validation_result()
  def validate(type, value, path), do: do_validate(type, value, path)

  @spec validate(Exdantic.Types.type_definition() | module(), term()) :: validation_result()
  def validate(type, value), do: do_validate(type, value, [])

  defp do_validate({:ref, schema}, value, path) when is_atom(schema) do
    # Check if schema has computed fields and use appropriate validation
    if has_computed_fields?(schema) do
      # Use StructValidator for schemas with computed fields
      case Exdantic.StructValidator.validate_schema(schema, value, path) do
        {:ok, validated} when is_struct(validated) ->
          # Convert struct back to map for consistency with validator expectations
          {:ok, Map.from_struct(validated)}

        {:ok, validated} when is_map(validated) ->
          {:ok, validated}

        {:error, errors} when is_list(errors) ->
          # Convert single-error lists to single errors for compatibility
          case errors do
            [single_error] -> {:error, single_error}
            multiple_errors -> {:error, multiple_errors}
          end
      end
    else
      # Use basic field validation for schemas without computed fields
      validate_schema(schema, value, path)
    end
  end

  defp do_validate(schema, value, path) when is_atom(schema) do
    do_validate_atom_schema(schema, value, path)
  end

  defp do_validate({:type, name, constraints}, value, path) do
    case Exdantic.Types.validate(name, value) do
      {:ok, validated} -> apply_constraints(validated, constraints, path)
      {:error, error} -> {:error, %{error | path: path ++ error.path}}
    end
  end

  defp do_validate({:array, inner_type, constraints}, value, path) do
    if is_list(value) do
      validate_array_items(value, inner_type, constraints, path)
    else
      {:error, [Error.new(path, :type, "expected array, got #{inspect(value)}")]}
    end
  end

  defp do_validate({:map, {key_type, value_type}, constraints}, value, path) do
    validate_map(value, key_type, value_type, constraints, path)
  end

  defp do_validate({:object, fields, constraints}, value, path) do
    validate_object(value, fields, constraints, path)
  end

  defp do_validate({:tuple, types}, value, path) do
    if is_tuple(value) and tuple_size(value) == length(types) do
      values = Tuple.to_list(value)

      results =
        Enum.zip(types, values)
        |> Enum.with_index()
        |> Enum.map(fn {{type, val}, idx} ->
          normalized_type = Exdantic.Types.normalize_type(type)

          case normalized_type do
            {:type, t, _} -> do_validate({:type, t, []}, val, path ++ [idx])
            {:union, _, _} -> do_validate(normalized_type, val, path ++ [idx])
            _ -> do_validate(normalized_type, val, path ++ [idx])
          end
        end)

      case Enum.find(results, &match?({:error, _}, &1)) do
        nil ->
          {:ok, value}

        {:error, err} ->
          {:error, Exdantic.Error.new(path, :type, "tuple element invalid: #{inspect(err)}")}
      end
    else
      {:error, Exdantic.Error.new(path, :type, "expected tuple, got #{inspect(value)}")}
    end
  end

  defp do_validate({:union, types, _constraints}, value, path) do
    normalized_types = Enum.map(types, &Exdantic.Types.normalize_type/1)

    results =
      Enum.map(normalized_types, fn type ->
        branch_result = do_validate(type, value, path)
        branch_result
      end)

    case Enum.find(results, &match?({:ok, _}, &1)) do
      {:ok, validated} ->
        {:ok, validated}

      nil ->
        detailed_errors =
          results
          |> Enum.flat_map(fn
            {:error, errors} when is_list(errors) -> errors
            {:error, error} -> [error]
            _ -> []
          end)

        case detailed_errors do
          [] ->
            {:error, [Exdantic.Error.new(path, :type, "value did not match any type in union")]}

          errors ->
            best_error = Enum.max_by(errors, fn error -> length(error.path) end)

            if length(best_error.path) > length(path) do
              {:error, [best_error]}
            else
              {:error, [Exdantic.Error.new(path, :type, "value did not match any type in union")]}
            end
        end
    end
  end

  defp do_validate_atom_schema(schema, value, path)
       when schema in [:string, :integer, :float, :boolean, :any, :atom, :map] do
    case Exdantic.Types.validate(schema, value) do
      {:ok, validated} -> {:ok, validated}
      {:error, error} -> {:error, %{error | path: path ++ error.path}}
    end
  end

  defp do_validate_atom_schema(schema, value, path) do
    cond do
      Code.ensure_loaded?(schema) and function_exported?(schema, :__schema__, 1) ->
        validate_schema(schema, value, path)

      Code.ensure_loaded?(schema) and function_exported?(schema, :type_definition, 0) ->
        schema.validate(value, path)

      value == schema ->
        {:ok, value}

      true ->
        {:error,
         Exdantic.Error.new(
           path,
           :type,
           "expected literal atom #{inspect(schema)}, got #{inspect(value)}"
         )}
    end
  end

  @spec apply_constraints(term(), [term()], validation_path()) :: validation_result()
  defp apply_constraints(value, constraints, path) do
    # Extract custom error messages from constraints
    error_messages = extract_error_messages(constraints)

    Enum.reduce_while(constraints, {:ok, value}, fn
      # Handle custom validator functions first
      {:validator, validator_fn}, {:ok, val} ->
        case validator_fn.(val) do
          {:ok, validated_val} ->
            {:cont, {:ok, validated_val}}

          {:error, message} ->
            {:halt, {:error, Error.new(path, :custom_validation, message)}}

          other ->
            {:halt,
             {:error,
              Error.new(
                path,
                :custom_validation,
                "Custom validator returned invalid format: #{inspect(other)}"
              )}}
        end

      # Skip error message constraints - they're already processed
      {:error_message, _, _}, {:ok, val} ->
        {:cont, {:ok, val}}

      # Handle regular constraints
      {constraint, constraint_value}, {:ok, val} ->
        case apply_constraint(constraint, val, constraint_value) do
          true ->
            {:cont, {:ok, val}}

          false ->
            message = Map.get(error_messages, constraint, "failed #{constraint} constraint")
            {:halt, {:error, Error.new(path, constraint, message)}}
        end

      # Handle any other case
      _, acc ->
        {:cont, acc}
    end)
  end

  @spec extract_error_messages([term()]) :: %{atom() => String.t()}
  defp extract_error_messages(constraints) do
    constraints
    |> Enum.filter(&match?({:error_message, _, _}, &1))
    |> Enum.into(%{}, fn {:error_message, constraint, message} -> {constraint, message} end)
  end

  # String constraints
  @spec apply_constraint(
          :choices
          | :format
          | :gt
          | :gteq
          | :lt
          | :lteq
          | :max_items
          | :max_length
          | :min_items
          | :min_length
          | :size?,
          term(),
          term()
        ) :: boolean()
  defp apply_constraint(:min_length, value, min) when is_binary(value) do
    String.length(value) >= min
  end

  defp apply_constraint(:max_length, value, max) when is_binary(value) do
    String.length(value) <= max
  end

  # List constraints
  defp apply_constraint(:min_items, value, min) when is_list(value) do
    length(value) >= min
  end

  defp apply_constraint(:max_items, value, max) when is_list(value) do
    length(value) <= max
  end

  # Number constraints
  defp apply_constraint(:gt, value, min) when is_number(value) do
    value > min
  end

  defp apply_constraint(:lt, value, max) when is_number(value) do
    value < max
  end

  defp apply_constraint(:gteq, value, min) when is_number(value) do
    value >= min
  end

  defp apply_constraint(:lteq, value, max) when is_number(value) do
    value <= max
  end

  # Map constraints
  defp apply_constraint(:size?, value, size) when is_map(value) do
    map_size(value) == size
  end

  # Format constraint for strings
  defp apply_constraint(:format, value, regex)
       when is_binary(value) and is_struct(regex, Regex) do
    Regex.match?(regex, value)
  end

  # Choices constraint
  defp apply_constraint(:choices, value, allowed_values) do
    value in allowed_values
  end

  # Handle unknown constraints gracefully
  defp apply_constraint(_constraint, _value, _constraint_value) do
    # Unknown constraints pass through
    true
  end

  # Array validation
  @spec validate_array_items(
          [term()],
          Exdantic.Types.type_definition(),
          [term()],
          validation_path()
        ) :: validation_result()
  defp validate_array_items(items, type, constraints, path) do
    results =
      items
      |> Enum.with_index()
      |> Enum.map(fn {item, idx} ->
        item_path = path ++ [idx]

        case validate(type, item, item_path) do
          {:ok, validated} -> {:ok, validated}
          {:error, errors} -> {:error, List.wrap(errors)}
        end
      end)

    case Enum.split_with(results, &match?({:ok, _}, &1)) do
      {oks, []} ->
        validated_array = Enum.map(oks, fn {:ok, val} -> val end)

        case apply_constraints(validated_array, constraints, path) do
          {:ok, final} -> {:ok, final}
          {:error, error} -> {:error, [error]}
        end

      {_, errors} ->
        {:error, Enum.flat_map(errors, fn {:error, errs} -> errs end)}
    end
  end

  @spec validate_map(
          term(),
          Exdantic.Types.type_definition(),
          Exdantic.Types.type_definition(),
          [term()],
          validation_path()
        ) :: validation_result()
  defp validate_map(value, key_type, value_type, constraints, path) when is_map(value) do
    results =
      Enum.map(value, fn {k, v} ->
        with {:ok, validated_key} <- validate(key_type, k, path ++ [:key]),
             {:ok, validated_value} <- validate(value_type, v, path ++ [validated_key]) do
          {:ok, {validated_key, validated_value}}
        else
          {:error, errors} -> {:error, errors}
        end
      end)

    case Enum.split_with(results, &match?({:ok, _}, &1)) do
      {oks, []} ->
        validated_map = Map.new(Enum.map(oks, fn {:ok, kv} -> kv end))

        case apply_constraints(validated_map, constraints, path) do
          {:ok, final} -> {:ok, final}
          {:error, error} -> {:error, [error]}
        end

      {_, errors} ->
        {:error, Enum.flat_map(errors, fn {:error, errs} -> List.wrap(errs) end)}
    end
  end

  defp validate_map(value, _key_type, _value_type, _constraints, path) do
    {:error, [Error.new(path, :type, "expected map, got #{inspect(value)}")]}
  end

  @spec validate_object(
          term(),
          %{atom() => Exdantic.Types.type_definition()},
          [term()],
          validation_path()
        ) :: validation_result()
  defp validate_object(value, fields, constraints, path) when is_map(value) do
    # Validate each field in the object schema
    results =
      Enum.map(fields, fn {field_key, field_type} ->
        field_path = path ++ [field_key]
        field_value = Map.get(value, field_key)

        case validate(field_type, field_value, field_path) do
          {:ok, validated} -> {:ok, {field_key, validated}}
          {:error, errors} -> {:error, errors}
        end
      end)

    # Check for validation errors
    case Enum.split_with(results, &match?({:ok, _}, &1)) do
      {oks, []} ->
        validated_object = Map.new(Enum.map(oks, fn {:ok, kv} -> kv end))

        # Apply constraints to the validated object
        case apply_constraints(validated_object, constraints, path) do
          {:ok, final} -> {:ok, final}
          {:error, error} -> {:error, [error]}
        end

      {_, errors} ->
        {:error, Enum.flat_map(errors, fn {:error, errs} -> List.wrap(errs) end)}
    end
  end

  defp validate_object(value, _fields, _constraints, path) do
    {:error, [Error.new(path, :type, "expected object (map), got #{inspect(value)}")]}
  end
end
