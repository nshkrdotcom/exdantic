#!/usr/bin/env elixir

# Enhanced Validator Example
# Run with: elixir examples/enhanced_validator.exs

Mix.install([{:exdantic, path: "."}])

IO.puts("""
🚀 Exdantic Enhanced Validator Example
=====================================

This example demonstrates the universal validation interface that works with
runtime schemas, compiled schemas, type specifications, and advanced configuration.
""")

# First, let's create some schemas for testing
defmodule UserSchema do
  use Exdantic

  schema "User account information" do
    field :name, :string do
      description("User's full name")
      min_length(2)
      max_length(50)
    end

    field :email, :string do
      description("User's email address")
      format(~r/^[^\s@]+@[^\s@]+\.[^\s@]+$/)
    end

    field :age, :integer do
      description("User's age")
      optional()
      gt(0)
      lt(150)
    end

    config do
      title("User Schema")
      strict(true)
    end
  end
end

# Example 1: Universal Validation Interface
IO.puts("\n🎯 Example 1: Universal Validation Interface")

user_data = %{
  name: "John Doe",
  email: "john@example.com",
  age: 30
}

# Validate against compiled schema
case Exdantic.EnhancedValidator.validate(UserSchema, user_data) do
  {:ok, validated} ->
    IO.puts("✅ Compiled schema validation succeeded:")
    IO.inspect(validated, pretty: true)
  {:error, _errors} ->
    IO.puts("❌ Compiled schema validation failed")
end

# Create a runtime schema
runtime_schema = Exdantic.Runtime.create_schema([
  {:product_name, :string, [required: true, min_length: 1]},
  {:price, :float, [required: true, gt: 0.0]},
  {:category, :string, [required: false]}
])

product_data = %{
  product_name: "Laptop",
  price: 999.99,
  category: "Electronics"
}

# Validate against runtime schema
case Exdantic.EnhancedValidator.validate(runtime_schema, product_data) do
  {:ok, validated} ->
    IO.puts("✅ Runtime schema validation succeeded:")
    IO.inspect(validated, pretty: true)
  {:error, _errors} ->
    IO.puts("❌ Runtime schema validation failed")
end

# Validate against type specification
type_spec = {:array, {:map, {:string, :integer}}}
type_data = [%{"count" => 1}, %{"total" => 100}]

case Exdantic.EnhancedValidator.validate(type_spec, type_data) do
  {:ok, validated} ->
    IO.puts("✅ Type specification validation succeeded:")
    IO.inspect(validated, pretty: true)
  {:error, _errors} ->
    IO.puts("❌ Type specification validation failed")
end

# Example 2: Configuration-Driven Validation
IO.puts("\n⚙️ Example 2: Configuration-Driven Validation")

test_data = %{
  name: "Jane",
  email: "jane@example.com",
  extra_field: "should be handled based on config"
}

# Create different configurations
strict_config = Exdantic.Config.create(%{
  strict: true,
  extra: :forbid,
  coercion: :none,
  error_format: :detailed
})

lenient_config = Exdantic.Config.create(%{
  strict: false,
  extra: :allow,
  coercion: :safe,
  error_format: :simple
})

# Test with strict configuration
IO.puts("Testing with strict configuration:")
case Exdantic.EnhancedValidator.validate(UserSchema, test_data, config: strict_config) do
  {:ok, _validated} ->
    IO.puts("✅ Strict validation passed (unexpected)")
  {:error, errors} ->
    IO.puts("❌ Strict validation rejected extra field (expected):")
    Enum.each(errors, &IO.puts("   - #{Exdantic.Error.format(&1)}"))
end

# Test with lenient configuration
IO.puts("Testing with lenient configuration:")
case Exdantic.EnhancedValidator.validate(UserSchema, test_data, config: lenient_config) do
  {:ok, validated} ->
    IO.puts("✅ Lenient validation passed:")
    IO.inspect(validated, pretty: true)
  {:error, _errors} ->
    IO.puts("❌ Lenient validation failed")
end

# Example 3: Wrapper Validation
IO.puts("\n🎁 Example 3: Wrapper Validation")

# Validate single values with coercion
coercion_config = Exdantic.Config.create(coercion: :safe)

coercion_tests = [
  {:score, :integer, "85"},
  {:percentage, :float, "87.5"},
  {:active, :boolean, "true"},
  {:tags, {:array, :string}, ["elixir", "programming"]}
]

for {field, type, value} <- coercion_tests do
  case Exdantic.EnhancedValidator.validate_wrapped(field, type, value, config: coercion_config) do
    {:ok, validated} ->
      IO.puts("✅ #{field}: #{inspect(value)} -> #{inspect(validated)}")
    {:error, _errors} ->
      IO.puts("❌ #{field}: #{inspect(value)} -> Error")
  end
