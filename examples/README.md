# Exdantic Examples

This directory contains comprehensive examples showcasing all of Exdantic's features, from basic validation to advanced LLM integration and DSPy patterns.

## Quick Start

Run any example with:
```bash
mix run examples/<example_name>.exs
```

## 📋 Complete Example Index

### 🟢 **Core & Beginner Examples**

#### 📝 [`basic_usage.exs`](basic_usage.exs)
- **What it covers**: Fundamental schema definition, validation, and error handling
- **Key concepts**: Basic types, constraints, field definitions, complex types
- **Best for**: Getting started with Exdantic
- **Features**: Type validation, constraints, arrays, maps, unions, error messages

#### 🏗️ [`advanced_features.exs`](advanced_features.exs)  
- **What it covers**: Complex schema patterns, nested validation, custom types
- **Key concepts**: Object types, unions, arrays, business domain modeling
- **Best for**: Understanding Exdantic's advanced validation capabilities
- **Features**: Nested objects, complex business rules, integration patterns

#### 🎨 [`custom_validation.exs`](custom_validation.exs)
- **What it covers**: Custom validation functions, error messages, business logic
- **Key concepts**: Custom validators, error customization, transformation patterns
- **Best for**: Implementing domain-specific validation logic
- **Features**: Email validation, password strength, value transformation, SKU validation

#### 📚 [`readme_examples.exs`](readme_examples.exs)
- **What it covers**: All examples from the main README for verification
- **Key concepts**: Complete feature overview and documentation testing
- **Best for**: Verifying installation and basic functionality
- **Features**: README code verification, comprehensive test suite

### 🟡 **Intermediate Features**

#### 🚀 [`runtime_schema.exs`](runtime_schema.exs) ⭐
- **What it covers**: Dynamic schema creation at runtime
- **Key concepts**: Runtime schema generation, field definitions, dynamic validation
- **DSPy pattern**: `pydantic.create_model("DSPyProgramOutputs", **fields)`
- **Best for**: Creating schemas programmatically based on runtime requirements
- **Features**: Dynamic field definitions, runtime validation, JSON schema generation

#### 🔧 [`type_adapter.exs`](type_adapter.exs) ⭐
- **What it covers**: Runtime type validation without schemas
- **Key concepts**: TypeAdapter system, type coercion, serialization
- **DSPy pattern**: `TypeAdapter(type(value)).validate_python(value)`
- **Best for**: One-off validations and dynamic type checking
- **Features**: Type coercion, batch validation, performance optimization

#### 🎁 [`wrapper_models.exs`](wrapper_models.exs) ⭐
- **What it covers**: Temporary single-field validation schemas
- **Key concepts**: Wrapper models, flexible input handling, factory patterns
- **DSPy pattern**: `create_model("Wrapper", value=(target_type, ...))`
- **Best for**: Complex type coercion and single-field validation
- **Features**: Single-field wrappers, factory patterns, flexible input handling

#### 🏛️ [`root_schema.exs`](root_schema.exs) ⭐
- **What it covers**: Validation of non-dictionary types at the root level
- **Key concepts**: Root schemas, array validation, primitive type validation
- **DSPy pattern**: Root-level validation for LLM outputs (arrays, single values)
- **Best for**: Validating LLM outputs that aren't dictionaries
- **Features**: Array validation, single values, union types, LLM output patterns

#### ⚙️ [`advanced_config.exs`](advanced_config.exs) ⭐
- **What it covers**: Runtime configuration modification and presets
- **Key concepts**: Configuration system, builder pattern, presets
- **DSPy pattern**: `ConfigDict(extra="forbid", frozen=True)`
- **Best for**: Flexible validation behavior based on context
- **Features**: Configuration presets, builder pattern, environment-based config

### 🔴 **Advanced Features**

#### 🚀 [`enhanced_validator.exs`](enhanced_validator.exs) ⭐
- **What it covers**: Universal validation interface across all Exdantic features
- **Key concepts**: Enhanced validator, configuration-driven validation, pipelines
- **DSPy pattern**: Unified validation with dynamic configuration
- **Best for**: Complex applications with varying validation requirements
- **Features**: Universal interface, batch validation, LLM optimizations

