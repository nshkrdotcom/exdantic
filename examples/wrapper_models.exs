#!/usr/bin/env elixir

# Wrapper Models Example
# Run with: elixir examples/wrapper_models.exs

Mix.install([{:exdantic, path: "."}])

IO.puts("""
🎁 Exdantic Wrapper Models Example
=================================

This example demonstrates temporary single-field validation schemas for complex
type coercion, similar to Pydantic's create_model("Wrapper", value=(type, ...)).
""")

# Example 1: Basic Wrapper Creation and Validation
IO.puts("\n📝 Example 1: Basic Wrapper Creation and Validation")

# Create a simple wrapper for score validation
score_wrapper = Exdantic.Wrapper.create_wrapper(:score, :integer,
  constraints: [gteq: 0, lteq: 100],
  description: "Test score between 0 and 100"
)

IO.puts("✅ Created score wrapper: #{score_wrapper.name}")

# Test valid scores
valid_scores = [85, 92, 76, 100, 0]
for score <- valid_scores do
  case Exdantic.Wrapper.validate_and_extract(score_wrapper, score, :score) do
    {:ok, validated} ->
      IO.puts("✅ Score #{score} -> #{validated}")
    {:error, _errors} ->
      IO.puts("❌ Score #{score} -> Error")
  end
end

# Test invalid scores
invalid_scores = [-5, 150, "not_a_number"]
for score <- invalid_scores do
  case Exdantic.Wrapper.validate_and_extract(score_wrapper, score, :score) do
    {:ok, validated} ->
      IO.puts("✅ Score #{inspect(score)} -> #{validated} (unexpected)")
    {:error, errors} ->
      IO.puts("❌ Score #{inspect(score)} -> #{hd(errors).message}")
  end
end

# Example 2: One-Step Wrapper Validation
IO.puts("\n⚡ Example 2: One-Step Wrapper Validation")

# Skip the wrapper creation step for simple validations
one_step_tests = [
  {:email, :string, "user@example.com", [constraints: [format: ~r/@/]]},
  {:age, :integer, "25", [coerce: true, constraints: [gt: 0]]},
  {:percentage, :float, "87.5", [coerce: true, constraints: [gteq: 0.0, lteq: 100.0]]},
  {:username, :string, "john_doe", [constraints: [min_length: 3, max_length: 20]]}
]

for {field, type, value, opts} <- one_step_tests do
  case Exdantic.Wrapper.wrap_and_validate(field, type, value, opts) do
    {:ok, validated} ->
      IO.puts("✅ #{field}: #{inspect(value)} -> #{inspect(validated)}")
    {:error, errors} ->
      IO.puts("❌ #{field}: #{inspect(value)} -> #{hd(errors).message}")
  end
end

# Example 3: Flexible Input Handling
IO.puts("\n🔀 Example 3: Flexible Input Handling")

# Create a flexible wrapper that can handle different input formats
age_wrapper = Exdantic.Wrapper.create_flexible_wrapper(:age, :integer, coerce: true)

# Test different input formats
flexible_inputs = [
  {25, "Raw integer value"},
  {%{age: 30}, "Map with atom key"},
  {%{"age" => "35"}, "Map with string key (needs coercion)"},
  {"40", "String value (needs coercion)"}
]

for {input, description} <- flexible_inputs do
  case Exdantic.Wrapper.validate_flexible(age_wrapper, input, :age) do
    {:ok, validated} ->
      IO.puts("✅ #{description}: #{inspect(input)} -> #{validated}")
    {:error, _errors} ->
      IO.puts("❌ #{description}: #{inspect(input)} -> Error")
  end
end

# Example 4: Multiple Wrapper Operations
IO.puts("\n📦 Example 4: Multiple Wrapper Operations")

