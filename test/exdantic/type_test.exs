defmodule Exdantic.TypeTest do
  use ExUnit.Case, async: true

  defmodule TestEmail do
    use Exdantic.Type

    def type_definition do
      Exdantic.Types.string()
      |> Exdantic.Types.with_constraints([
        # Wrap regex in a list
        {:format, ~r/^[^\s]+@[^\s]+$/}
      ])
    end

    def json_schema do
      %{
        "type" => "string",
        "format" => "email",
        "pattern" => "^[^\\s]+@[^\\s]+$"
      }
    end

    # Update format/2 to match the new argument structure
    def format(value, regex) do
      Regex.match?(regex, value)
    end
  end

  describe "custom type definition" do
    test "defines type correctly" do
      # Update assertion
      assert TestEmail.type_definition() ==
               {:type, :string, [format: ~r/^[^\s]+@[^\s]+$/]}
    end

    test "generates correct JSON schema" do
      assert TestEmail.json_schema() == %{
               "type" => "string",
               "format" => "email",
               "pattern" => "^[^\\s]+@[^\\s]+$"
             }
    end
  end

  describe "type validation" do
    test "validates correct email" do
      assert {:ok, "test@example.com"} = TestEmail.validate("test@example.com")
    end

    test "rejects invalid email format" do
      assert {:error, _} = TestEmail.validate("not-an-email")
    end

    test "rejects wrong type" do
      assert {:error, _} = TestEmail.validate(123)
    end
  end
end