#### 🔗 [`json_schema_resolver.exs`](json_schema_resolver.exs) ⭐
- **What it covers**: Advanced JSON schema manipulation for LLM integration
- **Key concepts**: Reference resolution, schema flattening, provider optimization
- **DSPy pattern**: LLM-compatible schema generation
- **Best for**: Preparing schemas for different LLM providers
- **Features**: Reference resolution, provider optimization, schema flattening

#### 🔮 [`dspy_integration.exs`](dspy_integration.exs) ⭐
- **What it covers**: Complete DSPy integration patterns
- **Key concepts**: All DSPy patterns working together in realistic scenarios
- **DSPy pattern**: Complete DSPy program simulation
- **Best for**: Understanding how to build DSPy-style applications with Exdantic
- **Features**: Complete DSPy simulation, provider optimization, error recovery

### 🎯 **Specialized Features**

#### 🧠 [`model_validators.exs`](model_validators.exs) ⭐
- **What it covers**: Cross-field validation and data transformation
- **Key concepts**: Model validators, business logic validation, transformation pipelines
- **Best for**: Complex business rules that span multiple fields
- **Features**: Password confirmation, business logic, data transformation, error handling

#### 🔢 [`computed_fields.exs`](computed_fields.exs) ⭐
- **What it covers**: Derived fields and automatic field generation
- **Key concepts**: Computed fields, data derivation, automatic calculations
- **Best for**: Generating additional data from validated input
- **Features**: Automatic calculations, data derivation, analytics, error handling

#### 🏷️ [`field_metadata_dspy.exs`](field_metadata_dspy.exs) ⭐
- **What it covers**: DSPy-style field metadata and annotations
- **Key concepts**: Field metadata, DSPy annotations, LLM hints
- **Best for**: DSPy integration with field-level metadata
- **Features**: DSPy field types, metadata extraction, runtime schema generation

### 🤖 **LLM Integration**

#### 🤖 [`llm_integration.exs`](llm_integration.exs) ⭐
- **What it covers**: LLM structured output validation and optimization
- **Key concepts**: LLM output validation, provider optimization, quality assessment
- **Best for**: Validating and optimizing LLM outputs
- **Features**: Structured output validation, provider optimization, quality metrics

#### 🔄 [`llm_pipeline_orchestration.exs`](llm_pipeline_orchestration.exs) ⭐
- **What it covers**: Multi-stage LLM validation pipelines
- **Key concepts**: Pipeline orchestration, error handling strategies, quality assessment
- **Best for**: Complex LLM workflows with multiple stages
- **Features**: Multi-stage pipelines, error handling, quality assessment, performance analysis

#### 🔀 [`conditional_recursive_validation.exs`](conditional_recursive_validation.exs) ⭐
- **What it covers**: Conditional validation and recursive data structures
- **Key concepts**: Conditional logic, recursive validation, dynamic schema selection
- **Best for**: Complex validation scenarios with conditional logic
- **Features**: Conditional validation, recursive trees, multi-step pipelines, cross-schema validation

### 🧪 **Development & Testing**

#### 🧪 [`phase_3_example.exs`](phase_3_example.exs)
- **What it covers**: Comprehensive integration testing and advanced patterns
- **Key concepts**: Integration testing, advanced patterns, performance analysis
- **Best for**: Understanding complex integration scenarios
- **Features**: Multiple schema types, integration patterns, performance testing

## 🚀 Running Examples

### Quick Test - Run All Core Examples
```bash
mix run examples/basic_usage.exs
mix run examples/advanced_features.exs
mix run examples/custom_validation.exs
mix run examples/readme_examples.exs
```

### DSPy Development Workflow
```bash
# Start with the big picture
mix run examples/dspy_integration.exs

# Then explore specific features
mix run examples/runtime_schema.exs
mix run examples/type_adapter.exs
mix run examples/wrapper_models.exs
mix run examples/field_metadata_dspy.exs
```

### LLM Integration Workflow
```bash
# Basic LLM integration
mix run examples/llm_integration.exs

# Advanced pipeline orchestration
mix run examples/llm_pipeline_orchestration.exs

# JSON schema optimization
mix run examples/json_schema_resolver.exs

# Root schema for non-dictionary outputs
mix run examples/root_schema.exs
```

