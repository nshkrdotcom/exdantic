# lib/exdantic.ex - Modified for struct pattern support

defmodule Exdantic do
  @moduledoc """
  Exdantic is a schema definition and validation library for Elixir.

  It provides a DSL for defining schemas with rich metadata, validation rules,
  and JSON Schema generation capabilities.

  ## Struct Pattern Support

  Exdantic now supports generating structs alongside validation schemas:

      defmodule UserSchema do
        use Exdantic, define_struct: true

        schema "User account information" do
          field :name, :string do
            required()
            min_length(2)
          end

          field :age, :integer do
            optional()
            gt(0)
          end
        end
      end

  The schema can then be used for validation and returns struct instances:

      # Returns {:ok, %UserSchema{name: "John", age: 30}}
      UserSchema.validate(%{name: "John", age: 30})

      # Serialize struct back to map
      {:ok, map} = UserSchema.dump(user_struct)

  ## Examples

      defmodule UserSchema do
        use Exdantic

        schema "User registration data" do
          field :name, :string do
            required()
            min_length(2)
          end

          field :age, :integer do
            optional()
            gt(0)
            lt(150)
          end

          field :email, Types.Email do
            required()
          end

          config do
            title("User Schema")
            strict(true)
          end
        end
      end

  The schema can then be used for validation and JSON Schema generation:

      # Validation (returns map by default)
      {:ok, user} = UserSchema.validate(%{
        name: "John Doe",
        email: "john@example.com",
        age: 30
      })

      # JSON Schema generation
      json_schema = UserSchema.json_schema()
  """

  @doc """
  Configures a module to be an Exdantic schema.

  ## Options

    * `:define_struct` - Whether to generate a struct for validated data.
      When `true`, validation returns struct instances instead of maps.
      Defaults to `false` for backwards compatibility.

  ## Examples

      # Traditional map-based validation
      defmodule UserMapSchema do
        use Exdantic

        schema do
          field :name, :string
        end
      end

      # Struct-based validation  
      defmodule UserStructSchema do
        use Exdantic, define_struct: true

        schema do
          field :name, :string
        end
      end
  """
  @spec __using__(keyword()) :: Macro.t()
  defmacro __using__(opts) do
    define_struct? = Keyword.get(opts, :define_struct, false)

    quote do
      import Exdantic.Schema

      # Register accumulating attributes
      Module.register_attribute(__MODULE__, :schema_description, [])
      Module.register_attribute(__MODULE__, :fields, accumulate: true)
      Module.register_attribute(__MODULE__, :validations, accumulate: true)
      Module.register_attribute(__MODULE__, :config, [])
      
      # Store struct option for use in __before_compile__
      @exdantic_define_struct unquote(define_struct?)

      @before_compile Exdantic
    end
  end

  @spec __before_compile__(Macro.Env.t()) :: Macro.t()
  defmacro __before_compile__(env) do
    define_struct? = Module.get_attribute(env.module, :exdantic_define_struct)
    fields = Module.get_attribute(env.module, :fields) || []
    
    # Extract field names for struct definition
    field_names = Enum.map(fields, fn {name, _meta} -> name end)
    
    # Generate struct definition if requested
    struct_def = if define_struct? do
      quote do
        defstruct unquote(field_names)
        
        @type t :: %__MODULE__{}
        
        @doc """
        Returns the struct definition fields for this schema.
        """
        @spec __struct_fields__ :: [atom()]
        def __struct_fields__, do: unquote(field_names)
        
        @doc """
        Returns whether this schema defines a struct.
        """
        @spec __struct_enabled__? :: true
        def __struct_enabled__?, do: true

        @doc """
        Serializes a struct instance back to a map.

        ## Parameters
          * `struct_or_map` - The struct instance or map to serialize

        ## Returns
          * `{:ok, map}` on success
          * `{:error, reason}` on failure

        ## Examples

            iex> user = %UserSchema{name: "John", age: 30}
            iex> UserSchema.dump(user)
            {:ok, %{name: "John", age: 30}}

            iex> UserSchema.dump(%{name: "John"})
            {:ok, %{name: "John"}}

            iex> UserSchema.dump("invalid")
            {:error, "Expected UserSchema struct or map, got: \\"invalid\\""}
        """
        @spec dump(struct() | map()) :: {:ok, map()} | {:error, String.t()}
        def dump(%__MODULE__{} = struct) do
          {:ok, Map.from_struct(struct)}
        end
        
        def dump(map) when is_map(map) do
          {:ok, map}
        end
        
        def dump(other) do
          {:error, "Expected #{__MODULE__} struct or map, got: #{inspect(other)}"}
        end
      end
    else
      quote do
        @doc """
        Returns whether this schema defines a struct.
        """
        @spec __struct_enabled__? :: false
        def __struct_enabled__?, do: false
      end
    end
    
    quote do
      # Inject struct definition if requested
      unquote(struct_def)

      # Define __schema__ functions (unchanged from original)
      def __schema__(:description), do: @schema_description
      def __schema__(:fields), do: @fields
      def __schema__(:validations), do: @validations
      def __schema__(:config), do: @config
      
      @doc """
      Validates data against this schema.

      ## Parameters
        * `data` - The data to validate (map)

      ## Returns
        * `{:ok, validated_data}` on success - returns struct if `define_struct: true`, map otherwise
        * `{:error, errors}` on validation failure

      ## Examples

          # With define_struct: false (default)
          iex> UserMapSchema.validate(%{name: "John"})
          {:ok, %{name: "John"}}

          # With define_struct: true  
          iex> UserStructSchema.validate(%{name: "John"})
          {:ok, %UserStructSchema{name: "John"}}
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
        * Validated data on success (struct or map depending on schema configuration)
        * Raises `Exdantic.ValidationError` on failure

      ## Examples

          iex> UserSchema.validate!(%{name: "John"})
          %{name: "John"}

          iex> UserSchema.validate!(%{})
          ** (Exdantic.ValidationError) name: field is required
      """
      @spec validate!(map()) :: map() | struct()
      def validate!(data) do
        case validate(data) do
          {:ok, validated} -> validated
          {:error, errors} -> raise Exdantic.ValidationError, errors: errors
        end
      end
    end
  end
end
