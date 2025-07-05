defmodule Exdantic.OptionalFieldsTest do
  use ExUnit.Case
  alias Exdantic.ModelValidatorTestSchemas.OptionalFieldValidator

  describe "model validators with optional fields" do
    test "validates successfully with name display preference" do
      data = %{name: "John Doe", display_preference: "name"}

      assert {:ok, result} = OptionalFieldValidator.validate(data)
      assert result.name == "John Doe"
      assert result.display_preference == "name"
      assert is_nil(result.nickname)
    end

    test "validates successfully with nickname display preference and nickname provided" do
      data = %{name: "John Doe", nickname: "Johnny", display_preference: "nickname"}

      assert {:ok, result} = OptionalFieldValidator.validate(data)
      assert result.name == "John Doe"
      assert result.nickname == "Johnny"
      assert result.display_preference == "nickname"
    end

    test "fails when nickname display preference but no nickname" do
      data = %{name: "John Doe", display_preference: "nickname"}

      assert {:error, errors} = OptionalFieldValidator.validate(data)
      assert length(errors) == 1
      assert hd(errors).message == "nickname required when display_preference is 'nickname'"
    end

    test "fails when nickname display preference but empty nickname" do
      data = %{name: "John Doe", nickname: "", display_preference: "nickname"}

      assert {:error, errors} = OptionalFieldValidator.validate(data)
      assert length(errors) == 1
      assert hd(errors).message == "nickname required when display_preference is 'nickname'"
    end

    test "uses default display preference" do
      # display_preference will use default "name"
      data = %{name: "John Doe"}

      assert {:ok, result} = OptionalFieldValidator.validate(data)
      assert result.display_preference == "name"
    end

    test "fails with invalid display preference" do
      data = %{name: "John Doe", display_preference: "invalid"}

      assert {:error, errors} = OptionalFieldValidator.validate(data)
      assert hd(errors).message == "display_preference must be 'name' or 'nickname'"
    end
  end
end
