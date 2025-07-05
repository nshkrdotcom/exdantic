defmodule Exdantic.Schema do
  @moduledoc """
  Schema DSL for defining data schemas with validation rules and metadata.

  This module provides macros and functions for defining structured data schemas
  with rich validation capabilities, type safety, and comprehensive error reporting.

  ## Phase 4 Enhancement: Anonymous Function Support

  Added support for inline anonymous functions in model validators and computed fields:

      schema do
        field :password, :string
        field :password_confirmation, :string

        # Named function (existing)
        model_validator :validate_passwords_match

        # Anonymous function (new)
        model_validator fn input ->
          if input.password == input.password_confirmation do
            {:ok, input}
          else
            {:error, "passwords do not match"}
          end
        end

        # Anonymous function with do-end block (new)
        model_validator do
          if input.password == input.password_confirmation do
            {:ok, input}
          else
            {:error, "passwords do not match"}
          end
        end

        computed_field :display_name, :string do
          String.upcase(input.name)
        end
      end
  """

  alias Exdantic.Types

  @type schema_config :: %{
          optional(:title) => String.t(),
          optional(:description) => String.t(),
          optional(:strict) => boolean()
        }

  @type model_validator_ast ::
          {:@, [{:context, Exdantic.Schema} | {:imports, [...]}],
           [{:model_validators, [...], [...]}]}
          | {:__block__, [], [{:def, [...], [...]} | {:@, [...], [...]}]}

  @type macro_ast :: term()

  @doc """
  Defines a new schema with optional description.

  ## Parameters
    * `description` - Optional string describing the schema's purpose
    * `do` - Block containing field definitions and configuration

  ## Examples

      schema "User registration data" do
        field :name, :string do
          required()
          min_length(2)
        end

        field :age, :integer do
          optional()
          gt(0)
        end
      end

      schema do
        field :email, :string
        field :active, :boolean, default: true
      end
  """
  @spec schema(String.t() | nil, keyword()) :: Macro.t()
  defmacro schema(description \\ nil, do: block) do
    quote do
      @schema_description unquote(description)

      unquote(block)
    end
  end

  @doc """
  Adds a minimum length constraint to a string field.

  ## Parameters
    * `value` - The minimum length required (must be a non-negative integer)

  ## Examples

      field :username, :string do
        min_length(3)
      end

      field :password, :string do
        min_length(8)
        max_length(100)
      end
  """
  @spec min_length(non_neg_integer()) :: Macro.t()
  defmacro min_length(value) do
    quote do
      current_constraints = Map.get(var!(field_meta), :constraints, [])

      var!(field_meta) =
        Map.put(var!(field_meta), :constraints, [
          {:min_length, unquote(value)} | current_constraints
        ])
    end
  end

  @doc """
  Adds a maximum length constraint to a string field.

  ## Parameters
    * `value` - The maximum length allowed (must be a non-negative integer)

  ## Examples

      field :username, :string do
        max_length(20)
      end

      field :description, :string do
        max_length(500)
      end
  """
  @spec max_length(non_neg_integer()) :: Macro.t()
  defmacro max_length(value) do
    quote do
      current_constraints = Map.get(var!(field_meta), :constraints, [])

      var!(field_meta) =
        Map.put(var!(field_meta), :constraints, [
          {:max_length, unquote(value)} | current_constraints
        ])
    end
  end

  @doc """
  Adds a minimum items constraint to an array field.

  ## Parameters
    * `value` - The minimum number of items required (must be a non-negative integer)

  ## Examples

      field :tags, {:array, :string} do
        min_items(1)
      end

      field :categories, {:array, :string} do
        min_items(2)
        max_items(5)
      end
  """
  @spec min_items(non_neg_integer()) :: Macro.t()
  defmacro min_items(value) do
    quote do
      current_constraints = Map.get(var!(field_meta), :constraints, [])

      var!(field_meta) =
        Map.put(var!(field_meta), :constraints, [
          {:min_items, unquote(value)} | current_constraints
        ])
    end
  end

  @doc """
  Adds a maximum items constraint to an array field.

  ## Parameters
    * `value` - The maximum number of items allowed (must be a non-negative integer)

  ## Examples

      field :tags, {:array, :string} do
        max_items(10)
      end

      field :favorites, {:array, :integer} do
        min_items(1)
        max_items(3)
      end
  """
  @spec max_items(non_neg_integer()) :: Macro.t()
  defmacro max_items(value) do
    quote do
      current_constraints = Map.get(var!(field_meta), :constraints, [])

      var!(field_meta) =
        Map.put(var!(field_meta), :constraints, [
          {:max_items, unquote(value)} | current_constraints
        ])
    end
  end

  @doc """
  Adds a greater than constraint to a numeric field.

  ## Parameters
    * `value` - The minimum value (exclusive)

  ## Examples

      field :age, :integer do
        gt(0)
      end

      field :score, :float do
        gt(0.0)
        lt(100.0)
      end
  """
  @spec gt(number()) :: Macro.t()
  defmacro gt(value) do
    quote do
      current_constraints = Map.get(var!(field_meta), :constraints, [])

      var!(field_meta) =
        Map.put(var!(field_meta), :constraints, [{:gt, unquote(value)} | current_constraints])
    end
  end

  @doc """
  Adds a less than constraint to a numeric field.

  ## Parameters
    * `value` - The maximum value (exclusive)

  ## Examples

      field :age, :integer do
        lt(100)
      end

      field :temperature, :float do
        gt(-50.0)
        lt(100.0)
      end
  """
  @spec lt(number()) :: Macro.t()
  defmacro lt(value) do
    quote do
      current_constraints = Map.get(var!(field_meta), :constraints, [])

      var!(field_meta) =
        Map.put(var!(field_meta), :constraints, [{:lt, unquote(value)} | current_constraints])
    end
  end

  @doc """
  Adds a greater than or equal to constraint to a numeric field.

  ## Parameters
    * `value` - The minimum value (inclusive)

  ## Examples

      field :age, :integer do
        gteq(18)
      end

      field :rating, :float do
        gteq(0.0)
        lteq(5.0)
      end
  """
  @spec gteq(number()) :: Macro.t()
  defmacro gteq(value) do
    quote do
      current_constraints = Map.get(var!(field_meta), :constraints, [])

      var!(field_meta) =
        Map.put(var!(field_meta), :constraints, [{:gteq, unquote(value)} | current_constraints])
    end
  end

  @doc """
  Adds a less than or equal to constraint to a numeric field.

  ## Parameters
    * `value` - The maximum value (inclusive)

  ## Examples

      field :rating, :float do
        lteq(5.0)
      end

      field :percentage, :integer do
        gteq(0)
        lteq(100)
      end
  """
  @spec lteq(number()) :: Macro.t()
  defmacro lteq(value) do
    quote do
      current_constraints = Map.get(var!(field_meta), :constraints, [])

      var!(field_meta) =
        Map.put(var!(field_meta), :constraints, [{:lteq, unquote(value)} | current_constraints])
    end
  end

  @doc """
  Adds a format constraint to a string field.

  ## Parameters
    * `value` - The format pattern (regular expression)

  ## Examples

      field :email, :string do
        format(~r/^[^\s@]+@[^\s@]+\.[^\s@]+$/)
      end

      field :phone, :string do
        format(~r/^\+?[1-9]\d{1,14}$/)
      end
  """
  @spec format(Regex.t()) :: Macro.t()
  defmacro format(value) do
    quote do
      current_constraints = Map.get(var!(field_meta), :constraints, [])

      var!(field_meta) =
        Map.put(var!(field_meta), :constraints, [{:format, unquote(value)} | current_constraints])
    end
  end

  @doc """
  Adds an enumeration constraint, limiting values to a predefined set.

  ## Parameters
    * `values` - List of allowed values

  ## Examples

      field :status, :string do
        choices(["pending", "active", "completed"])
      end

      field :priority, :integer do
        choices([1, 2, 3])
      end

      field :size, :string do
        choices(["small", "medium", "large"])
      end
  """
  @spec choices([term()]) :: Macro.t()
  defmacro choices(values) when is_list(values) do
    quote do
      current_constraints = Map.get(var!(field_meta), :constraints, [])

      var!(field_meta) =
        Map.put(var!(field_meta), :constraints, [
          {:choices, unquote(values)} | current_constraints
        ])
    end
  end

  @doc """
  Defines a field in the schema with a name, type, and optional constraints.

  ## Parameters
    * `name` - Atom representing the field name
    * `type` - The field's type, which can be:
      * A built-in type (`:string`, `:integer`, `:float`, `:boolean`, `:any`)
      * An array type (`{:array, type}`)
      * A map type (`{:map, {key_type, value_type}}`)
      * A union type (`{:union, [type1, type2, ...]}`)
      * A reference to another schema (atom)
    * `opts` - Optional block containing field constraints and metadata

  ## Examples

      # Simple field
      field :name, :string

      # Field with constraints
      field :age, :integer do
        description("User's age in years")
        gt(0)
        lt(150)
      end

      # Array field
      field :tags, {:array, :string} do
        min_items(1)
        max_items(10)
      end

      # Map field
      field :metadata, {:map, {:string, :any}}

      # Reference to another schema
      field :address, Address

      # Optional field with default
      field :active, :boolean do
        default(true)
      end
  """
  @spec field(atom(), term(), keyword()) :: Macro.t()
  defmacro field(name, type, opts \\ [do: {:__block__, [], []}])

  @spec field(atom(), term(), keyword()) :: Macro.t()
  defmacro field(name, type, opts) when is_list(opts) do
    # Handle the case where opts is a keyword list like [required: true, default: "value"]
    do_block = Keyword.get(opts, :do, {:__block__, [], []})
    opts_without_do = Keyword.delete(opts, :do)

    # Extract common options
    required = Keyword.get(opts_without_do, :required, true)
    optional = Keyword.get(opts_without_do, :optional, false)
    default_value = Keyword.get(opts_without_do, :default)
    extra_opts = Keyword.get(opts_without_do, :extra, %{})

    # Handle AST for map literals passed as options
    evaluated_extra_opts =
      case extra_opts do
        {:%{}, _, _} = ast ->
          # This is a map literal AST, evaluate it
          {map, _} = Code.eval_quoted(ast)
          map

        other ->
          other
      end

    # Determine if field is required (required: true takes precedence over optional: true)
    # Fields with default values should be optional unless explicitly marked as required
    is_required =
      if Keyword.has_key?(opts_without_do, :required) do
        required
      else
        # If a default value is provided, the field should be optional unless explicitly required
        if default_value != nil do
          false
        else
          not optional
        end
      end

    quote do
      field_meta = %Exdantic.FieldMeta{
        name: unquote(name),
        type: unquote(handle_type(type)),
        required: unquote(is_required),
        constraints: [],
        extra: unquote(Macro.escape(evaluated_extra_opts))
      }

      # Apply default if provided
      field_meta =
        if unquote(default_value) != nil do
          Map.put(field_meta, :default, unquote(default_value))
        else
          field_meta
        end

      # Create a variable accessible across all nested macros in this field block
      var!(field_meta) = field_meta

      unquote(do_block)

      # Apply constraints to the type
      final_type =
        case var!(field_meta).type do
          {:type, type_name, _} ->
            {:type, type_name, Enum.reverse(var!(field_meta).constraints)}

          {kind, inner, _} ->
            {kind, inner, Enum.reverse(var!(field_meta).constraints)}

          other ->
            other
        end

      final_meta = Map.put(var!(field_meta), :type, final_type)
      @fields {unquote(name), final_meta}
    end
  end

  defmacro field(name, type, do: block) do
    quote do
      field_meta = %Exdantic.FieldMeta{
        name: unquote(name),
        type: unquote(handle_type(type)),
        required: true,
        constraints: [],
        extra: %{}
      }

      # Create a variable accessible across all nested macros in this field block
      var!(field_meta) = field_meta

      unquote(block)

      # Apply constraints to the type
      final_type =
        case var!(field_meta).type do
          {:type, type_name, _} ->
            {:type, type_name, Enum.reverse(var!(field_meta).constraints)}

          {kind, inner, _} ->
            {kind, inner, Enum.reverse(var!(field_meta).constraints)}

          other ->
            other
        end

      final_meta = Map.put(var!(field_meta), :type, final_type)
      @fields {unquote(name), final_meta}
    end
  end

  # Field metadata setters

  @doc """
  Sets a description for the field.

  ## Parameters
    * `text` - String description of the field's purpose or usage

  ## Examples

      field :age, :integer do
        description("User's age in years")
      end

      field :email, :string do
        description("Primary contact email address")
        format(~r/@/)
      end
  """
  @spec description(String.t()) :: Macro.t()
  defmacro description(text) do
    quote do
      var!(field_meta) = Map.put(var!(field_meta), :description, unquote(text))
    end
  end

  @doc """
  Sets a single example value for the field.

  ## Parameters
    * `value` - An example value that would be valid for this field

  ## Examples

      field :age, :integer do
        example(25)
      end

      field :name, :string do
        example("John Doe")
      end
  """
  @spec example(term()) :: Macro.t()
  defmacro example(value) do
    quote do
      var!(field_meta) = Map.put(var!(field_meta), :example, unquote(value))
    end
  end

  @doc """
  Sets multiple example values for the field.

  ## Parameters
    * `values` - List of example values that would be valid for this field

  ## Examples

      field :status, :string do
        examples(["pending", "active", "completed"])
      end

      field :score, :integer do
        examples([85, 92, 78])
      end
  """
  @spec examples([term()]) :: Macro.t()
  defmacro examples(values) do
    quote do
      var!(field_meta) = Map.put(var!(field_meta), :examples, unquote(values))
    end
  end

  @doc """
  Marks the field as required (this is the default behavior).
  A required field must be present in the input data during validation.

  ## Examples

      field :email, :string do
        required()
        format(~r/@/)
      end

      field :name, :string do
        required()
        min_length(1)
      end
  """
  @spec required() :: Macro.t()
  defmacro required do
    quote do
      var!(field_meta) =
        var!(field_meta)
        |> Map.put(:required, true)
    end
  end

  @doc """
  Marks the field as optional.
  An optional field may be omitted from the input data during validation.

  ## Examples

      field :middle_name, :string do
        optional()
      end

      field :bio, :string do
        optional()
        max_length(500)
      end
  """
  @spec optional() :: Macro.t()
  defmacro optional do
    quote do
      var!(field_meta) =
        var!(field_meta)
        |> Map.put(:required, false)
    end
  end

  @doc """
  Sets a default value for the field and marks it as optional.
  The default value will be used if the field is omitted from input data.

  ## Parameters
    * `value` - The default value to use when the field is not provided

  ## Examples

      field :status, :string do
        default("pending")
      end

      field :active, :boolean do
        default(true)
      end

      field :retry_count, :integer do
        default(0)
        gteq(0)
      end
  """
  @spec default(term()) :: Macro.t()
  defmacro default(value) do
    quote do
      var!(field_meta) =
        var!(field_meta)
        |> Map.put(:default, unquote(value))
        |> Map.put(:required, false)
    end
  end

  @doc """
  Sets arbitrary extra metadata for the field.

  This allows storing custom key-value pairs in the field metadata,
  which is particularly useful for DSPy-style field type annotations
  and other framework-specific metadata.

  ## Parameters
    * `key` - String key for the metadata
    * `value` - The metadata value

  ## Examples

      field :answer, :string do
        extra("__dspy_field_type", "output")
        extra("prefix", "Answer:")
      end

      field :question, :string do
        extra("__dspy_field_type", "input")
      end

      # Can also be used with map
      field :data, :string, extra: %{"custom_key" => "custom_value"}
  """
  @spec extra(String.t(), term()) :: Macro.t()
  defmacro extra(key, value) do
    quote do
      current_extra = Map.get(var!(field_meta), :extra, %{})

      var!(field_meta) =
        Map.put(var!(field_meta), :extra, Map.put(current_extra, unquote(key), unquote(value)))
    end
  end

  @doc """
  Defines a computed field that generates a value based on validated data.

  Computed fields execute after field and model validation, generating additional
  data that becomes part of the final validated result. They are particularly
  useful for derived values, formatted representations, or aggregated data.

  ## Parameters
    * `name` - Field name (atom)
    * `type` - Field type specification (same as regular fields)
    * `function_name` - Name of the function to call for computation (atom) or anonymous function
    * `opts` - Optional keyword list with :description and :example (when using named function)

  ## Function Signature
  The computation function must accept one parameter (the validated data) and return:
    * `{:ok, computed_value}` - computation succeeds
    * `{:error, message}` - computation fails with error message
    * `{:error, %Exdantic.Error{}}` - computation fails with detailed error

  ## Execution Order
  Computed fields execute after:
  1. Field validation
  2. Model validation

  This ensures computed fields have access to fully validated and transformed data.

  ## Examples

      # Using named function
      defmodule UserSchema do
        use Exdantic, define_struct: true

        schema do
          field :first_name, :string, required: true
          field :last_name, :string, required: true
          field :email, :string, required: true

          computed_field :full_name, :string, :generate_full_name
          computed_field :email_domain, :string, :extract_email_domain,
            description: "Domain part of the email address",
            example: "example.com"
        end

        def generate_full_name(input) do
          {:ok, "\#{input.first_name} \#{input.last_name}"}
        end

        def extract_email_domain(input) do
          domain = input.email |> String.split("@") |> List.last()
          {:ok, domain}
        end
      end

      # Using anonymous function
      schema do
        field :first_name, :string
        field :last_name, :string

        computed_field :full_name, :string, fn input ->
          {:ok, "\#{input.first_name} \#{input.last_name}"}
        end

        computed_field :initials, :string, fn input ->
          first = String.first(input.first_name)
          last = String.first(input.last_name)
          {:ok, "\#{first}\#{last}"}
        end
      end

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

      defstruct [:first_name, :last_name, :email, :full_name, :email_domain]
  """

  @spec computed_field(atom(), term(), atom()) :: macro_ast
  defmacro computed_field(name, type, function_name)
           when is_atom(name) and is_atom(function_name) do
    quote do
      # Validate inputs
      unless is_atom(unquote(name)) and not is_nil(unquote(name)) do
        raise ArgumentError,
              "computed field name must be a non-nil atom, got: #{inspect(unquote(name))}"
      end

      unless is_atom(unquote(function_name)) and not is_nil(unquote(function_name)) do
        raise ArgumentError,
              "computed field function name must be a non-nil atom, got: #{inspect(unquote(function_name))}"
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

  @spec computed_field(atom(), term(), (map() ->
                                          {:ok, term()}
                                          | {:error, String.t() | Exdantic.Error.t()})) ::
          macro_ast
  defmacro computed_field(name, type, computation_fn) when is_atom(name) do
    # Generate unique function name
    function_name = generate_function_name("computed_field")

    quote do
      # Validate inputs
      unless is_atom(unquote(name)) and not is_nil(unquote(name)) do
        raise ArgumentError,
              "computed field name must be a non-nil atom, got: #{inspect(unquote(name))}"
      end

      # Define the function with generated name
      def unquote(function_name)(input) do
        computation_fn = unquote(computation_fn)
        computation_fn.(input)
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

  @spec computed_field(atom(), term(), atom(), [{:description, String.t()} | {:example, term()}]) ::
          macro_ast
  defmacro computed_field(name, type, function_name, opts)
           when is_atom(name) and is_atom(function_name) and is_list(opts) do
    description = Keyword.get(opts, :description)
    example = Keyword.get(opts, :example)

    quote do
      # Validate inputs
      unless is_atom(unquote(name)) and not is_nil(unquote(name)) do
        raise ArgumentError,
              "computed field name must be a non-nil atom, got: #{inspect(unquote(name))}"
      end

      unless is_atom(unquote(function_name)) and not is_nil(unquote(function_name)) do
        raise ArgumentError,
              "computed field function name must be a non-nil atom, got: #{inspect(unquote(function_name))}"
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

  @doc """
  Defines a model-level validator that runs after field validation.

  Model validators receive the validated data (as a map or struct) and can perform
  cross-field validation, data transformation, or complex business logic validation.

  ## Parameters
    * `function_name` - Name of the function to call for model validation (when using named function)
    * `validator_fn` - Anonymous function that accepts validated data and returns result (when using anonymous function)
    * `do` block - Block of code with implicit `input` variable (when using do-end block)

  ## Function Signature
  The validator must accept one parameter (the validated data) and return:
    * `{:ok, data}` - validation succeeds, optionally with transformed data
    * `{:error, message}` - validation fails with error message
    * `{:error, %Exdantic.Error{}}` - validation fails with detailed error

  ## Examples

      defmodule UserSchema do
        use Exdantic, define_struct: true

        schema do
          field :password, :string, required: true
          field :password_confirmation, :string, required: true

          # Using named function
          model_validator :validate_passwords_match

          # Using anonymous function
          model_validator fn input ->
            if input.password == input.password_confirmation do
              {:ok, input}
            else
              {:error, "passwords do not match"}
            end
          end

          # Using do-end block with implicit input
          model_validator do
            if input.password == input.password_confirmation do
              {:ok, input}
            else
              {:error, "passwords do not match"}
            end
          end
        end

        def validate_passwords_match(input) do
          if input.password == input.password_confirmation do
            {:ok, input}
          else
            {:error, "passwords do not match"}
          end
        end
      end

  ## Multiple Validators
  Multiple model validators can be defined and will execute in the order they are declared:

      schema do
        field :username, :string, required: true
        field :email, :string, required: true

        model_validator :validate_username_unique
        model_validator :validate_email_format
        model_validator :send_welcome_email
      end

  ## Data Transformation
  Model validators can transform the data by returning modified data:

      def normalize_email(input) do
        normalized = %{input | email: String.downcase(input.email)}
        {:ok, normalized}
      end
  """

  @spec model_validator((map() -> {:ok, map()} | {:error, String.t() | Exdantic.Error.t()})) ::
          macro_ast
  defmacro model_validator(validator_fn) when not is_atom(validator_fn) do
    # Generate unique function name
    function_name = generate_function_name("model_validator")

    quote do
      # Define the function with generated name
      def unquote(function_name)(input) do
        validator_fn = unquote(validator_fn)
        validator_fn.(input)
      end

      # Register the generated function
      @model_validators {__MODULE__, unquote(function_name)}
    end
  end

  @spec model_validator(atom()) :: macro_ast
  defmacro model_validator(function_name) when is_atom(function_name) do
    quote do
      @model_validators {__MODULE__, unquote(function_name)}
    end
  end

  @spec model_validator(keyword()) :: macro_ast
  defmacro model_validator(do: block) do
    # Generate unique function name
    function_name = generate_function_name("model_validator")

    # Transform the block to inject the input parameter
    transformed_block = inject_input_parameter(block)

    quote do
      # Define the function with generated name
      def unquote(function_name)(input) do
        unquote(transformed_block)
      end

      # Register the generated function
      @model_validators {__MODULE__, unquote(function_name)}
    end
  end

  # Configuration block

  @doc """
  Defines configuration settings for the schema.

  Configuration options can include:
    * title - Schema title
    * description - Schema description
    * strict - Whether to enforce strict validation

  ## Examples

      config do
        title("User Schema")
        config_description("Validates user registration data")
        strict(true)
      end

      config do
        strict(false)
      end
  """
  @spec config(keyword()) :: Macro.t()
  defmacro config(do: block) do
    quote do
      config = %{
        title: nil,
        description: nil,
        strict: false
      }

      var!(config) = config
      unquote(block)

      @config var!(config)
    end
  end

  # Config setters
  @doc """
  Sets the title for the schema configuration.

  ## Parameters
    * `text` - String title for the schema

  ## Examples

      config do
        title("User Schema")
      end

      config do
        title("Product Validation Schema")
        strict(true)
      end
  """
  @spec title(String.t()) :: Macro.t()
  defmacro title(text) do
    quote do
      var!(config) = Map.put(var!(config), :title, unquote(text))
    end
  end

  @doc """
  Sets the description for the schema configuration.

  ## Parameters
    * `text` - String description of the schema

  ## Examples

      config do
        config_description("Validates user data for registration")
      end

      config do
        title("User Schema")
        config_description("Comprehensive user validation with email format checking")
      end
  """
  @spec config_description(String.t()) :: Macro.t()
  defmacro config_description(text) do
    quote do
      var!(config) = Map.put(var!(config), :description, unquote(text))
    end
  end

  @doc """
  Sets whether the schema should enforce strict validation.
  When strict is true, unknown fields will cause validation to fail.

  ## Parameters
    * `bool` - Boolean indicating if strict validation should be enabled

  ## Examples

      config do
        strict(true)
      end

      config do
        title("Flexible Schema")
        strict(false)
      end
  """
  @spec strict(boolean()) :: Macro.t()
  defmacro strict(bool) do
    quote do
      var!(config) = Map.put(var!(config), :strict, unquote(bool))
    end
  end

  # Private helper function for generating unique function names
  @spec generate_function_name(String.t(), String.t() | nil) :: atom()
  defp generate_function_name(prefix, suffix \\ nil) do
    base_name = if suffix, do: "#{prefix}_#{suffix}", else: prefix
    unique_id = System.unique_integer([:positive])
    timestamp = System.system_time(:nanosecond)

    # Create a reasonably unique but readable function name
    :"__generated_#{base_name}_#{unique_id}_#{timestamp}"
  end

  # Private helper function to inject input parameter into block
  @spec inject_input_parameter(Macro.t()) :: Macro.t()
  defp inject_input_parameter(block) do
    # Use Macro.prewalk to traverse the AST and replace input references
    Macro.prewalk(block, fn
      # Replace bare :input atom references with a variable
      {:input, meta, nil} ->
        {:input, meta, Elixir}

      {:input, meta, context} when context != nil ->
        {:input, meta, Elixir}

      # Leave everything else unchanged
      node ->
        node
    end)
  end

  # Handle type definitions
  @spec handle_type(term()) :: Macro.t()
  defp handle_type({:array, type}) do
    quote do
      Types.array(unquote(handle_type(type)))
    end
  end

  # Handle map types
  defp handle_type({:map, {key_type, value_type}}) do
    normalized_key = handle_type(key_type)
    normalized_value = handle_type(value_type)

    quote do
      Types.map(unquote(normalized_key), unquote(normalized_value))
    end
  end

  defp handle_type({:union, types}) do
    quote do
      Types.union(unquote(types |> Enum.map(&handle_type/1)))
    end
  end

  defp handle_type({:__aliases__, _, _} = module_alias) do
    quote do
      unquote(module_alias)
    end
  end

  # Handle built-in types and references
  defp handle_type(type) when is_atom(type) do
    if type in [:string, :integer, :float, :boolean, :any, :atom, :map] do
      quote do
        Types.type(unquote(type))
      end
    else
      # Assume it's a reference
      {:ref, type}
    end
  end
end
