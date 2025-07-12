Mix.install([
  {:jsv, "~> 0.10"},
  {:exdantic, "~> 0.0.2"}
])

defmodule UserSchema do
  use Exdantic, define_struct: true

  schema "User account information" do
    field :name, :string do
      required()
      min_length(2)
      description("User's full name")
    end

    field :email, :string do
      required()
      format(~r/^[^\s@]+@[^\s@]+\.[^\s@]+$/)
      description("Primary email address")
    end

    field :age, :integer do
      optional()
      gt(0)
      lt(150)
      description("User's age in years")
    end

    field :active, :boolean do
      default(true)
      description("Whether the account is active")
    end

    # Cross-field validation
    model_validator(:validate_adult_email)

    # Computed field derived from other fields
    computed_field(:display_name, :string, :generate_display_name)

    config do
      title("User Schema")
      strict(true)
    end
  end

  def validate_adult_email(input) do
    if input.age && input.age >= 18 && String.contains?(input.email, "example.com") do
      {:error, "Adult users cannot use example.com emails"}
    else
      {:ok, input}
    end
  end

  def generate_display_name(input) do
    display =
      if input.age do
        "#{input.name} (#{input.age})"
      else
        input.name
      end

    {:ok, display}
  end

  use JSV.Schema

  def json_schema do
    JSV.Schema.with_cast([__MODULE__, :from_jsv])
  end

  defcast from_jsv(data) do
    validate(data)
  end

  def format_error("from_jsv", [exdantic_error | _], _) do
    Exdantic.Error.format(exdantic_error)
  end
end

# Test the integration
IO.puts("Building JSV schema...")
root = JSV.build!(UserSchema) |> dbg()

IO.puts("Testing with string keys (typical JSON)...")
data = %{"name" => "alice", "email" => "foo@bar.com"}

try do
  result = JSV.validate!(data, root)
  IO.puts("SUCCESS: #{inspect(result)}")
rescue
  e ->
    IO.puts("ERROR: #{inspect(e)}")
    IO.puts("Message: #{Exception.message(e)}")
end

IO.puts("\nTesting with atom keys...")
data_atoms = %{name: "alice", email: "foo@bar.com"}

try do
  result = JSV.validate!(data_atoms, root)
  IO.puts("SUCCESS: #{inspect(result)}")
rescue
  e ->
    IO.puts("ERROR: #{inspect(e)}")
    IO.puts("Message: #{Exception.message(e)}")
end