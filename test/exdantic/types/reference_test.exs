defmodule Exdantic.Types.ReferenceTest do
  use ExUnit.Case, async: true
  alias Exdantic.{Types, Validator}

  defmodule AddressSchema do
    use Exdantic

    schema "Address information" do
      field :street, :string do
      end

      field :city, :string do
      end
    end
  end

  test "validates using type reference" do
    valid_data = %{
      street: "123 Main St",
      city: "Springfield"
    }

    invalid_data = %{
      street: 123,
      city: "Springfield"
    }

    assert {:ok, _} = AddressSchema.validate(valid_data)
    assert {:error, _} = AddressSchema.validate(invalid_data)
  end

  test "validates using schema in array" do
    type = Types.array(AddressSchema)

    valid_data = [
      %{street: "123 Main St", city: "Springfield"},
      %{street: "456 Elm St", city: "Shelbyville"}
    ]

    assert {:ok, _} = Validator.validate(type, valid_data)
    assert {:error, _} = Validator.validate(type, [%{street: 123, city: "Springfield"}])
  end
end
