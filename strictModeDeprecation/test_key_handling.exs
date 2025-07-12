Mix.install([
  {:exdantic, "~> 0.0.2"}
])

defmodule SimpleSchema do
  use Exdantic, define_struct: true

  schema "Simple test schema" do
    field :name, :string do
      required()
    end

    field :email, :string do
      required()
    end

    config do
      strict(true)
    end
  end
end

# Test with string keys - this should fail in strict mode
IO.puts("Testing with string keys...")
string_key_data = %{"name" => "alice", "email" => "foo@bar.com"}

case SimpleSchema.validate(string_key_data) do
  {:ok, result} -> 
    IO.puts("SUCCESS: #{inspect(result)}")
  {:error, errors} -> 
    IO.puts("ERROR: #{inspect(errors)}")
end

# Test with atom keys
IO.puts("\nTesting with atom keys...")
atom_key_data = %{name: "alice", email: "foo@bar.com"}

case SimpleSchema.validate(atom_key_data) do
  {:ok, result} -> 
    IO.puts("SUCCESS: #{inspect(result)}")
  {:error, errors} -> 
    IO.puts("ERROR: #{inspect(errors)}")
end

# Test with mixed keys
IO.puts("\nTesting with mixed keys...")
mixed_key_data = %{"name" => "alice", email: "foo@bar.com"}

case SimpleSchema.validate(mixed_key_data) do
  {:ok, result} -> 
    IO.puts("SUCCESS: #{inspect(result)}")
  {:error, errors} -> 
    IO.puts("ERROR: #{inspect(errors)}")
end