### Advanced Validation Patterns
```bash
# Model validators for business logic
mix run examples/model_validators.exs

# Computed fields for derived data
mix run examples/computed_fields.exs

# Conditional and recursive validation
mix run examples/conditional_recursive_validation.exs

# Enhanced validator for complex scenarios
mix run examples/enhanced_validator.exs
```

### Configuration and Optimization
```bash
# Advanced configuration patterns
mix run examples/advanced_config.exs

# JSON schema manipulation
mix run examples/json_schema_resolver.exs

# Performance optimization
mix run examples/type_adapter.exs | grep "Performance"
```

### Run All Examples
```bash
# Run all examples in sequence
for example in examples/*.exs; do
  echo "Running $(basename $example)..."
  mix run "$example"
  echo "---"
done
```

## 📊 Examples by Use Case

### 📝 **Data Validation**
- **Basic**: `basic_usage.exs`, `custom_validation.exs`
- **Advanced**: `advanced_features.exs`, `enhanced_validator.exs`
- **Specialized**: `model_validators.exs`, `computed_fields.exs`

### 🤖 **LLM Integration**
- **Basic**: `llm_integration.exs`, `root_schema.exs`
- **Advanced**: `llm_pipeline_orchestration.exs`, `json_schema_resolver.exs`
- **DSPy**: `dspy_integration.exs`, `field_metadata_dspy.exs`

### ⚡ **Performance & Optimization**
- **Fast Validation**: `type_adapter.exs`, `wrapper_models.exs`
- **Batch Processing**: `enhanced_validator.exs`
- **Schema Optimization**: `json_schema_resolver.exs`

### 🔧 **Development Tools**
- **Dynamic Schemas**: `runtime_schema.exs`, `dspy_integration.exs`
- **Configuration**: `advanced_config.exs`
- **Testing**: `readme_examples.exs`, `phase_3_example.exs`

### 🏗️ **Complex Patterns**
- **Conditional Logic**: `conditional_recursive_validation.exs`
- **Multi-stage Processing**: `llm_pipeline_orchestration.exs`
- **Business Rules**: `model_validators.exs`

## 🎯 Learning Path Recommendations

### 🟢 **Beginner Path**
1. `basic_usage.exs` - Learn core concepts
2. `custom_validation.exs` - Add business logic
3. `advanced_features.exs` - Complex patterns
4. `readme_examples.exs` - Verify understanding

### 🟡 **Intermediate Path**
1. `runtime_schema.exs` - Dynamic schemas
2. `type_adapter.exs` - Runtime validation
3. `wrapper_models.exs` - Flexible input handling
4. `enhanced_validator.exs` - Universal interface

### 🔴 **Advanced Path**
1. `model_validators.exs` - Business logic validation
2. `computed_fields.exs` - Derived data
3. `conditional_recursive_validation.exs` - Complex patterns
4. `json_schema_resolver.exs` - Schema manipulation

### 🤖 **LLM Integration Path**
1. `llm_integration.exs` - Basic LLM validation
2. `root_schema.exs` - Non-dictionary outputs
3. `field_metadata_dspy.exs` - DSPy metadata
4. `llm_pipeline_orchestration.exs` - Complex pipelines
5. `dspy_integration.exs` - Complete integration

## 🔑 Key Concepts by Example

| Concept | Primary Examples | Supporting Examples |
|---------|------------------|-------------------|
| **Schema Definition** | `basic_usage.exs`, `advanced_features.exs` | `readme_examples.exs` |
| **Runtime Schemas** | `runtime_schema.exs`, `dspy_integration.exs` | `field_metadata_dspy.exs` |
| **Type Validation** | `type_adapter.exs`, `enhanced_validator.exs` | `wrapper_models.exs` |
| **Model Validators** | `model_validators.exs` | `conditional_recursive_validation.exs` |
| **Computed Fields** | `computed_fields.exs` | `model_validators.exs` |
| **Root Schemas** | `root_schema.exs` | `llm_integration.exs` |
| **Configuration** | `advanced_config.exs`, `enhanced_validator.exs` | All examples |
| **JSON Schema** | `json_schema_resolver.exs` | `runtime_schema.exs`, `dspy_integration.exs` |
| **LLM Integration** | `llm_integration.exs`, `llm_pipeline_orchestration.exs` | `dspy_integration.exs` |
| **DSPy Patterns** | `dspy_integration.exs`, `field_metadata_dspy.exs` | `runtime_schema.exs`, `wrapper_models.exs` |
| **Error Handling** | All examples | `enhanced_validator.exs` |
| **Performance** | All enhanced examples | `type_adapter.exs` |

