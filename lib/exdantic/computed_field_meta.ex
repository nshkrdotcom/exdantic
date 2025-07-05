defmodule Exdantic.ComputedFieldMeta do
  @moduledoc """
  Metadata structure for computed fields in Exdantic schemas.

  Computed fields are derived values that are calculated based on the validated
  data after field and model validation. They extend the validated result with
  additional computed information.
  """

  @enforce_keys [:name, :type, :function_name, :module]
  defstruct [
    :name,
    :type,
    :function_name,
    :module,
    :description,
    :example,
    :readonly
  ]

  @type t :: %__MODULE__{
          name: atom(),
          type: Exdantic.Types.type_definition(),
          function_name: atom(),
          module: module(),
          description: String.t() | nil,
          example: term() | nil,
          readonly: boolean()
        }

  @doc """
  Creates a new ComputedFieldMeta struct.

  ## Parameters
    * `name` - The computed field name (atom)
    * `type` - The computed field type definition
    * `function_name` - The name of the function to call for computation
    * `module` - The module containing the computation function

  ## Examples

      iex> Exdantic.ComputedFieldMeta.new(:uppercased, {:type, :string, []}, :upcase, String)
      %Exdantic.ComputedFieldMeta{
        name: :uppercased,
        type: {:type, :string, []},
        function_name: :upcase,
        module: String,
        readonly: true
      }
  """
  @spec new(atom(), Exdantic.Types.type_definition(), atom(), module()) :: t()
  def new(name, type, function_name, module) do
    %__MODULE__{
      name: name,
      type: type,
      function_name: function_name,
      module: module,
      readonly: true
    }
  end

  @doc """
  Updates the description of a computed field metadata.

  ## Parameters
    * `computed_field_meta` - The ComputedFieldMeta struct
    * `description` - The description text

  ## Examples

      iex> meta = Exdantic.ComputedFieldMeta.new(:uppercased, {:type, :string, []}, :upcase, String)
      iex> updated = Exdantic.ComputedFieldMeta.with_description(meta, "Uppercased version")
      iex> updated.description
      "Uppercased version"
  """
  @spec with_description(t(), String.t()) :: t()
  def with_description(%__MODULE__{} = computed_field_meta, description)
      when is_binary(description) do
    %{computed_field_meta | description: description}
  end

  @doc """
  Adds an example value to a computed field metadata.

  ## Parameters
    * `computed_field_meta` - The ComputedFieldMeta struct
    * `example` - The example value

  ## Examples

      iex> meta = Exdantic.ComputedFieldMeta.new(:uppercased, {:type, :string, []}, :upcase, String)
      iex> updated = Exdantic.ComputedFieldMeta.with_example(meta, "HELLO")
      iex> updated.example
      "HELLO"
  """
  @spec with_example(t(), term()) :: t()
  def with_example(%__MODULE__{} = computed_field_meta, example) do
    %{computed_field_meta | example: example}
  end

  @doc """
  Sets the readonly flag for a computed field metadata.

  While computed fields are readonly by default, this function allows
  explicit control over the readonly flag for special cases.

  ## Parameters
    * `computed_field_meta` - The ComputedFieldMeta struct
    * `readonly` - Whether the field should be marked as readonly

  ## Examples

      iex> meta = Exdantic.ComputedFieldMeta.new(:uppercased, {:type, :string, []}, :upcase, String)
      iex> updated = Exdantic.ComputedFieldMeta.set_readonly(meta, false)
      iex> updated.readonly
      false
  """
  @spec set_readonly(t(), boolean()) :: t()
  def set_readonly(%__MODULE__{} = computed_field_meta, readonly) when is_boolean(readonly) do
    %{computed_field_meta | readonly: readonly}
  end

  @doc """
  Validates that the computation function exists in the specified module.

  ## Parameters
    * `computed_field_meta` - The ComputedFieldMeta struct

  ## Returns
    * `:ok` if the function exists and has the correct arity
    * `{:error, reason}` if the function is invalid

  ## Examples

      # For a module that exists with the function
      iex> meta = Exdantic.ComputedFieldMeta.new(:result, {:type, :string, []}, :upcase, String)
      iex> Exdantic.ComputedFieldMeta.validate_function(meta)
      :ok

      # For a module with a missing function
      iex> meta = Exdantic.ComputedFieldMeta.new(:bad_field, {:type, :string, []}, :missing_function, String)
      iex> Exdantic.ComputedFieldMeta.validate_function(meta)
      {:error, "Function String.missing_function/1 is not defined"}
  """
  @spec validate_function(t()) :: :ok | {:error, String.t()}
  def validate_function(%__MODULE__{} = computed_field_meta) do
    if function_exported?(computed_field_meta.module, computed_field_meta.function_name, 1) do
      :ok
    else
      function_ref = function_reference(computed_field_meta)
      {:error, "Function #{function_ref} is not defined"}
    end
  end

  @doc """
  Returns a string representation of the computed field function reference.

  ## Parameters
    * `computed_field_meta` - The ComputedFieldMeta struct

  ## Returns
    * String in the format "Module.function/arity"

  ## Examples

      iex> meta = Exdantic.ComputedFieldMeta.new(:uppercased, {:type, :string, []}, :upcase, String)
      iex> Exdantic.ComputedFieldMeta.function_reference(meta)
      "String.upcase/1"
  """
  @spec function_reference(t()) :: String.t()
  def function_reference(%__MODULE__{} = computed_field_meta) do
    module_name =
      computed_field_meta.module |> to_string() |> String.replace_prefix("Elixir.", "")

    "#{module_name}.#{computed_field_meta.function_name}/1"
  end

  @doc """
  Converts computed field metadata to a map for debugging or serialization.

  ## Parameters
    * `computed_field_meta` - The ComputedFieldMeta struct

  ## Returns
    * Map representation of the computed field metadata

  ## Examples

      iex> meta = Exdantic.ComputedFieldMeta.new(:uppercased, {:type, :string, []}, :upcase, String)
      iex> |> Exdantic.ComputedFieldMeta.with_description("Uppercased version")
      iex> Exdantic.ComputedFieldMeta.to_map(meta)
      %{
        name: :uppercased,
        type: {:type, :string, []},
        function_name: :upcase,
        module: String,
        description: "Uppercased version",
        example: nil,
        readonly: true,
        function_reference: "String.upcase/1"
      }
  """
  @spec to_map(t()) :: %{
          name: atom(),
          type: Exdantic.Types.type_definition(),
          function_name: atom(),
          module: module(),
          description: String.t() | nil,
          example: term() | nil,
          readonly: boolean(),
          function_reference: String.t()
        }
  def to_map(%__MODULE__{} = computed_field_meta) do
    %{
      name: computed_field_meta.name,
      type: computed_field_meta.type,
      function_name: computed_field_meta.function_name,
      module: computed_field_meta.module,
      description: computed_field_meta.description,
      example: computed_field_meta.example,
      readonly: computed_field_meta.readonly,
      function_reference: function_reference(computed_field_meta)
    }
  end
end
