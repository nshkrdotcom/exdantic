defmodule Exdantic.Settings.Loader do
  @moduledoc false

  alias Exdantic.Settings.{Decode, DeepMerge, Env, Keys}

  @type load_result :: {:ok, map()} | {:error, [Exdantic.Error.t()]}

  @spec load_env_values(module(), map(), keyword()) :: load_result()
  def load_env_values(schema_module, env_map, opts) do
    fields = schema_module.__schema__(:fields)
    env_entries = Map.to_list(env_map)

    {values, errors} =
      Enum.reduce(fields, {%{}, []}, fn {name, meta}, {acc, errs} ->
        candidates =
          Keys.candidate_keys(
            name,
            meta,
            Keyword.get(opts, :env_prefix, ""),
            Keyword.get(opts, :env_nested_delimiter, "__")
          )

        path = [name]

        case build_field_value(meta.type, candidates, env_map, env_entries, path, opts) do
          {:ok, :not_set} ->
            {acc, errs}

          {:ok, value} ->
            {Map.put(acc, name, value), errs}

          {:error, field_errors} ->
            {acc, [field_errors | errs]}
        end
      end)

    final_errors =
      errors
      |> Enum.reverse()
      |> List.flatten()

    if final_errors == [], do: {:ok, values}, else: {:error, final_errors}
  end

  defp build_field_value(type, candidates, env_map, env_entries, path, opts) do
    top_level = decode_top_level(type, candidates, env_map, path, opts)
    exploded = decode_exploded(type, candidates, env_entries, path, opts)

    case collect_decode_errors(top_level, exploded) do
      [] ->
        merge_decode_values(top_level, exploded)

      errors ->
        {:error, errors}
    end
  end

  defp collect_decode_errors({:error, e1}, {:error, e2}), do: e1 ++ e2
  defp collect_decode_errors({:error, e}, _), do: e
  defp collect_decode_errors(_, {:error, e}), do: e
  defp collect_decode_errors({:ok, _}, {:ok, _}), do: []

  defp merge_decode_values({:ok, :not_set}, {:ok, :not_set}), do: {:ok, :not_set}
  defp merge_decode_values({:ok, value}, {:ok, :not_set}), do: {:ok, value}
  defp merge_decode_values({:ok, :not_set}, {:ok, value}), do: {:ok, value}

  defp merge_decode_values({:ok, left}, {:ok, right}) when is_map(left) and is_map(right),
    do: {:ok, DeepMerge.deep_merge(left, right)}

  # Exploded values take precedence over top-level values.
  defp merge_decode_values({:ok, _left}, {:ok, right}), do: {:ok, right}

  defp decode_top_level(type, candidates, env_map, path, opts) do
    case find_first_env_value(candidates, env_map, opts) do
      :not_found ->
        {:ok, :not_set}

      {:ok, value} ->
        Decode.decode_env_value(type, to_string(value), path, opts)
    end
  end

  defp decode_exploded(type, candidates, env_entries, path, opts) do
    if Decode.supports_exploded_nested?(type) do
      delimiter = Keyword.get(opts, :env_nested_delimiter, "__")

      candidates
      |> Enum.reverse()
      |> Enum.reduce_while({:ok, %{}}, fn candidate, {:ok, acc} ->
        prefix = Env.lookup_key(candidate <> delimiter, opts)
        entries = exploded_entries(env_entries, prefix, opts)

        case decode_prefix_entries(type, entries, path, opts, delimiter) do
          {:ok, map} when map_size(map) > 0 ->
            {:cont, {:ok, DeepMerge.deep_merge(acc, map)}}

          {:ok, _} ->
            {:cont, {:ok, acc}}

          {:error, errors} ->
            {:halt, {:error, errors}}
        end
      end)
      |> case do
        {:ok, merged} when map_size(merged) == 0 -> {:ok, :not_set}
        {:ok, merged} -> {:ok, merged}
        {:error, _} = err -> err
      end
    else
      {:ok, :not_set}
    end
  end

  defp decode_prefix_entries(type, entries, path, opts, delimiter) do
    Enum.reduce_while(entries, {:ok, %{}}, fn {full_key, value}, {:ok, acc} ->
      case decode_single_exploded_entry(type, full_key, to_string(value), path, opts, delimiter) do
        {:ok, :skip} ->
          {:cont, {:ok, acc}}

        {:ok, {parts, decoded}} ->
          updated = deep_put(acc, parts, decoded)
          {:cont, {:ok, updated}}

        {:error, errors} ->
          {:halt, {:error, errors}}
      end
    end)
  end

  defp decode_single_exploded_entry(type, tail_key, value, path, opts, delimiter) do
    normalized_tail =
      tail_key
      |> String.split(delimiter)
      |> Enum.reject(&(&1 == ""))
      |> Enum.join(delimiter)

    if normalized_tail == "" do
      {:ok, :skip}
    else
      with {:ok, field_path_parts, leaf_type} <-
             resolve_exploded_path(type, normalized_tail, opts, delimiter),
           {:ok, decoded} <-
             Decode.decode_exploded_leaf(leaf_type, value, path ++ field_path_parts, opts) do
        {:ok, {field_path_parts, decoded}}
      else
        :error -> {:ok, :skip}
        {:error, _} = err -> err
      end
    end
  end

  defp resolve_exploded_path(type, tail, opts, delimiter),
    do: resolve_exploded_path(type, tail, opts, delimiter, [])

  defp resolve_exploded_path(_type, "", _opts, _delimiter, _acc), do: :error

  defp resolve_exploded_path(type, tail, opts, delimiter, acc) do
    case Decode.resolve_nested_prefix(type, tail, opts, delimiter) do
      {:ok, name, leaf_type, ""} ->
        {:ok, acc ++ [Atom.to_string(name)], leaf_type}

      {:ok, name, next_type, rest_tail} ->
        if match?({:array, _, _}, next_type) do
          :error
        else
          resolve_exploded_path(
            next_type,
            rest_tail,
            opts,
            delimiter,
            acc ++ [Atom.to_string(name)]
          )
        end

      :error ->
        :error
    end
  end

  defp exploded_entries(env_entries, normalized_prefix, opts) do
    ignore_empty = Keyword.get(opts, :ignore_empty, false)

    env_entries
    |> Enum.filter(fn {key, _value} -> String.starts_with?(key, normalized_prefix) end)
    |> Enum.reject(fn {_key, value} -> ignore_empty and value == "" end)
    |> Enum.map(fn {key, value} ->
      tail = String.replace_prefix(key, normalized_prefix, "")
      {tail, value}
    end)
    |> Enum.sort_by(fn {key, _} -> key end)
  end

  defp find_first_env_value(candidates, env_map, opts) do
    Enum.find_value(candidates, :not_found, fn candidate ->
      case Env.lookup(env_map, candidate, opts) do
        {:ok, value} -> {:ok, value}
        :not_found -> false
      end
    end)
  end

  defp deep_put(map, [key], value), do: Map.put(map, key, value)

  defp deep_put(map, [key | rest], value) do
    existing = Map.get(map, key, %{})
    next = if is_map(existing), do: existing, else: %{}
    Map.put(map, key, deep_put(next, rest, value))
  end
end