end

# Example 4: Batch Validation
IO.puts("\n📦 Example 4: Batch Validation")

# Validate multiple values of the same type
usernames = ["alice", "bob", "charlie", "x", "very_long_username_that_exceeds_limit"]
username_type = Exdantic.Types.string() 
               |> Exdantic.Types.with_constraints([min_length: 2, max_length: 20])

case Exdantic.EnhancedValidator.validate_many(username_type, usernames) do
  {:ok, validated_usernames} ->
    IO.puts("✅ All usernames valid: #{inspect(validated_usernames)}")
  {:error, errors_by_index} ->
    IO.puts("❌ Some usernames invalid:")
    for {index, errors} <- errors_by_index do
      username = Enum.at(usernames, index)
      IO.puts("   #{username}: #{hd(errors).message}")
    end
end

# Example 5: Validation with Schema Generation
IO.puts("\n📋 Example 5: Validation with Schema Generation")

# Validate and generate JSON schema simultaneously
api_schema = Exdantic.Runtime.create_schema([
  {:endpoint, :string, [required: true]},
  {:method, :string, [choices: ["GET", "POST", "PUT", "DELETE"]]},
  {:headers, {:map, {:string, :string}}, [required: false]}
])

api_request = %{
  endpoint: "/api/users",
  method: "GET",
  headers: %{"Authorization" => "Bearer token123"}
}

case Exdantic.EnhancedValidator.validate_with_schema(api_schema, api_request) do
  {:ok, validated_data, json_schema} ->
    IO.puts("✅ API request validated:")
    IO.inspect(validated_data, pretty: true)
    IO.puts("Generated JSON Schema:")
    IO.puts(Jason.encode!(json_schema, pretty: true))
  {:error, _errors} ->
    IO.puts("❌ API request validation failed")
end

# Example 6: LLM Provider Optimization
IO.puts("\n🤖 Example 6: LLM Provider Optimization")

# Create a schema and optimize it for different LLM providers
llm_schema = Exdantic.Runtime.create_schema([
  {:reasoning, :string, [required: true, description: "Chain of thought"]},
  {:answer, :string, [required: true, description: "Final answer"]},
  {:confidence, :float, [gteq: 0.0, lteq: 1.0, description: "Confidence score"]}
])

llm_response = %{
  reasoning: "The user is asking about...",
  answer: "Based on the analysis...",
  confidence: 0.95
}

# Optimize for OpenAI
case Exdantic.EnhancedValidator.validate_for_llm(llm_schema, llm_response, :openai) do
  {:ok, _validated, openai_schema} ->
    IO.puts("✅ OpenAI-optimized validation succeeded")
    IO.puts("OpenAI schema constraints:")
    IO.puts("   additionalProperties: #{openai_schema["additionalProperties"]}")
  {:error, _errors} ->
    IO.puts("❌ OpenAI validation failed")
end

# Optimize for Anthropic
case Exdantic.EnhancedValidator.validate_for_llm(llm_schema, llm_response, :anthropic) do
  {:ok, _validated, anthropic_schema} ->
    IO.puts("✅ Anthropic-optimized validation succeeded")
    IO.puts("Anthropic schema has required array: #{Map.has_key?(anthropic_schema, "required")}")
  {:error, _errors} ->
    IO.puts("❌ Anthropic validation failed")
end

# Example 7: Validation Pipelines
IO.puts("\n🔄 Example 7: Validation Pipelines")

# Create a validation and transformation pipeline
text_processing_pipeline = [
  :string,                                    # Validate as string
  fn s -> {:ok, String.trim(s)} end,         # Trim whitespace
  fn s -> {:ok, String.downcase(s)} end,     # Convert to lowercase
  fn s -> if String.length(s) > 0, do: {:ok, s}, else: {:error, "empty string"} end,
  :string                                     # Final validation
]

pipeline_inputs = [
  "  Hello World  ",
  "ELIXIR",
  "   ",
  "programming"
]

for input <- pipeline_inputs do
  case Exdantic.EnhancedValidator.pipeline(text_processing_pipeline, input) do
    {:ok, result} ->
      IO.puts("✅ Pipeline: #{inspect(input)} -> #{inspect(result)}")
    {:error, {step_index, _errors}} ->
      IO.puts("❌ Pipeline failed at step #{step_index}: #{inspect(input)}")
  end
end

# Example 8: Validation Reports for Debugging
IO.puts("\n🔍 Example 8: Validation Reports for Debugging")

