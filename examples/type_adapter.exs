#!/usr/bin/env elixir

# TypeAdapter System Example
# Run with: elixir examples/type_adapter.exs

Mix.install([{:exdantic, path: "."}])

IO.puts("""
🔧 Exdantic TypeAdapter System Example
=====================================

This example demonstrates runtime type validation and serialization without
requiring full schema definitions, similar to Pydantic's TypeAdapter functionality.
""")

# Example 1: Basic Type Validation
IO.puts("\n📝 Example 1: Basic Type Validation")

# Validate basic types
basic_tests = [
  {:string, "hello", "Basic string validation"},
  {:integer, 42, "Basic integer validation"},
  {:boolean, true, "Basic boolean validation"},
  {:float, 3.14, "Basic float validation"},
  {:atom, :example, "Basic atom validation"}
]

for {type, value, description} <- basic_tests do
  case Exdantic.TypeAdapter.validate(type, value) do
    {:ok, validated} ->
      IO.puts("✅ #{description}: #{inspect(validated)}")
    {:error, _errors} ->
      IO.puts("❌ #{description}: Error")
  end
end

# Example 2: Type Coercion
IO.puts("\n🔄 Example 2: Type Coercion")

coercion_tests = [
  {:integer, "123", "String to integer"},
  {:string, 42, "Integer to string"},
  {:string, :atom_value, "Atom to string"},
  {:integer, "not_a_number", "Invalid integer coercion"}
]

for {type, value, description} <- coercion_tests do
  case Exdantic.TypeAdapter.validate(type, value, coerce: true) do
    {:ok, validated} ->
      IO.puts("✅ #{description}: #{inspect(value)} -> #{inspect(validated)}")
    {:error, _errors} ->
      IO.puts("❌ #{description}: #{inspect(value)} -> Error")
  end
end

# Example 3: Complex Type Structures
IO.puts("\n🏗️ Example 3: Complex Type Structures")

# Array validation
array_data = ["apple", "banana", "cherry"]
case Exdantic.TypeAdapter.validate({:array, :string}, array_data) do
  {:ok, validated} ->
    IO.puts("✅ Array of strings: #{inspect(validated)}")
  {:error, _errors} ->
    IO.puts("❌ Array validation failed")
end

# Map validation
_map_data = %{"name" => "John", "age" => 30}
case Exdantic.TypeAdapter.validate({:map, {:string, :integer}}, %{"age" => 30}) do
  {:ok, validated} ->
    IO.puts("✅ Map validation: #{inspect(validated)}")
  {:error, _errors} ->
    IO.puts("❌ Map validation failed")
end

# Mixed map validation
mixed_map = %{"name" => "John", "age" => 30, "tags" => ["admin"]}
mixed_type = {:map, {:string, {:union, [:string, :integer, {:array, :string}]}}}

case Exdantic.TypeAdapter.validate(mixed_type, mixed_map) do
  {:ok, validated} ->
    IO.puts("✅ Mixed map validation: #{inspect(validated)}")
  {:error, _errors} ->
    IO.puts("❌ Mixed map validation failed")
end

# Example 4: Union Types
IO.puts("\n🔀 Example 4: Union Types")

union_type = {:union, [:string, :integer, :boolean]}
union_tests = ["hello", 42, true, 3.14]  # 3.14 should fail

for value <- union_tests do
  case Exdantic.TypeAdapter.validate(union_type, value) do
    {:ok, validated} ->
      IO.puts("✅ Union accepts #{inspect(value)}: #{inspect(validated)}")
    {:error, _errors} ->
      IO.puts("❌ Union rejects #{inspect(value)}")
  end
end

# Example 5: Serialization (Dump)
IO.puts("\n📤 Example 5: Serialization (Dump)")

serialization_tests = [
  {:string, "hello", "String serialization"},
  {:atom, :test_atom, "Atom to string serialization"},
  {{:array, :string}, ["a", "b", "c"], "Array serialization"},
  {{:map, {:string, :integer}}, %{"count" => 5}, "Map serialization"}
]

for {type, value, description} <- serialization_tests do
  case Exdantic.TypeAdapter.dump(type, value) do
    {:ok, serialized} ->
      IO.puts("✅ #{description}: #{inspect(value)} -> #{inspect(serialized)}")
    {:error, reason} ->
      IO.puts("❌ #{description}: #{reason}")
  end
end

# Example 6: Reusable TypeAdapter Instances
IO.puts("\n♻️ Example 6: Reusable TypeAdapter Instances")

# Create reusable adapters for common types
string_array_adapter = Exdantic.TypeAdapter.create({:array, :string}, coerce: true)
_user_data_adapter = Exdantic.TypeAdapter.create({:map, {:string, :any}})

# Test data
test_arrays = [
  ["hello", "world"],
  [:atom1, :atom2],  # Should coerce atoms to strings
  [1, 2, 3]          # Should coerce numbers to strings
]

