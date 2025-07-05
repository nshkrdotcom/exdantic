defmodule Exdantic.ValidationError do
  @moduledoc """
  Exception raised when schema validation fails.

  This exception is raised when using the validate!/1 functions
  and validation fails, providing detailed error information.
  """

  @enforce_keys [:errors]
  defexception [:errors]

  @type t :: %__MODULE__{
          errors: [Exdantic.Error.t()]
        }

  @impl true
  @doc """
  Formats the validation errors into a human-readable message.

  ## Parameters
    * `exception` - The ValidationError exception struct

  ## Returns
    * A formatted error message string

  ## Examples

      iex> errors = [%Exdantic.Error{path: [:name], code: :required, message: "field is required"}]
      iex> exception = %Exdantic.ValidationError{errors: errors}
      iex> Exdantic.ValidationError.message(exception)
      "name: field is required"
  """
  @spec message(t()) :: String.t()
  def message(%{errors: errors}) do
    errors
    |> Enum.map_join("\n", &Exdantic.Error.format/1)
  end
end