# Generate comprehensive validation reports
debug_data = %{
  user_id: 12345,
  preferences: %{
    theme: "dark",
    notifications: true,
    language: "en"
  },
  metadata: [
    %{key: "created_at", value: "2023-01-01"},
    %{key: "updated_at", value: "2023-06-15"}
  ]
}

debug_schema = Exdantic.Runtime.create_schema([
  {:user_id, :integer, [required: true]},
  {:preferences, {:map, {:string, :any}}, [required: true]},
  {:metadata, {:array, {:map, {:string, :string}}}, [required: false]}
])

report = Exdantic.EnhancedValidator.validation_report(debug_schema, debug_data)

IO.puts("✅ Validation Report Generated:")
IO.puts("   Validation result: #{elem(report.validation_result, 0)}")
IO.puts("   Target type: #{report.target_info.type}")
IO.puts("   Input type: #{report.input_analysis.type}")
IO.puts("   Duration: #{report.performance_metrics.duration_milliseconds}ms")
IO.puts("   Configuration: #{report.configuration.validation_mode}")

# Example 9: Error Recovery Patterns
IO.puts("\n🚨 Example 9: Error Recovery Patterns")

# Demonstrate error handling with fallback strategies
unreliable_data = [
  %{name: "Valid User", email: "valid@example.com"},
  %{name: "No Email User"},  # Missing required field
  %{name: "Bad Email", email: "invalid-email"},  # Invalid format
  %{email: "orphan@example.com"},  # Missing name
]

recovery_config = Exdantic.Config.create(error_format: :detailed)

validated_users = []
failed_users = []

for {user_data, index} <- Enum.with_index(unreliable_data) do
  case Exdantic.EnhancedValidator.validate(UserSchema, user_data, config: recovery_config) do
    {:ok, validated} ->
      _validated_users = [validated | validated_users]
      IO.puts("✅ User #{index}: Validated successfully")
    {:error, errors} ->
      _failed_users = [{index, user_data, errors} | failed_users]
      IO.puts("❌ User #{index}: Validation failed")
      Enum.each(errors, &IO.puts("     #{Exdantic.Error.format(&1)}"))
  end
end

IO.puts("Summary: #{length(validated_users)} valid, #{length(failed_users)} failed")

# Example 10: Performance Benchmarking
IO.puts("\n⚡ Example 10: Performance Benchmarking")

# Compare different validation approaches
benchmark_data = for i <- 1..1000 do
  %{id: i, name: "User #{i}", email: "user#{i}@example.com"}
end

# Benchmark compiled schema validation
{time_compiled_us, _} = :timer.tc(fn ->
  Enum.each(benchmark_data, fn data ->
    Exdantic.EnhancedValidator.validate(UserSchema, data)
  end)
end)

# Benchmark runtime schema validation
benchmark_schema = Exdantic.Runtime.create_schema([
  {:id, :integer, [required: true]},
  {:name, :string, [required: true]},
  {:email, :string, [required: true]}
])

{time_runtime_us, _} = :timer.tc(fn ->
  Enum.each(benchmark_data, fn data ->
    Exdantic.EnhancedValidator.validate(benchmark_schema, data)
  end)
end)

# Benchmark type specification validation
type_spec = {:map, {:string, :any}}
{time_typespec_us, _} = :timer.tc(fn ->
  Enum.each(benchmark_data, fn data ->
    Exdantic.EnhancedValidator.validate(type_spec, data)
  end)
end)

IO.puts("✅ Performance comparison (1000 validations):")
IO.puts("   Compiled schema: #{Float.round(time_compiled_us / 1000, 2)}ms")
IO.puts("   Runtime schema:  #{Float.round(time_runtime_us / 1000, 2)}ms")
IO.puts("   Type spec:       #{Float.round(time_typespec_us / 1000, 2)}ms")

IO.puts("""

🎯 Summary
==========
This example demonstrated:
1. 🎯 Universal validation interface (compiled, runtime, type specs)
2. ⚙️ Configuration-driven validation behavior
3. 🎁 Wrapper validation for single values
4. 📦 Batch validation for multiple values
5. 📋 Validation with simultaneous JSON schema generation
6. 🤖 LLM provider-specific optimizations
7. 🔄 Validation and transformation pipelines
8. 🔍 Comprehensive validation reports for debugging
9. 🚨 Error recovery and handling patterns
10. ⚡ Performance benchmarking across approaches

Enhanced Validator provides a unified interface for all Exdantic validation
capabilities, making it perfect for complex applications with varying
validation requirements.
""")

# Clean exit
:ok
