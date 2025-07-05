defmodule Exdantic.JsonSchema.ReferenceStore do
  @moduledoc """
  Manages schema references and definitions for JSON Schema generation.

  This module provides a stateful store for tracking schema references
  and their corresponding JSON Schema definitions during conversion.
  """

  @type state :: %{
          refs: MapSet.t(module()),
          definitions: %{String.t() => map()}
        }

  @doc """
  Starts a new reference store process.

  ## Returns
    * `{:ok, pid}` on success

  ## Examples

      iex> {:ok, store} = Exdantic.JsonSchema.ReferenceStore.start_link()
      {:ok, #PID<...>}
  """
  @spec start_link() :: {:ok, pid()}
  def start_link do
    Agent.start_link(fn ->
      %{
        refs: MapSet.new(),
        definitions: %{}
      }
    end)
  end

  @doc """
  Stops the reference store process.

  ## Parameters
    * `agent` - The reference store process PID

  ## Examples

      iex> {:ok, store} = Exdantic.JsonSchema.ReferenceStore.start_link()
      iex> Exdantic.JsonSchema.ReferenceStore.stop(store)
      :ok
  """
  @spec stop(pid()) :: :ok
  def stop(agent) do
    Agent.stop(agent)
  end

  @doc """
  Adds a schema module reference to track for processing.

  ## Parameters
    * `agent` - The reference store process PID
    * `module` - The schema module to add as a reference

  ## Examples

      iex> Exdantic.JsonSchema.ReferenceStore.add_reference(store, MySchema)
      :ok
  """
  @spec add_reference(pid(), module()) :: :ok
  def add_reference(agent, module) when is_atom(module) do
    Agent.update(agent, fn state ->
      %{state | refs: MapSet.put(state.refs, module)}
    end)
  end

  @doc """
  Gets all module references currently tracked in the store.

  ## Parameters
    * `agent` - The reference store process PID

  ## Returns
    * List of module atoms

  ## Examples

      iex> Exdantic.JsonSchema.ReferenceStore.get_references(store)
      [MySchema, AnotherSchema]
  """
  @spec get_references(pid()) :: [module()]
  def get_references(agent) do
    Agent.get(agent, fn state ->
      MapSet.to_list(state.refs)
    end)
  end

  @doc """
  Checks if a module reference is already tracked in the store.

  ## Parameters
    * `agent` - The reference store process PID
    * `module` - The module to check for

  ## Returns
    * `true` if the module is tracked, `false` otherwise

  ## Examples

      iex> Exdantic.JsonSchema.ReferenceStore.has_reference?(store, MySchema)
      true
  """
  @spec has_reference?(pid(), module()) :: boolean()
  def has_reference?(agent, module) do
    Agent.get(agent, fn state ->
      MapSet.member?(state.refs, module)
    end)
  end

  @doc """
  Adds a JSON Schema definition for a module.

  ## Parameters
    * `agent` - The reference store process PID
    * `module` - The module for which to store the schema definition
    * `schema` - The JSON Schema map representation

  ## Examples

      iex> schema = %{"type" => "object", "properties" => %{}}
      iex> Exdantic.JsonSchema.ReferenceStore.add_definition(store, MySchema, schema)
      :ok
  """
  @spec add_definition(pid(), module(), map()) :: :ok
  def add_definition(agent, module, schema) do
    Agent.update(agent, fn state ->
      %{state | definitions: Map.put(state.definitions, module_name(module), schema)}
    end)
  end

  @doc """
  Checks if a schema definition exists for a module.

  ## Parameters
    * `agent` - The reference store process PID
    * `module` - The module to check for a definition

  ## Returns
    * `true` if a definition exists, `false` otherwise

  ## Examples

      iex> Exdantic.JsonSchema.ReferenceStore.has_definition?(store, MySchema)
      false
  """
  @spec has_definition?(pid(), module()) :: boolean()
  def has_definition?(agent, module) do
    Agent.get(agent, fn state ->
      Map.has_key?(state.definitions, module_name(module))
    end)
  end

  @doc """
  Gets all schema definitions currently stored.

  ## Parameters
    * `agent` - The reference store process PID

  ## Returns
    * Map of module names to their JSON Schema definitions

  ## Examples

      iex> Exdantic.JsonSchema.ReferenceStore.get_definitions(store)
      %{"MySchema" => %{"type" => "object"}}
  """
  @spec get_definitions(pid()) :: %{String.t() => map()}
  def get_definitions(agent) do
    Agent.get(agent, fn state -> state.definitions end)
  end

  @doc """
  Generates a JSON Schema reference path for a module.

  ## Parameters
    * `module` - The module to generate a reference path for

  ## Returns
    * JSON Schema reference string in the format "#/definitions/ModuleName"

  ## Examples

      iex> Exdantic.JsonSchema.ReferenceStore.ref_path(MySchema)
      "#/definitions/MySchema"
  """
  @spec ref_path(module()) :: String.t()
  def ref_path(module) do
    "#/definitions/#{module_name(module)}"
  end

  @spec module_name(module()) :: String.t()
  defp module_name(module) do
    if is_atom(module) do
      # Handle plain atoms by converting to string and extracting last part
      module_string =
        module
        |> Atom.to_string()
        |> String.replace_prefix("Elixir.", "")

      # For atoms with special characters that can't be split by Module.split,
      # we need to handle them differently
      case String.split(module_string, ".") do
        [single_name] -> single_name
        parts -> List.last(parts)
      end
    else
      # Handle actual modules
      try do
        module
        |> Module.split()
        |> List.last()
      rescue
        ArgumentError ->
          # If Module.split fails, fall back to atom string conversion
          module
          |> Atom.to_string()
          |> String.replace_prefix("Elixir.", "")
          |> String.split(".")
          |> List.last()
      end
    end
  end
end
