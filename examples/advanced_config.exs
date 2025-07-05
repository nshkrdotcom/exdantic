#!/usr/bin/env elixir

# Advanced Configuration Example
# Run with: elixir examples/advanced_config.exs

Mix.install([{:exdantic, path: "."}])

IO.puts("""
⚙️ Exdantic Advanced Configuration Example
=========================================

This example demonstrates runtime configuration modification, presets,
and the builder pattern for flexible validation behavior.
""")

# Example 1: Basic Configuration Creation
IO.puts("\n📝 Example 1: Basic Configuration Creation")

# Create configurations with different options
basic_config = Exdantic.Config.create(%{
  strict: true,
  extra: :forbid,
  coercion: :safe
})

IO.puts("✅ Basic configuration created:")
IO.inspect(Exdantic.Config.summary(basic_config), pretty: true)

# Create configuration from keyword list
keyword_config = Exdantic.Config.create([
  strict: false,
  extra: :allow,
  coercion: :aggressive,
  error_format: :simple
])

IO.puts("✅ Keyword configuration created:")
IO.inspect(Exdantic.Config.summary(keyword_config), pretty: true)

# Example 2: Configuration Presets
IO.puts("\n🎛️ Example 2: Configuration Presets")

# Test all available presets
presets = [:strict, :lenient, :api, :json_schema, :development, :production]

for preset <- presets do
  config = Exdantic.Config.preset(preset)
  summary = Exdantic.Config.summary(config)
  IO.puts("✅ #{preset} preset: #{summary.validation_mode} validation, #{summary.coercion} coercion")
end

# Example 3: Configuration Merging
IO.puts("\n🔀 Example 3: Configuration Merging")

# Start with a base configuration
base_config = Exdantic.Config.create(%{
  strict: false,
  extra: :allow,
  coercion: :safe
})

# Merge with overrides
strict_override = Exdantic.Config.merge(base_config, %{
  strict: true,
  extra: :forbid,
  error_format: :detailed
})

IO.puts("Base config: #{Exdantic.Config.summary(base_config).validation_mode}")
IO.puts("Merged config: #{Exdantic.Config.summary(strict_override).validation_mode}")

# Test frozen configuration behavior
frozen_config = Exdantic.Config.create(%{frozen: true, strict: true})
IO.puts("✅ Frozen config created")

# Try to merge with frozen config (empty merge should work)
try do
  _empty_merge = Exdantic.Config.merge(frozen_config, %{})
  IO.puts("✅ Empty merge with frozen config succeeded")
rescue
  RuntimeError -> 
    IO.puts("❌ Empty merge with frozen config failed (unexpected)")
end

# Try to merge with non-empty override (should fail)
try do
  Exdantic.Config.merge(frozen_config, %{strict: false})
  IO.puts("❌ Non-empty merge with frozen config succeeded (unexpected)")
rescue
  RuntimeError -> 
    IO.puts("✅ Non-empty merge with frozen config failed (expected)")
end

# Example 4: Builder Pattern
IO.puts("\n🏗️ Example 4: Builder Pattern")

# Build configuration fluently
api_config = Exdantic.Config.builder()
|> Exdantic.Config.Builder.strict(true)
|> Exdantic.Config.Builder.forbid_extra()
|> Exdantic.Config.Builder.safe_coercion()
|> Exdantic.Config.Builder.detailed_errors()
|> Exdantic.Config.Builder.frozen(true)
|> Exdantic.Config.Builder.build()

IO.puts("✅ API config built:")
IO.inspect(Exdantic.Config.summary(api_config), pretty: true)

# Build configuration with convenience methods
dev_config = Exdantic.Config.builder()
|> Exdantic.Config.Builder.allow_extra()
|> Exdantic.Config.Builder.aggressive_coercion()
|> Exdantic.Config.Builder.case_insensitive()
|> Exdantic.Config.Builder.simple_errors()
|> Exdantic.Config.Builder.build()

IO.puts("✅ Development config built:")
IO.inspect(Exdantic.Config.summary(dev_config), pretty: true)

# Example 5: Conditional Configuration
IO.puts("\n🔀 Example 5: Conditional Configuration")

