defmodule Exdantic.Types.TupleUnionTest do
  use ExUnit.Case, async: true
  alias Exdantic.Types

  describe "tuple/union type validation" do
    test "validates string or {:system, String.t}" do
      # Simulate a union type: string | {:system, String.t}
      type = Types.union([Types.string(), Types.tuple([:system, :string])])
      assert Types.validate(type, "abc") == {:ok, "abc"}
      assert Types.validate(type, {:system, "ENV_VAR"}) == {:ok, {:system, "ENV_VAR"}}
      assert match?({:error, _}, Types.validate(type, 123))
      assert match?({:error, _}, Types.validate(type, {:system, 123}))
      assert match?({:error, _}, Types.validate(type, {:other, "ENV_VAR"}))
    end
  end
end