# Create multiple wrappers for a user registration form
user_specs = [
  {:username, :string, [constraints: [min_length: 3, max_length: 20]]},
  {:email, :string, [constraints: [format: ~r/^[^\s@]+@[^\s@]+\.[^\s@]+$/]]},
  {:age, :integer, [constraints: [gteq: 13, lteq: 120]]},
  {:newsletter, :boolean, [default: false]}
]

user_wrappers = Exdantic.Wrapper.create_multiple_wrappers(user_specs)

IO.puts("✅ Created #{map_size(user_wrappers)} user field wrappers")

# Validate a complete user registration
registration_data = %{
  username: "john_doe",
  email: "john@example.com", 
  age: 25,
  newsletter: true
}

case Exdantic.Wrapper.validate_multiple(user_wrappers, registration_data) do
  {:ok, validated_user} ->
    IO.puts("✅ User registration validated:")
    IO.inspect(validated_user, pretty: true)
  {:error, errors_by_field} ->
    IO.puts("❌ User registration failed:")
    for {field, errors} <- errors_by_field do
      IO.puts("   #{field}: #{hd(errors).message}")
    end
end

# Example 5: Wrapper Factory Pattern
IO.puts("\n🏭 Example 5: Wrapper Factory Pattern")

# Create reusable wrapper factories for common types
email_factory = Exdantic.Wrapper.create_wrapper_factory(:string,
  constraints: [format: ~r/^[^\s@]+@[^\s@]+\.[^\s@]+$/],
  description: "Email address validation"
)

url_factory = Exdantic.Wrapper.create_wrapper_factory(:string,
  constraints: [format: ~r/^https?:\/\/.+/],
  description: "URL validation"
)

# Use factories to create specific field wrappers
user_email_wrapper = email_factory.(:user_email)
admin_email_wrapper = email_factory.(:admin_email)
website_url_wrapper = url_factory.(:website_url)
profile_url_wrapper = url_factory.(:profile_url)

# Test the factory-created wrappers
factory_tests = [
  {user_email_wrapper, "user@example.com", :user_email},
  {admin_email_wrapper, "admin@company.com", :admin_email},
  {website_url_wrapper, "https://example.com", :website_url},
  {profile_url_wrapper, "invalid-url", :profile_url}
]

for {wrapper, value, field} <- factory_tests do
  case Exdantic.Wrapper.validate_and_extract(wrapper, value, field) do
    {:ok, validated} ->
      IO.puts("✅ #{field}: #{value} -> #{validated}")
    {:error, errors} ->
      IO.puts("❌ #{field}: #{value} -> #{hd(errors).message}")
  end
end

# Example 6: Complex Type Wrappers
IO.puts("\n🎯 Example 6: Complex Type Wrappers")

# Wrapper for array validation
tags_wrapper = Exdantic.Wrapper.create_wrapper(:tags, {:array, :string},
  constraints: [min_items: 1, max_items: 5],
  description: "User tags (1-5 strings)"
)

tags_data = ["elixir", "programming", "web-development"]
case Exdantic.Wrapper.validate_and_extract(tags_wrapper, tags_data, :tags) do
  {:ok, validated} ->
    IO.puts("✅ Tags validated: #{inspect(validated)}")
  {:error, _errors} ->
    IO.puts("❌ Tags validation failed")
end

# Wrapper for map validation
metadata_wrapper = Exdantic.Wrapper.create_wrapper(:metadata, {:map, {:string, :any}},
  description: "Flexible metadata map"
)

metadata = %{"version" => "1.0", "author" => "John", "settings" => %{"theme" => "dark"}}
case Exdantic.Wrapper.validate_and_extract(metadata_wrapper, metadata, :metadata) do
  {:ok, validated} ->
    IO.puts("✅ Metadata validated: #{inspect(validated)}")
  {:error, _errors} ->
    IO.puts("❌ Metadata validation failed")
end

# Example 7: JSON Schema Generation from Wrappers
IO.puts("\n📋 Example 7: JSON Schema Generation from Wrappers")

