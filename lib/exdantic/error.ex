defmodule Exdantic.Error do
  @moduledoc """
  Structured error representation for Exdantic validation errors.
  """

  @enforce_keys [:path, :code, :message]
  defstruct [:path, :code, :message]

  @type t :: %__MODULE__{
          path: [atom() | String.t()],
          code: atom(),
          message: String.t()
        }

  @doc """
  Creates a new validation error.

  ## Parameters
    * `path` - Path to the field that caused the error
    * `code` - Error code identifying the type of error
    * `message` - Human-readable error message

  ## Examples

      iex> Exdantic.Error.new([:user, :email], :format, "invalid email format")
      %Exdantic.Error{path: [:user, :email], code: :format, message: "invalid email format"}

      iex> Exdantic.Error.new(:name, :required, "field is required")
      %Exdantic.Error{path: [:name], code: :required, message: "field is required"}
  """
  @spec new([atom() | String.t()] | atom() | String.t(), atom(), String.t()) :: t()
  def new(path, code, message) do
    %__MODULE__{
      path: List.wrap(path),
      code: code,
      message: message
    }
  end

  @doc """
  Formats an error into a human-readable string.

  ## Examples

      iex> error = %Exdantic.Error{path: [:user, :email], code: :format, message: "invalid format"}
      iex> Exdantic.Error.format(error)
      "user.email: invalid format"

      iex> error = %Exdantic.Error{path: [], code: :type, message: "expected string"}
      iex> Exdantic.Error.format(error)
      ": expected string"
  """
  @spec format(t()) :: String.t()
  def format(%__MODULE__{path: path, message: message}) do
    path_str = Enum.map_join(path, ".", &to_string/1)
    "#{path_str}: #{message}"
  end
end
