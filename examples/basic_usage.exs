# Basic Usage Examples for Exdantic

# This file demonstrates the fundamental features of Exdantic
# Run with: `mix run examples/basic_usage.exs`

# Compile and load the Exdantic modules
Mix.Task.run("compile")

defmodule BasicUsageExamples do
  alias Exdantic.Types
  alias Exdantic.Validator

  def run do
    IO.puts("=== Basic Exdantic Usage Examples ===\n")

    # 1. Basic Type Validation
    basic_types()

    # 2. Type Constraints
    type_constraints()

    # 3. Complex Types
    complex_types()

    # 4. Custom Error Messages
    custom_error_messages()

    # 5. Object Types (Fixed-Key Maps)
    object_types()
  end

  defp basic_types do
    IO.puts("1. Basic Type Validation")
    IO.puts("------------------------")

    # String validation
    string_type = Types.string()
    IO.puts("String validation:")
    IO.puts("  ✅ Valid: \"Hello\"")
    IO.inspect(Validator.validate(string_type, "Hello"), label: "     Result")
    IO.puts("  ❌ Invalid: 123")
    IO.inspect(Validator.validate(string_type, 123), label: "     Result")

    # Integer validation
    integer_type = Types.integer()
    IO.puts("\nInteger validation:")
    IO.puts("  ✅ Valid: 42")
    IO.inspect(Validator.validate(integer_type, 42), label: "     Result")
    IO.puts("  ❌ Invalid: \"not a number\"")
    IO.inspect(Validator.validate(integer_type, "not a number"), label: "     Result")

    # Boolean validation
    boolean_type = Types.boolean()
    IO.puts("\nBoolean validation:")
    IO.puts("  ✅ Valid: true")
    IO.inspect(Validator.validate(boolean_type, true), label: "     Result")
    IO.puts("  ❌ Invalid: \"yes\"")
    IO.inspect(Validator.validate(boolean_type, "yes"), label: "     Result")

    # Atom validation
    atom_type = Types.type(:atom)
    IO.puts("\nAtom validation:")
    IO.puts("  ✅ Valid: :active")
    IO.inspect(Validator.validate(atom_type, :active), label: "     Result")
    IO.puts("  ❌ Invalid: \"not_atom\"")
    IO.inspect(Validator.validate(atom_type, "not_atom"), label: "     Result")

    IO.puts("")
  end

  defp type_constraints do
    IO.puts("2. Type Constraints")
    IO.puts("-------------------")

    # String constraints
    name_type =
      Types.string()
      |> Types.with_constraints(min_length: 2, max_length: 50)

    IO.puts("String with length constraints (min: 2, max: 50):")
    IO.puts("  ✅ Valid: \"John\"")
    IO.inspect(Validator.validate(name_type, "John"), label: "     Result")
    IO.puts("  ❌ Too short: \"J\"")
    IO.inspect(Validator.validate(name_type, "J"), label: "     Result")
    IO.puts("  ❌ Too long: (51 characters)")
    IO.inspect(Validator.validate(name_type, String.duplicate("A", 51)), label: "     Result")

    # Integer constraints
    age_type =
      Types.integer()
      |> Types.with_constraints(gt: 0, lt: 150)

    IO.puts("\nInteger with range constraints (0 < age < 150):")
    IO.puts("  ✅ Valid: 25")
    IO.inspect(Validator.validate(age_type, 25), label: "     Result")
    IO.puts("  ❌ Too low: -5")
    IO.inspect(Validator.validate(age_type, -5), label: "     Result")
    IO.puts("  ❌ Too high: 200")
    IO.inspect(Validator.validate(age_type, 200), label: "     Result")

    # Choices constraint
    status_type =
      Types.type(:atom)
      |> Types.with_constraints(choices: [:active, :inactive, :pending])

    IO.puts("\nAtom with choices constraint:")
    IO.puts("  ✅ Valid: :active")
    IO.inspect(Validator.validate(status_type, :active), label: "     Result")
    IO.puts("  ❌ Invalid choice: :unknown")
    IO.inspect(Validator.validate(status_type, :unknown), label: "     Result")

    IO.puts("")
  end

  defp complex_types do
    IO.puts("3. Complex Types")
    IO.puts("----------------")

    # Array of strings
    tags_type = Types.array(Types.string())
    IO.puts("Array of strings:")
    IO.puts("  ✅ Valid: [\"elixir\", \"phoenix\", \"liveview\"]")
    IO.inspect(Validator.validate(tags_type, ["elixir", "phoenix", "liveview"]), label: "     Result")
    IO.puts("  ❌ Mixed types: [\"valid\", 123, \"mixed\"]")
    IO.inspect(Validator.validate(tags_type, ["valid", 123, "mixed"]), label: "     Result")

    # Array with constraints
    limited_tags_type =
      Types.array(Types.string())
      |> Types.with_constraints(min_items: 1, max_items: 5)

    IO.puts("\nArray with constraints (min: 1, max: 5 items):")
    IO.puts("  ✅ Valid: [\"elixir\"]")
    IO.inspect(Validator.validate(limited_tags_type, ["elixir"]), label: "     Result")
    IO.puts("  ❌ Empty array: []")
    IO.inspect(Validator.validate(limited_tags_type, []), label: "     Result")

    # Union types
    id_type = Types.union([Types.string(), Types.integer()])
    IO.puts("\nUnion type (string OR integer):")
    IO.puts("  ✅ Valid string: \"user-123\"")
    IO.inspect(Validator.validate(id_type, "user-123"), label: "     Result")
    IO.puts("  ✅ Valid integer: 456")
    IO.inspect(Validator.validate(id_type, 456), label: "     Result")
    IO.puts("  ❌ Invalid type: true (boolean)")
    IO.inspect(Validator.validate(id_type, true), label: "     Result")

    # Map types
    settings_type = Types.map(Types.string(), Types.boolean())
    IO.puts("\nMap type (string keys → boolean values):")
    IO.puts("  ✅ Valid: %{\"notifications\" => true, \"dark_mode\" => false}")
    IO.inspect(Validator.validate(settings_type, %{"notifications" => true, "dark_mode" => false}), label: "     Result")
    IO.puts("  ❌ Wrong value type: %{\"setting\" => \"invalid\"}")
    IO.inspect(Validator.validate(settings_type, %{"setting" => "invalid"}), label: "     Result")

    IO.puts("")
  end

  defp custom_error_messages do
    IO.puts("4. Custom Error Messages")
    IO.puts("------------------------")

    # Single custom error message
    name_type =
      Types.string()
      |> Types.with_constraints(min_length: 3)
      |> Types.with_error_message(:min_length, "Name must be at least 3 characters long")

    IO.puts("Single custom error message:")
    IO.puts("  ❌ Input: \"Jo\" (too short)")
    case Validator.validate(name_type, "Jo") do
      {:error, error} -> IO.puts("     Error: #{error.message}")
      result -> IO.inspect(result, label: "     Result")
    end

    # Multiple custom error messages
    password_type =
      Types.string()
      |> Types.with_constraints(min_length: 8, max_length: 100)
      |> Types.with_error_messages(%{
        min_length: "Password must be at least 8 characters long",
        max_length: "Password cannot exceed 100 characters"
      })

    IO.puts("\nMultiple custom error messages:")
    IO.puts("  ❌ Input: \"123\" (too short)")
    case Validator.validate(password_type, "123") do
      {:error, error} -> IO.puts("     Error: #{error.message}")
      result -> IO.inspect(result, label: "     Result")
    end

    IO.puts("  ❌ Input: (101 characters - too long)")
    case Validator.validate(password_type, String.duplicate("a", 101)) do
      {:error, error} -> IO.puts("     Error: #{error.message}")
      result -> IO.inspect(result, label: "     Result")
    end

    IO.puts("")
  end

  defp object_types do
    IO.puts("5. Object Types (Fixed-Key Maps)")
    IO.puts("--------------------------------")

    # Simple object
    user_type =
      Types.object(%{
        name: Types.string(),
        age: Types.integer(),
        active: Types.boolean()
      })

    IO.puts("Simple object validation:")
    valid_user = %{name: "Alice", age: 30, active: true}
    IO.puts("  ✅ Valid: #{inspect(valid_user)}")
    IO.inspect(Validator.validate(user_type, valid_user), label: "     Result")

    invalid_user = %{name: "Bob", age: "thirty", active: true}
    IO.puts("  ❌ Invalid: #{inspect(invalid_user)} (age should be integer)")
    case Validator.validate(user_type, invalid_user) do
      {:error, [error]} -> IO.puts("     Error at #{inspect(error.path)}: #{error.message}")
      result -> IO.inspect(result, label: "     Result")
    end

    # Nested object
    address_type =
      Types.object(%{
        street: Types.string(),
        city: Types.string(),
        zip: Types.integer()
      })

    person_type =
      Types.object(%{
        name: Types.string(),
        address: address_type
      })

    IO.puts("\nNested object validation:")
    valid_person = %{
      name: "Charlie",
      address: %{street: "123 Main St", city: "Springfield", zip: 12345}
    }
    IO.puts("  ✅ Valid nested object:")
    IO.inspect(Validator.validate(person_type, valid_person), label: "     Result")

    invalid_person = %{
      name: "David",
      address: %{street: "456 Oak Ave", city: "Springfield", zip: "invalid"}
    }
    IO.puts("  ❌ Invalid nested object (zip should be integer):")
    case Validator.validate(person_type, invalid_person) do
      {:error, [error]} -> IO.puts("     Error at #{inspect(error.path)}: #{error.message}")
      result -> IO.inspect(result, label: "     Result")
    end

    IO.puts("")
  end
end

# Run the examples
BasicUsageExamples.run()