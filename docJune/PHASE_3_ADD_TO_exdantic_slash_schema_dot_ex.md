# This code should be added to exdantic/schema.ex

@doc """
Defines a computed field that generates a value based on validated data.

Computed fields execute after field and model validation, generating additional
data that becomes part of the final validated result. They are particularly
useful for derived values, formatted representations, or aggregated data.

## Parameters
  * `name` - Field name (atom)
  * `type` - Field type specification (same as regular fields)
  * `function_name` - Name of the function to call for computation (atom)

## Function Signature
The referenced function must accept one parameter (the validated data) and return:
  * `{:ok, computed_value}` - computation succeeds
  * `{:error, message}` - computation fails with error message
  * `{:error, %Exdantic.Error{}}` - computation fails with detailed error

## Execution Order
Computed fields execute after:
1. Field validation
2. Model validation

This ensures computed fields have access to fully validated and transformed data.

## Examples

    defmodule UserSchema do
      use Exdantic, define_struct: true
      
      schema do
        field :first_name, :string, required: true
        field :last_name, :string, required: true
        field :email, :string, required: true
        
        computed_field :full_name, :string, :generate_full_name
        computed_field :email_domain, :string, :extract_email_domain
        computed_field :initials, :string, :create_initials
      end
      
      def generate_full_name(data) do
        {:ok, "#{data.first_name} #{data.last_name}"}
      end
      
      def extract_email_domain(data) do
        domain = data.email |> String.split("@") |> List.last()
        {:ok, domain}
      end
      
      def create_initials(data) do
        first_initial = String.first(data.first_name)
        last_initial = String.first(data.last_name)
        {:ok, "#{first_initial}#{last_initial}"}
      end
    end

    # Usage
    {:ok, user} = UserSchema.validate(%{
      first_name: "John",
      last_name: "Doe", 
      email: "john@example.com"
    })
    
    # Result includes computed fields
    # user.full_name => "John Doe"
    # user.email_domain => "example.com"
    # user.initials => "JD"

## Error Handling

Computed field functions can return errors that will be included in validation results:

    def risky_computation(data) do
      if valid_computation?(data) do
        {:ok, compute_value(data)}
      else
        {:error, "Computation failed due to invalid data"}
      end
    end

## Type Safety

Computed field return values are validated against their declared types:

    computed_field :score, :integer, :calculate_score
    
    def calculate_score(data) do
      # This will fail validation if score is not an integer
      {:ok, "not an integer"}
    end

## JSON Schema Integration

Computed fields are automatically included in generated JSON schemas and marked as `readOnly`:

    %{
      "type" => "object",
      "properties" => %{
        "first_name" => %{"type" => "string"},
        "full_name" => %{"type" => "string", "readOnly" => true}
      }
    }

## With Struct Definition

When using `define_struct: true`, computed fields are included in the struct definition:

    defstruct [:first_name, :last_name, :email, :full_name, :email_domain, :initials]
"""
@spec computed_field(atom(), term(), atom()) :: Macro.t()
defmacro computed_field(name, type, function_name) 
    when is_atom(name) and is_atom(function_name) do
  quote do
    # Validate that the field name is a valid atom
    unless is_atom(unquote(name)) and not is_nil(unquote(name)) do
      raise ArgumentError, "computed field name must be a non-nil atom, got: #{inspect(unquote(name))}"
    end
    
    # Validate that the function name is a valid atom  
    unless is_atom(unquote(function_name)) and not is_nil(unquote(function_name)) do
      raise ArgumentError, "computed field function name must be a non-nil atom, got: #{inspect(unquote(function_name))}"
    end

    # Create computed field metadata
    computed_field_meta = %Exdantic.ComputedFieldMeta{
      name: unquote(name),
      type: unquote(handle_type(type)),
      function_name: unquote(function_name),
      module: __MODULE__,
      readonly: true
    }
    
    # Store the computed field metadata
    @computed_fields {unquote(name), computed_field_meta}
  end
end