IO.puts("Testing string array adapter with coercion:")
for array <- test_arrays do
  case Exdantic.TypeAdapter.Instance.validate(string_array_adapter, array) do
    {:ok, validated} ->
      IO.puts("✅ #{inspect(array)} -> #{inspect(validated)}")
    {:error, _errors} ->
      IO.puts("❌ #{inspect(array)} -> Error")
  end
end

# Example 7: Batch Validation
IO.puts("\n📦 Example 7: Batch Validation")

# Validate multiple values at once
email_adapter = Exdantic.TypeAdapter.create(:string)
emails = ["user1@example.com", "user2@example.com", "invalid-email", "user3@example.com"]

case Exdantic.TypeAdapter.Instance.validate_many(email_adapter, emails) do
  {:ok, validated_emails} ->
    IO.puts("✅ All emails valid: #{inspect(validated_emails)}")
  {:error, error_map} ->
    IO.puts("❌ Some emails invalid:")
    for {index, _errors} <- error_map do
      IO.puts("   Email #{index}: #{inspect(Enum.at(emails, index))} -> Error")
    end
end

# Example 8: JSON Schema Generation
IO.puts("\n📋 Example 8: JSON Schema Generation")

# Generate JSON schemas for different types
schema_examples = [
  {:string, "Simple string type"},
  {{:array, :integer}, "Array of integers"},
  {{:map, {:string, :boolean}}, "Map with string keys and boolean values"},
  {{:union, [:string, :integer]}, "Union of string or integer"}
]

for {type_spec, description} <- schema_examples do
  schema = Exdantic.TypeAdapter.json_schema(type_spec, title: description)
  IO.puts("✅ #{description}:")
  IO.puts("   #{Jason.encode!(schema)}")
end

# Example 9: Complex Nested Validation
IO.puts("\n🎯 Example 9: Complex Nested Validation")

# Define a complex nested structure
user_profile_type = {
  :map, 
  {
    :string, 
    {:union, [
      :string,
      :integer,
      {:array, :string},
      {:map, {:string, :any}}
    ]}
  }
}

complex_profile = %{
  "name" => "John Doe",
  "age" => 30,
  "skills" => ["elixir", "python", "javascript"],
  "address" => %{
    "street" => "123 Main St",
    "city" => "Anytown"
  },
  "active" => true
}

case Exdantic.TypeAdapter.validate(user_profile_type, complex_profile) do
  {:ok, validated} ->
    IO.puts("✅ Complex profile validation succeeded:")
    IO.inspect(validated, pretty: true)
  {:error, errors} ->
    IO.puts("❌ Complex profile validation failed:")
    Enum.each(errors, &IO.puts("   - #{Exdantic.Error.format(&1)}"))
end

# Example 10: Performance Benchmarking
IO.puts("\n⚡ Example 10: Performance Benchmarking")

# Create an adapter for performance testing
perf_adapter = Exdantic.TypeAdapter.create({:map, {:string, :integer}})

# Generate test data
test_data = for i <- 1..1000 do
  %{"id" => i, "value" => i * 2}
end

# Benchmark single validations
{time_single_us, _} = :timer.tc(fn ->
  Enum.each(test_data, fn item ->
    Exdantic.TypeAdapter.validate({:map, {:string, :integer}}, item)
  end)
end)

# Benchmark batch validation
{time_batch_us, _} = :timer.tc(fn ->
  Exdantic.TypeAdapter.Instance.validate_many(perf_adapter, test_data)
end)

IO.puts("✅ Performance comparison (1000 validations):")
IO.puts("   Single validations: #{Float.round(time_single_us / 1000, 2)}ms")
IO.puts("   Batch validation: #{Float.round(time_batch_us / 1000, 2)}ms")
IO.puts("   Speedup: #{Float.round(time_single_us / time_batch_us, 2)}x")

# Example 11: Error Handling Patterns
IO.puts("\n🚨 Example 11: Error Handling Patterns")

# Different ways to handle validation errors
problematic_data = [
  {42, "Should be string"},
  {"hello", "Should be integer"},
  {[1, "mixed", 3], "Should be array of integers"}
]

for {data, description} <- problematic_data do
  case Exdantic.TypeAdapter.validate(:string, data) do
    {:ok, _validated} ->
      IO.puts("✅ #{description}: Unexpected success")
    {:error, [error]} ->
      IO.puts("❌ #{description}: #{error.message}")
    {:error, errors} when is_list(errors) ->
      IO.puts("❌ #{description}: Multiple errors")
      Enum.each(errors, &IO.puts("     - #{&1.message}"))
  end
end

IO.puts("""

🎯 Summary
==========
This example demonstrated:
1. ✅ Basic type validation for primitive types
2. 🔄 Type coercion capabilities
3. 🏗️ Complex nested type structures
4. 🔀 Union type handling
5. 📤 Value serialization (dump)
6. ♻️ Reusable TypeAdapter instances
7. 📦 Batch validation for performance
8. 📋 JSON Schema generation
9. 🎯 Complex nested validation scenarios
10. ⚡ Performance benchmarking
11. 🚨 Comprehensive error handling

TypeAdapter provides runtime type validation without schemas, perfect for
one-off validations and dynamic type checking in DSPy-style applications.
""")

# Clean exit
:ok
