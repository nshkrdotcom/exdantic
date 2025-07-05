
#!/usr/bin/env elixir

# Runtime Schema Generation Example
# Run with: elixir examples/runtime_schema.exs

Mix.install([{:exdantic, path: "."}])

IO.puts("""
🚀 Exdantic Runtime Schema Generation Example
===========================================

This example demonstrates how to create and use schemas dynamically at runtime,
inspired by Pydantic's create_model() functionality.
""")

# Example 1: Basic Runtime Schema Creation
IO.puts("\n📝 Example 1: Basic Runtime Schema Creation")
IO.puts("Creating a User schema dynamically...")

user_fields = [
  {:name, :string, [required: true, min_length: 2, max_length: 50]},
  {:email, :string, [required: true, format: ~r/^[^\s@]+@[^\s@]+\.[^\s@]+$/]},
  {:age, :integer, [required: false, gt: 0, lt: 150]},
  {:active, :boolean, [default: true]},
  {:tags, {:array, :string}, [required: false, min_items: 0, max_items: 10]}
]

user_schema = Exdantic.Runtime.create_schema(user_fields,
  title: "Dynamic User Schema",
  description: "A user schema created at runtime",
  strict: true
)

IO.puts("✅ Schema created: #{user_schema.name}")
IO.puts("   Fields: #{inspect(Exdantic.Runtime.DynamicSchema.field_names(user_schema))}")
IO.puts("   Required: #{inspect(Exdantic.Runtime.DynamicSchema.required_fields(user_schema))}")
IO.puts("   Optional: #{inspect(Exdantic.Runtime.DynamicSchema.optional_fields(user_schema))}")

# Example 2: Validating Data Against Runtime Schema
IO.puts("\n✅ Example 2: Validating Data Against Runtime Schema")

valid_user = %{
  name: "John Doe",
  email: "john@example.com",
  age: 30,
  tags: ["admin", "user"]
}

case Exdantic.Runtime.validate(valid_user, user_schema) do
  {:ok, validated} ->
    IO.puts("✅ Valid user data:")
    IO.inspect(validated, pretty: true)
  {:error, errors} ->
    IO.puts("❌ Validation failed:")
    Enum.each(errors, &IO.puts("   - #{Exdantic.Error.format(&1)}"))
end

# Example 3: Handling Validation Errors
IO.puts("\n❌ Example 3: Handling Validation Errors")

invalid_user = %{
  name: "A",  # Too short
  email: "invalid-email",  # Invalid format
  age: -5,  # Invalid range
  tags: Enum.map(1..15, &"tag#{&1}")  # Too many items
}

case Exdantic.Runtime.validate(invalid_user, user_schema) do
  {:ok, _validated} ->
    IO.puts("✅ Unexpected success")
  {:error, errors} ->
    IO.puts("❌ Expected validation errors:")
    Enum.each(errors, &IO.puts("   - #{Exdantic.Error.format(&1)}"))
end

# Example 4: Complex Nested Schema
IO.puts("\n🏗️ Example 4: Complex Nested Schema")

# Define an address schema
address_fields = [
  {:street, :string, [required: true, min_length: 5]},
  {:city, :string, [required: true, min_length: 2]},
  {:zipcode, :string, [required: true, format: ~r/^\d{5}(-\d{4})?$/]},
  {:country, :string, [default: "USA"]}
]

_address_schema = Exdantic.Runtime.create_schema(address_fields,
  title: "Address Schema"
)

# Create a person schema with nested address
person_fields = [
  {:name, :string, [required: true]},
  {:address, {:map, {:any, :any}}, [required: true]},  # Would be validated separately
  {:contacts, {:array, {:map, {:string, :string}}}, [required: false]}
]

person_schema = Exdantic.Runtime.create_schema(person_fields,
  title: "Person with Address"
)

person_data = %{
  name: "Jane Smith",
  address: %{
    street: "123 Main St",
    city: "Anytown",
    zipcode: "12345"
  },
  contacts: [
    %{"type" => "email", "value" => "jane@example.com"},
    %{"type" => "phone", "value" => "555-1234"}
  ]
}

case Exdantic.Runtime.validate(person_data, person_schema) do
  {:ok, validated} ->
    IO.puts("✅ Complex nested data validated:")
    IO.inspect(validated, pretty: true)
  {:error, errors} ->
    IO.puts("❌ Validation failed:")
    Enum.each(errors, &IO.puts("   - #{Exdantic.Error.format(&1)}"))
end

# Example 5: JSON Schema Generation
IO.puts("\n📋 Example 5: JSON Schema Generation")

json_schema = Exdantic.Runtime.to_json_schema(user_schema)
IO.puts("✅ Generated JSON Schema:")
IO.puts(Jason.encode!(json_schema, pretty: true))

