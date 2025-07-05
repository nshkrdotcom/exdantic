# test/exdantic/validator_test.exs
defmodule Exdantic.ValidatorTest do
  use ExUnit.Case, async: true
  alias Exdantic.{Types, Validator}

  describe "basic type validation" do
    test "validates string" do
      type = Types.string()
      assert {:ok, "test"} = Validator.validate(type, "test")
      assert {:error, _} = Validator.validate(type, 123)
    end

    test "validates string with constraints" do
      type =
        Types.string()
        |> Types.with_constraints([
          {:min_length, 3},
          {:max_length, 10},
          {:format, ~r/^[a-z]+$/}
        ])

      assert {:ok, "test"} = Validator.validate(type, "test")
      # too short
      assert {:error, _} = Validator.validate(type, "ab")
      # too long
      assert {:error, _} = Validator.validate(type, "verylongstring")
      # wrong format
      assert {:error, _} = Validator.validate(type, "Test123")
    end

    test "validates string with choices constraint" do
      type =
        Types.string()
        |> Types.with_constraints([{:choices, ["draft", "published", "archived"]}])

      assert {:ok, "draft"} = Validator.validate(type, "draft")
      assert {:ok, "published"} = Validator.validate(type, "published")
      assert {:ok, "archived"} = Validator.validate(type, "archived")
      assert {:error, _} = Validator.validate(type, "invalid")
    end

    test "validates integer" do
      type = Types.integer()
      assert {:ok, 123} = Validator.validate(type, 123)
      assert {:error, _} = Validator.validate(type, "123")
    end

    test "validates integer with constraints" do
      type =
        Types.integer()
        |> Types.with_constraints([
          {:gt, 0},
          {:lt, 100}
        ])

      assert {:ok, 50} = Validator.validate(type, 50)
      assert {:error, _} = Validator.validate(type, 0)
      assert {:error, _} = Validator.validate(type, 100)
    end

    test "validates float" do
      type = Types.float()
      assert {:ok, 123.45} = Validator.validate(type, 123.45)
      assert {:error, _} = Validator.validate(type, "123.45")
    end

    test "validates boolean" do
      type = Types.boolean()
      assert {:ok, true} = Validator.validate(type, true)
      assert {:ok, false} = Validator.validate(type, false)
      assert {:error, _} = Validator.validate(type, "true")
    end
  end

  describe "array validation" do
    test "validates array of strings" do
      type = Types.array(Types.string())
      assert {:ok, ["a", "b"]} = Validator.validate(type, ["a", "b"])
      assert {:error, [error]} = Validator.validate(type, ["a", 1])
      assert error.path == [1]
      assert error.code == :type

      assert {:error, [error]} = Validator.validate(type, "not an array")
      assert error.code == :type
      assert error.path == []
    end

    test "validates nested arrays" do
      type = Types.array(Types.array(Types.integer()))

      # Valid case
      assert {:ok, [[1, 2], [3, 4]]} = Validator.validate(type, [[1, 2], [3, 4]])

      # Invalid inner element
      assert {:error, [error]} = Validator.validate(type, [[1, "2"], [3, 4]])
      assert error.path == [0, 1]
      assert error.code == :type

      # Invalid outer elements (non-arrays)
      assert {:error, errors} = Validator.validate(type, [1, 2, 3, 4])
      assert length(errors) == 4

      # Check first error
      first_error = Enum.at(errors, 0)
      assert first_error.path == [0]
      assert first_error.code == :type
      assert first_error.message =~ "expected array"

      # Check all errors are about expecting arrays
      for error <- errors do
        assert error.code == :type
        assert error.message =~ "expected array"
      end
    end

    test "validates array with constraints" do
      type =
        Types.array(Types.string())
        |> Types.with_constraints(min_items: 2, max_items: 4)

      assert {:ok, ["a", "b"]} = Validator.validate(type, ["a", "b"])
      assert {:ok, ["a", "b", "c"]} = Validator.validate(type, ["a", "b", "c"])

      # too few items
      assert {:error, [error]} = Validator.validate(type, ["a"])
      assert error.code == :min_items

      # too many items
      assert {:error, [error]} = Validator.validate(type, ["a", "b", "c", "d", "e"])
      assert error.code == :max_items
    end
  end

  describe "map validation" do
    test "validates map with string keys and integer values" do
      type = Types.map(Types.string(), Types.integer())

      assert {:ok, %{"a" => 1, "b" => 2}} = Validator.validate(type, %{"a" => 1, "b" => 2})
      assert {:error, _} = Validator.validate(type, %{"a" => "1"})
      assert {:error, _} = Validator.validate(type, %{1 => 1})
      assert {:error, _} = Validator.validate(type, "not a map")
    end

    test "validates nested maps" do
      type =
        Types.map(
          Types.string(),
          Types.map(Types.string(), Types.integer())
        )

      valid_data = %{
        "user" => %{"age" => 25, "id" => 1},
        "other" => %{"value" => 42}
      }

      assert {:ok, ^valid_data} = Validator.validate(type, valid_data)
      assert {:error, _} = Validator.validate(type, %{"user" => %{"age" => "25"}})
      assert {:error, _} = Validator.validate(type, %{"user" => "invalid"})
    end

    test "validates map with constraints" do
      type =
        Types.map(Types.string(), Types.integer())
        |> Types.with_constraints([{:size?, 2}])

      assert {:ok, %{"a" => 1, "b" => 2}} = Validator.validate(type, %{"a" => 1, "b" => 2})
      # too small
      assert {:error, _} = Validator.validate(type, %{"a" => 1})
      # too large
      assert {:error, _} = Validator.validate(type, %{"a" => 1, "b" => 2, "c" => 3})
    end
  end

  describe "union type validation" do
    test "validates simple union" do
      type = Types.union([Types.string(), Types.integer()])

      assert {:ok, "test"} = Validator.validate(type, "test")
      assert {:ok, 123} = Validator.validate(type, 123)
      assert {:error, _} = Validator.validate(type, %{})
    end

    test "validates union with constraints" do
      type =
        Types.union([
          Types.string() |> Types.with_constraints([{:min_length, 3}]),
          Types.integer() |> Types.with_constraints([{:gt, 0}])
        ])

      assert {:ok, "test"} = Validator.validate(type, "test")
      assert {:ok, 123} = Validator.validate(type, 123)
      # string too short
      assert {:error, _} = Validator.validate(type, "ab")
      # integer too small
      assert {:error, _} = Validator.validate(type, -1)
      # wrong type
      assert {:error, _} = Validator.validate(type, %{})
    end

    test "validates nested unions" do
      type =
        Types.union([
          Types.array(Types.string()),
          Types.map(Types.string(), Types.integer())
        ])

      assert {:ok, ["a", "b"]} = Validator.validate(type, ["a", "b"])
      assert {:ok, %{"a" => 1}} = Validator.validate(type, %{"a" => 1})
      # wrong array type
      assert {:error, _} = Validator.validate(type, [1, 2])
      # wrong map types
      assert {:error, _} = Validator.validate(type, %{1 => "a"})
    end
  end

  describe "complex nested validation" do
    test "validates deeply nested structure" do
      # Define a complex type: array of maps with string keys and union values
      type =
        Types.array(
          Types.map(
            Types.string(),
            Types.union([
              Types.string(),
              Types.array(Types.integer()),
              Types.map(Types.string(), Types.boolean())
            ])
          )
        )

      valid_data = [
        %{"name" => "test", "nums" => [1, 2, 3]},
        %{"name" => "test2", "value" => "string"},
        %{"name" => "test3", "flags" => %{"active" => true, "verified" => false}}
      ]

      invalid_data = [
        %{"name" => "test", "value" => %{"invalid" => "type"}}
      ]

      assert {:ok, ^valid_data} = Validator.validate(type, valid_data)
      assert {:error, _} = Validator.validate(type, invalid_data)
    end

    test "validates with multiple constraints at different levels" do
      type =
        Types.array(
          Types.map(
            Types.string() |> Types.with_constraints([{:min_length, 2}]),
            Types.integer() |> Types.with_constraints([{:gt, 0}])
          )
        )
        |> Types.with_constraints([{:min_items, 1}, {:max_items, 3}])

      valid_data = [%{"ab" => 1}, %{"cd" => 2}]

      assert {:ok, ^valid_data} = Validator.validate(type, valid_data)
      # too few items
      assert {:error, _} = Validator.validate(type, [])
      # key too short
      assert {:error, _} = Validator.validate(type, [%{"a" => 1}])
      # value too small
      assert {:error, _} = Validator.validate(type, [%{"ab" => 0}])
    end
  end
end
