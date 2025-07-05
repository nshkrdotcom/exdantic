defmodule Exdantic.ValidatorEnhancedFeaturesTest do
  use ExUnit.Case, async: true
  alias Exdantic.{Types, Validator}

  describe "validator with custom error messages and validation functions" do
    test "applies custom error messages in complex nested validation" do
      # Complex type with multiple levels of custom error messages
      order_type =
        Types.object(%{
          order_id:
            Types.string()
            |> Types.with_constraints(format: ~r/^ORD-\d{6}$/)
            |> Types.with_error_message(:format, "Order ID must be in format ORD-######"),
          items:
            Types.array(
              Types.object(%{
                sku:
                  Types.string()
                  |> Types.with_constraints(min_length: 3, max_length: 20)
                  |> Types.with_error_messages(%{
                    min_length: "SKU too short (minimum 3 characters)",
                    max_length: "SKU too long (maximum 20 characters)"
                  }),
                quantity:
                  Types.integer()
                  |> Types.with_constraints(gt: 0, lteq: 1000)
                  |> Types.with_error_messages(%{
                    gt: "Quantity must be at least 1",
                    lteq: "Quantity cannot exceed 1000"
                  })
              })
            )
            |> Types.with_constraints(min_items: 1)
            |> Types.with_error_message(:min_items, "Order must contain at least one item"),
          status:
            Types.type(:atom)
            |> Types.with_constraints(choices: [:pending, :confirmed, :shipped, :delivered])
            |> Types.with_error_message(
              :choices,
              "Status must be pending, confirmed, shipped, or delivered"
            )
        })

      # Test top-level custom error message
      invalid_order_id = %{
        order_id: "INVALID-123",
        items: [%{sku: "ABC123", quantity: 1}],
        status: :pending
      }

      assert {:error, [error]} = Validator.validate(order_type, invalid_order_id)
      assert error.path == [:order_id]
      assert error.message == "Order ID must be in format ORD-######"

      # Test nested custom error message
      invalid_sku = %{
        order_id: "ORD-123456",
        # Too short
        items: [%{sku: "AB", quantity: 1}],
        status: :pending
      }

      assert {:error, [error]} = Validator.validate(order_type, invalid_sku)
      assert error.path == [:items, 0, :sku]
      assert error.message == "SKU too short (minimum 3 characters)"

      # Test array custom error message
      empty_items = %{
        order_id: "ORD-123456",
        items: [],
        status: :pending
      }

      assert {:error, [error]} = Validator.validate(order_type, empty_items)
      assert error.path == [:items]
      assert error.message == "Order must contain at least one item"

      # Test atom choices custom error message
      invalid_status = %{
        order_id: "ORD-123456",
        items: [%{sku: "ABC123", quantity: 1}],
        status: :invalid_status
      }

      assert {:error, [error]} = Validator.validate(order_type, invalid_status)
      assert error.path == [:status]
      assert error.message == "Status must be pending, confirmed, shipped, or delivered"
    end

    test "custom validators with error handling and value transformation" do
      # Email type with comprehensive validation and transformation
      email_type =
        Types.string()
        |> Types.with_constraints(min_length: 5)
        |> Types.with_error_message(:min_length, "Email must be at least 5 characters")
        |> Types.with_validator(fn value ->
          cond do
            not String.contains?(value, "@") ->
              {:error, "Email must contain @ symbol"}

            not String.match?(value, ~r/^[^@]+@[^@]+\.[^@]+$/) ->
              {:error, "Email format is invalid"}

            String.ends_with?(value, ".test") ->
              {:error, "Test email domains not allowed"}

            true ->
              # Transform: lowercase and trim
              cleaned = value |> String.trim() |> String.downcase()
              {:ok, cleaned}
          end
        end)

      # Test successful transformation
      assert {:ok, "user@example.com"} = Validator.validate(email_type, "  USER@EXAMPLE.COM  ")

      # Test constraint error (happens before custom validator)
      assert {:error, error} = Validator.validate(email_type, "ab")
      assert error.message == "Email must be at least 5 characters"
      assert error.code == :min_length

      # Test custom validator errors
      assert {:error, error} = Validator.validate(email_type, "noemail")
      assert error.message == "Email must contain @ symbol"
      assert error.code == :custom_validation

      assert {:error, error} = Validator.validate(email_type, "invalid@format")
      assert error.message == "Email format is invalid"

      assert {:error, error} = Validator.validate(email_type, "user@domain.test")
      assert error.message == "Test email domains not allowed"
    end

    test "multiple custom validators in sequence" do
      # Phone number with multiple validation steps
      phone_type =
        Types.string()
        |> Types.with_validator(fn value ->
          # Step 1: Clean the input
          cleaned = String.replace(value, ~r/[^\d]/, "")

          if String.length(cleaned) == 10 do
            {:ok, cleaned}
          else
            {:error, "Phone must contain exactly 10 digits"}
          end
        end)
        |> Types.with_validator(fn value ->
          # Step 2: Validate area code
          area_code = String.slice(value, 0, 3)

          if area_code in ["800", "888", "877", "866"] do
            {:error, "Toll-free numbers not allowed"}
          else
            {:ok, value}
          end
        end)
        |> Types.with_validator(fn value ->
          # Step 3: Format the number
          formatted =
            "#{String.slice(value, 0, 3)}-#{String.slice(value, 3, 3)}-#{String.slice(value, 6, 4)}"

          {:ok, formatted}
        end)

      # Test successful multi-step validation
      assert {:ok, "555-123-4567"} = Validator.validate(phone_type, "(555) 123-4567")
      assert {:ok, "555-123-4567"} = Validator.validate(phone_type, "555.123.4567")
      assert {:ok, "555-123-4567"} = Validator.validate(phone_type, "5551234567")

      # Test first validator failure
      assert {:error, error} = Validator.validate(phone_type, "123")
      assert error.message == "Phone must contain exactly 10 digits"

      # Test second validator failure
      assert {:error, error} = Validator.validate(phone_type, "800-123-4567")
      assert error.message == "Toll-free numbers not allowed"
    end

    test "custom validators with exception handling" do
      # Validator that might throw exceptions
      risky_type =
        Types.string()
        |> Types.with_validator(fn value ->
          case value do
            "crash" -> raise "Intentional crash"
            "invalid_return" -> :not_a_valid_return
            "error_tuple" -> {:error, "Custom error message"}
            "success" -> {:ok, "validated"}
            _ -> {:ok, value}
          end
        end)

      # Test normal operation
      assert {:ok, "validated"} = Validator.validate(risky_type, "success")
      assert {:ok, "normal"} = Validator.validate(risky_type, "normal")

      # Test custom error
      assert {:error, error} = Validator.validate(risky_type, "error_tuple")
      assert error.message == "Custom error message"
      assert error.code == :custom_validation

      # Test invalid return format
      assert {:error, error} = Validator.validate(risky_type, "invalid_return")
      assert error.code == :custom_validation
      assert String.contains?(error.message, "invalid format")

      # Test exception propagation
      assert_raise RuntimeError, "Intentional crash", fn ->
        Validator.validate(risky_type, "crash")
      end
    end

    test "integration of custom validators with constraint systems" do
      # Password validation with both constraints and custom logic
      password_type =
        Types.string()
        |> Types.with_constraints(min_length: 8, max_length: 100)
        |> Types.with_error_messages(%{
          min_length: "Password must be at least 8 characters",
          max_length: "Password too long"
        })
        |> Types.with_validator(fn value ->
          cond do
            not String.match?(value, ~r/[A-Z]/) ->
              {:error, "Password must contain at least one uppercase letter"}

            not String.match?(value, ~r/[a-z]/) ->
              {:error, "Password must contain at least one lowercase letter"}

            not String.match?(value, ~r/\d/) ->
              {:error, "Password must contain at least one digit"}

            not String.match?(value, ~r/[!@#$%^&*(),.?":{}|<>]/) ->
              {:error, "Password must contain at least one special character"}

            String.contains?(String.downcase(value), "password") ->
              {:error, "Password cannot contain the word 'password'"}

            true ->
              {:ok, value}
          end
        end)

      # Test constraint failure (happens first)
      assert {:error, error} = Validator.validate(password_type, "short")
      assert error.message == "Password must be at least 8 characters"
      assert error.code == :min_length

      # Test custom validation failures (after constraints pass)
      assert {:error, error} = Validator.validate(password_type, "lowercase123!")
      assert error.message == "Password must contain at least one uppercase letter"

      assert {:error, error} = Validator.validate(password_type, "UPPERCASE123!")
      assert error.message == "Password must contain at least one lowercase letter"

      assert {:error, error} = Validator.validate(password_type, "NoNumbers!")
      assert error.message == "Password must contain at least one digit"

      assert {:error, error} = Validator.validate(password_type, "NoSpecial123")
      assert error.message == "Password must contain at least one special character"

      assert {:error, error} = Validator.validate(password_type, "MyPassword123!")
      assert error.message == "Password cannot contain the word 'password'"

      # Test successful validation
      assert {:ok, "StrongPass123!"} = Validator.validate(password_type, "StrongPass123!")
    end

    test "custom validators in nested structures maintain proper error paths" do
      user_type =
        Types.object(%{
          profile:
            Types.object(%{
              username:
                Types.string()
                |> Types.with_validator(fn value ->
                  if String.match?(value, ~r/^[a-zA-Z0-9_]+$/) do
                    {:ok, String.downcase(value)}
                  else
                    {:error, "Username can only contain letters, numbers, and underscores"}
                  end
                end),
              bio:
                Types.string()
                |> Types.with_constraints(max_length: 500)
                |> Types.with_validator(fn value ->
                  # Remove excessive whitespace
                  cleaned = value |> String.trim() |> String.replace(~r/\s+/, " ")

                  if String.length(cleaned) == 0 do
                    {:error, "Bio cannot be empty after cleaning"}
                  else
                    {:ok, cleaned}
                  end
                end)
            }),
          contacts:
            Types.array(
              Types.object(%{
                type:
                  Types.type(:atom) |> Types.with_constraints(choices: [:email, :phone, :social]),
                value:
                  Types.string()
                  |> Types.with_validator(fn value ->
                    # This validator will be called for each contact value
                    if String.length(String.trim(value)) > 0 do
                      {:ok, String.trim(value)}
                    else
                      {:error, "Contact value cannot be empty"}
                    end
                  end)
              })
            )
        })

      valid_data = %{
        profile: %{
          # Should be transformed to "user_name123"
          username: "User_Name123",
          # Should be cleaned to "This is my bio"
          bio: "  This   is    my    bio  "
        },
        contacts: [
          # Should be trimmed
          %{type: :email, value: "  user@example.com  "},
          %{type: :phone, value: "555-1234"}
        ]
      }

      assert {:ok, validated} = Validator.validate(user_type, valid_data)
      # Transformed
      assert validated.profile.username == "user_name123"
      # Cleaned
      assert validated.profile.bio == "This is my bio"
      # Trimmed
      assert validated.contacts |> Enum.at(0) |> Map.get(:value) == "user@example.com"

      # Test custom validator error with proper path
      invalid_username = %{
        profile: %{
          # Contains invalid characters
          username: "invalid-username!",
          bio: "Valid bio"
        },
        contacts: []
      }

      assert {:error, [error]} = Validator.validate(user_type, invalid_username)
      assert error.path == [:profile, :username]
      assert error.message == "Username can only contain letters, numbers, and underscores"
      assert error.code == :custom_validation

      # Test nested array custom validator error
      empty_contact = %{
        profile: %{username: "validuser", bio: "Valid bio"},
        # Empty after trim
        contacts: [%{type: :email, value: "   "}]
      }

      assert {:error, [error]} = Validator.validate(user_type, empty_contact)
      assert error.path == [:contacts, 0, :value]
      assert error.message == "Contact value cannot be empty"
    end
  end

  describe "performance and edge cases with enhanced features" do
    test "handles large datasets with custom validators efficiently" do
      # Simple type with custom validator for performance testing
      item_type =
        Types.object(%{
          id: Types.integer() |> Types.with_constraints(gt: 0),
          name:
            Types.string()
            |> Types.with_validator(fn value ->
              # Simple transformation - capitalize
              {:ok, String.capitalize(value)}
            end),
          active: Types.type(:atom) |> Types.with_constraints(choices: [:yes, :no])
        })

      large_dataset =
        Enum.map(1..1000, fn i ->
          %{id: i, name: "item #{i}", active: if(rem(i, 2) == 0, do: :yes, else: :no)}
        end)

      array_type = Types.array(item_type)

      # This should complete without performance issues
      start_time = System.monotonic_time(:millisecond)
      assert {:ok, validated} = Validator.validate(array_type, large_dataset)
      end_time = System.monotonic_time(:millisecond)

      # Verify transformations were applied
      assert length(validated) == 1000
      # Capitalized
      assert validated |> Enum.at(0) |> Map.get(:name) == "Item 1"

      # Should complete in reasonable time (less than 5 seconds)
      duration = end_time - start_time
      assert duration < 5000
    end

    test "handles complex custom validator chains without stack overflow" do
      # Create a type with many chained validators
      multi_validator_type =
        Enum.reduce(1..50, Types.string(), fn i, acc ->
          acc
          |> Types.with_validator(fn value ->
            # Each validator adds a number
            {:ok, "#{value}_#{i}"}
          end)
        end)

      assert {:ok, result} = Validator.validate(multi_validator_type, "start")

      # Should have all transformations applied
      assert String.starts_with?(result, "start_1")
      assert String.ends_with?(result, "_50")
    end

    test "handles custom validator errors in deeply nested structures" do
      # 5 levels deep with custom validators at each level
      deep_type =
        Types.array(
          Types.object(%{
            level1:
              Types.array(
                Types.object(%{
                  level2:
                    Types.map(
                      Types.string(),
                      Types.object(%{
                        level3:
                          Types.string()
                          |> Types.with_validator(fn value ->
                            if String.length(value) > 3 do
                              {:ok, value}
                            else
                              {:error, "Level 3 value too short"}
                            end
                          end)
                      })
                    )
                })
              )
          })
        )

      deep_invalid_data = [
        %{
          level1: [
            %{
              level2: %{
                # Valid (length > 3)
                "key1" => %{level3: "valid"},
                # Invalid - too short
                "key2" => %{level3: "no"}
              }
            }
          ]
        }
      ]

      assert {:error, [error]} = Validator.validate(deep_type, deep_invalid_data)
      assert error.path == [0, :level1, 0, :level2, "key2", :level3]
      assert error.message == "Level 3 value too short"
    end
  end
end
