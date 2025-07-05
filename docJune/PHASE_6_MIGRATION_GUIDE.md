# Phase 6 Migration Guide: Enhanced JSON Schema Resolution & Complete Integration

## Overview

Phase 6 completes the Exdantic enhancement implementation with:
- Enhanced JSON Schema resolution with full metadata support
- Complete LLM provider optimization
- DSPy integration patterns
- Performance optimization and monitoring
- Comprehensive validation pipeline integration

## New Features in Phase 6

### 1. Enhanced JSON Schema Resolution

```elixir
# Enhanced schema resolution with full metadata
schema = Exdantic.JsonSchema.EnhancedResolver.resolve_enhanced(UserSchema,
  optimize_for_provider: :openai,
  include_model_validators: true,
  include_computed_fields: true,
  flatten_for_llm: true
)

# Result includes complete metadata
assert schema["x-exdantic-enhanced"] == true
assert schema["x-model-validators"] == 2
assert schema["x-computed-fields"] == 1
assert schema["x-supports-struct"] == true
```

### 2. Comprehensive Schema Analysis

```elixir
# Complete schema analysis with validation testing
report = Exdantic.JsonSchema.EnhancedResolver.comprehensive_analysis(
  UserSchema,
  sample_data,
  include_validation_test: true,
  test_llm_providers: [:openai, :anthropic, :generic]
)

# Report includes:
# - Schema structure analysis
# - Performance metrics
# - LLM provider compatibility
# - Validation testing results
# - Optimization recommendations
```

### 3. DSPy Integration Patterns

```elixir
# Optimize schemas for DSPy usage patterns
dspy_schema = Exdantic.JsonSchema.EnhancedResolver.optimize_for_dspy(UserSchema,
  signature_mode: true,        # For DSPy signatures
  remove_computed_fields: true, # For input validation
  strict_types: true,          # Ensure strict validation
  field_descriptions: true     # Help LLM understanding
)

# DSPy-specific configuration
config = Exdantic.Config.for_dspy(:signature, provider: :openai)
```

### 4. Enhanced Validation Pipeline

```elixir
# Validation with enhanced reporting
result = Exdantic.EnhancedValidator.validate_with_enhanced_schema(
  UserSchema,
  data,
  generate_enhanced_schema: true,
  optimize_for_provider: :openai,
  include_metadata: true
)

case result do
  {:ok, validated_data, enhanced_schema, metadata} ->
    # Full pipeline result with all enhancements
  {:error, errors} ->
    # Enhanced error reporting
end
```

## Migration Path

### From Phase 5 to Phase 6

#### 1. Existing Code Compatibility

**✅ No Breaking Changes**: All existing Phase 5 code continues to work without modification.

```elixir
# Phase 5 code - still works
enhanced_schema = Runtime.create_enhanced_schema(fields, opts)
{:ok, result} = Runtime.validate_enhanced(data, enhanced_schema)
json_schema = Runtime.enhanced_to_json_schema(enhanced_schema)
```

#### 2. Enhanced JSON Schema Generation

**Before (Phase 5)**:
```elixir
# Basic JSON schema generation
json_schema = Exdantic.JsonSchema.from_schema(UserSchema)
```

**After (Phase 6)**:
```elixir
# Enhanced JSON schema with full metadata
enhanced_schema = Exdantic.JsonSchema.EnhancedResolver.resolve_enhanced(UserSchema,
  optimize_for_provider: :openai,
  include_model_validators: true,
  include_computed_fields: true
)

# Includes enhanced metadata:
# - x-exdantic-enhanced: true
# - x-model-validators: count
# - x-computed-fields: count
# - x-supports-struct: boolean
# - Provider-specific optimizations
```

#### 3. DSPy Integration

**New in Phase 6**:
```elixir
# Create DSPy-optimized schemas
input_schema = Exdantic.JsonSchema.EnhancedResolver.optimize_for_dspy(
  MySchema,
  remove_computed_fields: true,  # For input validation
  strict_types: true
)

output_schema = Exdantic.JsonSchema.EnhancedResolver.optimize_for_dspy(
  MySchema,
  signature_mode: true,          # For output validation
  field_descriptions: true
)

# DSPy-specific configuration
dspy_config = Exdantic.Config.for_dspy(:signature, provider: :openai)
```

