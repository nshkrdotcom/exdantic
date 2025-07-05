# Exdantic Enhancement Implementation Plan

## Overview

This document provides a detailed, step-by-step implementation plan for an agent to flesh out the new Exdantic features and fix the tests. The existing codebase has some implementations but they will likely be buggy and incomplete. This plan ensures systematic development and testing.

## Phase 1: Core Infrastructure Setup (Days 1-3)

### Step 1.1: Analyze and Fix Core Dependencies
**Priority: Critical**
**Time Estimate: 4-6 hours**

1. **Review existing core modules:**
   ```bash
   # Examine current state
   find lib/exdantic -name "*.ex" | xargs grep -l "defmodule.*\." | sort
   ```

2. **Fix base type system issues:**
   - Open `lib/exdantic/types.ex`
   - Run basic tests: `mix test test/exdantic/types_test.exs` (if exists)
   - Fix any compilation errors in `normalize_type/1` and `validate/2` functions
   - Ensure all basic types (string, integer, float, boolean, atom, any, map) work
   - Test constraint application functions

3. **Verify error handling:**
   - Open `lib/exdantic/error.ex`
   - Test `Error.new/3` and `Error.format/1` functions
   - Ensure proper struct definition and validation

4. **Fix field metadata:**
   - Open `lib/exdantic/field_meta.ex`
   - Verify `FieldMeta` struct definition
   - Test `FieldMeta.new/3` function

### Step 1.2: Fix Core Validator
**Priority: Critical**
**Time Estimate: 6-8 hours**

1. **Debug validator module:**
   ```elixir
   # Test basic validation first
   iex> Exdantic.Validator.validate(:string, "hello", [])
   ```

2. **Fix validation pipeline:**
   - Open `lib/exdantic/validator.ex`
   - Test each validation function individually:
     - `validate_schema/3`
     - `validate/3` with different type definitions
     - Constraint application functions
   - Fix any pattern matching errors
   - Ensure error path construction works correctly

3. **Test constraint validation:**
   ```elixir
   # Test each constraint type
   iex> Exdantic.Validator.validate({:type, :string, [min_length: 3]}, "hi", [])
   iex> Exdantic.Validator.validate({:type, :integer, [gt: 0]}, 5, [])
   ```

### Step 1.3: Create Basic Test Infrastructure
**Priority: High**
**Time Estimate: 2-3 hours**

1. **Set up test helper:**
   ```bash
   # Copy the test helper we created
   cp test_helper.exs test/test_helper.exs
   ```

2. **Create basic validation tests:**
   ```bash
   mkdir -p test/exdantic
   # Start with simple validator tests before complex features
   ```

3. **Ensure mix test runs:**
   ```bash
   mix compile
   mix test --no-start
   ```

## Phase 2: Runtime Schema Generation (Days 4-8)

### Step 2.1: Implement Dynamic Schema Structure
**Priority: Critical**
**Time Estimate: 8-12 hours**

1. **Fix DynamicSchema struct:**
   - Open `lib/exdantic/runtime/dynamic_schema.ex`
   - Test struct creation:
     ```elixir
     iex> alias Exdantic.Runtime.DynamicSchema
     iex> DynamicSchema.new("test", %{}, %{})
     ```

2. **Implement missing functions:**
   - Fix `get_field/2`, `field_names/1`, `required_fields/1`
   - Test each function individually
   - Add error handling for edge cases

3. **Test DynamicSchema operations:**
   ```elixir
   # Create test schema
   fields = %{name: %Exdantic.FieldMeta{name: :name, type: {:type, :string, []}, required: true}}
   schema = DynamicSchema.new("TestSchema", fields, %{})
   
   # Test operations
   DynamicSchema.get_field(schema, :name)
   DynamicSchema.field_names(schema)
   DynamicSchema.required_fields(schema)
   ```

### Step 2.2: Implement Runtime Schema Creation
**Priority: Critical**
**Time Estimate: 10-14 hours**

1. **Fix field definition parsing:**
   - Open `lib/exdantic/runtime.ex`
   - Debug `normalize_field_definition/1`:
     ```elixir
     # Test field parsing
     iex> fields = [{:name, :string, [required: true]}]
     iex> Exdantic.Runtime.normalize_field_definition(hd(fields))
     ```