# Build configuration based on environment
env = :production  # Simulate production environment

prod_config = Exdantic.Config.builder()
|> Exdantic.Config.Builder.when_true(env == :production, fn builder ->
  builder
  |> Exdantic.Config.Builder.strict(true)
  |> Exdantic.Config.Builder.forbid_extra()
  |> Exdantic.Config.Builder.frozen(true)
end)
|> Exdantic.Config.Builder.when_true(env == :development, fn builder ->
  builder
  |> Exdantic.Config.Builder.allow_extra()
  |> Exdantic.Config.Builder.aggressive_coercion()
end)
|> Exdantic.Config.Builder.build()

IO.puts("✅ Environment-specific config (#{env}):")
IO.inspect(Exdantic.Config.summary(prod_config), pretty: true)

# Example 6: Preset Application with Builder
IO.puts("\n🎨 Example 6: Preset Application with Builder")

# Start with a preset and customize it
custom_api_config = Exdantic.Config.builder()
|> Exdantic.Config.Builder.apply_preset(:api)
|> Exdantic.Config.Builder.case_insensitive()  # Override case sensitivity
|> Exdantic.Config.Builder.max_union_length(10)  # Custom union length
|> Exdantic.Config.Builder.build()

IO.puts("✅ Customized API config:")
IO.inspect(Exdantic.Config.summary(custom_api_config), pretty: true)

# Example 7: Configuration for Different Use Cases
IO.puts("\n🎯 Example 7: Configuration for Different Use Cases")

# Configuration for API endpoints
api_endpoint_config = Exdantic.Config.builder()
|> Exdantic.Config.Builder.for_api()
|> Exdantic.Config.Builder.build()

# Configuration for JSON schema generation
schema_gen_config = Exdantic.Config.builder()
|> Exdantic.Config.Builder.for_json_schema()
|> Exdantic.Config.Builder.build()

# Configuration for development
development_config = Exdantic.Config.builder()
|> Exdantic.Config.Builder.for_development()
|> Exdantic.Config.Builder.build()

# Configuration for production
production_config = Exdantic.Config.builder()
|> Exdantic.Config.Builder.for_production()
|> Exdantic.Config.Builder.build()

use_cases = [
  {"API Endpoint", api_endpoint_config},
  {"JSON Schema", schema_gen_config},
  {"Development", development_config},
  {"Production", production_config}
]

for {name, config} <- use_cases do
  summary = Exdantic.Config.summary(config)
  IO.puts("✅ #{name}: #{summary.validation_mode}, extra: #{summary.extra_fields}")
end

# Example 8: Configuration Validation and Error Handling
IO.puts("\n🚨 Example 8: Configuration Validation and Error Handling")

# Create a valid configuration
valid_config = Exdantic.Config.create(%{strict: true, extra: :forbid})

case Exdantic.Config.validate_config(valid_config) do
  :ok ->
    IO.puts("✅ Valid configuration passed validation")
  {:error, reasons} ->
    IO.puts("❌ Valid configuration failed: #{inspect(reasons)}")
end

# Test invalid configuration options
try do
  Exdantic.Config.create(%{invalid_option: true})
  IO.puts("❌ Invalid option accepted (unexpected)")
rescue
  ArgumentError -> 
    IO.puts("✅ Invalid option rejected (expected)")
end

# Example 9: Configuration Conversion
IO.puts("\n🔄 Example 9: Configuration Conversion")

# Create a comprehensive configuration
comprehensive_config = Exdantic.Config.create(%{
  strict: true,
  extra: :forbid,
  coercion: :safe,
  validate_assignment: true,
  case_sensitive: false,
  error_format: :detailed,
  use_enum_values: true,
  max_anyof_union_len: 3
})

# Convert to validation options
validation_opts = Exdantic.Config.to_validation_opts(comprehensive_config)
IO.puts("✅ Validation options:")
IO.inspect(validation_opts, pretty: true)

# Convert to JSON schema options
json_schema_opts = Exdantic.Config.to_json_schema_opts(comprehensive_config)
IO.puts("✅ JSON Schema options:")
IO.inspect(json_schema_opts, pretty: true)

