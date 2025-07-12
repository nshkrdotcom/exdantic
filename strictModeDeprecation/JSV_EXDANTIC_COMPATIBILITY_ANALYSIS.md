# JSV/Exdantic Compatibility Analysis

## Executive Summary

The reported incompatibility between JSV and Exdantic stems from a **key type handling mismatch** in strict mode validation, not from the libraries' core validation approaches. JSV provides raw JSON data with binary (string) keys, while Exdantic's strict mode validation expects the exact keys that were processed during field validation.

## Root Cause Analysis

### The Problem

When using JSV with Exdantic through the `defcast` integration pattern:

1. **JSV receives JSON data** with string keys: `%{"name" => "alice", "email" => "foo@bar.com"}`
2. **Exdantic processes fields** by looking for both atom and string keys, but stores results with atom keys
3. **Strict mode validation fails** because it compares the original input keys (strings) against the processed keys (atoms)

### Key Code Analysis

#### Exdantic Field Processing (`lib/exdantic/validator.ex:84`)
```elixir
value = Map.get(data, name) || Map.get(data, Atom.to_string(name))
```
- Exdantic tries both atom keys and string keys when extracting field values
- This allows flexible input but creates the mismatch with strict validation

#### Strict Mode Validation (`lib/exdantic/validator.ex:106-113`)
```elixir
defp validate_strict(%{strict: true}, validated, original, path) do
  case Map.keys(original) -- Map.keys(validated) do
    [] -> :ok
    extra -> {:error, Error.new(path, :additional_properties, "unknown fields: #{inspect(extra)}")}
  end
end
```
- Compares original input keys directly against processed output keys
- Fails when input has string keys but output has atom keys

### Test Results

| Input Keys | Exdantic Result | JSV Integration Result |
|------------|-----------------|----------------------|
| String keys (`%{"name" => "alice"}`) | ❌ Strict mode error | ❌ Same error |
| Atom keys (`%{name: "alice"}`) | ✅ Success | ❌ Model validator error |
| Mixed keys (`%{"name" => "alice", email: "foo"}`) | ❌ Partial strict error | ❌ Same error |

## Technical Investigation Details

### Reproduction Steps

1. **Created integration test** (`test_jsv_integration.exs`):
   - Defines UserSchema with JSV.Schema integration
   - Tests with string keys (typical JSON)
   - Tests with atom keys

2. **Isolated Exdantic behavior** (`test_key_handling.exs`):
   - Confirmed strict mode fails with string keys
   - Confirmed success with atom keys
   - Identified the exact validation step that fails

### Error Analysis

#### String Keys Error (Primary Issue)
```
unknown fields: ["email", "name"]
```
- **Cause**: Strict validation sees string keys in input, atom keys in output
- **Location**: `validate_strict/4` function
- **Impact**: Blocks all JSON data in strict mode

#### Model Validator Error (Secondary Issue)
```
key :age not found in: %{active: true, name: "alice", email: "foo@bar.com"}
```
- **Cause**: Custom validator assumes atom key access
- **Location**: User-defined `validate_adult_email/1` function
- **Impact**: Breaks even when strict validation passes

## Potential Solutions

### 1. Fix Strict Mode Key Handling (Recommended)

**Problem**: Strict validation doesn't account for key type normalization.

**Solution**: Modify `validate_strict/4` to handle key type mismatches:

```elixir
defp validate_strict(%{strict: true}, validated, original, path) do
  # Normalize both sets of keys for comparison
  original_keys = Map.keys(original) |> normalize_keys()
  validated_keys = Map.keys(validated) |> normalize_keys()
  
  case original_keys -- validated_keys do
    [] -> :ok
    extra -> {:error, Error.new(path, :additional_properties, "unknown fields: #{inspect(extra)}")}
  end
end

defp normalize_keys(keys) do
  keys
  |> Enum.map(fn
    key when is_atom(key) -> key
    key when is_binary(key) -> String.to_existing_atom(key)
    key -> key
  end)
  |> Enum.sort()
end
```

**Pros**: Fixes the root cause, maintains strict validation semantics
**Cons**: Requires modification to Exdantic core

### 2. Key Normalization in JSV Integration

**Problem**: JSV passes string keys but user code expects atom keys.

**Solution**: Add key transformation in the cast function:

```elixir
defcast from_jsv(data) do
  # Convert string keys to atom keys before validation
  normalized_data = 
    data
    |> Enum.map(fn {k, v} -> 
      key = if is_binary(k), do: String.to_existing_atom(k), else: k
      {key, v}
    end)
    |> Map.new()
  
  validate(normalized_data)
end
```

**Pros**: Quick fix, doesn't require Exdantic changes
**Cons**: Requires manual implementation in each schema, potential atom exhaustion

### 3. Disable Strict Mode for JSV Integration

**Problem**: Strict mode is incompatible with string key inputs.

**Solution**: Use non-strict schemas for JSV integration:

```elixir
schema "User account information" do
  # ... fields ...
  
  config do
    title("User Schema")
    strict(false)  # Allow string keys
  end
end
```

**Pros**: Immediate fix, no code changes needed
**Cons**: Loses strict validation benefits

### 4. Dual Validation Approach

**Problem**: Need both JSV compliance and Exdantic strict validation.

**Solution**: Separate validation stages:

```elixir
def from_jsv(data) do
  # Stage 1: Validate with relaxed Exdantic (no strict)
  with {:ok, basic_valid} <- BasicUserSchema.validate(data),
       # Stage 2: Convert to atom keys
       atom_data <- normalize_keys(basic_valid),
       # Stage 3: Validate with strict Exdantic  
       {:ok, final} <- StrictUserSchema.validate(atom_data) do
    {:ok, final}
  end
end
```

**Pros**: Maintains both validations, clear separation of concerns
**Cons**: More complex, potential performance impact

## Recommendations

### Immediate Actions

1. **For JSV Integration**: Use Solution #2 (key normalization) or #3 (disable strict mode) as a quick fix
2. **Document the limitation**: Add clear documentation about key type requirements

### Long-term Solutions

1. **Enhance Exdantic**: Implement Solution #1 to fix strict mode key handling
2. **Improve JSV Integration**: Add built-in key normalization utilities
3. **Add Integration Tests**: Create comprehensive test suite for JSV/Exdantic compatibility

### Code Quality Improvements

The current JSV/Exdantic integration attempts show that both libraries are well-designed individually but need better integration patterns. The issue is not fundamental incompatibility but rather a need for better key handling in edge cases.

## Conclusion

The JSV/Exdantic incompatibility is **solvable** and stems from strict mode validation logic rather than fundamental design differences. The libraries can work together effectively with proper key handling. The recommended approach is to fix the strict validation logic in Exdantic while providing temporary workarounds for immediate use cases.

This analysis demonstrates that LLM-generated code performed reasonably well in identifying a real integration challenge, though it didn't account for the key type handling nuances in strict mode validation.