# Example 6: Dynamic Schema Modification
IO.puts("\n🔧 Example 6: Dynamic Schema Modification")

# Start with a basic schema
basic_fields = [
  {:id, :integer, [required: true]},
  {:name, :string, [required: true]}
]

basic_schema = Exdantic.Runtime.create_schema(basic_fields, title: "Basic Schema")

# Add more fields dynamically (by creating a new schema)
extended_fields = basic_fields ++ [
  {:created_at, :string, [required: false]},
  {:metadata, {:map, {:string, :any}}, [required: false]}
]

extended_schema = Exdantic.Runtime.create_schema(extended_fields, title: "Extended Schema")

IO.puts("Basic schema fields: #{inspect(Exdantic.Runtime.DynamicSchema.field_names(basic_schema))}")
IO.puts("Extended schema fields: #{inspect(Exdantic.Runtime.DynamicSchema.field_names(extended_schema))}")

# Example 7: Conditional Field Requirements
IO.puts("\n🔀 Example 7: Conditional Field Requirements")

# Create different schemas based on user type
create_user_schema = fn user_type ->
  base_fields = [
    {:username, :string, [required: true, min_length: 3]},
    {:email, :string, [required: true, format: ~r/@/]}
  ]

  additional_fields = case user_type do
    :admin ->
      [
        {:permissions, {:array, :string}, [required: true, min_items: 1]},
        {:admin_level, :integer, [required: true, gteq: 1, lteq: 5]}
      ]
    :customer ->
      [
        {:customer_id, :string, [required: true]},
        {:subscription_level, :string, [choices: ["basic", "premium", "enterprise"]]}
      ]
    :guest ->
      [
        {:session_id, :string, [required: true]},
        {:expires_at, :string, [required: true]}
      ]
  end

  Exdantic.Runtime.create_schema(base_fields ++ additional_fields,
    title: "#{String.capitalize(to_string(user_type))} User Schema"
  )
end

# Test different user types
for user_type <- [:admin, :customer, :guest] do
  schema = create_user_schema.(user_type)
  IO.puts("#{user_type} schema fields: #{inspect(Exdantic.Runtime.DynamicSchema.field_names(schema))}")
end

# Example 8: Schema Validation with Different Configurations
IO.puts("\n⚙️ Example 8: Schema Validation with Different Configurations")

test_data = %{
  name: "Test User",
  email: "test@example.com",
  extra_field: "should be ignored or rejected"
}

# Lenient validation (allows extra fields)
IO.puts("Lenient validation (allows extra fields):")
case Exdantic.Runtime.validate(test_data, user_schema, strict: false) do
  {:ok, _validated} ->
    IO.puts("✅ Accepted with extra fields")
  {:error, errors} ->
    IO.puts("❌ Rejected: #{inspect(errors)}")
end

# Strict validation (rejects extra fields)
IO.puts("Strict validation (rejects extra fields):")
case Exdantic.Runtime.validate(test_data, user_schema, strict: true) do
  {:ok, _validated} ->
    IO.puts("✅ Unexpected acceptance")
  {:error, errors} ->
    IO.puts("❌ Expected rejection:")
    Enum.each(errors, &IO.puts("   - #{Exdantic.Error.format(&1)}"))
end

# Example 9: Performance Comparison
IO.puts("\n⚡ Example 9: Performance Comparison")

# Create a schema once
performance_schema = Exdantic.Runtime.create_schema([
  {:id, :integer, [required: true]},
  {:value, :string, [required: true]}
])

test_records = for i <- 1..1000 do
  %{id: i, value: "record_#{i}"}
end

# Time the validation
{time_us, results} = :timer.tc(fn ->
  Enum.map(test_records, fn record ->
    Exdantic.Runtime.validate(record, performance_schema)
  end)
end)

successful_validations = Enum.count(results, &match?({:ok, _}, &1))
time_ms = time_us / 1000

IO.puts("✅ Validated #{successful_validations} records in #{Float.round(time_ms, 2)}ms")
IO.puts("   Average: #{Float.round(time_ms / 1000, 4)}ms per validation")

IO.puts("""

🎯 Summary
==========
This example demonstrated:
1. ✅ Basic runtime schema creation with field definitions
2. ✅ Data validation against runtime schemas
3. ❌ Error handling and reporting
4. 🏗️ Complex nested data structures
5. 📋 JSON Schema generation
6. 🔧 Dynamic schema modification
7. 🔀 Conditional field requirements
8. ⚙️ Different validation configurations
9. ⚡ Performance characteristics

Runtime schemas enable dynamic validation patterns similar to Pydantic's
create_model() functionality, perfect for DSPy integration patterns.
""")

# Clean exit
:ok
