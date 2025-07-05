#!/usr/bin/env elixir

# This file demonstrates the new struct pattern functionality
# Run with: elixir demo_struct_pattern.exs

Code.require_file("mix.exs")
Mix.install(File.read!("mix.exs") |> Code.eval_string() |> elem(0).project()[:deps])

# Traditional schema (returns map)
defmodule UserMapSchema do
  use Exdantic, define_struct: false

  schema "User without struct" do
    field :name, :string do
      required()
      min_length(1)
    end

    field :age, :integer do
      optional()
      gteq(0)
    end

    field :email, :string do
      required()
      format(~r/@/)
    end

    field :active, :boolean do
      default(true)
    end
  end
end

# New struct schema (returns struct)
defmodule UserStructSchema do
  use Exdantic, define_struct: true

  schema "User with struct" do
    field :name, :string do
      required()
      min_length(1)
    end

    field :age, :integer do
      optional()
      gteq(0)
    end

    field :email, :string do
      required()
      format(~r/@/)
    end

    field :active, :boolean do
      default(true)
    end
  end
end

# Sample data
data = %{
  name: "Alice Johnson",
  age: 28,
  email: "alice@example.com"
}

IO.puts("=== Exdantic Struct Pattern Demo ===\n")

# Traditional map validation
IO.puts("1. Traditional Map Schema:")
{:ok, map_result} = UserMapSchema.validate(data)
IO.puts("   Result type: #{if is_struct(map_result), do: "struct", else: "map"}")
IO.puts("   Struct enabled?: #{UserMapSchema.__struct_enabled__?()}")
IO.puts("   Data: #{inspect(map_result)}")

IO.puts("\n2. New Struct Schema:")
{:ok, struct_result} = UserStructSchema.validate(data)
IO.puts("   Result type: #{if is_struct(struct_result), do: "struct", else: "map"}")
IO.puts("   Struct enabled?: #{UserStructSchema.__struct_enabled__?()}")
IO.puts("   Struct module: #{struct_result.__struct__}")
IO.puts("   Data: #{inspect(struct_result)}")

IO.puts("\n3. Struct Features:")
IO.puts("   Struct fields: #{inspect(UserStructSchema.__struct_fields__())}")
IO.puts("   Has dump function?: #{function_exported?(UserStructSchema, :dump, 1)}")

IO.puts("\n4. Struct Serialization:")
{:ok, dumped} = UserStructSchema.dump(struct_result)
IO.puts("   Dumped back to map: #{inspect(dumped)}")

IO.puts("\n5. Field Access:")
IO.puts("   Name: #{struct_result.name}")
IO.puts("   Age: #{struct_result.age}")
IO.puts("   Email: #{struct_result.email}")
IO.puts("   Active: #{struct_result.active}")

IO.puts("\n6. Backward Compatibility:")
IO.puts("   Map schema still works exactly as before!")
IO.puts("   Both schemas validate the same data successfully.")
IO.puts("   No existing functionality changed.")

IO.puts("\n=== Demo Complete ===")