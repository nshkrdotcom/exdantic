Mix.install([
  {:exdantic, "~> 0.0.2"},
  {:jason, "~> 1.4"}
])

defmodule StrictSchema do
  use Exdantic, define_struct: true

  schema "Strict validation example" do
    field :name, :string do
      required()
      min_length(2)
    end

    field :email, :string do
      required()
      format(~r/^[^\s@]+@[^\s@]+\.[^\s@]+$/)
    end

    field :age, :integer do
      optional()
      gt(0)
      lt(120)
    end

    config do
      title("Strict User Schema")
      strict(true)  # Rejects unknown fields
    end
  end
end

defmodule NonStrictSchema do
  use Exdantic, define_struct: true

  schema "Non-strict validation example" do
    field :name, :string do
      required()
      min_length(2)
    end

    field :email, :string do
      required()
      format(~r/^[^\s@]+@[^\s@]+\.[^\s@]+$/)
    end

    field :age, :integer do
      optional()
      gt(0)
      lt(120)
    end

    config do
      title("Non-Strict User Schema")
      strict(false)  # Allows unknown fields
    end
  end
end

IO.puts("=== EXDANTIC STRICT vs NON-STRICT BEHAVIOR ANALYSIS ===\n")

# Test cases covering various scenarios
test_cases = [
  # Basic valid data with atom keys
  {"Valid atom keys", %{name: "Alice", email: "alice@example.com", age: 30}},
  
  # Basic valid data with string keys  
  {"Valid string keys", %{"name" => "Bob", "email" => "bob@example.com", "age" => 25}},
  
  # Mixed keys
  {"Mixed keys", %{"name" => "Charlie", "email" => "charlie@example.com", "age" => 35}},
  
  # Extra fields with atom keys
  {"Extra fields (atom keys)", %{name: "David", email: "david@example.com", age: 40, role: "admin", active: true}},
  
  # Extra fields with string keys (typical JSON)
  {"Extra fields (string keys)", %{"name" => "Eve", "email" => "eve@example.com", "age" => 28, "role" => "user", "created_at" => "2024-01-01"}},
  
  # Missing required field
  {"Missing required field", %{name: "Frank"}},
  
  # Invalid field value
  {"Invalid email", %{name: "Grace", email: "invalid-email", age: 32}},
  
  # Nested extra data (common in APIs)
  {"Nested extra data", %{
    "name" => "Henry", 
    "email" => "henry@example.com", 
    "age" => 45,
    "profile" => %{"bio" => "Software engineer", "skills" => ["elixir", "rust"]},
    "metadata" => %{"source" => "api", "version" => "v2"}
  }}
]

test_schema = fn schema_name, schema_module, test_name, data ->
  IO.puts("#{schema_name} - #{test_name}:")
  IO.puts("  Input: #{inspect(data, limit: :infinity)}")
  
  case schema_module.validate(data) do
    {:ok, result} -> 
      IO.puts("  ✅ SUCCESS: #{inspect(result, limit: :infinity)}")
    {:error, errors} -> 
      IO.puts("  ❌ ERROR: #{inspect(errors, limit: :infinity)}")
  end
  IO.puts("")
end

# Run all test cases for both schemas
Enum.each(test_cases, fn {test_name, data} ->
  test_schema.("STRICT", StrictSchema, test_name, data)
  test_schema.("NON-STRICT", NonStrictSchema, test_name, data)
  IO.puts("---")
end)

# Real-world JSON API example
IO.puts("=== REAL-WORLD JSON API SCENARIO ===\n")

json_from_api = """
{
  "name": "API User",
  "email": "user@api.com", 
  "age": 29,
  "id": "12345",
  "created_at": "2024-01-15T10:30:00Z",
  "updated_at": "2024-01-15T10:30:00Z",
  "metadata": {
    "source": "registration",
    "ip_address": "192.168.1.1"
  }
}
"""

IO.puts("Typical JSON from API:")
IO.puts(json_from_api)

parsed_json = Jason.decode!(json_from_api)
IO.puts("Parsed JSON: #{inspect(parsed_json, limit: :infinity)}\n")

test_schema.("STRICT", StrictSchema, "Real API JSON", parsed_json)
test_schema.("NON-STRICT", NonStrictSchema, "Real API JSON", parsed_json)

# Performance comparison
IO.puts("=== PERFORMANCE IMPLICATIONS ===\n")

large_data_atom = %{
  name: "Performance Test",
  email: "perf@test.com", 
  age: 30
}

large_data_string = %{
  "name" => "Performance Test",
  "email" => "perf@test.com", 
  "age" => 30
}

large_data_with_extras = Map.merge(large_data_string, %{
  "extra1" => "value1", "extra2" => "value2", "extra3" => "value3",
  "extra4" => "value4", "extra5" => "value5", "extra6" => "value6"
})

# Simple timing function
defmodule Benchmark do
  def time(fun) do
    {time, result} = :timer.tc(fun)
    {time / 1000, result}  # Convert to milliseconds
  end
end

{strict_time, _} = Benchmark.time(fn -> 
  Enum.each(1..1000, fn _ -> StrictSchema.validate(large_data_atom) end)
end)

{nonstrict_time, _} = Benchmark.time(fn -> 
  Enum.each(1..1000, fn _ -> NonStrictSchema.validate(large_data_atom) end)
end)

{strict_with_extras_time, _} = Benchmark.time(fn -> 
  Enum.each(1..1000, fn _ -> StrictSchema.validate(large_data_with_extras) end)
end)

{nonstrict_with_extras_time, _} = Benchmark.time(fn -> 
  Enum.each(1..1000, fn _ -> NonStrictSchema.validate(large_data_with_extras) end)
end)

IO.puts("Performance (1000 validations):")
IO.puts("  Strict mode (valid data): #{Float.round(strict_time, 2)}ms")
IO.puts("  Non-strict mode (valid data): #{Float.round(nonstrict_time, 2)}ms")
IO.puts("  Strict mode (extra fields): #{Float.round(strict_with_extras_time, 2)}ms")
IO.puts("  Non-strict mode (extra fields): #{Float.round(nonstrict_with_extras_time, 2)}ms")

IO.puts("\n=== KEY INSIGHTS ===")
IO.puts("1. Strict mode ONLY works with atom keys in practice")
IO.puts("2. Non-strict mode handles both atom and string keys gracefully")
IO.puts("3. Real-world JSON APIs always have extra fields")
IO.puts("4. String keys are the norm for external data")
IO.puts("5. Strict mode limits interoperability significantly")