2. **Fix type normalization:**
   - Debug `normalize_type_definition/2`
   - Test with different type specs:
     ```elixir
     iex> Exdantic.Runtime.normalize_type_definition(:string, [])
     iex> Exdantic.Runtime.normalize_type_definition({:array, :string}, [])
     ```

3. **Implement schema creation:**
   ```elixir
   # Test basic schema creation
   iex> fields = [{:name, :string, [required: true]}]
   iex> schema = Exdantic.Runtime.create_schema(fields)
   ```

4. **Debug constraint extraction:**
   - Fix `extract_constraints/1`
   - Test with various constraint types

### Step 2.3: Implement Runtime Validation
**Priority: Critical**
**Time Estimate: 8-10 hours**

1. **Fix validation functions:**
   - Debug `validate/3` in Runtime module
   - Test `validate_required_fields/3`
   - Fix `validate_fields/3` 
   - Test `validate_strict_mode/4`

2. **Test validation pipeline:**
   ```elixir
   # Test complete validation
   schema = Exdantic.Runtime.create_schema([{:name, :string, [required: true]}])
   Exdantic.Runtime.validate(%{name: "John"}, schema)
   ```

3. **Fix error handling:**
   - Ensure proper error path construction
   - Test with invalid data and verify error messages

### Step 2.4: Implement JSON Schema Generation
**Priority: High**
**Time Estimate: 6-8 hours**

1. **Fix JSON schema generation:**
   - Debug `to_json_schema/2` in Runtime module
   - Test `convert_field_metadata/1`
   - Fix reference handling

2. **Test JSON schema output:**
   ```elixir
   schema = Exdantic.Runtime.create_schema([{:name, :string, [min_length: 3]}])
   json_schema = Exdantic.Runtime.to_json_schema(schema)
   # Verify structure and constraints
   ```

### Step 2.5: Fix Runtime Tests
**Priority: High**
**Time Estimate: 4-6 hours**

1. **Run runtime tests:**
   ```bash
   mix test test/exdantic/runtime_test.exs
   ```

2. **Fix failing tests one by one:**
   - Start with basic schema creation tests
   - Fix validation tests
   - Fix JSON schema generation tests

3. **Add missing test cases for edge cases found during implementation**

## Phase 3: TypeAdapter Implementation (Days 9-13)

### Step 3.1: Implement Core TypeAdapter
**Priority: Critical**
**Time Estimate: 10-12 hours**

1. **Fix TypeAdapter module structure:**
   - Open `lib/exdantic/type_adapter.ex`
   - Test `validate/3` function:
     ```elixir
     iex> Exdantic.TypeAdapter.validate(:string, "hello")
     ```

2. **Debug type normalization:**
   - Fix `normalize_type_spec/1`
   - Test with various type specifications

3. **Implement coercion system:**
   - Debug `attempt_coercion/2`
   - Test coercion for different types:
     ```elixir
     iex> Exdantic.TypeAdapter.validate(:integer, "123", coerce: true)
     ```

4. **Fix complex type validation:**
   - Debug array validation
   - Debug map validation  
   - Debug union type validation

### Step 3.2: Implement Serialization (Dump)
**Priority: High**
**Time Estimate: 6-8 hours**

1. **Implement dump functionality:**
   - Debug `dump/3` function
   - Fix `serialize_value/4`
   - Test with different types:
     ```elixir
     iex> Exdantic.TypeAdapter.dump(:string, "hello")
     iex> Exdantic.TypeAdapter.dump({:array, :integer}, [1, 2, 3])
     ```

2. **Test serialization options:**
   - Test `exclude_none` option
   - Test `exclude_defaults` option

### Step 3.3: Implement TypeAdapter Instance
**Priority: Medium**
**Time Estimate: 6-8 hours**

1. **Fix TypeAdapter.Instance module:**
   - Open `lib/exdantic/type_adapter/instance.ex`
   - Test instance creation:
     ```elixir
     iex> adapter = Exdantic.TypeAdapter.Instance.new(:string)
     ```

2. **Fix instance methods:**
   - Debug `validate/3`
   - Debug `dump/3`
   - Test caching functionality

3. **Implement batch operations:**
   - Fix `validate_many/3`
   - Fix `dump_many/3`