#### 4. Performance Monitoring

**New in Phase 6**:
```elixir
# Comprehensive performance analysis
report = Exdantic.JsonSchema.EnhancedResolver.comprehensive_analysis(MySchema)

# Performance metrics include:
# - Complexity scoring
# - Memory footprint estimation
# - Validation time estimation
# - Optimization recommendations
```

### Migration Examples

#### Basic Schema Enhancement

```elixir
# Before: Basic schema
defmodule UserSchema do
  use Exdantic

  schema do
    field :name, :string
    field :email, :string
  end
end

# After: Enhanced with Phase 6 features
defmodule UserSchema do
  use Exdantic, define_struct: true

  schema do
    field :name, :string, required: true, min_length: 2
    field :email, :string, required: true, format: ~r/@/

    model_validator :normalize_email
    computed_field :email_domain, :string, :extract_domain
  end

  def normalize_email(input) do
    {:ok, %{input | email: String.downcase(input.email)}}
  end

  def extract_domain(input) do
    domain = input.email |> String.split("@") |> List.last()
    {:ok, domain}
  end
end

# Phase 6 enhanced usage
enhanced_schema = Exdantic.JsonSchema.EnhancedResolver.resolve_enhanced(UserSchema)
{:ok, validated, metadata} = UserSchema.validate_enhanced(data, include_performance_metrics: true)
```

#### Runtime Schema Enhancement

```elixir
# Phase 5 runtime schema
fields = [{:name, :string}, {:email, :string}]
schema = Runtime.create_schema(fields)

# Phase 6 enhanced runtime schema
enhanced_schema = Runtime.create_enhanced_schema_v6(fields,
  auto_optimize_for_provider: :openai,
  dspy_compatible: true,
  include_validation_metadata: true
)

# Enhanced validation with reporting
{:ok, result, metadata} = Runtime.validate_enhanced_v6(data, enhanced_schema,
  test_all_providers: true,
  generate_performance_report: true
)
```

## New Configuration Options

### Enhanced Config Creation

```elixir
# Phase 6 enhanced configuration
config = Exdantic.Config.create_enhanced(%{
  llm_provider: :openai,           # Target LLM provider
  dspy_compatible: true,           # Ensure DSPy compatibility
  performance_mode: :balanced,     # :speed, :memory, or :balanced
  enhanced_validation: true,       # Enable enhanced features
  include_metadata: true           # Include enhanced metadata
})

# DSPy-specific configurations
signature_config = Exdantic.Config.for_dspy(:signature, provider: :openai)
cot_config = Exdantic.Config.for_dspy(:chain_of_thought, provider: :anthropic)
io_config = Exdantic.Config.for_dspy(:input_output)
```

### Schema Validation and Compatibility

```elixir
# Validate schema compatibility
case Exdantic.JsonSchema.EnhancedResolver.validate_schema_compatibility(MySchema) do
  :ok -> 
    IO.puts("Schema is fully compatible")
  {:error, issues} -> 
    IO.puts("Issues found: #{inspect(issues)}")
end

# Test LLM provider compatibility
analysis = Exdantic.JsonSchema.EnhancedResolver.comprehensive_analysis(MySchema)
compatibility = analysis.llm_compatibility

# Check DSPy readiness
info = MySchema.__enhanced_schema_info__()
dspy_ready = info.dspy_ready.ready
```

## Performance Optimizations

### Performance Monitoring

```elixir
# Built-in performance analysis
performance = MySchema.__enhanced_schema_info__().performance_profile

# Complexity scoring
complexity = performance.complexity_score
estimated_time = performance.estimated_validation_time
memory_footprint = performance.memory_footprint

# Optimization recommendations
recommendations = analysis.recommendations
```

### Memory and Speed Optimizations

```elixir
# Speed-optimized configuration
speed_config = Exdantic.Config.create_enhanced(%{
  performance_mode: :speed,
  enhanced_validation: false,  # Disable for speed
  error_format: :minimal
})

# Memory-optimized configuration
memory_config = Exdantic.Config.create_enhanced(%{
  performance_mode: :memory,
  max_anyof_union_len: 2,      # Reduce memory usage
  error_format: :minimal
})
```

