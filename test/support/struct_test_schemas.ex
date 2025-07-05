defmodule Exdantic.StructTestSchemas do
  @moduledoc """
  Test schemas for struct pattern testing.
  """

  # Schema with struct enabled
  defmodule UserStructSchema do
    @moduledoc "Schema with struct generation enabled."
    use Exdantic, define_struct: true

    schema "User with struct" do
      field :name, :string do
        required()
        min_length(1)
      end

      field :age, :integer do
        optional()
        gteq(0)
      end

      field :email, :string do
        required()
        format(~r/@/)
      end

      field :active, :boolean do
        default(true)
      end
    end
  end

  # Schema without struct (existing behavior)
  defmodule UserMapSchema do
    @moduledoc "Schema with struct generation disabled."
    use Exdantic, define_struct: false

    schema "User without struct" do
      field :name, :string do
        required()
        min_length(1)
      end

      field :age, :integer do
        optional()
        gteq(0)
      end
    end
  end

  # Schema with default behavior (no struct)
  defmodule DefaultSchema do
    @moduledoc "Schema with default behavior (no struct generation)."
    # No explicit define_struct option
    use Exdantic

    schema do
      field :title, :string do
        required()
      end

      field :count, :integer do
        required()
      end
    end
  end

  # Complex schema with nested types
  defmodule ComplexStructSchema do
    @moduledoc "Complex schema with nested types and struct generation."
    use Exdantic, define_struct: true

    schema do
      field :tags, {:array, :string} do
        required()
        min_items(1)
      end

      field :metadata, {:map, {:string, :any}} do
        optional()
      end

      field :score, :float do
        optional()
        gteq(0.0)
        lteq(1.0)
      end
    end
  end
end
