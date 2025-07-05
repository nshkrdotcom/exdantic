# Solutions for Function Storage in Compile-time Schemas

## Problem Analysis

The core issue is that Elixir module attributes cannot store anonymous functions:
```elixir
# This doesn't work:
@model_validators fn data -> {:ok, data} end  # Cannot store function

# This works:
@model_validators {MyModule, :validate_function}  # Can store MFA tuple
```

## Solution 1: Function Name References (Recommended)

### Implementation Strategy
Instead of storing anonymous functions, require users to define named functions and reference them.

```elixir
# New DSL syntax
defmodule UserSchema do
  use Exdantic, define_struct: true

  schema do
    field :password, :string, required: true
    field :password_confirmation, :string, required: true

    # Reference named function instead of anonymous function
    model_validator :validate_passwords
    
    computed_field :full_name, :string, :compute_full_name
  end
  
  # Define the validation function
  def validate_passwords(data) do
    if data.password == data.password_confirmation do
      {:ok, data}
    else
      {:error, "passwords do not match"}
    end
  end
  
  # Define the computed field function
  def compute_full_name(data) do
    "#{data.first_name} #{data.last_name}"
  end
end
```

### Macro Implementation
```elixir
# In exdantic/schema.ex
defmacro model_validator(function_name) when is_atom(function_name) do
  quote do
    @model_validators {__MODULE__, unquote(function_name)}
  end
end

defmacro computed_field(name, type, function_name) when is_atom(function_name) do
  quote do
    field_meta = %Exdantic.FieldMeta{
      name: unquote(name),
      type: unquote(handle_type(type)),
      required: false,
      constraints: []
    }
    
    @computed_fields {unquote(name), {field_meta, {__MODULE__, unquote(function_name)}}}
  end
end
```

### Enhanced Schema Validator Changes
```elixir
# In exdantic/enhanced_schema_validator.ex
defp apply_model_validators(model_validators, validated_data, path) do
  Enum.reduce_while(model_validators, {:ok, validated_data}, fn 
    {module, function_name}, {:ok, current_data} ->
      case apply(module, function_name, [current_data]) do
        {:ok, new_data} -> {:cont, {:ok, new_data}}
        {:error, reason} -> 
          error = Error.new(path, :model_validation, reason)
          {:halt, {:error, [error]}}
      end
      
    validator_fn, {:ok, current_data} when is_function(validator_fn) ->
      # Support runtime anonymous functions
      case validator_fn.(current_data) do
        {:ok, new_data} -> {:cont, {:ok, new_data}}
        {:error, reason} -> 
          error = Error.new(path, :model_validation, reason)
          {:halt, {:error, [error]}}
      end
  end)
end
```

## Solution 2: Code Generation with AST Storage

### Implementation Strategy
Store the AST of functions and generate actual functions at compile time.

```elixir
defmodule UserSchema do
  use Exdantic, define_struct: true

  schema do
    field :password, :string, required: true
    field :password_confirmation, :string, required: true

    # Store AST, generate function at compile time
    model_validator do
      fn data ->
        if data.password == data.password_confirmation do
          {:ok, data}
        else
          {:error, "passwords do not match"}
        end
      end
    end
  end
end
```

### Macro Implementation
```elixir
defmacro model_validator(do: block) do
  # Generate a unique function name
  function_name = :"__model_validator_#{System.unique_integer([:positive])}"
  
  quote do
    # Store the function reference
    @model_validators {__MODULE__, unquote(function_name)}
    
    # Generate the actual function
    def unquote(function_name)(data) do
      validator_fn = unquote(block)
      validator_fn.(data)
    end
  end
end

defmacro computed_field(name, type, do: block) do
  function_name = :"__computed_field_#{name}_#{System.unique_integer([:positive])}"
  
  quote do
    field_meta = %Exdantic.FieldMeta{
      name: unquote(name),
      type: unquote(handle_type(type)),
      required: false,
      constraints: []
    }
    
    @computed_fields {unquote(name), {field_meta, {__MODULE__, unquote(function_name)}}}
    
    def unquote(function_name)(data) do
      compute_fn = unquote(block)
      compute_fn.(data)
    end
  end
end
```

## Solution 3: Hybrid Approach (Best of Both Worlds)

### Implementation Strategy
Support both named functions and anonymous functions with different syntax.