## Best Practices for Phase 6

### 1. Schema Design

```elixir
# ✅ Good: Well-structured schema with clear separation
defmodule APIResponseSchema do
  use Exdantic, define_struct: true

  schema "API response with metadata" do
    field :data, :any, required: true
    field :status, :string, required: true, choices: ["success", "error"]
    field :timestamp, :string, required: true

    # Separate input processing and output generation
    model_validator :validate_timestamp_format
    computed_field :response_size, :integer, :calculate_size
    computed_field :cache_key, :string, :generate_cache_key
  end

  # Keep validators focused and efficient
  def validate_timestamp_format(input) do
    # Quick validation
    {:ok, input}
  end

  # Keep computed fields simple
  def calculate_size(input) do
    size = :erlang.external_size(input.data)
    {:ok, size}
  end

  def generate_cache_key(input) do
    key = :crypto.hash(:md5, "#{input.status}_#{input.timestamp}") |> Base.encode16()
    {:ok, key}
  end
end
```

### 2. DSPy Integration

```elixir
# ✅ Good: Separate input and output schemas for DSPy
defmodule QuestionAnsweringInput do
  use Exdantic

  schema "Input for question answering" do
    field :question, :string, required: true
    field :context, :string, required: true
  end
end

defmodule QuestionAnsweringOutput do
  use Exdantic, define_struct: true

  schema "Output from question answering" do
    field :question, :string, required: true
    field :context, :string, required: true
    field :answer, :string, required: true

    computed_field :confidence_score, :float, :calculate_confidence
    computed_field :answer_length, :integer, :count_answer_words
  end

  def calculate_confidence(input) do
    # Simple confidence based on answer characteristics
    score = if String.length(input.answer) > 10, do: 0.8, else: 0.6
    {:ok, score}
  end

  def count_answer_words(input) do
    count = input.answer |> String.split() |> length()
    {:ok, count}
  end
end

# Usage with DSPy optimization
input_schema = Exdantic.JsonSchema.EnhancedResolver.optimize_for_dspy(
  QuestionAnsweringInput,
  strict_types: true
)

output_schema = Exdantic.JsonSchema.EnhancedResolver.optimize_for_dspy(
  QuestionAnsweringOutput,
  signature_mode: true,
  field_descriptions: true
)
```

### 3. Performance Optimization

```elixir
# ✅ Good: Performance-conscious schema design
defmodule HighPerformanceSchema do
  use Exdantic, define_struct: true

  schema do
    field :id, :integer, required: true
    field :name, :string, required: true

    # Limit expensive operations
    model_validator :quick_validation  # Keep fast
    
    # Limit computed fields for performance
    computed_field :display_name, :string, :simple_display
  end

  # Fast validator
  def quick_validation(input) do
    if input.id > 0, do: {:ok, input}, else: {:error, "Invalid ID"}
  end

  # Simple computed field
  def simple_display(input) do
    {:ok, "User: #{input.name}"}
  end
end

# Monitor performance
report = Exdantic.JsonSchema.EnhancedResolver.comprehensive_analysis(
  HighPerformanceSchema,
  include_validation_test: true
)

if report.performance_metrics.complexity_score > 50 do
  IO.puts("Consider optimizing schema complexity")
end
```

## Testing Phase 6 Features

### Unit Tests

```elixir
defmodule MySchemaPhase6Test do
  use ExUnit.Case

  test "enhanced JSON schema generation" do
    schema = Exdantic.JsonSchema.EnhancedResolver.resolve_enhanced(MySchema)
    
    assert schema["x-exdantic-enhanced"] == true
    assert is_map(schema["properties"])
    assert schema["type"] == "object"
  end

  test "DSPy optimization" do
    dspy_schema = Exdantic.JsonSchema.EnhancedResolver.optimize_for_dspy(MySchema)
    
    assert dspy_schema["x-dspy-optimized"] == true
    assert dspy_schema["additionalProperties"] == false
  end

  test "comprehensive analysis" do
    analysis = Exdantic.JsonSchema.EnhancedResolver.comprehensive_analysis(MySchema)
    
    assert analysis.schema_type == :compiled_schema
    assert is_map(analysis.performance_metrics)
    assert is_list(analysis.recommendations)
  end

  test "enhanced validation pipeline" do
    data = %{name: "Test", email: "test@example.com"}
    
    {:ok, result, metadata} = MySchema.validate_enhanced(data,
      include_performance_metrics: true
    )
    
    assert is_map(result)
    assert is_map(metadata.performance_metrics)
  end
end
```

