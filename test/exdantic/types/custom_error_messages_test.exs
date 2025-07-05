defmodule Exdantic.Types.CustomErrorMessagesTest do
  use ExUnit.Case, async: true
  alias Exdantic.Types
  alias Exdantic.Validator

  describe "with_error_message/3" do
    test "adds custom error message for constraint" do
      type =
        Types.string()
        |> Types.with_constraints(min_length: 3)
        |> Types.with_error_message(:min_length, "Name must be at least 3 characters long")

      assert type ==
               {:type, :string,
                [
                  {:min_length, 3},
                  {:error_message, :min_length, "Name must be at least 3 characters long"}
                ]}
    end

    test "works with integer type" do
      type =
        Types.integer()
        |> Types.with_constraints(gt: 10)
        |> Types.with_error_message(:gt, "Age must be greater than 10")

      assert type ==
               {:type, :integer,
                [{:gt, 10}, {:error_message, :gt, "Age must be greater than 10"}]}
    end

    test "works with multiple constraints and error messages" do
      type =
        Types.string()
        |> Types.with_constraints(min_length: 3, max_length: 50)
        |> Types.with_error_message(:min_length, "Too short")
        |> Types.with_error_message(:max_length, "Too long")

      assert type ==
               {:type, :string,
                [
                  {:min_length, 3},
                  {:max_length, 50},
                  {:error_message, :min_length, "Too short"},
                  {:error_message, :max_length, "Too long"}
                ]}
    end

    test "works with complex types" do
      type =
        Types.array(Types.string())
        |> Types.with_constraints(min_items: 1)
        |> Types.with_error_message(:min_items, "At least one item is required")

      assert type ==
               {:array, {:type, :string, []},
                [{:min_items, 1}, {:error_message, :min_items, "At least one item is required"}]}
    end
  end

  describe "with_error_messages/2" do
    test "adds multiple custom error messages from keyword list" do
      type =
        Types.string()
        |> Types.with_constraints(min_length: 3, max_length: 50)
        |> Types.with_error_messages(
          min_length: "Name must be at least 3 characters long",
          max_length: "Name cannot exceed 50 characters"
        )

      assert type ==
               {:type, :string,
                [
                  {:min_length, 3},
                  {:max_length, 50},
                  {:error_message, :min_length, "Name must be at least 3 characters long"},
                  {:error_message, :max_length, "Name cannot exceed 50 characters"}
                ]}
    end

    test "adds multiple custom error messages from map" do
      type =
        Types.integer()
        |> Types.with_constraints(gt: 0, lt: 100)
        |> Types.with_error_messages(%{
          gt: "Must be positive",
          lt: "Must be less than 100"
        })

      assert type ==
               {:type, :integer,
                [
                  {:gt, 0},
                  {:lt, 100},
                  {:error_message, :gt, "Must be positive"},
                  {:error_message, :lt, "Must be less than 100"}
                ]}
    end

    test "works with array types" do
      type =
        Types.array(Types.integer())
        |> Types.with_constraints(min_items: 1, max_items: 10)
        |> Types.with_error_messages(
          min_items: "At least one number is required",
          max_items: "Cannot have more than 10 numbers"
        )

      assert type ==
               {:array, {:type, :integer, []},
                [
                  {:min_items, 1},
                  {:max_items, 10},
                  {:error_message, :min_items, "At least one number is required"},
                  {:error_message, :max_items, "Cannot have more than 10 numbers"}
                ]}
    end
  end

  describe "validation with custom error messages" do
    test "uses custom error message for string min_length constraint" do
      type =
        Types.string()
        |> Types.with_constraints(min_length: 3)
        |> Types.with_error_message(:min_length, "Name must be at least 3 characters long")

      assert {:error, error} = Validator.validate(type, "ab")
      assert error.message == "Name must be at least 3 characters long"
      assert error.code == :min_length
      assert error.path == []
    end

    test "uses custom error message for string max_length constraint" do
      type =
        Types.string()
        |> Types.with_constraints(max_length: 5)
        |> Types.with_error_message(:max_length, "Name is too long")

      assert {:error, error} = Validator.validate(type, "verylongname")
      assert error.message == "Name is too long"
      assert error.code == :max_length
    end

    test "uses custom error message for integer gt constraint" do
      type =
        Types.integer()
        |> Types.with_constraints(gt: 10)
        |> Types.with_error_message(:gt, "Age must be greater than 10")

      assert {:error, error} = Validator.validate(type, 5)
      assert error.message == "Age must be greater than 10"
      assert error.code == :gt
    end

    test "uses custom error message for integer lt constraint" do
      type =
        Types.integer()
        |> Types.with_constraints(lt: 100)
        |> Types.with_error_message(:lt, "Value too high")

      assert {:error, error} = Validator.validate(type, 150)
      assert error.message == "Value too high"
      assert error.code == :lt
    end

    test "uses custom error message for choices constraint" do
      type =
        Types.string()
        |> Types.with_constraints(choices: ["red", "green", "blue"])
        |> Types.with_error_message(:choices, "Color must be red, green, or blue")

      assert {:error, error} = Validator.validate(type, "yellow")
      assert error.message == "Color must be red, green, or blue"
      assert error.code == :choices
    end

    test "uses custom error message for array min_items constraint" do
      type =
        Types.array(Types.string())
        |> Types.with_constraints(min_items: 2)
        |> Types.with_error_message(:min_items, "At least 2 items are required")

      assert {:error, [error]} = Validator.validate(type, ["one"])
      assert error.message == "At least 2 items are required"
      assert error.code == :min_items
    end

    test "uses custom error message for array max_items constraint" do
      type =
        Types.array(Types.string())
        |> Types.with_constraints(max_items: 2)
        |> Types.with_error_message(:max_items, "Too many items")

      assert {:error, [error]} = Validator.validate(type, ["one", "two", "three"])
      assert error.message == "Too many items"
      assert error.code == :max_items
    end

    test "falls back to default error message when no custom message is provided" do
      type =
        Types.string()
        |> Types.with_constraints(min_length: 3)

      assert {:error, error} = Validator.validate(type, "ab")
      assert error.message == "failed min_length constraint"
      assert error.code == :min_length
    end

    test "uses custom error messages for multiple constraints" do
      type =
        Types.string()
        |> Types.with_constraints(min_length: 3, max_length: 10)
        |> Types.with_error_messages(
          min_length: "Name too short",
          max_length: "Name too long"
        )

      # Test min_length custom message
      assert {:error, error} = Validator.validate(type, "ab")
      assert error.message == "Name too short"
      assert error.code == :min_length

      # Test max_length custom message
      assert {:error, error} = Validator.validate(type, "verylongname")
      assert error.message == "Name too long"
      assert error.code == :max_length
    end

    test "validates successfully when constraints pass" do
      type =
        Types.string()
        |> Types.with_constraints(min_length: 3, max_length: 10)
        |> Types.with_error_messages(
          min_length: "Name too short",
          max_length: "Name too long"
        )

      assert {:ok, "hello"} = Validator.validate(type, "hello")
    end
  end

  describe "validation with schema fields using custom error messages" do
    test "custom error messages work in schema field validation (direct type validation)" do
      # Test with direct type validation since schema system doesn't support complex expressions
      name_type =
        Types.string()
        |> Types.with_constraints(min_length: 3)
        |> Types.with_error_message(:min_length, "Name must be at least 3 characters long")

      age_type =
        Types.integer()
        |> Types.with_constraints(gt: 0, lt: 120)
        |> Types.with_error_messages(
          gt: "Age must be positive",
          lt: "Age must be realistic (less than 120)"
        )

      # Test custom error message for name field
      assert {:error, error} = Validator.validate(name_type, "ab")
      assert error.message == "Name must be at least 3 characters long"
      assert error.code == :min_length

      # Test custom error message for age field - gt constraint
      assert {:error, error} = Validator.validate(age_type, -5)
      assert error.message == "Age must be positive"
      assert error.code == :gt

      # Test other age constraint - lt constraint
      assert {:error, error} = Validator.validate(age_type, 150)
      assert error.message == "Age must be realistic (less than 120)"
      assert error.code == :lt

      # Test successful validation
      assert {:ok, "John"} = Validator.validate(name_type, "John")
      assert {:ok, 25} = Validator.validate(age_type, 25)
    end
  end

  describe "edge cases" do
    test "custom error message overrides default for same constraint" do
      type =
        Types.string()
        |> Types.with_constraints(min_length: 3)
        |> Types.with_error_message(:min_length, "Custom message")
        |> Types.with_error_message(:min_length, "Newer custom message")

      assert {:error, error} = Validator.validate(type, "ab")
      # Should use the last custom message set
      assert error.message == "Newer custom message"
    end

    test "custom error messages for constraints that don't exist are ignored" do
      type =
        Types.string()
        |> Types.with_constraints(min_length: 3)
        |> Types.with_error_message(:nonexistent_constraint, "This won't be used")

      assert {:error, error} = Validator.validate(type, "ab")
      assert error.message == "failed min_length constraint"
    end

    test "custom error messages work with format constraint" do
      type =
        Types.string()
        |> Types.with_constraints(format: ~r/^[a-z]+$/)
        |> Types.with_error_message(:format, "Must contain only lowercase letters")

      assert {:error, error} = Validator.validate(type, "Hello123")
      assert error.message == "Must contain only lowercase letters"
      assert error.code == :format
    end

    test "custom error messages work with map size constraint" do
      type =
        Types.map(Types.string(), Types.integer())
        |> Types.with_constraints(size?: 2)
        |> Types.with_error_message(:size?, "Map must have exactly 2 entries")

      assert {:error, [error]} = Validator.validate(type, %{"one" => 1})
      assert error.message == "Map must have exactly 2 entries"
      assert error.code == :size?
    end
  end
end