### Step 3.4: Fix TypeAdapter Tests
**Priority: High**
**Time Estimate: 4-6 hours**

1. **Run TypeAdapter tests:**
   ```bash
   mix test test/exdantic/type_adapter_test.exs
   ```

2. **Fix test failures systematically:**
   - Basic type validation tests
   - Complex type tests
   - Coercion tests
   - Serialization tests
   - Instance tests

## Phase 4: JSON Schema Resolution (Days 14-17)

### Step 4.1: Implement Reference Resolution
**Priority: High**
**Time Estimate: 8-10 hours**

1. **Fix Resolver module:**
   - Open `lib/exdantic/json_schema/resolver.ex`
   - Test basic reference resolution:
     ```elixir
     schema = %{"$ref" => "#/definitions/User", "definitions" => %{"User" => %{"type" => "object"}}}
     Exdantic.JsonSchema.Resolver.resolve_references(schema)
     ```

2. **Debug reference resolution pipeline:**
   - Fix `resolve_schema_part/3`
   - Fix `resolve_reference/3`
   - Handle circular references

3. **Test with complex schemas:**
   - Nested references
   - Multiple definition levels
   - Circular reference detection

### Step 4.2: Implement Schema Flattening
**Priority: Medium**
**Time Estimate: 6-8 hours**

1. **Implement flattening functionality:**
   - Debug `flatten_schema/2`
   - Fix `inline_simple_types/2`

2. **Test flattening operations:**
   ```elixir
   complex_schema = # Create schema with multiple references
   flattened = Exdantic.JsonSchema.Resolver.flatten_schema(complex_schema)
   ```

### Step 4.3: Implement LLM Provider Support
**Priority: Medium**
**Time Estimate: 4-6 hours**

1. **Fix provider-specific enforcement:**
   - Debug `enforce_structured_output/2`
   - Fix `apply_provider_rules/3`
   - Test OpenAI and Anthropic rules

2. **Implement optimization functions:**
   - Fix `optimize_for_llm/2`
   - Test description removal
   - Test union simplification

### Step 4.4: Fix Resolver Tests
**Priority: Medium**
**Time Estimate: 3-4 hours**

1. **Run resolver tests:**
   ```bash
   mix test test/exdantic/json_schema/resolver_test.exs
   ```

2. **Fix failing tests and add edge cases**

## Phase 5: Wrapper Implementation (Days 18-21)

### Step 5.1: Implement Core Wrapper Functionality
**Priority: High**
**Time Estimate: 8-10 hours**

1. **Fix Wrapper module:**
   - Open `lib/exdantic/wrapper.ex`
   - Test wrapper creation:
     ```elixir
     iex> wrapper = Exdantic.Wrapper.create_wrapper(:test, :string)
     ```

2. **Debug validation and extraction:**
   - Fix `validate_and_extract/3`
   - Fix `wrap_and_validate/4`
   - Test data normalization functions

3. **Test wrapper operations:**
   ```elixir
   wrapper = Exdantic.Wrapper.create_wrapper(:score, :integer, constraints: [gt: 0])
   Exdantic.Wrapper.validate_and_extract(wrapper, 42, :score)
   ```

### Step 5.2: Implement Advanced Wrapper Features
**Priority: Medium**
**Time Estimate: 6-8 hours**

1. **Fix multi-wrapper operations:**
   - Debug `create_multiple_wrappers/2`
   - Debug `validate_multiple/2`

2. **Implement flexible wrapper handling:**
   - Fix `create_flexible_wrapper/3`
   - Debug `validate_flexible/3`

3. **Test factory pattern:**
   - Fix `create_wrapper_factory/2`

### Step 5.3: Fix Wrapper Tests
**Priority: Medium**
**Time Estimate: 3-4 hours**

1. **Run wrapper tests:**
   ```bash
   mix test test/exdantic/wrapper_test.exs
   ```

2. **Fix test failures and performance issues**

## Phase 6: Configuration System (Days 22-24)

### Step 6.1: Implement Advanced Configuration
**Priority: High**
**Time Estimate: 6-8 hours**

1. **Fix Config module:**
   - Open `lib/exdantic/config.ex`
   - Test basic configuration:
     ```elixir
     iex> config = Exdantic.Config.create(strict: true)
     ```

