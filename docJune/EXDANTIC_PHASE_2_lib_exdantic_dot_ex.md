# lib/exdantic.ex - Changes for Phase 2 (Model Validators)

# CHANGE 1: Add model_validators to __using__ macro
# In the existing __using__ macro, add this line after the other Module.register_attribute calls:

defmacro __using__(opts) do
  define_struct? = Keyword.get(opts, :define_struct, false)

  quote do
    import Exdantic.Schema

    # Register accumulating attributes
    Module.register_attribute(__MODULE__, :schema_description, [])
    Module.register_attribute(__MODULE__, :fields, accumulate: true)
    Module.register_attribute(__MODULE__, :validations, accumulate: true)
    Module.register_attribute(__MODULE__, :config, [])
    Module.register_attribute(__MODULE__, :model_validators, accumulate: true)  # NEW LINE
    
    # Store struct option for use in __before_compile__
    @exdantic_define_struct unquote(define_struct?)

    @before_compile Exdantic
  end
end

# CHANGE 2: Add model_validators to __schema__ functions
# In the existing __before_compile__ macro, add this line to the __schema__ function definitions:

defmacro __before_compile__(env) do
  define_struct? = Module.get_attribute(env.module, :exdantic_define_struct)
  fields = Module.get_attribute(env.module, :fields) || []
  
  # Extract field names for struct definition
  field_names = Enum.map(fields, fn {name, _meta} -> name end)
  
  # ... existing struct_def logic unchanged ...
  
  quote do
    # Inject struct definition if requested
    unquote(struct_def)

    # Define __schema__ functions
    def __schema__(:description), do: @schema_description
    def __schema__(:fields), do: @fields
    def __schema__(:validations), do: @validations
    def __schema__(:config), do: @config
    def __schema__(:model_validators), do: @model_validators || []  # NEW LINE
    
    # ... rest of the functions unchanged ...
  end
end
