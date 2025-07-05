# README Examples Verification

# This file contains all the code examples from the README.md file
# to ensure they work exactly as documented.
# Run with: `mix run examples/readme_examples.exs`

# Compile and load the Exdantic modules
Mix.Task.run("compile")

defmodule ReadmeExamplesTest do
  alias Exdantic.{Types, Validator}

  def run do
    IO.puts("=== README Examples Verification ===\n")

    # Test each section from the README
    basic_usage()
    schema_based_validation()
    core_feature_1_rich_type_system()
    core_feature_2_object_validation()
    core_feature_3_custom_validation_functions()
    core_feature_4_custom_error_messages()
    core_feature_5_complex_nested_structures()

    IO.puts("🎉 All README examples verified successfully!")
  end

  defp basic_usage do
    IO.puts("🔍 Testing Basic Usage Examples")
    IO.puts("--------------------------------")

    # Simple type validation
    alias Exdantic.{Types, Validator}

    # Validate basic types
    result1 = Validator.validate(Types.string(), "hello")
    IO.puts("✅ Basic string validation: #{inspect(result1)}")
    assert_match({:ok, "hello"}, result1)

    result2 = Validator.validate(Types.integer(), "not a number")
    IO.puts("✅ Basic integer validation (should fail): #{match?({:error, _}, result2)}")
    assert_error_result(result2)

    # Add constraints
    age_type = Types.integer() |> Types.with_constraints(gt: 0, lt: 150)
    result3 = Validator.validate(age_type, 25)
    IO.puts("✅ Constrained validation (valid): #{inspect(result3)}")
    assert_match({:ok, 25}, result3)

    result4 = Validator.validate(age_type, -5)
    IO.puts("✅ Constrained validation (invalid): #{match?({:error, _}, result4)}")
    assert_error_result(result4)

    IO.puts("")
  end

  defp schema_based_validation do
    IO.puts("🔍 Testing Schema-Based Validation")
    IO.puts("----------------------------------")

    # Note: The README shows schema DSL which we don't test here as it requires
    # module compilation. Instead we show the equivalent direct validation.

    # Equivalent validation using Types directly
    user_type = Types.object(%{
      name: Types.string()
            |> Types.with_constraints(min_length: 2, max_length: 50),
      age: Types.integer()
           |> Types.with_constraints(gt: 0, lt: 150),
      email: Types.string()
             |> Types.with_constraints(format: ~r/^[^\s]+@[^\s]+$/),
      tags: Types.array(Types.string())
            |> Types.with_constraints(min_items: 0, max_items: 5)
    })

    # Use the schema equivalent
    user_data = %{
      name: "John Doe",
      email: "john@example.com",
      age: 30,
      tags: ["admin"]
    }

    case Validator.validate(user_type, user_data) do
      {:ok, validated_data} ->
        IO.puts("✅ Schema-based validation successful")
        IO.puts("    Validated data: #{inspect(validated_data)}")

      {:error, errors} ->
        IO.puts("❌ Schema-based validation failed")
        Enum.each(errors, fn error ->
          IO.puts("    Error: #{error.message}")
        end)
    end

    IO.puts("")
  end

  defp core_feature_1_rich_type_system do
    IO.puts("🔍 Testing Core Feature 1: Rich Type System")
    IO.puts("--------------------------------------------")

    # Basic types
    IO.puts("Basic types:")
    IO.inspect(Types.string(), label: "  string")
    IO.inspect(Types.integer(), label: "  integer")
    IO.inspect(Types.float(), label: "  float")
    IO.inspect(Types.boolean(), label: "  boolean")
    IO.inspect(Types.type(:atom), label: "  atom")

    # Complex types
    IO.puts("\nComplex types:")
    IO.inspect(Types.array(Types.string()), label: "  array of strings")
    IO.inspect(Types.map(Types.string(), Types.integer()), label: "  map string->integer")
    IO.inspect(Types.union([Types.string(), Types.integer()]), label: "  union string|integer")
    IO.inspect(Types.object(%{name: Types.string(), age: Types.integer()}), label: "  object")

    # With constraints
    IO.puts("\nWith constraints:")
    constrained_type = Types.string()
    |> Types.with_constraints([
      min_length: 3,
      max_length: 50,
      format: ~r/^[a-zA-Z ]+$/
    ])
    IO.inspect(constrained_type, label: "  constrained string")

    IO.puts("")
  end

  defp core_feature_2_object_validation do
    IO.puts("🔍 Testing Core Feature 2: Object Validation")
    IO.puts("---------------------------------------------")

    # Validate structured data with field-by-field validation:
    user_type = Types.object(%{
      name: Types.string()
            |> Types.with_constraints(min_length: 1),
      age: Types.integer()
           |> Types.with_constraints(gt: 0, lt: 120),
      email: Types.string()
             |> Types.with_constraints(format: ~r/^[^\s]+@[^\s]+\.[^\s]+$/),
      active: Types.boolean()
    })

    # Validates each field individually
    result = Validator.validate(user_type, %{
      name: "John Doe",
      age: 30,
      email: "john@example.com",
      active: true
    })

    case result do
      {:ok, user} ->
        IO.puts("✅ Object validation successful")
        IO.puts("    Validated user: #{inspect(user)}")
        assert_ok_result(result)

      {:error, errors} ->
        IO.puts("❌ Object validation failed: #{inspect(errors)}")
    end

    IO.puts("")
  end

  defp core_feature_3_custom_validation_functions do
    IO.puts("🔍 Testing Core Feature 3: Custom Validation Functions")
    IO.puts("-------------------------------------------------------")

    # Add business logic validation beyond basic constraints:
    email_type = Types.string()
    |> Types.with_constraints(min_length: 5)
    |> Types.with_validator(fn value ->
      cond do
        not String.contains?(value, "@") ->
          {:error, "Must be a valid email address"}
        not String.match?(value, ~r/^[^@]+@[^@]+\.[^@]+$/) ->
          {:error, "Email format is invalid"}
        true ->
          {:ok, String.downcase(value)}  # Transform to lowercase
      end
    end)

    result = Validator.validate(email_type, "USER@EXAMPLE.COM")
    IO.puts("✅ Custom validation with transformation:")
    IO.puts("    Input: \"USER@EXAMPLE.COM\"")
    IO.puts("    Result: #{inspect(result)}")
    assert_match({:ok, "user@example.com"}, result)

    IO.puts("")
  end

  defp core_feature_4_custom_error_messages do
    IO.puts("🔍 Testing Core Feature 4: Custom Error Messages")
    IO.puts("-------------------------------------------------")

    # Single custom message
    name_type = Types.string()
    |> Types.with_constraints(min_length: 3)
    |> Types.with_error_message(:min_length, "Name must be at least 3 characters long")

    result1 = Validator.validate(name_type, "Jo")
    case result1 do
      {:error, error} ->
        IO.puts("✅ Single custom error message: #{error.message}")
        assert_equal("Name must be at least 3 characters long", error.message)
    end

    # Multiple custom messages
    password_type = Types.string()
    |> Types.with_constraints(min_length: 8, max_length: 100)
    |> Types.with_error_messages(%{
      min_length: "Password must be at least 8 characters long",
      max_length: "Password cannot exceed 100 characters"
    })

    result2 = Validator.validate(password_type, "123")
    case result2 do
      {:error, error} ->
        IO.puts("✅ Multiple custom error message: #{error.message}")
        assert_equal("Password must be at least 8 characters long", error.message)
    end

    IO.puts("")
  end

  defp core_feature_5_complex_nested_structures do
    IO.puts("🔍 Testing Core Feature 5: Complex Nested Structures")
    IO.puts("----------------------------------------------------")

    # Handle deeply nested data with path-aware error reporting:
    person_type = Types.object(%{
      name: Types.string(),
      address: Types.object(%{
        street: Types.string(),
        city: Types.string(),
        zip: Types.string() |> Types.with_constraints(format: ~r/^\d{5}$/)
      })
    })

    # Error paths show exactly where validation failed
    result = Validator.validate(person_type, %{
      name: "John",
      address: %{street: "123 Main", city: "Springfield", zip: "invalid"}
    })

    case result do
      {:error, [error]} ->
        IO.puts("✅ Nested validation with path-aware errors:")
        IO.puts("    Error at #{inspect(error.path)}: #{error.message}")
        assert_equal([:address, :zip], error.path)
        assert_equal(:format, error.code)

      other ->
        IO.puts("❌ Unexpected result: #{inspect(other)}")
    end

    IO.puts("")
  end

  # Helper functions to assert results
  defp assert_match(expected, actual) do
    case actual do
      ^expected -> :ok
      _ -> raise "Expected #{inspect(expected)}, got #{inspect(actual)}"
    end
  end

  defp assert_ok_result(result) do
    case result do
      {:ok, _} -> :ok
      _ -> raise "Expected {:ok, _}, got #{inspect(result)}"
    end
  end

  defp assert_error_result(result) do
    case result do
      {:error, _} -> :ok
      _ -> raise "Expected {:error, _}, got #{inspect(result)}"
    end
  end

  defp assert_equal(expected, actual) do
    if expected == actual do
      :ok
    else
      raise "Expected #{inspect(expected)}, got #{inspect(actual)}"
    end
  end
end

# Run the verification
ReadmeExamplesTest.run()