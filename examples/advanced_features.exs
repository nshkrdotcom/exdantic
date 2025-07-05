# Advanced Features Examples for Exdantic

# This file demonstrates advanced features including object validation,
# complex nested structures, and integration patterns
# Run with: `mix run examples/advanced_features.exs`

# Compile and load the Exdantic modules
Mix.Task.run("compile")

defmodule AdvancedFeaturesExamples do
  alias Exdantic.Types
  alias Exdantic.Validator

  def run do
    IO.puts("=== Advanced Exdantic Features Examples ===\n")

    # 1. Object validation with complex nested structures
    nested_object_validation()

    # 2. Arrays with object elements
    array_of_objects()

    # 3. Union types with objects
    union_with_objects()

    # 4. Complex business domain modeling
    domain_modeling()

    # 5. Error handling patterns
    error_handling_patterns()

    # 6. Integration with custom error messages and validators
    integration_patterns()
  end

  defp nested_object_validation do
    IO.puts("1. Complex Nested Object Validation")
    IO.puts("-----------------------------------")

    # Define nested types
    contact_info_type =
      Types.object(%{
        email: Types.string()
               |> Types.with_constraints(format: ~r/^[^\s]+@[^\s]+\.[^\s]+$/)
               |> Types.with_error_message(:format, "Must be a valid email address"),
        phone: Types.string()
               |> Types.with_validator(fn phone ->
                 digits = String.replace(phone, ~r/\D/, "")
                 if String.length(digits) == 10,
                   do: {:ok, phone},
                   else: {:error, "Phone must have 10 digits"}
               end)
      })

    address_type =
      Types.object(%{
        street: Types.string()
                |> Types.with_constraints(min_length: 1)
                |> Types.with_error_message(:min_length, "Street address is required"),
        city: Types.string()
              |> Types.with_constraints(min_length: 1)
              |> Types.with_error_message(:min_length, "City is required"),
        state: Types.string()
               |> Types.with_constraints(min_length: 2, max_length: 2)
               |> Types.with_error_messages(%{
                 min_length: "State must be 2 characters",
                 max_length: "State must be 2 characters"
               }),
        zip: Types.string()
             |> Types.with_constraints(format: ~r/^\d{5}(-\d{4})?$/)
             |> Types.with_error_message(:format, "ZIP code must be in format 12345 or 12345-6789")
      })

    person_type =
      Types.object(%{
        name: Types.string()
              |> Types.with_constraints(min_length: 1)
              |> Types.with_error_message(:min_length, "Name is required"),
        age: Types.integer()
             |> Types.with_constraints(gt: 0, lt: 120)
             |> Types.with_error_messages(%{
               gt: "Age must be positive",
               lt: "Age must be less than 120"
             }),
        contact: contact_info_type,
        address: address_type,
        status: Types.type(:atom)
                |> Types.with_constraints(choices: [:active, :inactive, :pending])
                |> Types.with_error_message(:choices, "Status must be active, inactive, or pending")
      })

    # Valid person
    valid_person = %{
      name: "John Doe",
      age: 30,
      contact: %{
        email: "john@example.com",
        phone: "(555) 123-4567"
      },
      address: %{
        street: "123 Main St",
        city: "Springfield",
        state: "IL",
        zip: "62701"
      },
      status: :active
    }

    IO.puts("Valid nested object:")
    case Validator.validate(person_type, valid_person) do
      {:ok, _result} -> IO.puts("✓ Validation passed")
      {:error, errors} -> IO.puts("✗ Validation failed: #{inspect(errors)}")
    end

    # Invalid person with nested errors
    invalid_person = %{
      name: "",
      age: -5,
      contact: %{
        email: "invalid-email",
        phone: "123"
      },
      address: %{
        street: "",
        city: "",
        state: "Illinois",
        zip: "invalid"
      },
      status: :unknown
    }

    IO.puts("\nInvalid nested object with multiple errors:")
    case Validator.validate(person_type, invalid_person) do
      {:ok, _result} -> IO.puts("✓ Validation passed")
      {:error, errors} ->
        IO.puts("✗ Validation failed with #{length(errors)} errors:")
        Enum.each(errors, fn error ->
          IO.puts("  - #{inspect(error.path)}: #{error.message}")
        end)
    end

    IO.puts("")
  end

  defp array_of_objects do
    IO.puts("2. Arrays with Object Elements")
    IO.puts("------------------------------")

    # Define a product type
    product_type =
      Types.object(%{
        id: Types.integer()
            |> Types.with_constraints(gt: 0)
            |> Types.with_error_message(:gt, "Product ID must be positive"),
        name: Types.string()
              |> Types.with_constraints(min_length: 1)
              |> Types.with_error_message(:min_length, "Product name is required"),
        price: Types.float()
               |> Types.with_constraints(gt: 0.0)
               |> Types.with_error_message(:gt, "Price must be positive"),
        category: Types.type(:atom)
                  |> Types.with_constraints(choices: [:electronics, :books, :clothing, :home])
                  |> Types.with_error_message(:choices, "Invalid category")
      })

    # Order type with array of products
    order_type =
      Types.object(%{
        order_id: Types.string()
                  |> Types.with_constraints(format: ~r/^ORD-\d{6}$/)
                  |> Types.with_error_message(:format, "Order ID must be in format ORD-123456"),
        products: Types.array(product_type)
                  |> Types.with_constraints(min_items: 1)
                  |> Types.with_error_message(:min_items, "Order must contain at least one product"),
        total: Types.float()
               |> Types.with_constraints(gt: 0.0)
               |> Types.with_error_message(:gt, "Total must be positive")
      })

    # Valid order
    valid_order = %{
      order_id: "ORD-123456",
      products: [
        %{id: 1, name: "Laptop", price: 999.99, category: :electronics},
        %{id: 2, name: "Mouse", price: 29.99, category: :electronics}
      ],
      total: 1029.98
    }

    IO.puts("Valid order with products:")
    case Validator.validate(order_type, valid_order) do
      {:ok, _result} -> IO.puts("✓ Order validation passed")
      {:error, errors} -> IO.puts("✗ Order validation failed: #{inspect(errors)}")
    end

    # Invalid order with product errors
    invalid_order = %{
      order_id: "INVALID",
      products: [
        %{id: -1, name: "", price: -10.0, category: :invalid},
        %{id: 2, name: "Valid Product", price: 29.99, category: :electronics}
      ],
      total: -10.0
    }

    IO.puts("\nInvalid order with product errors:")
    case Validator.validate(order_type, invalid_order) do
      {:ok, _result} -> IO.puts("✓ Order validation passed")
      {:error, errors} ->
        IO.puts("✗ Order validation failed with #{length(errors)} errors:")
        Enum.each(errors, fn error ->
          IO.puts("  - #{inspect(error.path)}: #{error.message}")
        end)
    end

    IO.puts("")
  end

  defp union_with_objects do
    IO.puts("3. Union Types with Objects")
    IO.puts("---------------------------")

    # Define different event types
    user_event_type =
      Types.object(%{
        type: Types.type(:atom)
              |> Types.with_constraints(choices: [:user_created, :user_updated, :user_deleted]),
        user_id: Types.integer()
                 |> Types.with_constraints(gt: 0),
        data: Types.object(%{
          name: Types.string(),
          email: Types.string()
        })
      })

    order_event_type =
      Types.object(%{
        type: Types.type(:atom)
              |> Types.with_constraints(choices: [:order_placed, :order_shipped, :order_delivered]),
        order_id: Types.string(),
        data: Types.object(%{
          amount: Types.float(),
          status: Types.type(:atom)
        })
      })

    # Union of event types
    event_type = Types.union([user_event_type, order_event_type])

    # Valid user event
    user_event = %{
      type: :user_created,
      user_id: 123,
      data: %{
        name: "John Doe",
        email: "john@example.com"
      }
    }

    IO.puts("Valid user event:")
    case Validator.validate(event_type, user_event) do
      {:ok, _result} -> IO.puts("✓ User event validation passed")
      {:error, errors} -> IO.puts("✗ User event validation failed: #{inspect(errors)}")
    end

    # Valid order event
    order_event = %{
      type: :order_placed,
      order_id: "ORD-123456",
      data: %{
        amount: 99.99,
        status: :pending
      }
    }

    IO.puts("\nValid order event:")
    case Validator.validate(event_type, order_event) do
      {:ok, _result} -> IO.puts("✓ Order event validation passed")
      {:error, errors} -> IO.puts("✗ Order event validation failed: #{inspect(errors)}")
    end

    IO.puts("")
  end

  defp domain_modeling do
    IO.puts("4. Complex Business Domain Modeling")
    IO.puts("-----------------------------------")

    # E-commerce domain modeling
    money_type =
      Types.object(%{
        amount: Types.float()
                |> Types.with_constraints(gt: 0.0)
                |> Types.with_error_message(:gt, "Amount must be positive"),
        currency: Types.string()
                  |> Types.with_constraints(choices: ["USD", "EUR", "GBP", "CAD"])
                  |> Types.with_error_message(:choices, "Unsupported currency")
      })

    inventory_item_type =
      Types.object(%{
        sku: Types.string()
             |> Types.with_constraints(format: ~r/^[A-Z]{3}-\d{4}-[A-Z]{2}$/)
             |> Types.with_error_message(:format, "SKU must be in format ABC-1234-XY"),
        quantity: Types.integer()
                  |> Types.with_constraints(gteq: 0)
                  |> Types.with_error_message(:gteq, "Quantity cannot be negative"),
        reserved: Types.integer()
                  |> Types.with_constraints(gteq: 0)
                  |> Types.with_error_message(:gteq, "Reserved quantity cannot be negative")
      })
      |> Types.with_validator(fn item ->
        if item.reserved <= item.quantity,
          do: {:ok, item},
          else: {:error, "Reserved quantity cannot exceed available quantity"}
      end)

    product_type =
      Types.object(%{
        id: Types.integer()
            |> Types.with_constraints(gt: 0),
        name: Types.string()
              |> Types.with_constraints(min_length: 1, max_length: 100),
        description: Types.string()
                     |> Types.with_constraints(max_length: 1000),
        price: money_type,
        inventory: inventory_item_type,
        tags: Types.array(Types.string())
              |> Types.with_constraints(max_items: 10)
              |> Types.with_validator(fn tags ->
                if length(tags) == length(Enum.uniq(tags)),
                  do: {:ok, tags},
                  else: {:error, "Tags must be unique"}
              end),
        active: Types.boolean()
      })

    # Valid product
    valid_product = %{
      id: 1,
      name: "Laptop Computer",
      description: "High-performance laptop for developers",
      price: %{amount: 1299.99, currency: "USD"},
      inventory: %{sku: "ELC-1234-AB", quantity: 50, reserved: 5},
      tags: ["electronics", "computer", "laptop"],
      active: true
    }

    IO.puts("Valid product:")
    case Validator.validate(product_type, valid_product) do
      {:ok, _result} -> IO.puts("✓ Product validation passed")
      {:error, errors} -> IO.puts("✗ Product validation failed: #{inspect(errors)}")
    end

    # Invalid product with business rule violation
    invalid_product = %{
      id: 1,
      name: "Laptop Computer",
      description: "High-performance laptop for developers",
      price: %{amount: 1299.99, currency: "USD"},
      inventory: %{sku: "ELC-1234-AB", quantity: 50, reserved: 60},  # Reserved > quantity
      tags: ["electronics", "computer", "electronics"],  # Duplicate tags
      active: true
    }

    IO.puts("\nInvalid product with business rule violations:")
    case Validator.validate(product_type, invalid_product) do
      {:ok, _result} -> IO.puts("✓ Product validation passed")
      {:error, errors} ->
        IO.puts("✗ Product validation failed with #{length(errors)} errors:")
        Enum.each(errors, fn error ->
          IO.puts("  - #{inspect(error.path)}: #{error.message}")
        end)
    end

    IO.puts("")
  end

  defp error_handling_patterns do
    IO.puts("5. Error Handling Patterns")
    IO.puts("--------------------------")

    # Demonstration of different error handling approaches
    user_type =
      Types.object(%{
        email: Types.string()
               |> Types.with_constraints(format: ~r/^[^\s]+@[^\s]+\.[^\s]+$/)
               |> Types.with_error_message(:format, "Must be a valid email address"),
        age: Types.integer()
             |> Types.with_constraints(gteq: 18, lteq: 100)
             |> Types.with_error_messages(%{
               gteq: "Must be at least 18 years old",
               lteq: "Must be 100 years old or younger"
             })
      })

    invalid_user = %{email: "invalid-email", age: 15}

    IO.puts("Pattern 1: Simple error checking")
    case Validator.validate(user_type, invalid_user) do
      {:ok, user} ->
        IO.puts("User is valid: #{inspect(user)}")

      {:error, errors} ->
        IO.puts("Validation errors found:")
        Enum.each(errors, fn error ->
          IO.puts("  - #{error.message}")
        end)
    end

    IO.puts("\nPattern 2: Field-specific error handling")
    case Validator.validate(user_type, invalid_user) do
      {:ok, user} ->
        IO.puts("User is valid: #{inspect(user)}")

      {:error, errors} ->
        # Group errors by field
        field_errors =
          errors
          |> Enum.group_by(fn error -> List.first(error.path) end)

        Enum.each(field_errors, fn {field, field_errors} ->
          messages = Enum.map(field_errors, & &1.message)
          IO.puts("  #{field}: #{Enum.join(messages, ", ")}")
        end)
    end

    IO.puts("\nPattern 3: Error transformation for APIs")
    case Validator.validate(user_type, invalid_user) do
      {:ok, user} ->
        {:ok, user}

      {:error, errors} ->
        # Transform to API-friendly format
        api_errors =
          errors
          |> Enum.map(fn error ->
            %{
              field: Enum.join(error.path, "."),
              code: error.code,
              message: error.message
            }
          end)

        IO.puts("API error format:")
        IO.inspect(api_errors, pretty: true)
    end

    IO.puts("")
  end

  defp integration_patterns do
    IO.puts("6. Integration with Custom Error Messages and Validators")
    IO.puts("-------------------------------------------------------")

    # Complete integration example: User registration form
    user_registration_type =
      Types.object(%{
        username: Types.string()
                  |> Types.with_constraints(min_length: 3, max_length: 20)
                  |> Types.with_error_messages(%{
                    min_length: "Username must be at least 3 characters",
                    max_length: "Username cannot exceed 20 characters"
                  })
                  |> Types.with_validator(fn username ->
                    cond do
                      not String.match?(username, ~r/^[a-zA-Z0-9_]+$/) ->
                        {:error, "Username can only contain letters, numbers, and underscores"}

                      String.downcase(username) in ["admin", "root", "system"] ->
                        {:error, "Username '#{username}' is not available"}

                      true ->
                        {:ok, username}
                    end
                  end),

        email: Types.string()
               |> Types.with_constraints(min_length: 5, max_length: 100)
               |> Types.with_error_messages(%{
                 min_length: "Email is too short",
                 max_length: "Email is too long"
               })
               |> Types.with_validator(fn email ->
                 if String.match?(email, ~r/^[^\s]+@[^\s]+\.[^\s]+$/),
                   do: {:ok, String.downcase(email)},
                   else: {:error, "Please enter a valid email address"}
               end),

        password: Types.string()
                  |> Types.with_constraints(min_length: 8)
                  |> Types.with_error_message(:min_length, "Password must be at least 8 characters")
                  |> Types.with_validator(fn password ->
                    checks = [
                      {String.match?(password, ~r/[A-Z]/), "Password must contain an uppercase letter"},
                      {String.match?(password, ~r/[a-z]/), "Password must contain a lowercase letter"},
                      {String.match?(password, ~r/[0-9]/), "Password must contain a number"},
                      {String.match?(password, ~r/[!@#$%^&*]/), "Password must contain a special character"}
                    ]

                    case Enum.find(checks, fn {valid, _} -> not valid end) do
                      {false, message} -> {:error, message}
                      nil -> {:ok, password}
                    end
                  end),

        age: Types.integer()
             |> Types.with_constraints(gteq: 13, lteq: 120)
             |> Types.with_error_messages(%{
               gteq: "You must be at least 13 years old to register",
               lteq: "Please enter a valid age"
             }),

        terms_accepted: Types.boolean()
                        |> Types.with_validator(fn accepted ->
                          if accepted,
                            do: {:ok, accepted},
                            else: {:error, "You must accept the terms and conditions"}
                        end)
      })

    # Valid registration
    valid_registration = %{
      username: "john_doe",
      email: "JOHN@EXAMPLE.COM",
      password: "SecurePass123!",
      age: 25,
      terms_accepted: true
    }

    IO.puts("Valid user registration:")
    case Validator.validate(user_registration_type, valid_registration) do
      {:ok, user} ->
        IO.puts("✓ Registration successful!")
        IO.puts("  Username: #{user.username}")
        IO.puts("  Email: #{user.email}")  # Should be lowercased
        IO.puts("  Age: #{user.age}")

      {:error, errors} ->
        IO.puts("✗ Registration failed: #{inspect(errors)}")
    end

    # Invalid registration
    invalid_registration = %{
      username: "ad",
      email: "invalid-email",
      password: "weak",
      age: 12,
      terms_accepted: false
    }

    IO.puts("\nInvalid user registration:")
    case Validator.validate(user_registration_type, invalid_registration) do
      {:ok, _user} ->
        IO.puts("✓ Registration successful!")

      {:error, errors} ->
        IO.puts("✗ Registration failed with #{length(errors)} errors:")
        Enum.each(errors, fn error ->
          field = if error.path == [], do: "form", else: Enum.join(error.path, ".")
          IO.puts("  - #{field}: #{error.message}")
        end)
    end

    IO.puts("")
  end
end

# Run the examples
AdvancedFeaturesExamples.run()