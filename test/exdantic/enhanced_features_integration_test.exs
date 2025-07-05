defmodule Exdantic.EnhancedFeaturesIntegrationTest do
  use ExUnit.Case, async: true
  alias Exdantic.{Types, Validator}

  describe "integration of all new features" do
    test "object validation with custom error messages and custom validators" do
      # Define a comprehensive object type that uses all new features
      user_type =
        Types.object(%{
          # Atom with choices constraint
          role:
            Types.type(:atom)
            |> Types.with_constraints(choices: [:admin, :user, :guest])
            |> Types.with_error_message(:choices, "Role must be admin, user, or guest"),

          # String with custom error message and custom validator
          email:
            Types.string()
            |> Types.with_constraints(min_length: 5, format: ~r/@/)
            |> Types.with_error_messages(%{
              min_length: "Email must be at least 5 characters",
              format: "Email must contain @ symbol"
            })
            |> Types.with_validator(fn value ->
              if String.ends_with?(String.downcase(value), ".com") do
                {:ok, String.downcase(value)}
              else
                {:error, "Email must end with .com"}
              end
            end),

          # Integer with custom validation and error message
          age:
            Types.integer()
            |> Types.with_constraints(gt: 0, lt: 120)
            |> Types.with_error_message(:gt, "Age must be positive")
            |> Types.with_validator(fn value ->
              if rem(value, 1) == 0, do: {:ok, value}, else: {:error, "Age must be whole number"}
            end),

          # Optional field with custom validation
          phone:
            Types.string()
            |> Types.with_constraints(min_length: 10)
            |> Types.with_validator(fn value ->
              # Transform phone number format
              cleaned = String.replace(value, ~r/[^\d]/, "")

              if String.length(cleaned) == 10 do
                {:ok,
                 "#{String.slice(cleaned, 0, 3)}-#{String.slice(cleaned, 3, 3)}-#{String.slice(cleaned, 6, 4)}"}
              else
                {:error, "Phone must be 10 digits"}
              end
            end)
        })

      # Test successful validation with transformation
      valid_data = %{
        role: :admin,
        # Should be transformed to lowercase
        email: "USER@EXAMPLE.COM",
        age: 30,
        # Should be transformed to 555-123-4567
        phone: "(555) 123-4567"
      }

      assert {:ok, validated} = Validator.validate(user_type, valid_data)
      assert validated.role == :admin
      # Transformed
      assert validated.email == "user@example.com"
      assert validated.age == 30
      # Transformed
      assert validated.phone == "555-123-4567"

      # Test atom choices constraint with custom error
      invalid_role = %{role: :invalid, email: "test@example.com", age: 30, phone: "5551234567"}
      assert {:error, [error]} = Validator.validate(user_type, invalid_role)
      assert error.path == [:role]
      assert error.message == "Role must be admin, user, or guest"

      # Test custom email validation
      invalid_email = %{role: :user, email: "test@example.org", age: 30, phone: "5551234567"}
      assert {:error, [error]} = Validator.validate(user_type, invalid_email)
      assert error.path == [:email]
      assert error.message == "Email must end with .com"
    end

    test "nested objects with all enhanced features" do
      address_type =
        Types.object(%{
          street:
            Types.string()
            |> Types.with_constraints(min_length: 5)
            |> Types.with_error_message(:min_length, "Street address too short"),
          type:
            Types.type(:atom)
            |> Types.with_constraints(choices: [:home, :work, :other])
            |> Types.with_error_message(:choices, "Address type must be home, work, or other")
        })

      person_type =
        Types.object(%{
          name:
            Types.string()
            |> Types.with_validator(fn value ->
              # Capitalize each word
              capitalized =
                value |> String.split() |> Enum.map_join(" ", &String.capitalize/1)

              {:ok, capitalized}
            end),
          addresses:
            Types.array(address_type)
            |> Types.with_constraints(min_items: 1)
            |> Types.with_error_message(:min_items, "At least one address required")
        })

      valid_data = %{
        # Should be transformed to "John Doe"
        name: "john doe",
        addresses: [
          %{street: "123 Main Street", type: :home},
          %{street: "456 Corporate Blvd", type: :work}
        ]
      }

      assert {:ok, validated} = Validator.validate(person_type, valid_data)
      # Transformed
      assert validated.name == "John Doe"
      assert length(validated.addresses) == 2

      # Test nested custom error message
      invalid_address_type = %{
        name: "John Doe",
        addresses: [%{street: "123 Main Street", type: :invalid}]
      }

      assert {:error, [error]} = Validator.validate(person_type, invalid_address_type)
      assert error.path == [:addresses, 0, :type]
      assert error.message == "Address type must be home, work, or other"
    end

    test "union types with enhanced features" do
      # Union of different enhanced types
      id_type =
        Types.union([
          # String with custom validation
          Types.string()
          |> Types.with_constraints(format: ~r/^USER-\d+$/)
          |> Types.with_error_message(:format, "String ID must match USER-#### format"),

          # Integer with custom validation
          Types.integer()
          |> Types.with_constraints(gt: 1000)
          |> Types.with_error_message(:gt, "Numeric ID must be greater than 1000"),

          # Atom with choices
          Types.type(:atom)
          |> Types.with_constraints(choices: [:auto, :system])
          |> Types.with_error_message(:choices, "Special ID must be :auto or :system")
        ])

      # Test string variant
      assert {:ok, "USER-1234"} = Validator.validate(id_type, "USER-1234")

      # Test integer variant
      assert {:ok, 5000} = Validator.validate(id_type, 5000)

      # Test atom variant
      assert {:ok, :auto} = Validator.validate(id_type, :auto)

      # Test union failure with detailed error from best match
      assert {:error, [error]} = Validator.validate(id_type, "INVALID-123")
      # Should show the most relevant error (string format error)
      assert String.contains?(error.message, "USER-#### format") or
               String.contains?(error.message, "union")
    end

    test "array of objects with comprehensive validation" do
      item_type =
        Types.object(%{
          id:
            Types.integer()
            |> Types.with_constraints(gt: 0)
            |> Types.with_error_message(:gt, "Item ID must be positive"),
          category:
            Types.type(:atom)
            |> Types.with_constraints(choices: [:food, :tech, :clothing])
            |> Types.with_error_message(:choices, "Invalid category"),
          price:
            Types.float()
            |> Types.with_constraints(gteq: 0.01)
            |> Types.with_validator(fn value ->
              # Round to 2 decimal places
              rounded = Float.round(value, 2)
              {:ok, rounded}
            end)
        })

      inventory_type =
        Types.array(item_type)
        |> Types.with_constraints(min_items: 1, max_items: 100)
        |> Types.with_error_messages(%{
          min_items: "Inventory cannot be empty",
          max_items: "Too many items in inventory"
        })

      valid_data = [
        # Should round to 10.00
        %{id: 1, category: :food, price: 9.999},
        %{id: 2, category: :tech, price: 299.95}
      ]

      assert {:ok, validated} = Validator.validate(inventory_type, valid_data)
      assert length(validated) == 2
      # Rounded
      assert validated |> Enum.at(0) |> Map.get(:price) == 10.00

      # Test array constraint error
      assert {:error, [error]} = Validator.validate(inventory_type, [])
      assert error.message == "Inventory cannot be empty"

      # Test nested object error
      invalid_item = [%{id: -1, category: :food, price: 10.00}]
      assert {:error, [error]} = Validator.validate(inventory_type, invalid_item)
      assert error.path == [0, :id]
      assert error.message == "Item ID must be positive"
    end
  end
end