2. **Fix configuration operations:**
   - Debug `merge/2`
   - Fix `validate_config/1`
   - Test preset configurations

3. **Fix builder integration:**
   - Open `lib/exdantic/config/builder.ex`
   - Test builder pattern

### Step 6.2: Fix Configuration Tests
**Priority: Medium**
**Time Estimate: 3-4 hours**

1. **Run configuration tests:**
   ```bash
   mix test test/exdantic/config_test.exs
   ```

2. **Fix failing tests and edge cases**

## Phase 7: Enhanced Validator (Days 25-27)

### Step 7.1: Implement Enhanced Validator
**Priority: High**
**Time Estimate: 8-10 hours**

1. **Fix EnhancedValidator module:**
   - Open `lib/exdantic/enhanced_validator.ex`
   - Test universal validation:
     ```elixir
     iex> Exdantic.EnhancedValidator.validate(schema, data)
     ```

2. **Debug validation dispatch:**
   - Fix target type detection
   - Fix configuration integration
   - Test with different input types

3. **Implement advanced features:**
   - Fix `validate_many/3`
   - Fix `pipeline/3`
   - Fix `validation_report/3`

### Step 7.2: Fix Enhanced Validator Tests
**Priority: Medium**
**Time Estimate: 4-5 hours**

1. **Run enhanced validator tests:**
   ```bash
   mix test test/exdantic/enhanced_validator_test.exs
   ```

2. **Fix integration issues and performance problems**

## Phase 8: Integration and Testing (Days 28-30)

### Step 8.1: Run Integration Tests
**Priority: Critical**
**Time Estimate: 6-8 hours**

1. **Run full integration test suite:**
   ```bash
   mix test test/exdantic/integration_test.exs
   ```

2. **Fix complex integration issues:**
   - Runtime + TypeAdapter integration
   - Configuration + Validation integration
   - JSON Schema + Resolver integration

3. **Test DSPy patterns:**
   - Test `create_model` simulation
   - Test `TypeAdapter` patterns
   - Test wrapper model patterns

### Step 8.2: Performance Optimization
**Priority: Medium**
**Time Estimate: 4-6 hours**

1. **Run performance benchmarks:**
   ```bash
   mix test --include slow
   ```

2. **Optimize bottlenecks:**
   - Profile with `:fprof` or `:eprof`
   - Optimize hot paths
   - Reduce memory allocations

3. **Verify performance targets:**
   - Runtime schema creation: 1000 schemas < 1 second
   - TypeAdapter validation: 10k items < 200ms
   - JSON schema generation: complex schemas < 50ms

### Step 8.3: Final Testing and Documentation
**Priority: High**
**Time Estimate: 4-6 hours**

1. **Run complete test suite:**
   ```bash
   mix test --cover
   ```

2. **Fix any remaining test failures**

3. **Update inline documentation and examples**

## Debugging Strategy

### Common Issue Patterns

1. **Pattern Matching Errors:**
   ```elixir
   # Add debug prints to see actual vs expected patterns
   IO.inspect(value, label: "Actual value")
   ```

2. **Struct Definition Issues:**
   ```elixir
   # Test struct creation in iex
   iex> %Exdantic.Runtime.DynamicSchema{}
   ```

3. **Module Loading Issues:**
   ```bash
   # Check compilation
   mix compile --warnings-as-errors
   ```

4. **Function Clause Errors:**
   - Add catch-all clauses with detailed error messages
   - Use guards to validate input types

### Testing Approach

1. **Bottom-up Testing:**
   - Test basic functions first
   - Build up to complex integrations
   - Use iex for interactive testing

2. **Incremental Development:**
   - Fix one test at a time
   - Commit working increments
   - Don't move to next feature until current is stable

3. **Error-driven Development:**
   - Let tests guide implementation
   - Fix compilation errors first
   - Then fix test failures
   - Finally optimize performance

### Success Criteria

**Phase 1-2 Complete:** Basic runtime schema creation and validation works
**Phase 3-4 Complete:** TypeAdapter and JSON schema resolution functional  
**Phase 5-6 Complete:** Wrapper models and configuration system operational
**Phase 7-8 Complete:** All features integrated, tests pass, performance targets met

**Final Success:** All tests pass, DSPy integration patterns work, performance benchmarks met, ready for production use in DSPEx.
