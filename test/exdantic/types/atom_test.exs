defmodule Exdantic.Types.AtomTest do
  use ExUnit.Case, async: true
  alias Exdantic.Types

  describe ":atom type validation" do
    test "validates atom values" do
      assert Types.validate(:atom, :foo) == {:ok, :foo}
      assert Types.validate(:atom, :bar) == {:ok, :bar}
      assert match?({:error, _}, Types.validate(:atom, "foo"))
      assert match?({:error, _}, Types.validate(:atom, 123))
    end

    test "choices constraint for atom type" do
      type = {:type, :atom, [choices: [:foo, :bar]]}
      assert Types.validate(type, :foo) == {:ok, :foo}
      assert Types.validate(type, :bar) == {:ok, :bar}
      assert match?({:error, _}, Types.validate(type, :baz))
    end
  end
end