## 🛠️ Common Patterns

### Creating Dynamic Schemas
```elixir
# See: runtime_schema.exs, dspy_integration.exs
fields = [
  {:name, :string, [required: true, min_length: 2]},
  {:email, :string, [required: true, format: ~r/@/]}
]
schema = Exdantic.Runtime.create_schema(fields)
```

### Quick Type Validation
```elixir
# See: type_adapter.exs, enhanced_validator.exs  
{:ok, validated} = Exdantic.TypeAdapter.validate(:integer, "123", coerce: true)
```

### Wrapper Validation
```elixir
# See: wrapper_models.exs, dspy_integration.exs
{:ok, score} = Exdantic.Wrapper.wrap_and_validate(:score, :integer, "85", 
  coerce: true, constraints: [gteq: 0, lteq: 100])
```

### Model Validators
```elixir
# See: model_validators.exs, conditional_recursive_validation.exs
defmodule UserSchema do
  use Exdantic
  
  schema do
    field :password, :string
    field :password_confirmation, :string
    model_validator :validate_passwords_match
  end
end
```

### Computed Fields
```elixir
# See: computed_fields.exs
defmodule ProfileSchema do
  use Exdantic
  
  schema do
    field :first_name, :string
    field :last_name, :string
    computed_field :full_name, :string, :generate_full_name
  end
end
```

### LLM Schema Optimization
```elixir
# See: json_schema_resolver.exs, llm_integration.exs
optimized = json_schema
|> Exdantic.JsonSchema.Resolver.resolve_references()
|> Exdantic.JsonSchema.Resolver.optimize_for_provider(:openai)
```

## 📈 Performance Features

Most examples include performance benchmarks showing:
- **Validation Speed**: How fast different approaches validate data
- **Memory Usage**: Memory efficiency of different patterns
- **Batch Processing**: Performance gains from batch operations
- **Schema Compilation**: Runtime vs compile-time schema performance

## 🚨 Error Handling Patterns

Examples demonstrate comprehensive error handling:
- **Field-level errors**: Individual field validation failures
- **Model-level errors**: Cross-field validation failures  
- **Type errors**: Type mismatch and coercion failures
- **Business logic errors**: Custom validation failures
- **Pipeline errors**: Multi-stage validation failures

## 🔍 Debugging Features

Many examples include debugging helpers:
- **Validation reports**: Detailed validation information
- **Schema introspection**: Understanding schema structure
- **Error path tracking**: Finding exactly where validation failed
- **Performance profiling**: Identifying bottlenecks

## 💡 Tips for Learning

1. **Start Simple**: Begin with `basic_usage.exs` to understand core concepts
2. **Follow Use Cases**: Pick examples based on your specific needs
3. **Read the Code**: Each example is heavily commented with explanations
4. **Experiment**: Modify the examples to test different scenarios
5. **Check Performance**: Most examples include performance benchmarks
6. **Understand Errors**: Examples demonstrate both success and failure cases

## 🆘 Getting Help

- Each example includes comprehensive comments explaining the concepts
- Error messages in examples show common pitfalls and solutions
- Performance sections help you understand when to use each feature
- DSPy integration examples show real-world usage patterns

## 🤝 Contributing Examples

When adding new examples:

1. Follow the established format with clear sections and comments
2. Include both success and failure scenarios  
3. Add performance benchmarks for new features
4. Provide practical, real-world use cases
5. Update this README with the new example information

---

**Made with Elixir** 💜 | **Enhanced for DSPy** 🔮 | **Optimized for LLMs** 🤖