```elixir
defmodule UserSchema do
  use Exdantic, define_struct: true

  schema do
    field :password, :string, required: true
    field :password_confirmation, :string, required: true
    field :first_name, :string, required: true
    field :last_name, :string, required: true

    # Option 1: Named function reference
    model_validator :validate_passwords
    
    # Option 2: Inline anonymous function (generates named function)
    model_validator do
      fn data ->
        if String.length(data.password) >= 8 do
          {:ok, data}
        else
          {:error, "password too short"}
        end
      end
    end
    
    # Option 3: Direct function body
    model_validator fn data ->
      cond do
        data.first_name == data.last_name -> {:error, "first and last name cannot be same"}
        true -> {:ok, data}
      end
    end
    
    # Computed fields with same flexibility
    computed_field :full_name, :string, :compute_full_name
    
    computed_field :initials, :string, do: fn data ->
      "#{String.first(data.first_name)}.#{String.first(data.last_name)}."
    end
  end
  
  # Named functions for references
  def validate_passwords(data) do
    if data.password == data.password_confirmation do
      {:ok, data}
    else
      {:error, "passwords do not match"}
    end
  end
  
  def compute_full_name(data) do
    "#{data.first_name} #{data.last_name}"
  end
end
```

### Macro Implementation
```elixir
# Support multiple forms
defmacro model_validator(function_name) when is_atom(function_name) do
  quote do
    @model_validators {__MODULE__, unquote(function_name)}
  end
end

defmacro model_validator(do: block) do
  function_name = :"__model_validator_#{System.unique_integer([:positive])}"
  
  quote do
    @model_validators {__MODULE__, unquote(function_name)}
    
    def unquote(function_name)(data) do
      validator_fn = unquote(block)
      validator_fn.(data)
    end
  end
end

defmacro model_validator(function_literal) do
  function_name = :"__model_validator_#{System.unique_integer([:positive])}"
  
  quote do
    @model_validators {__MODULE__, unquote(function_name)}
    
    def unquote(function_name)(data) do
      validator_fn = unquote(function_literal)
      validator_fn.(data)
    end
  end
end
```

## Solution 4: External Function Registry

### Implementation Strategy
Use a global registry to store functions with generated keys.

```elixir
defmodule Exdantic.FunctionRegistry do
  @moduledoc """
  Global registry for storing validator and computed field functions.
  """
  
  use Agent
  
  def start_link(_opts) do
    Agent.start_link(fn -> %{} end, name: __MODULE__)
  end
  
  def register_function(key, function) do
    Agent.update(__MODULE__, &Map.put(&1, key, function))
  end
  
  def get_function(key) do
    Agent.get(__MODULE__, &Map.get(&1, key))
  end
end

# In schema definition
defmacro model_validator(function_literal) do
  key = "#{__CALLER__.module}_validator_#{System.unique_integer([:positive])}"
  
  quote do
    # Register function at compile time
    Exdantic.FunctionRegistry.register_function(unquote(key), unquote(function_literal))
    @model_validators unquote(key)
  end
end
```

## Recommendation: Solution 3 (Hybrid Approach)

### Why This is Best:

1. **Flexibility**: Supports both simple named functions and complex inline logic
2. **Clean API**: Users can choose the most appropriate syntax for their use case
3. **No External Dependencies**: No need for registries or agents
4. **Compile-time Safety**: All functions are generated at compile time
5. **Backward Compatibility**: Easy to migrate existing code

### Implementation Plan:

1. **Phase 1**: Implement named function support (Solution 1)
2. **Phase 2**: Add `do:` block support for inline functions
3. **Phase 3**: Add direct function literal support
4. **Phase 4**: Update documentation and examples

### Usage Examples:

```elixir
# Simple case - named function
model_validator :check_age

# Complex case - inline logic
model_validator do
  fn data ->
    errors = []
    
    errors = if data.age < 18, do: ["too young" | errors], else: errors
    errors = if not String.contains?(data.email, "@"), do: ["invalid email" | errors], else: errors
    
    case errors do
      [] -> {:ok, data}
      errs -> {:error, Enum.join(errs, ", ")}
    end
  end
end

# Medium case - simple inline function
computed_field :display_name, :string, fn data ->
  if data.nickname, do: data.nickname, else: data.full_name
end
```

This hybrid approach gives users the flexibility to choose the right level of complexity for their validation needs while solving the function storage limitation completely.