@doc """
Defines a computed field with additional metadata like description and example.

This version allows you to provide a description and example for the computed field,
which will be included in generated JSON schemas and documentation.

## Parameters
  * `name` - Field name (atom)
  * `type` - Field type specification
  * `function_name` - Name of the function to call for computation (atom)
  * `opts` - Options for the computed field

## Options
  * `:description` - Description of the computed field
  * `:example` - Example value for the computed field

## Examples

    schema do
      field :first_name, :string, required: true
      field :last_name, :string, required: true
      
      computed_field :full_name, :string, :generate_full_name,
        description: "User's full name combining first and last name",
        example: "John Doe"
    end
"""
@spec computed_field(atom(), term(), atom(), keyword()) :: Macro.t()
defmacro computed_field(name, type, function_name, opts) 
    when is_atom(name) and is_atom(function_name) and is_list(opts) do
  description = Keyword.get(opts, :description)
  example = Keyword.get(opts, :example)
  
  quote do
    # Validate inputs
    unless is_atom(unquote(name)) and not is_nil(unquote(name)) do
      raise ArgumentError, "computed field name must be a non-nil atom, got: #{inspect(unquote(name))}"
    end
    
    unless is_atom(unquote(function_name)) and not is_nil(unquote(function_name)) do
      raise ArgumentError, "computed field function name must be a non-nil atom, got: #{inspect(unquote(function_name))}"
    end

    # Create computed field metadata with additional options
    computed_field_meta = %Exdantic.ComputedFieldMeta{
      name: unquote(name),
      type: unquote(handle_type(type)),
      function_name: unquote(function_name),
      module: __MODULE__,
      description: unquote(description),
      example: unquote(example),
      readonly: true
    }
    
    # Store the computed field metadata
    @computed_fields {unquote(name), computed_field_meta}
  end
end

# Add helper macros for computed field metadata within the computed_field block context

@doc """
Sets a description for the computed field.

This macro should be used within a computed_field block to provide
documentation for the computed field.

## Parameters
  * `text` - String description of the computed field's purpose

## Examples

    computed_field :display_name, :string, :create_display_name do
      description("User's display name for UI components")
    end
"""
@spec computed_description(String.t()) :: Macro.t()
defmacro computed_description(text) do
  quote do
    var!(computed_field_meta) = 
      Exdantic.ComputedFieldMeta.with_description(var!(computed_field_meta), unquote(text))
  end
end

@doc """
Sets an example value for the computed field.

This macro should be used within a computed_field block to provide
an example value for documentation and testing.

## Parameters
  * `value` - Example value that the computed field might return

## Examples

    computed_field :age_category, :string, :categorize_age do
      computed_example("adult")
    end
"""
@spec computed_example(term()) :: Macro.t()
defmacro computed_example(value) do
  quote do
    var!(computed_field_meta) = 
      Exdantic.ComputedFieldMeta.with_example(var!(computed_field_meta), unquote(value))
  end
end

@doc """
Alternative syntax for computed fields with a do block for metadata.

This provides a more structured way to define computed fields with metadata,
similar to how regular fields work.

## Examples

    computed_field :user_summary, :string, :generate_user_summary do
      computed_description("A summary of the user's profile information")
      computed_example("John Doe (john@example.com) - Software Engineer")
    end
"""
@spec computed_field(atom(), term(), atom(), keyword()) :: Macro.t()
defmacro computed_field(name, type, function_name, do: block) 
    when is_atom(name) and is_atom(function_name) do
  quote do
    # Validate inputs
    unless is_atom(unquote(name)) and not is_nil(unquote(name)) do
      raise ArgumentError, "computed field name must be a non-nil atom, got: #{inspect(unquote(name))}"
    end
    
    unless is_atom(unquote(function_name)) and not is_nil(unquote(function_name)) do
      raise ArgumentError, "computed field function name must be a non-nil atom, got: #{inspect(unquote(function_name))}"
    end

    # Create base computed field metadata
    computed_field_meta = %Exdantic.ComputedFieldMeta{
      name: unquote(name),
      type: unquote(handle_type(type)),
      function_name: unquote(function_name),
      module: __MODULE__,
      readonly: true
    }
    
    # Create a variable accessible within the block for metadata updates
    var!(computed_field_meta) = computed_field_meta
    
    # Execute the block to apply metadata
    unquote(block)
    
    # Store the final computed field metadata
    @computed_fields {unquote(name), var!(computed_field_meta)}
  end
end
