# Phase 3: Named Function Computed Fields - Implementation Plan

## Overview

Add computed fields using named function references that execute after model validation. Computed fields generate additional data based on validated input and are included in the final result.

## Goals

- Add `computed_field/3` macro accepting name, type, and function name
- Execute computed fields after model validation
- Include computed fields in struct definition when `define_struct: true`
- Mark computed fields as `readOnly` in JSON schema
- Maintain backward compatibility with existing functionality

## Technical Design

### 1. Schema DSL Extension

Add new `computed_field/3` macro to the schema DSL:

```elixir
schema do
  field :name, :string, required: true
  field :email, :string, required: true
  
  computed_field :display_name, :string, :generate_display_name
  computed_field :email_domain, :string, :extract_email_domain
end

def generate_display_name(data) do
  {:ok, "#{data.name} <#{data.email}>"}
end

def extract_email_domain(data) do
  {:ok, data.email |> String.split("@") |> List.last()}
end
```

### 2. Computed Field Metadata

Extend field metadata to support computed fields:

```elixir
defmodule Exdantic.ComputedFieldMeta do
  defstruct [
    :name,
    :type, 
    :function_name,
    :module,
    :description,
    :example,
    :readonly
  ]
end
```

### 3. Validation Pipeline Extension

Extend the validation pipeline to include computed field execution:

1. Field validation (existing)
2. Model validation (Phase 2)
3. **Computed field execution (new)**
4. Struct creation (Phase 1)

### 4. Implementation Components

#### A. Macro Implementation (`exdantic/schema.ex`)

```elixir
@doc """
Defines a computed field that generates a value based on validated data.

Computed fields execute after model validation and generate additional
data that becomes part of the final validated result.

## Parameters
  * `name` - Field name (atom)
  * `type` - Field type specification
  * `function_name` - Name of function to call for computation

## Function Signature
The referenced function must accept one parameter (validated data) and return:
  * `{:ok, computed_value}` - computation succeeds
  * `{:error, message}` - computation fails

## Examples

    computed_field :full_name, :string, :generate_full_name
    computed_field :age_category, :string, :categorize_age
"""
@spec computed_field(atom(), term(), atom()) :: Macro.t()
defmacro computed_field(name, type, function_name)
```

#### B. StructValidator Enhancement (`exdantic/struct_validator.ex`)

Extend validation pipeline to include computed field execution:

```elixir
defp apply_computed_fields(schema_module, validated_data, path) do
  computed_fields = get_computed_fields(schema_module)
  
  Enum.reduce_while(computed_fields, {:ok, validated_data}, fn
    computed_field_meta, {:ok, current_data} ->
      case execute_computed_field(computed_field_meta, current_data, path) do
        {:ok, computed_value} ->
          updated_data = Map.put(current_data, computed_field_meta.name, computed_value)
          {:cont, {:ok, updated_data}}
        {:error, errors} ->
          {:halt, {:error, errors}}
      end
  end)
end
```

#### C. JSON Schema Integration (`exdantic/json_schema.ex`)

Mark computed fields as `readOnly` in JSON schema:

```elixir
defp convert_computed_field_metadata(computed_field_meta) do
  base_schema = TypeMapper.to_json_schema(computed_field_meta.type, store)
  
  base_schema
  |> Map.put("readOnly", true)
  |> Map.put("description", computed_field_meta.description)
  |> maybe_add_example(computed_field_meta.example)
end
```

#### D. Struct Definition Enhancement (`exdantic.ex`)

Include computed fields in struct definition:

```elixir
# Extract field names including computed fields for struct definition
field_names = Enum.map(fields, fn {name, _meta} -> name end)
computed_field_names = Enum.map(computed_fields, fn {name, _meta} -> name end)
all_field_names = field_names ++ computed_field_names

struct_def = 
  if define_struct? do
    quote do
      defstruct unquote(all_field_names)
    end
  end
```

### 5. Error Handling

Computed field errors should:
- Include field path information
- Distinguish from validation errors
- Allow continuation or halt based on error type
- Provide clear error messages

### 6. Type Safety

- Computed field types are validated like regular fields
- Type specifications support all existing Exdantic types
- Return values are type-checked before inclusion

### 7. Performance Considerations

- Computed fields execute only after successful validation
- Functions are called directly (no dynamic dispatch overhead)
- Minimal memory allocation for field metadata
- Short-circuit execution on first error

## Implementation Steps

### Step 1: Core Infrastructure
1. Add `ComputedFieldMeta` struct
2. Add `computed_field/3` macro to Schema DSL
3. Extend module attribute collection
4. Add computed field retrieval functions

### Step 2: Validation Pipeline
1. Extend `StructValidator.validate_schema/3`
2. Add computed field execution logic
3. Implement error handling and path management
4. Add comprehensive test coverage

### Step 3: Struct Integration
1. Modify struct definition generation
2. Include computed fields in field lists
3. Update `dump/1` to handle computed fields
4. Test struct creation with computed fields

### Step 4: JSON Schema Integration
1. Extend JSON schema generation
2. Mark computed fields as `readOnly`
3. Include computed fields in schema properties
4. Maintain schema validation

### Step 5: Documentation & Examples
1. Add comprehensive documentation
2. Create example schemas
3. Document error patterns
4. Add migration examples

## Testing Strategy

### Unit Tests
- Test `computed_field/3` macro compilation
- Test computed field execution with various return types
- Test error handling and propagation
- Test type validation of computed values

### Integration Tests
- Test full validation pipeline with computed fields
- Test struct creation with computed fields
- Test JSON schema generation
- Test interaction with model validators

### Edge Cases
- Computed functions that reference missing data
- Computed functions that throw exceptions
- Computed values that fail type validation
- Multiple computed fields with dependencies

### Performance Tests
- Benchmark validation pipeline with computed fields
- Memory usage analysis
- Comparison with baseline performance

## Success Criteria

✅ **Backward Compatibility**
- All existing 530 tests continue to pass
- No breaking changes to existing APIs
- Default behavior unchanged

✅ **Functionality**
- Computed fields execute after model validation
- Computed values are included in validation results
- Computed fields appear in struct definitions
- JSON schema marks computed fields as `readOnly`

✅ **Error Handling**
- Computed field errors are properly reported
- Error paths include computed field context
- Graceful handling of function execution failures

✅ **Type Safety**
- Computed values are type-validated
- Dialyzer remains green
- Type specifications work correctly

✅ **Performance**
- No significant performance regression
- Efficient computed field execution
- Minimal memory overhead

✅ **Documentation**
- Clear examples and usage patterns
- Complete API documentation
- Error handling guidance

## Risk Mitigation

### Struct Definition Timing
**Risk**: Computed fields might not be available during struct compilation
**Mitigation**: Collect computed fields during `@before_compile` phase

### Function Resolution
**Risk**: Referenced functions might not exist at compile time
**Mitigation**: Add compile-time checks and clear error messages

### Execution Order
**Risk**: Computed fields might depend on other computed fields
**Mitigation**: Document execution order; consider dependency resolution in future phases

### Performance Impact
**Risk**: Additional validation steps could slow down validation
**Mitigation**: Profile critical paths; optimize computed field execution

### Memory Usage
**Risk**: Storing computed field metadata could increase memory usage
**Mitigation**: Use efficient data structures; minimize metadata size

## Future Enhancements

- **Computed Field Dependencies**: Allow computed fields to reference other computed fields
- **Conditional Computation**: Add support for conditional computed fields
- **Async Computation**: Support for async computed field functions
- **Caching**: Cache computed field results for expensive operations
- **Runtime Computed Fields**: Extend runtime schemas with computed field support
