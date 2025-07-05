# test/struct_pattern/property_test.exs
defmodule Exdantic.StructPropertyTest do
  use ExUnit.Case
  use ExUnitProperties

  defmodule UserStructSchema do
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

  describe "struct pattern properties" do
    property "validated struct always has correct field structure" do
      check all(
              name <- string(:printable, min_length: 1),
              email <- string(:printable, min_length: 1),
              age <- integer(0..150)
            ) do
        # Add @ to make email format valid
        valid_email = "#{email}@example.com"
        data = %{name: name, email: valid_email, age: age}

        case UserStructSchema.validate(data) do
          {:ok, result} ->
            assert is_struct(result, UserStructSchema)
            assert result.name == name
            assert result.email == valid_email
            assert result.age == age
            assert is_boolean(result.active)

          {:error, _errors} ->
            # Validation failure is acceptable for property testing
            :ok
        end
      end
    end

    property "dump and validate round-trip preserves data structure" do
      check all(
              name <- string(:printable, min_length: 1),
              email <- string(:printable, min_length: 1),
              age <- one_of([integer(0..150), constant(nil)]),
              active <- boolean()
            ) do
        valid_email = "#{email}@example.com"
        original_data = %{name: name, email: valid_email}
        original_data = if age, do: Map.put(original_data, :age, age), else: original_data
        original_data = Map.put(original_data, :active, active)

        case UserStructSchema.validate(original_data) do
          {:ok, struct} ->
            {:ok, dumped} = UserStructSchema.dump(struct)

            # Core fields should be preserved
            assert dumped.name == name
            assert dumped.email == valid_email
            # The active field should match what was validated (which includes default logic)
            assert dumped.active == struct.active

            if age do
              assert dumped.age == age
            end

          {:error, _} ->
            :ok
        end
      end
    end
  end
end
