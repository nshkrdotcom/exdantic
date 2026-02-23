defmodule Exdantic.Settings.Decode do
  @moduledoc false

  alias Exdantic.Error
  alias Exdantic.Settings.Keys

  @type decode_result :: {:ok, term()} | {:error, [Error.t()]}

  @spec decode_env_value(term(), term(), [atom() | String.t()], keyword()) :: decode_result()
  def decode_env_value(type, value, path, opts) when is_binary(value) do
    cond do
      union_type?(type) ->
        decode_union(type, value, path)

      structured_type?(type) ->
        decode_json(value, path)

      custom_type_module?(type) ->
        decode_custom_type(type, value, path, opts)

      true ->
        decode_scalar(type, value, path, opts)
    end
  end

  def decode_env_value(_type, value, _path, _opts), do: {:ok, value}

  @spec decode_exploded_leaf(term(), term(), [atom() | String.t()], keyword()) :: decode_result()
  def decode_exploded_leaf(type, value, path, opts), do: decode_env_value(type, value, path, opts)

  @spec structured_type?(term()) :: boolean()
  def structured_type?({:array, _, _}), do: true
  def structured_type?({:map, _, _}), do: true
  def structured_type?({:object, _, _}), do: true
  def structured_type?({:ref, _}), do: true
  def structured_type?({:type, :map, _}), do: true
  def structured_type?({:union, types, _}), do: Enum.any?(types, &structured_type?/1)

  def structured_type?(type) when is_atom(type) do
    cond do
      schema_module?(type) ->
        true

      custom_type_module?(type) ->
        type
        |> safe_type_definition()
        |> structured_type?()

      true ->
        false
    end
  end

  def structured_type?(_), do: false

  @spec union_type?(term()) :: boolean()
  def union_type?({:union, _types, _}), do: true
  def union_type?(_), do: false

  @spec supports_exploded_nested?(term()) :: boolean()
  def supports_exploded_nested?({:ref, schema}) when is_atom(schema), do: schema_module?(schema)
  def supports_exploded_nested?({:object, _fields, _}), do: true

  def supports_exploded_nested?(module) when is_atom(module) do
    cond do
      schema_module?(module) ->
        true

      custom_type_module?(module) ->
        module
        |> safe_type_definition()
        |> supports_exploded_nested?()

      true ->
        false
    end
  end

  def supports_exploded_nested?(_), do: false

  @spec resolve_nested_field_type(term(), String.t(), keyword()) :: {:ok, atom(), term()} | :error
  def resolve_nested_field_type(type, segment, opts) do
    with {:ok, fields} <- extract_nested_fields(type),
         {:ok, name, field_meta} <- match_field_segment(fields, segment, opts) do
      {:ok, name, field_meta.type}
    end
  end

  @spec resolve_nested_prefix(term(), String.t(), keyword(), String.t()) ::
          {:ok, atom(), term(), String.t()} | :error
  def resolve_nested_prefix(type, tail, opts, delimiter)
      when is_binary(tail) and is_binary(delimiter) do
    with {:ok, fields} <- extract_nested_fields(type) do
      match_field_prefix(fields, tail, opts, delimiter)
    end
  end

  @spec decode_scalar(term(), String.t(), [atom() | String.t()], keyword()) :: decode_result()
  def decode_scalar({:type, :string, _}, value, _path, _opts), do: {:ok, value}

  def decode_scalar({:type, :integer, _}, value, path, _opts) do
    case Integer.parse(value) do
      {int, ""} -> {:ok, int}
      _ -> cast_error(path, "expected integer env value, got #{inspect(value)}")
    end
  end

  def decode_scalar({:type, :float, _}, value, path, _opts) do
    case Float.parse(value) do
      {float, ""} -> {:ok, float}
      _ -> cast_error(path, "expected float env value, got #{inspect(value)}")
    end
  end

  def decode_scalar({:type, :boolean, _}, value, path, opts) do
    parse_boolean(value, path, Keyword.get(opts, :bool_numeric, true))
  end

  def decode_scalar({:type, :atom, _}, value, path, opts) do
    case Keyword.get(opts, :allow_atoms, false) do
      :existing ->
        try do
          {:ok, String.to_existing_atom(value)}
        rescue
          ArgumentError -> cast_error(path, "atom #{inspect(value)} does not exist")
        end

      _ ->
        cast_error(path, "atom env casting is disabled")
    end
  end

  def decode_scalar({:type, :any, _}, value, _path, _opts), do: {:ok, value}

  def decode_scalar(:string, value, path, opts),
    do: decode_scalar({:type, :string, []}, value, path, opts)

  def decode_scalar(:integer, value, path, opts),
    do: decode_scalar({:type, :integer, []}, value, path, opts)

  def decode_scalar(:float, value, path, opts),
    do: decode_scalar({:type, :float, []}, value, path, opts)

  def decode_scalar(:boolean, value, path, opts),
    do: decode_scalar({:type, :boolean, []}, value, path, opts)

  def decode_scalar(:atom, value, path, opts),
    do: decode_scalar({:type, :atom, []}, value, path, opts)

  def decode_scalar(:any, value, path, opts),
    do: decode_scalar({:type, :any, []}, value, path, opts)

  # Unknown scalar-like values in v1 are passed through to validator.
  def decode_scalar(type, value, _path, _opts) when is_atom(type), do: {:ok, value}

  def decode_scalar(_type, value, _path, _opts), do: {:ok, value}

  # Conservative union handling in v1:
  # - JSON-like strings for unions with structured members must decode as JSON.
  # - Otherwise leave value as raw string and let validator resolve the union.
  defp decode_union({:union, types, _}, value, path) do
    has_structured = Enum.any?(types, &structured_type?/1)

    if has_structured and String.starts_with?(value, ["{", "["]) do
      decode_json(value, path)
    else
      {:ok, value}
    end
  end

  defp decode_custom_type(type, value, path, opts) do
    type_def = safe_type_definition(type)

    if structured_type?(type_def) do
      decode_json(value, path)
    else
      decode_scalar(type_def, value, path, opts)
    end
  end

  defp decode_json(value, path) do
    case Jason.decode(value) do
      {:ok, decoded} ->
        {:ok, decoded}

      {:error, reason} ->
        msg = "invalid JSON env value: #{Exception.message(reason)}"
        {:error, [Error.new(path, :env_json, msg)]}
    end
  end

  defp parse_boolean(value, path, bool_numeric?) do
    down = String.downcase(value)

    cond do
      down == "true" -> {:ok, true}
      down == "false" -> {:ok, false}
      bool_numeric? and down == "1" -> {:ok, true}
      bool_numeric? and down == "0" -> {:ok, false}
      true -> cast_error(path, "expected boolean env value, got #{inspect(value)}")
    end
  end

  defp cast_error(path, message), do: {:error, [Error.new(path, :env_cast, message)]}

  defp extract_nested_fields({:ref, schema}) when is_atom(schema),
    do: extract_nested_fields(schema)

  defp extract_nested_fields({:object, fields, _}) when is_map(fields) do
    field_list =
      fields
      |> Enum.map(fn {name, type} ->
        {name, %Exdantic.FieldMeta{name: name, type: type, required: false}}
      end)

    {:ok, field_list}
  end

  defp extract_nested_fields(schema) when is_atom(schema) do
    cond do
      schema_module?(schema) ->
        {:ok, schema.__schema__(:fields)}

      custom_type_module?(schema) ->
        schema
        |> safe_type_definition()
        |> extract_nested_fields()

      true ->
        :error
    end
  end

  defp extract_nested_fields(_), do: :error

  defp match_field_segment(fields, segment, opts) do
    comparer =
      if Keyword.get(opts, :case_sensitive, false) do
        fn left, right -> left == right end
      else
        fn left, right -> String.upcase(left) == String.upcase(right) end
      end

    fields
    |> Enum.find_value(:error, fn {name, meta} ->
      expected = Keys.segment_to_env(name)
      if comparer.(expected, segment), do: {:ok, name, meta}, else: false
    end)
  end

  defp match_field_prefix(fields, tail, opts, delimiter) do
    case_sensitive = Keyword.get(opts, :case_sensitive, false)
    normalized_tail = normalize_segment(tail, case_sensitive)
    normalized_delimiter = normalize_segment(delimiter, case_sensitive)

    fields
    |> Enum.sort_by(fn {name, _meta} -> byte_size(Keys.segment_to_env(name)) end, :desc)
    |> Enum.find_value(:error, fn {name, meta} ->
      expected = Keys.segment_to_env(name)
      normalized_expected = normalize_segment(expected, case_sensitive)

      cond do
        normalized_tail == normalized_expected ->
          {:ok, name, meta.type, ""}

        String.starts_with?(normalized_tail, normalized_expected <> normalized_delimiter) ->
          rest_start = byte_size(expected) + byte_size(delimiter)
          rest_length = byte_size(tail) - rest_start
          rest = binary_part(tail, rest_start, rest_length)
          {:ok, name, meta.type, rest}

        true ->
          false
      end
    end)
  end

  defp normalize_segment(value, true), do: value
  defp normalize_segment(value, false), do: String.upcase(value)

  defp schema_module?(module) when is_atom(module) do
    Code.ensure_loaded?(module) and function_exported?(module, :__schema__, 1)
  end

  defp custom_type_module?(module) when is_atom(module) do
    Code.ensure_loaded?(module) and function_exported?(module, :type_definition, 0)
  end

  defp custom_type_module?(_), do: false

  defp safe_type_definition(module) when is_atom(module) do
    if custom_type_module?(module), do: module.type_definition(), else: module
  rescue
    _ -> module
  end
end
