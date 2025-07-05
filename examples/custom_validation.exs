# Custom Validation Functions Examples for Exdantic

# This file demonstrates the custom validation function features
# Run with: `mix run examples/custom_validation.exs`

# Compile and load the Exdantic modules
Mix.Task.run("compile")

defmodule CustomValidationExamples do
  alias Exdantic.Types
  alias Exdantic.Validator

  def run do
    IO.puts("=== Custom Validation Functions Examples ===\n")

    # 1. Email validation with custom logic
    email_validation()

    # 2. Business logic validation
    business_logic_validation()

    # 3. Value transformation
    value_transformation()

    # 4. Multiple validators
    multiple_validators()

    # 5. Complex business rules
    complex_business_rules()
  end

  defp email_validation do
    IO.puts("1. Email Validation with Custom Logic")
    IO.puts("-------------------------------------")

    email_type =
      Types.string()
      |> Types.with_constraints(min_length: 5)
      |> Types.with_validator(fn value ->
        cond do
          not String.contains?(value, "@") ->
            {:error, "Must be a valid email address"}

          not String.match?(value, ~r/^[^@]+@[^@]+\.[^@]+$/) ->
            {:error, "Email format is invalid"}

          String.length(value) > 100 ->
            {:error, "Email address too long"}

          true ->
            {:ok, String.downcase(value)}
        end
      end)

    IO.puts("Valid email:")
    IO.inspect(Validator.validate(email_type, "USER@EXAMPLE.COM"))

    IO.puts("\nInvalid email (no @):")
    case Validator.validate(email_type, "userexample.com") do
      {:error, error} -> IO.puts("Error: #{error.message}")
      result -> IO.inspect(result)
    end

    IO.puts("\nInvalid email format:")
    case Validator.validate(email_type, "user@@example.com") do
      {:error, error} -> IO.puts("Error: #{error.message}")
      result -> IO.inspect(result)
    end

    IO.puts("")
  end

  defp business_logic_validation do
    IO.puts("2. Business Logic Validation")
    IO.puts("----------------------------")

    # Age validation with business rules
    age_type =
      Types.integer()
      |> Types.with_constraints(gt: 0)
      |> Types.with_validator(fn age ->
        cond do
          age < 13 -> {:error, "Must be at least 13 years old"}
          age > 120 -> {:error, "Age must be realistic"}
          true -> {:ok, age}
        end
      end)

    IO.puts("Valid age:")
    IO.inspect(Validator.validate(age_type, 25))

    IO.puts("\nToo young:")
    case Validator.validate(age_type, 10) do
      {:error, error} -> IO.puts("Error: #{error.message}")
      result -> IO.inspect(result)
    end

    IO.puts("\nUnrealistic age:")
    case Validator.validate(age_type, 150) do
      {:error, error} -> IO.puts("Error: #{error.message}")
      result -> IO.inspect(result)
    end

    # Password strength validation
    password_type =
      Types.string()
      |> Types.with_constraints(min_length: 8)
      |> Types.with_validator(fn password ->
        cond do
          not String.match?(password, ~r/[A-Z]/) ->
            {:error, "Password must contain at least one uppercase letter"}

          not String.match?(password, ~r/[a-z]/) ->
            {:error, "Password must contain at least one lowercase letter"}

          not String.match?(password, ~r/[0-9]/) ->
            {:error, "Password must contain at least one number"}

          not String.match?(password, ~r/[!@#$%^&*]/) ->
            {:error, "Password must contain at least one special character (!@#$%^&*)"}

          true ->
            {:ok, password}
        end
      end)

    IO.puts("\nPassword validation:")
    IO.puts("Valid password:")
    IO.inspect(Validator.validate(password_type, "MyPassword123!"))

    IO.puts("\nWeak password:")
    case Validator.validate(password_type, "weakpassword") do
      {:error, error} -> IO.puts("Error: #{error.message}")
      result -> IO.inspect(result)
    end

    IO.puts("")
  end

  defp value_transformation do
    IO.puts("3. Value Transformation")
    IO.puts("-----------------------")

    # Phone number normalization
    phone_type =
      Types.string()
      |> Types.with_validator(fn phone ->
        # Remove all non-digit characters
        digits = String.replace(phone, ~r/\D/, "")

        cond do
          String.length(digits) != 10 ->
            {:error, "Phone number must have exactly 10 digits"}

          true ->
            # Format as (XXX) XXX-XXXX
            formatted = String.replace(digits, ~r/(\d{3})(\d{3})(\d{4})/, "(\\1) \\2-\\3")
            {:ok, formatted}
        end
      end)

    IO.puts("Phone number normalization:")
    IO.inspect(Validator.validate(phone_type, "555-123-4567"))
    IO.inspect(Validator.validate(phone_type, "(555) 123 4567"))
    IO.inspect(Validator.validate(phone_type, "5551234567"))

    IO.puts("\nInvalid phone:")
    case Validator.validate(phone_type, "123-456") do
      {:error, error} -> IO.puts("Error: #{error.message}")
      result -> IO.inspect(result)
    end

    # Currency amount validation and normalization
    currency_type =
      Types.string()
      |> Types.with_validator(fn amount_str ->
        # Remove currency symbols and whitespace
        cleaned = String.replace(amount_str, ~r/[$,\s]/, "")

        case Float.parse(cleaned) do
          {amount, ""} when amount >= 0 ->
            {:ok, Float.round(amount, 2)}

          {_amount, ""} ->
            {:error, "Amount must be positive"}

          _ ->
            {:error, "Invalid currency format"}
        end
      end)

    IO.puts("\nCurrency validation and transformation:")
    IO.inspect(Validator.validate(currency_type, "$1,234.56"))
    IO.inspect(Validator.validate(currency_type, "99.99"))

    IO.puts("")
  end

  defp multiple_validators do
    IO.puts("4. Multiple Validators")
    IO.puts("----------------------")

    # Username with multiple validation rules
    username_type =
      Types.string()
      |> Types.with_constraints(min_length: 3, max_length: 20)
      |> Types.with_validator(fn username ->
        if String.match?(username, ~r/^[a-zA-Z0-9_]+$/),
          do: {:ok, username},
          else: {:error, "Username can only contain letters, numbers, and underscores"}
      end)
      |> Types.with_validator(fn username ->
        if String.match?(username, ~r/^[a-zA-Z]/),
          do: {:ok, username},
          else: {:error, "Username must start with a letter"}
      end)
      |> Types.with_validator(fn username ->
        reserved = ["admin", "root", "system", "null", "undefined"]

        if String.downcase(username) in reserved,
          do: {:error, "Username '#{username}' is reserved"},
          else: {:ok, username}
      end)

    IO.puts("Valid username:")
    IO.inspect(Validator.validate(username_type, "user123"))

    IO.puts("\nInvalid characters:")
    case Validator.validate(username_type, "user-123") do
      {:error, error} -> IO.puts("Error: #{error.message}")
      result -> IO.inspect(result)
    end

    IO.puts("\nMust start with letter:")
    case Validator.validate(username_type, "123user") do
      {:error, error} -> IO.puts("Error: #{error.message}")
      result -> IO.inspect(result)
    end

    IO.puts("\nReserved name:")
    case Validator.validate(username_type, "admin") do
      {:error, error} -> IO.puts("Error: #{error.message}")
      result -> IO.inspect(result)
    end

    IO.puts("")
  end

  defp complex_business_rules do
    IO.puts("5. Complex Business Rules")
    IO.puts("-------------------------")

    # Product SKU validation with complex business logic
    sku_type =
      Types.string()
      |> Types.with_constraints(min_length: 8, max_length: 12)
      |> Types.with_validator(fn sku ->
        # SKU format: ABC-1234-XY (3 letter category, 4 digit product ID, 2 letter variant)
        case String.split(sku, "-") do
          [category, product_id, variant] ->
            cond do
              not String.match?(category, ~r/^[A-Z]{3}$/) ->
                {:error, "Category must be 3 uppercase letters"}

              not String.match?(product_id, ~r/^[0-9]{4}$/) ->
                {:error, "Product ID must be 4 digits"}

              not String.match?(variant, ~r/^[A-Z]{2}$/) ->
                {:error, "Variant must be 2 uppercase letters"}

              category not in ["ELC", "PHX", "LIV", "OTP"] ->
                {:error, "Invalid category code"}

              true ->
                {:ok, sku}
            end

          _ ->
            {:error, "SKU must be in format: XXX-XXXX-XX"}
        end
      end)

    IO.puts("Valid SKU:")
    IO.inspect(Validator.validate(sku_type, "ELC-1234-AB"))

    IO.puts("\nInvalid format:")
    case Validator.validate(sku_type, "ELC12ABCD") do
      {:error, error} -> IO.puts("Error: #{error.message}")
      result -> IO.inspect(result)
    end

    IO.puts("\nInvalid category:")
    case Validator.validate(sku_type, "XXX-1234-AB") do
      {:error, error} -> IO.puts("Error: #{error.message}")
      result -> IO.inspect(result)
    end

    # Credit card validation (simplified Luhn algorithm)
    credit_card_type =
      Types.string()
      |> Types.with_validator(fn card_number ->
        # Remove spaces and dashes
        digits = String.replace(card_number, ~r/[\s-]/, "")

        cond do
          not String.match?(digits, ~r/^\d+$/) ->
            {:error, "Credit card number must contain only digits"}

          String.length(digits) < 13 or String.length(digits) > 19 ->
            {:error, "Credit card number must be between 13 and 19 digits"}

          not luhn_valid?(digits) ->
            {:error, "Invalid credit card number"}

          true ->
            # Mask all but last 4 digits
            masked = String.duplicate("*", String.length(digits) - 4) <> String.slice(digits, -4..-1)
            {:ok, masked}
        end
      end)

    IO.puts("\nCredit card validation (with masking):")
    # This is a test credit card number that passes Luhn validation
    IO.inspect(Validator.validate(credit_card_type, "4532-1234-5678-9012"))

    IO.puts("\nInvalid credit card:")
    case Validator.validate(credit_card_type, "1234-5678-9012-3456") do
      {:error, error} -> IO.puts("Error: #{error.message}")
      result -> IO.inspect(result)
    end

    IO.puts("")
  end

  # Simplified Luhn algorithm implementation
  defp luhn_valid?(digits) do
    digits
    |> String.reverse()
    |> String.graphemes()
    |> Enum.map(&String.to_integer/1)
    |> Enum.with_index()
    |> Enum.map(fn {digit, index} ->
      if rem(index, 2) == 1 do
        doubled = digit * 2
        if doubled > 9, do: doubled - 9, else: doubled
      else
        digit
      end
    end)
    |> Enum.sum()
    |> rem(10) == 0
  end
end

# Run the examples
CustomValidationExamples.run()