# Example 10: Configuration Testing and Validation
IO.puts("\n🧪 Example 10: Configuration Testing with Real Data")

# Create test schema and data
test_schema = Exdantic.Runtime.create_schema([
  {:name, :string, [required: true, min_length: 2]},
  {:email, :string, [required: true, format: ~r/@/]},
  {:age, :integer, [required: false, gt: 0]}
])

test_data = %{
  name: "John",
  email: "john@example.com",
  age: "30",  # String that can be coerced
  extra_field: "should be handled per config"
}

# Test different configurations
test_configs = [
  {"Strict + No Coercion", Exdantic.Config.preset(:strict)},
  {"Lenient + Safe Coercion", Exdantic.Config.preset(:lenient)},
  {"Development", Exdantic.Config.preset(:development)},
  {"Production", Exdantic.Config.preset(:production)}
]

for {name, config} <- test_configs do
  case Exdantic.EnhancedValidator.validate(test_schema, test_data, config: config) do
    {:ok, validated} ->
      IO.puts("✅ #{name}: Validation succeeded")
      type_name = cond do
        is_integer(validated.age) -> "integer"
        is_binary(validated.age) -> "string"
        true -> "other"
      end
      IO.puts("   Age coerced: #{inspect(validated.age)} (#{type_name})")
    {:error, errors} ->
      IO.puts("❌ #{name}: Validation failed")
      IO.puts("   Reason: #{hd(errors).message}")
  end
end

# Helper function to show type
# Helper function definitions removed - replaced with inline logic above

# Example 11: Builder Validation and Error Recovery
IO.puts("\n🔧 Example 11: Builder Validation and Error Recovery")

# Create a builder and validate before building
builder = Exdantic.Config.builder()
|> Exdantic.Config.Builder.strict(true)
|> Exdantic.Config.Builder.forbid_extra()
|> Exdantic.Config.Builder.safe_coercion()

case Exdantic.Config.Builder.validate_and_build(builder) do
  {:ok, config} ->
    IO.puts("✅ Builder validation succeeded")
    IO.inspect(Exdantic.Config.summary(config), pretty: true)
  {:error, reasons} ->
    IO.puts("❌ Builder validation failed: #{inspect(reasons)}")
end

# Example 12: Configuration Introspection
IO.puts("\n🔍 Example 12: Configuration Introspection")

# Create a complex configuration
complex_config = Exdantic.Config.builder()
|> Exdantic.Config.Builder.strict(true)
|> Exdantic.Config.Builder.safe_coercion()
|> Exdantic.Config.Builder.validate_assignment(true)
|> Exdantic.Config.Builder.use_enum_values(true)
|> Exdantic.Config.Builder.case_sensitive(false)
|> Exdantic.Config.Builder.build()

# Inspect configuration properties
IO.puts("✅ Configuration introspection:")
IO.puts("   Allow extra fields: #{Exdantic.Config.allow_extra_fields?(complex_config)}")
IO.puts("   Should coerce: #{Exdantic.Config.should_coerce?(complex_config)}")
IO.puts("   Coercion level: #{Exdantic.Config.coercion_level(complex_config)}")

summary = Exdantic.Config.summary(complex_config)
IO.puts("   Enabled features: #{inspect(summary.features)}")

IO.puts("""

🎯 Summary
==========
This example demonstrated:
1. 📝 Basic configuration creation from maps and keywords
2. 🎛️ Predefined configuration presets for common scenarios
3. 🔀 Configuration merging with frozen config behavior
4. 🏗️ Fluent builder pattern for readable configuration
5. 🔀 Conditional configuration based on environment
6. 🎨 Preset application with builder customization
7. 🎯 Purpose-built configurations for different use cases
8. 🚨 Configuration validation and error handling
9. 🔄 Configuration conversion to validation options
10. 🧪 Real-world testing with different configurations
11. 🔧 Builder validation and error recovery
12. 🔍 Configuration introspection and property checking

Advanced Configuration enables DSPy-style ConfigDict patterns with
runtime modification, immutability controls, and flexible validation behavior.
""")

# Clean exit
:ok
