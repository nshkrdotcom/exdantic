defmodule Exdantic.FieldMeta do
  @moduledoc """
  Struct for field metadata in Exdantic schemas.

  This module defines the structure and types for field metadata used
  throughout the Exdantic schema system.
  """

  @enforce_keys [:name, :type, :required]
  defstruct [
    :name,
    :type,
    :description,
    :example,
    :examples,
    :required,
    :optional,
    :default,
    :constraints,
    extra: %{}
  ]

  @type t :: %__MODULE__{
          name: atom(),
          type: Exdantic.Types.type_definition(),
          description: String.t() | nil,
          example: term() | nil,
          examples: [term()] | nil,
          required: boolean(),
          optional: boolean() | nil,
          default: term() | nil,
          constraints: [term()] | nil,
          extra: %{String.t() => term()}
        }

  @doc """
  Creates a new FieldMeta struct with the given parameters.

  ## Parameters
    * `name` - The field name (atom)
    * `type` - The field type definition
    * `required` - Whether the field is required (boolean)

  ## Examples

      iex> Exdantic.FieldMeta.new(:email, {:type, :string, []}, true)
      %Exdantic.FieldMeta{name: :email, type: {:type, :string, []}, required: true}
  """
  @spec new(atom(), Exdantic.Types.type_definition(), boolean()) :: t()
  def new(name, type, required) do
    %__MODULE__{
      name: name,
      type: type,
      required: required
    }
  end
end