### Performance Tests

```elixir
defmodule MySchemaPerformanceTest do
  use ExUnit.Case
  
  @tag :performance
  test "validation performance under load" do
    data = %{name: "Test User", email: "test@example.com"}
    
    {time, _results} = :timer.tc(fn ->
      for _ <- 1..1000 do
        MySchema.validate(data)
      end
    end)
    
    avg_time = time / 1000
    assert avg_time < 5000  # < 5ms average
  end
  
  @tag :performance  
  test "JSON schema generation performance" do
    {time, _schema} = :timer.tc(fn ->
      for _ <- 1..100 do
        Exdantic.JsonSchema.EnhancedResolver.resolve_enhanced(MySchema)
      end
    end)
    
    avg_time = time / 100
    assert avg_time < 10000  # < 10ms average
  end
end
```

## Troubleshooting

### Common Issues and Solutions

#### 1. Performance Issues

**Problem**: Slow validation with complex schemas
```elixir
# ❌ Avoid: Too many complex computed fields
computed_field :expensive_calculation, :string, :slow_function

def slow_function(input) do
  # Expensive operation
  :timer.sleep(100)
  {:ok, "result"}
end
```

**Solution**: Optimize or cache expensive operations
```elixir
# ✅ Better: Simple, fast computed fields
computed_field :simple_calculation, :string, :fast_function

def fast_function(input) do
  {:ok, String.upcase(input.name)}
end

# ✅ Or: Use caching for expensive operations
def expensive_with_cache(input) do
  case get_cache(input.id) do
    nil ->
      result = expensive_calculation(input)
      put_cache(input.id, result)
      {:ok, result}
    cached ->
      {:ok, cached}
  end
end
```

#### 2. DSPy Compatibility Issues

**Problem**: Schema not optimizing well for DSPy
```elixir
# Check compatibility
case Exdantic.JsonSchema.EnhancedResolver.validate_schema_compatibility(MySchema) do
  {:error, issues} ->
    IO.inspect(issues)  # Review specific issues
  :ok ->
    :ok
end
```

**Solution**: Follow DSPy best practices
```elixir
# ✅ Good: DSPy-friendly schema
defmodule DSPyFriendlySchema do
  use Exdantic

  schema do
    # Clear, well-described fields
    field :input, :string, required: true, 
      description: "The input text to process"
    field :output, :string, required: true,
      description: "The processed output text"
    
    # Minimal model validation
    model_validator :simple_validation
    
    # Avoid complex computed fields in DSPy schemas
  end

  def simple_validation(input) do
    if String.length(input.input) > 0 do
      {:ok, input}
    else
      {:error, "Input cannot be empty"}
    end
  end
end
```

#### 3. Memory Usage Issues

**Problem**: High memory usage with many schemas

**Solution**: Use performance monitoring and optimization
```elixir
# Monitor memory usage
initial_memory = :erlang.memory(:total)

# Your schema operations
result = perform_schema_operations()

:erlang.garbage_collect()
final_memory = :erlang.memory(:total)

memory_increase = final_memory - initial_memory
IO.puts("Memory increase: #{memory_increase / 1024}KB")

# Optimize based on analysis
analysis = Exdantic.JsonSchema.EnhancedResolver.comprehensive_analysis(MySchema)
IO.inspect(analysis.performance_metrics.optimization_suggestions)
```

## Summary

Phase 6 completes the Exdantic enhancement implementation with:

✅ **Enhanced JSON Schema Resolution**: Complete metadata and LLM optimization
✅ **DSPy Integration**: Optimized schemas for DSPy patterns  
✅ **Performance Optimization**: Monitoring and tuning capabilities
✅ **Complete Integration**: All features work together seamlessly
✅ **Backward Compatibility**: All existing code continues to work
✅ **Production Ready**: Performance benchmarks and monitoring

The implementation provides a complete, production-ready schema validation system with advanced features while maintaining the simplicity and reliability of the original Exdantic design.