# Generate JSON schemas from wrapper schemas
json_schema = Exdantic.Wrapper.to_json_schema(score_wrapper)
IO.puts("✅ Score wrapper JSON schema:")
IO.puts(Jason.encode!(json_schema, pretty: true))

# Example 8: Wrapper Information and Introspection
IO.puts("\n🔍 Example 8: Wrapper Information and Introspection")

# Get information about wrapper schemas
wrapper_info = Exdantic.Wrapper.wrapper_info(score_wrapper)
IO.puts("✅ Score wrapper information:")
IO.inspect(wrapper_info, pretty: true)

# Check if a schema is a wrapper
IO.puts("Is score_wrapper a wrapper? #{Exdantic.Wrapper.wrapper_schema?(score_wrapper)}")

# Example 9: Error Handling and Recovery
IO.puts("\n🚨 Example 9: Error Handling and Recovery")

# Create a wrapper with multiple constraints
strict_password_wrapper = Exdantic.Wrapper.create_wrapper(:password, :string,
  constraints: [
    min_length: 8,
    max_length: 100,
    format: ~r/^(?=.*[a-z])(?=.*[A-Z])(?=.*\d).+$/  # At least one lower, upper, digit
  ],
  description: "Strong password requirements"
)

password_tests = [
  "weakpass",        # Too simple
  "SHORT",           # Too short  
  "longenoughbutnostrongpattern", # No uppercase/digits
  "ValidPass123"     # Should pass
]

for password <- password_tests do
  case Exdantic.Wrapper.validate_and_extract(strict_password_wrapper, password, :password) do
    {:ok, _validated} ->
      IO.puts("✅ Password '#{password}' accepted")
    {:error, errors} ->
      IO.puts("❌ Password '#{password}' rejected:")
      Enum.each(errors, &IO.puts("   - #{&1.message}"))
  end
end

# Example 10: Performance and Reuse Patterns
IO.puts("\n⚡ Example 10: Performance and Reuse Patterns")

# Create a wrapper once and reuse it many times
id_wrapper = Exdantic.Wrapper.create_wrapper(:id, :integer,
  constraints: [gt: 0],
  description: "Positive integer ID"
)

# Generate test data
test_ids = 1..1000 |> Enum.to_list()

# Time the validation using the same wrapper
{time_us, results} = :timer.tc(fn ->
  Enum.map(test_ids, fn id ->
    Exdantic.Wrapper.validate_and_extract(id_wrapper, id, :id)
  end)
end)

successful = Enum.count(results, &match?({:ok, _}, &1))
time_ms = time_us / 1000

IO.puts("✅ Validated #{successful} IDs in #{Float.round(time_ms, 2)}ms")
IO.puts("   Average: #{Float.round(time_ms / 1000, 4)}ms per validation")

# Compare with one-step validation (less efficient)
{time_one_step_us, _} = :timer.tc(fn ->
  Enum.map(test_ids, fn id ->
    Exdantic.Wrapper.wrap_and_validate(:id, :integer, id, constraints: [gt: 0])
  end)
end)

IO.puts("   One-step validation: #{Float.round(time_one_step_us / 1000, 2)}ms")
IO.puts("   Reuse speedup: #{Float.round(time_one_step_us / time_us, 2)}x")

IO.puts("""

🎯 Summary
==========
This example demonstrated:
1. ✅ Basic wrapper creation and validation
2. ⚡ One-step wrapper validation for convenience
3. 🔀 Flexible input handling (raw values, maps with atom/string keys)
4. 📦 Multiple wrapper operations for complex forms
5. 🏭 Wrapper factory pattern for reusable type definitions
6. 🎯 Complex type wrappers (arrays, maps, unions)
7. 📋 JSON Schema generation from wrappers
8. 🔍 Wrapper introspection and information
9. 🚨 Comprehensive error handling and validation
10. ⚡ Performance optimization through wrapper reuse

Wrapper models provide temporary validation schemas perfect for DSPy-style
single-field validation with complex constraints and coercion.
""")
