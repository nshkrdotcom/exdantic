# This code updates exdantic.ex to support computed fields

# Add to the __using__/1 macro:
@spec __using__(keyword()) :: Macro.t()
defmacro __using__(opts) do
  define_struct? = Keyword.get(opts, :define_struct, false)

  quote do
    import Exdantic.Schema

    # Register accumulating attributes (updated to include computed_fields)
    Module.register_attribute(__MODULE__, :schema_description, [])
    Module.register_attribute(__MODULE__, :fields, accumulate: true)
    Module.register_attribute(__MODULE__, :validations, accumulate: true)
    Module.register_attribute(__MODULE__, :config, [])
    Module.register_attribute(__MODULE__, :model_validators, accumulate: true)
    Module.register_attribute(__MODULE__, :computed_fields, accumulate: true)  # NEW

    # Store struct option for use in __before_compile__
    @exdantic_define_struct unquote(define_struct?)

    @before_compile Exdantic
  end
end

# Update the __before_compile__/1 macro:
@spec __before_compile__(Macro.Env.t()) :: Macro.t()
defmacro __before_compile__(env) do
  define_struct? = Module.get_attribute(env.module, :exdantic_define_struct)
  fields = Module.get_attribute(env.module, :fields) || []
  computed_fields = Module.get_attribute(env.module, :computed_fields) || []  # NEW

  # Extract field names for struct definition (updated to include computed fields)
  field_names = Enum.map(fields, fn {name, _meta} -> name end)
  computed_field_names = Enum.map(computed_fields, fn {name, _meta} -> name end)
  all_field_names = field_names ++ computed_field_names  # Include computed fields in struct

  # Generate struct definition if requested (updated)
  struct_def =
    if define_struct? do
      quote do
        defstruct unquote(all_field_names)

        @type t :: %__MODULE__{}

        @doc """
        Returns the struct definition fields for this schema.
        Includes both regular fields and computed fields.
        """
        @spec __struct_fields__ :: [atom()]
        def __struct_fields__, do: unquote(all_field_names)

        @doc """
        Returns the regular (non-computed) struct fields for this schema.
        """
        @spec __regular_fields__ :: [atom()]
        def __regular_fields__, do: unquote(field_names)

        @doc """
        Returns the computed field names for this schema.
        """
        @spec __computed_field_names__ :: [atom()]
        def __computed_field_names__, do: unquote(computed_field_names)

        @doc """
        Returns whether this schema defines a struct.
        """
        @spec __struct_enabled__? :: true
        def __struct_enabled__?, do: true

        @doc """
        Serializes a struct instance back to a map.

        When serializing structs with computed fields, the computed fields
        are included in the resulting map since they are part of the struct.

        ## Parameters
          * `struct_or_map` - The struct instance or map to serialize

        ## Returns
          * `{:ok, map}` on success (includes computed fields)
          * `{:error, reason}` on failure

        ## Examples

            iex> user = %UserSchema{
            ...>   name: "John", 
            ...>   email: "john@example.com",
            ...>   full_display: "John <john@example.com>"  # computed field
            ...> }
            iex> UserSchema.dump(user)
            {:ok, %{
              name: "John", 
              email: "john@example.com",
              full_display: "John <john@example.com>"
            }}

            iex> UserSchema.dump(%{name: "John"})
            {:ok, %{name: "John"}}

            iex> UserSchema.dump("invalid")
            {:error, "Expected UserSchema struct or map, got: \"invalid\""}
        """
        @spec dump(struct() | map()) :: {:ok, map()} | {:error, String.t()}
        def dump(value), do: do_dump(__MODULE__, value)

        defp do_dump(module, %mod{} = struct) when mod == module,
          do: {:ok, Map.from_struct(struct)}

        defp do_dump(_module, map) when is_map(map), do: {:ok, map}

        defp do_dump(module, other),
          do: {:error, "Expected #{module} struct or map, got: #{inspect(other)}"}
      end
    else
      quote do
        @doc """
        Returns whether this schema defines a struct.
        """
        @spec __struct_enabled__? :: false
        def __struct_enabled__?, do: false

        @doc """
        Returns empty list since no struct is defined.
        """
        @spec __struct_fields__ :: []
        def __struct_fields__, do: []

        @doc """
        Returns the regular field names for this schema.
        """
        @spec __regular_fields__ :: [atom()]
        def __regular_fields__, do: unquote(field_names)

        @doc """
        Returns the computed field names for this schema.
        """
        @spec __computed_field_names__ :: [atom()]
        def __computed_field_names__, do: unquote(computed_field_names)
      end
    end

  quote do
    # Inject struct definition if requested
    unquote(struct_def)

    # Define __schema__ functions (updated to include computed_fields)
    def __schema__(:description), do: @schema_description
    def __schema__(:fields), do: @fields
    def __schema__(:validations), do: @validations
    def __schema__(:config), do: @config
    def __schema__(:model_validators), do: @model_validators || []
    def __schema__(:computed_fields), do: @computed_fields || []  # NEW

    @doc """
    Validates data against this schema with full pipeline support.

    The validation pipeline now includes computed fields:
    1. Field validation
    2. Model validation (if any model validators are defined)
    3. Computed field execution (if any computed fields are defined)
    4. Struct creation (if define_struct: true)

    ## Parameters
      * `data` - The data to validate (map)

    ## Returns
      * `{:ok, validated_data}` on success - includes computed fields and returns struct if `define_struct: true`, map otherwise
      * `{:error, errors}` on validation failure

    ## Examples

        # Schema with computed fields
        defmodule UserSchema do
          use Exdantic, define_struct: true
          
          schema do
            field :first_name, :string, required: true
            field :last_name, :string, required: true
            field :email, :string, required: true
            
            computed_field :full_name, :string, :generate_full_name
            computed_field :email_domain, :string, :extract_email_domain
          end
          
          def generate_full_name(data) do
            {:ok, "#{data.first_name} #{data.last_name}"}
          end
          
          def extract_email_domain(data) do
            {:ok, data.email |> String.split("@") |> List.last()}
          end
        end

        # With define_struct: true
        iex> UserSchema.validate(%{
        ...>   first_name: "John",
        ...>   last_name: "Doe", 
        ...>   email: "john@example.com"
        ...> })
        {:ok, %UserSchema{
          first_name: "John",
          last_name: "Doe",
          email: "john@example.com",
          full_name: "John Doe",         # computed field
          email_domain: "example.com"    # computed field
        }}

        # With define_struct: false (default)
        iex> UserMapSchema.validate(data)
        {:ok, %{
          first_name: "John",
          last_name: "Doe", 
          email: "john@example.com",
          full_name: "John Doe",
          email_domain: "example.com"
        }}
    """
    @spec validate(map()) :: {:ok, map() | struct()} | {:error, [Exdantic.Error.t()]}
    def validate(data) do
      Exdantic.StructValidator.validate_schema(__MODULE__, data)
    end

    @doc """
    Validates data against this schema, raising an exception on failure.

    ## Parameters
      * `data` - The data to validate (map)

    ## Returns
      * Validated data on success (struct or map depending on schema configuration, includes computed fields)
      * Raises `Exdantic.ValidationError` on failure

    ## Examples

        iex> UserSchema.validate!(%{first_name: "John", last_name: "Doe", email: "john@example.com"})
        %UserSchema{
          first_name: "John", 
          last_name: "Doe", 
          email: "john@example.com",
          full_name: "John Doe",         # computed field included
          email_domain: "example.com"    # computed field included
        }

        iex> UserSchema.validate!(%{})
        ** (Exdantic.ValidationError) first_name: field is required
    """
    @spec validate!(map()) :: map() | struct()
    def validate!(data) do
      case validate(data) do
        {:ok, validated} -> validated
        {:error, errors} -> raise Exdantic.ValidationError, errors: errors
      end
    end

    @doc """
    Returns information about the schema including computed fields.

    ## Returns
      * Map with schema metadata including computed field information

    ## Examples

        iex> UserSchema.__schema_info__()
        %{
          has_struct: true,
          field_count: 3,
          computed_field_count: 2,
          model_validator_count: 0,
          regular_fields: [:first_name, :last_name, :email],
          computed_fields: [:full_name, :email_domain],
          all_fields: [:first_name, :last_name, :email, :full_name, :email_domain]
        }
    """
    @spec __schema_info__() :: map()
    def __schema_info__() do
      regular_fields = __schema__(:fields) |> Enum.map(fn {name, _} -> name end)
      computed_fields = __schema__(:computed_fields) |> Enum.map(fn {name, _} -> name end)
      model_validators = __schema__(:model_validators)

      %{
        has_struct: __struct_enabled__?(),
        field_count: length(regular_fields),
        computed_field_count: length(computed_fields),
        model_validator_count: length(model_validators),
        regular_fields: regular_fields,
        computed_fields: computed_fields,
        all_fields: regular_fields ++ computed_fields,
        model_validators: Enum.map(model_validators, fn {mod, fun} -> "#{mod}.#{fun}/1" end)
      }
    end
  end
end
