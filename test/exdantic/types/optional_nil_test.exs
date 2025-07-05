defmodule Exdantic.Types.OptionalNilTest do
  use ExUnit.Case, async: true
  alias Exdantic.Types

  describe "optional field nil handling" do
    test "optional field present with nil is invalid" do
      # nil should not be accepted, even if optional
      assert match?({:error, _}, Types.validate(:integer, nil))
    end

    test "optional atom field present with nil is invalid" do
      assert match?({:error, _}, Types.validate(:atom, nil))
    end
  end
end
