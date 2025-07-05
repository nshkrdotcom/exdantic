defmodule Exdantic.ModelValidatorBackwardsCompatibilityTest do
  use ExUnit.Case

  # Define test schemas at module level to avoid compilation issues
  defmodule LegacySchemaTest do
    use Exdantic, define_struct: true

    schema do
      field(:name, :string, required: true)
      field(:age, :integer, optional: true)
    end
  end

  defmodule LegacyValidationTest do
    use Exdantic

    schema do
      field :email, :string do
        required()
        format(~r/@/)
      end
    end
  end

  defmodule IntrospectionTest do
    use Exdantic

    schema "Test schema" do
      field(:test_field, :string, required: true)
    end
  end

  defmodule StructCompatTest do
    use Exdantic, define_struct: true

    schema do
      field(:value, :string, required: true)
    end
  end

  describe "backwards compatibility" do
    test "existing schemas without model validators work unchanged" do
      data = %{name: "Test User", age: 30}

      assert {:ok, result} = LegacySchemaTest.validate(data)
      assert %LegacySchemaTest{} = result
      assert result.name == "Test User"
      assert result.age == 30
    end

    test "existing validation behavior unchanged" do
      # Valid case
      assert {:ok, result} = LegacyValidationTest.validate(%{email: "test@example.com"})
      assert result.email == "test@example.com"

      # Invalid case
      assert {:error, errors} = LegacyValidationTest.validate(%{email: "invalid"})

      # Handle case where errors might be a single error or list
      error_list = if is_list(errors), do: errors, else: [errors]
      assert length(error_list) == 1
      assert hd(error_list).code == :format
    end

    test "existing __schema__ introspection unchanged for schemas without model validators" do
      assert IntrospectionTest.__schema__(:description) == "Test schema"
      assert is_list(IntrospectionTest.__schema__(:fields))
      assert IntrospectionTest.__schema__(:model_validators) == []
    end

    test "Phase 1 struct functionality unchanged" do
      data = %{value: "test"}

      # Validation returns struct
      assert {:ok, result} = StructCompatTest.validate(data)
      assert %StructCompatTest{} = result

      # Dump works
      assert {:ok, dumped} = StructCompatTest.dump(result)
      assert dumped == %{value: "test"}

      # Introspection works
      assert StructCompatTest.__struct_enabled__?()
      assert StructCompatTest.__struct_fields__() == [:value]
    end
  end
end
