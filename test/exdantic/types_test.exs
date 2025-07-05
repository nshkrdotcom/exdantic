defmodule Exdantic.TypesTest do
  use ExUnit.Case, async: true
  alias Exdantic.Types

  describe "basic types" do
    test "string type" do
      assert Types.string() == {:type, :string, []}
    end

    test "integer type" do
      assert Types.integer() == {:type, :integer, []}
    end

    test "float type" do
      assert Types.float() == {:type, :float, []}
    end

    test "boolean type" do
      assert Types.boolean() == {:type, :boolean, []}
    end
  end

  describe "complex types" do
    test "array type" do
      assert Types.array(Types.string()) == {:array, {:type, :string, []}, []}
    end

    test "array of array of strings" do
      assert Types.array(Types.array(Types.string())) ==
               {:array, {:array, {:type, :string, []}, []}, []}
    end

    test "map type" do
      assert Types.map(Types.string(), Types.integer()) ==
               {:map, {{:type, :string, []}, {:type, :integer, []}}, []}
    end

    test "union type" do
      assert Types.union([Types.string(), Types.integer()]) ==
               {:union, [{:type, :string, []}, {:type, :integer, []}], []}
    end

    test "union of string and array of maps" do
      assert Types.union([
               Types.string(),
               Types.array(Types.map(Types.string(), Types.integer()))
             ]) ==
               {:union,
                [
                  {:type, :string, []},
                  {:array, {:map, {{:type, :string, []}, {:type, :integer, []}}, []}, []}
                ], []}
    end
  end

  describe "type validation" do
    test "validates string type" do
      assert {:ok, "test"} = Types.validate(:string, "test")
      assert {:error, _} = Types.validate(:string, 123)
    end

    test "validates integer type" do
      assert {:ok, 123} = Types.validate(:integer, 123)
      assert {:error, _} = Types.validate(:integer, "123")
    end

    test "validates float type" do
      assert {:ok, 123.45} = Types.validate(:float, 123.45)
      assert {:error, _} = Types.validate(:float, "123.45")
    end

    test "validates boolean type" do
      assert {:ok, true} = Types.validate(:boolean, true)
      assert {:ok, false} = Types.validate(:boolean, false)
      assert {:error, _} = Types.validate(:boolean, "true")
    end
  end

  describe "type constraints" do
    test "adds constraints to basic types" do
      constrained_string = Types.with_constraints(Types.string(), min_length: 3)
      assert constrained_string == {:type, :string, [min_length: 3]}
    end

    test "adds constraints to complex types" do
      constrained_array = Types.with_constraints(Types.array(Types.string()), min_items: 1)
      assert constrained_array == {:array, {:type, :string, []}, [min_items: 1]}
    end
  end
end
