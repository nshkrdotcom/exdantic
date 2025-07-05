#!/usr/bin/env elixir

# Root Schema Examples
# Demonstrates comprehensive patterns for Root Schema validation in Exdantic

defmodule RootSchemaExamples do
  @moduledoc """
  Complete examples for Root Schema functionality in Exdantic.

  This module demonstrates:
  - Basic root schema validation for non-dictionary types
  - Array validation at root level
  - Single value validation with constraints
  - Union types at root level
  - Complex nested structures
  - Integration with other Exdantic features
  - JSON Schema generation for root schemas
  """

  # Example 1: Basic Array Validation
  defmodule TagListSchema do
    use Exdantic.RootSchema, root: {:array, :string}
  end

  defmodule NumberListSchema do
    use Exdantic.RootSchema, root: {:array, :integer}
  end

  # Example 2: Single Value with Constraints
  defmodule ScoreSchema do
    use Exdantic.RootSchema,
      root: {:type, :integer, [gteq: 0, lteq: 100]}
  end

  defmodule EmailSchema do
    use Exdantic.RootSchema,
      root: {:type, :string, [format: ~r/^[^\s@]+@[^\s@]+\.[^\s@]+$/]}
  end

  defmodule PortSchema do
    use Exdantic.RootSchema,
      root: {:type, :integer, [gteq: 1024, lteq: 65535]}
  end

  # Example 3: Union Types at Root Level
  defmodule IdSchema do
    use Exdantic.RootSchema, root: {:union, [:string, :integer]}
  end

  defmodule SentimentSchema do
    use Exdantic.RootSchema,
      root: {:type, :string, [choices: ["positive", "negative", "neutral"]]}
  end

  # Example 4: Complex Nested Structures
  defmodule NestedDataSchema do
    use Exdantic.RootSchema,
      root: {:map, {:string, {:array, :integer}}}
  end

  # Example 5: Root Schema with Complex Schema References
  defmodule UserSchema do
    use Exdantic

    schema do
      field :name, :string, required: true
      field :email, :string, required: true
      field :age, :integer, optional: true
    end
  end

  defmodule UserListSchema do
    use Exdantic.RootSchema, root: {:array, UserSchema}
  end

  defmodule ContactInfoSchema do
    use Exdantic

    schema do
      field :type, :string, choices: ["email", "phone", "address"]
      field :value, :string, required: true
      field :primary, :boolean, default: false
    end
  end

  defmodule ContactListSchema do
    use Exdantic.RootSchema, root: {:array, ContactInfoSchema}
  end

  # Example 6: Root Schema for LLM Outputs
  defmodule EntityExtractionSchema do
    use Exdantic.RootSchema,
      root: {:array, {:type, :string, [min_length: 1]}}
  end

  defmodule ClassificationResultSchema do
    use Exdantic.RootSchema,
      root: {:type, :string, [choices: ["spam", "ham", "unsure"]]}
  end

  defmodule ConfidenceScoreSchema do
    use Exdantic.RootSchema,
      root: {:type, :float, [gteq: 0.0, lteq: 1.0]}
  end

  # Example 7: Complex Business Logic Root Schema
  defmodule ProductCodeSchema do
    use Exdantic.RootSchema,
      root: {:type, :string, [format: ~r/^[A-Z]{2}-\d{4}-[A-Z]{1}$/]}
  end

  defmodule CurrencyAmountSchema do
    use Exdantic.RootSchema,
      root: {:type, :float, [gt: 0.0, lteq: 1_000_000.0]}
  end

  # Example 8: Flexible Data Structures
  defmodule FlexibleConfigSchema do
    use Exdantic.RootSchema,
      root: {:union, [
        :string,
        :integer,
        :boolean,
        {:array, :string},
        {:map, {:string, :any}}
      ]}
  end

  def run do
    IO.puts("=== Root Schema Examples ===\n")

    # Example 1: Basic Array Validation
    basic_array_validation()

    # Example 2: Single Value Validation
    single_value_validation()

    # Example 3: Union Types
    union_type_validation()

    # Example 4: Complex Nested Structures
    nested_structure_validation()

    # Example 5: Schema References
    schema_reference_validation()

    # Example 6: LLM Output Patterns
    llm_output_validation()

    # Example 7: Business Logic Validation
    business_logic_validation()

    # Example 8: JSON Schema Generation
    json_schema_generation()

    # Example 9: Integration with Enhanced Validator
    enhanced_validator_integration()

    # Example 10: Performance Comparison
    performance_comparison()

    IO.puts("\n=== Root Schema Examples Complete ===")
  end

  defp basic_array_validation do
    IO.puts("1. Basic Array Validation")
    IO.puts("-------------------------")

    # String array validation
    IO.puts("String array validation:")
    IO.puts("  ✅ Valid: [\"tag1\", \"tag2\", \"tag3\"]")
    case TagListSchema.validate(["tag1", "tag2", "tag3"]) do
      {:ok, result} -> IO.puts("     Result: #{inspect(result)}")
      {:error, errors} -> IO.puts("     Errors: #{inspect(errors)}")
    end

    IO.puts("  ❌ Invalid: [\"tag1\", 123, \"tag3\"]")
    case TagListSchema.validate(["tag1", 123, "tag3"]) do
      {:ok, result} -> IO.puts("     Result: #{inspect(result)}")
      {:error, errors} -> IO.puts("     Errors: #{inspect(errors)}")
    end

    # Integer array validation
    IO.puts("\nInteger array validation:")
    IO.puts("  ✅ Valid: [1, 2, 3, 4, 5]")
    case NumberListSchema.validate([1, 2, 3, 4, 5]) do
      {:ok, result} -> IO.puts("     Result: #{inspect(result)}")
      {:error, errors} -> IO.puts("     Errors: #{inspect(errors)}")
    end

    IO.puts("  ❌ Invalid: [1, \"two\", 3]")
    case NumberListSchema.validate([1, "two", 3]) do
      {:ok, result} -> IO.puts("     Result: #{inspect(result)}")
      {:error, errors} -> IO.puts("     Errors: #{inspect(errors)}")
    end

    IO.puts("")
  end

  defp single_value_validation do
    IO.puts("2. Single Value Validation with Constraints")
    IO.puts("-------------------------------------------")

    # Score validation
    IO.puts("Score validation (0-100):")
    IO.puts("  ✅ Valid: 85")
    case ScoreSchema.validate(85) do
      {:ok, result} -> IO.puts("     Result: #{inspect(result)}")
      {:error, errors} -> IO.puts("     Errors: #{inspect(errors)}")
    end

    IO.puts("  ❌ Invalid: 150 (out of range)")
    case ScoreSchema.validate(150) do
      {:ok, result} -> IO.puts("     Result: #{inspect(result)}")
      {:error, errors} -> IO.puts("     Errors: #{inspect(errors)}")
    end

    # Email validation
    IO.puts("\nEmail validation:")
    IO.puts("  ✅ Valid: \"user@example.com\"")
    case EmailSchema.validate("user@example.com") do
      {:ok, result} -> IO.puts("     Result: #{inspect(result)}")
      {:error, errors} -> IO.puts("     Errors: #{inspect(errors)}")
    end

    IO.puts("  ❌ Invalid: \"invalid-email\"")
    case EmailSchema.validate("invalid-email") do
      {:ok, result} -> IO.puts("     Result: #{inspect(result)}")
      {:error, errors} -> IO.puts("     Errors: #{inspect(errors)}")
    end

    # Port validation
    IO.puts("\nPort validation (1024-65535):")
    IO.puts("  ✅ Valid: 8080")
    case PortSchema.validate(8080) do
      {:ok, result} -> IO.puts("     Result: #{inspect(result)}")
      {:error, errors} -> IO.puts("     Errors: #{inspect(errors)}")
    end

    IO.puts("  ❌ Invalid: 80 (below minimum)")
    case PortSchema.validate(80) do
      {:ok, result} -> IO.puts("     Result: #{inspect(result)}")
      {:error, errors} -> IO.puts("     Errors: #{inspect(errors)}")
    end

    IO.puts("")
  end

  defp union_type_validation do
    IO.puts("3. Union Type Validation")
    IO.puts("------------------------")

    # ID validation (string or integer)
    IO.puts("ID validation (string OR integer):")
    IO.puts("  ✅ Valid string: \"user_123\"")
    case IdSchema.validate("user_123") do
      {:ok, result} -> IO.puts("     Result: #{inspect(result)}")
      {:error, errors} -> IO.puts("     Errors: #{inspect(errors)}")
    end

    IO.puts("  ✅ Valid integer: 456")
    case IdSchema.validate(456) do
      {:ok, result} -> IO.puts("     Result: #{inspect(result)}")
      {:error, errors} -> IO.puts("     Errors: #{inspect(errors)}")
    end

    IO.puts("  ❌ Invalid: 3.14 (float not allowed)")
    case IdSchema.validate(3.14) do
      {:ok, result} -> IO.puts("     Result: #{inspect(result)}")
      {:error, errors} -> IO.puts("     Errors: #{inspect(errors)}")
    end

    # Sentiment validation
    IO.puts("\nSentiment validation (choices):")
    IO.puts("  ✅ Valid: \"positive\"")
    case SentimentSchema.validate("positive") do
      {:ok, result} -> IO.puts("     Result: #{inspect(result)}")
      {:error, errors} -> IO.puts("     Errors: #{inspect(errors)}")
    end

    IO.puts("  ❌ Invalid: \"happy\" (not in choices)")
    case SentimentSchema.validate("happy") do
      {:ok, result} -> IO.puts("     Result: #{inspect(result)}")
      {:error, errors} -> IO.puts("     Errors: #{inspect(errors)}")
    end

    IO.puts("")
  end

  defp nested_structure_validation do
    IO.puts("4. Complex Nested Structure Validation")
    IO.puts("---------------------------------------")

    # Nested map validation
    IO.puts("Nested map validation (string keys → array of integers):")
    valid_data = %{
      "scores" => [200, 150, 180],
      "grades" => [190, 160, 170],
      "ratings" => [4, 5, 3]
    }

    IO.puts("  ✅ Valid: #{inspect(valid_data)}")
    case NestedDataSchema.validate(valid_data) do
      {:ok, result} -> IO.puts("     Result: #{inspect(result)}")
      {:error, errors} -> IO.puts("     Errors: #{inspect(errors)}")
    end

    invalid_data = %{
      "scores" => [200, "ninety", 180],  # Mixed types in array
      "grades" => [190, 160, 170]
    }

    IO.puts("  ❌ Invalid: #{inspect(invalid_data)}")
    case NestedDataSchema.validate(invalid_data) do
      {:ok, result} -> IO.puts("     Result: #{inspect(result)}")
      {:error, errors} -> IO.puts("     Errors: #{inspect(errors)}")
    end

    IO.puts("")
  end

  defp schema_reference_validation do
    IO.puts("5. Schema Reference Validation")
    IO.puts("------------------------------")

    # User list validation
    users = [
      %{name: "John Doe", email: "john@example.com", age: 30},
      %{name: "Jane Smith", email: "jane@example.com"}
    ]

    IO.puts("User list validation:")
    IO.puts("  ✅ Valid: #{inspect(users)}")
    case UserListSchema.validate(users) do
      {:ok, result} -> IO.puts("     Result: #{inspect(result)}")
      {:error, errors} -> IO.puts("     Errors: #{inspect(errors)}")
    end

    invalid_users = [
      %{name: "John Doe", email: "john@example.com"},
      %{name: "Invalid User"}  # Missing email
    ]

    IO.puts("  ❌ Invalid: #{inspect(invalid_users)}")
    case UserListSchema.validate(invalid_users) do
      {:ok, result} -> IO.puts("     Result: #{inspect(result)}")
      {:error, errors} -> IO.puts("     Errors: #{inspect(errors)}")
    end

    # Contact list validation
    contacts = [
      %{type: "email", value: "john@example.com", primary: true},
      %{type: "phone", value: "+1-555-0123", primary: false}
    ]

    IO.puts("\nContact list validation:")
    IO.puts("  ✅ Valid: #{inspect(contacts)}")
    case ContactListSchema.validate(contacts) do
      {:ok, result} -> IO.puts("     Result: #{inspect(result)}")
      {:error, errors} -> IO.puts("     Errors: #{inspect(errors)}")
    end

    IO.puts("")
  end

  defp llm_output_validation do
    IO.puts("6. LLM Output Validation Patterns")
    IO.puts("----------------------------------")

    # Entity extraction
    IO.puts("Entity extraction validation:")
    entities = ["Apple Inc.", "Microsoft Corporation", "Google LLC"]
    IO.puts("  ✅ Valid: #{inspect(entities)}")
    case EntityExtractionSchema.validate(entities) do
      {:ok, result} -> IO.puts("     Result: #{inspect(result)}")
      {:error, errors} -> IO.puts("     Errors: #{inspect(errors)}")
    end

    invalid_entities = ["Apple Inc.", "", "Google LLC"]  # Empty string
    IO.puts("  ❌ Invalid: #{inspect(invalid_entities)}")
    case EntityExtractionSchema.validate(invalid_entities) do
      {:ok, result} -> IO.puts("     Result: #{inspect(result)}")
      {:error, errors} -> IO.puts("     Errors: #{inspect(errors)}")
    end

    # Classification result
    IO.puts("\nClassification result validation:")
    IO.puts("  ✅ Valid: \"spam\"")
    case ClassificationResultSchema.validate("spam") do
      {:ok, result} -> IO.puts("     Result: #{inspect(result)}")
      {:error, errors} -> IO.puts("     Errors: #{inspect(errors)}")
    end

    IO.puts("  ❌ Invalid: \"junk\" (not in choices)")
    case ClassificationResultSchema.validate("junk") do
      {:ok, result} -> IO.puts("     Result: #{inspect(result)}")
      {:error, errors} -> IO.puts("     Errors: #{inspect(errors)}")
    end

    # Confidence score
    IO.puts("\nConfidence score validation:")
    IO.puts("  ✅ Valid: 0.85")
    case ConfidenceScoreSchema.validate(0.85) do
      {:ok, result} -> IO.puts("     Result: #{inspect(result)}")
      {:error, errors} -> IO.puts("     Errors: #{inspect(errors)}")
    end

    IO.puts("  ❌ Invalid: 1.5 (out of range)")
    case ConfidenceScoreSchema.validate(1.5) do
      {:ok, result} -> IO.puts("     Result: #{inspect(result)}")
      {:error, errors} -> IO.puts("     Errors: #{inspect(errors)}")
    end

    IO.puts("")
  end

  defp business_logic_validation do
    IO.puts("7. Business Logic Validation")
    IO.puts("----------------------------")

    # Product code validation
    IO.puts("Product code validation (format: XX-9999-X):")
    IO.puts("  ✅ Valid: \"AB-1234-C\"")
    case ProductCodeSchema.validate("AB-1234-C") do
      {:ok, result} -> IO.puts("     Result: #{inspect(result)}")
      {:error, errors} -> IO.puts("     Errors: #{inspect(errors)}")
    end

    IO.puts("  ❌ Invalid: \"invalid-format\"")
    case ProductCodeSchema.validate("invalid-format") do
      {:ok, result} -> IO.puts("     Result: #{inspect(result)}")
      {:error, errors} -> IO.puts("     Errors: #{inspect(errors)}")
    end

    # Currency amount validation
    IO.puts("\nCurrency amount validation (0 < amount <= 1,000,000):")
    IO.puts("  ✅ Valid: 1500.50")
    case CurrencyAmountSchema.validate(1500.50) do
      {:ok, result} -> IO.puts("     Result: #{inspect(result)}")
      {:error, errors} -> IO.puts("     Errors: #{inspect(errors)}")
    end

    IO.puts("  ❌ Invalid: 0.0 (must be greater than 0)")
    case CurrencyAmountSchema.validate(0.0) do
      {:ok, result} -> IO.puts("     Result: #{inspect(result)}")
      {:error, errors} -> IO.puts("     Errors: #{inspect(errors)}")
    end

    IO.puts("")
  end

  defp json_schema_generation do
    IO.puts("8. JSON Schema Generation")
    IO.puts("-------------------------")

    # Generate JSON schemas for different root types
    IO.puts("Generated JSON Schemas:")

    # Array schema
    array_schema = TagListSchema.json_schema()
    IO.puts("  Array schema: #{inspect(array_schema)}")

    # Single value with constraints
    score_schema = ScoreSchema.json_schema()
    IO.puts("  Score schema: #{inspect(score_schema)}")

    # Union schema
    id_schema = IdSchema.json_schema()
    IO.puts("  ID schema: #{inspect(id_schema)}")

    # Complex nested schema
    nested_schema = NestedDataSchema.json_schema()
    IO.puts("  Nested schema: #{inspect(nested_schema)}")

    # Schema with references
    user_list_schema = UserListSchema.json_schema()
    IO.puts("  User list schema: #{inspect(user_list_schema)}")

    IO.puts("")
  end

  defp enhanced_validator_integration do
    IO.puts("9. Enhanced Validator Integration")
    IO.puts("---------------------------------")

    IO.puts("Root Schemas vs Enhanced Validator comparison:")
    IO.puts("(Root Schemas validate non-dictionary data directly)")

    # Show that Root Schemas work directly
    IO.puts("  Root Schema direct validation:")
    string_numbers = ["1", "2", "3", "4", "5"]
    IO.puts("    Input: #{inspect(string_numbers)}")
    case TagListSchema.validate(string_numbers) do
      {:ok, result} -> IO.puts("    ✅ Root Schema result: #{inspect(result)}")
      {:error, errors} -> IO.puts("    ❌ Root Schema errors: #{inspect(errors)}")
    end

    # Show TypeAdapter for coercion instead
    IO.puts("  TypeAdapter with coercion (equivalent functionality):")
    adapter = Exdantic.TypeAdapter.create({:array, :integer}, coerce: true)
    numeric_strings = ["1", "2", "3", "4", "5"]
    IO.puts("    Input: #{inspect(numeric_strings)}")
    case Exdantic.TypeAdapter.Instance.validate(adapter, numeric_strings) do
      {:ok, result} -> IO.puts("    ✅ TypeAdapter coerced result: #{inspect(result)}")
      {:error, errors} -> IO.puts("    ❌ TypeAdapter errors: #{inspect(errors)}")
    end

    IO.puts("    Note: Root Schemas and Enhanced Validator serve different purposes:")
    IO.puts("    - Root Schemas: Direct validation of non-dictionary data")
    IO.puts("    - Enhanced Validator: Schema-based validation with advanced features")
    IO.puts("    - TypeAdapter: Type validation with coercion support")

    IO.puts("")
  end

  defp performance_comparison do
    IO.puts("10. Performance Comparison")
    IO.puts("--------------------------")

    # Compare root schema vs regular schema performance
    data = ["tag1", "tag2", "tag3", "tag4", "tag5"]
    iterations = 1000

    # Root schema performance
    {root_time, _} = :timer.tc(fn ->
      for _ <- 1..iterations do
        TagListSchema.validate(data)
      end
    end)

    # TypeAdapter performance (equivalent functionality)
    adapter = Exdantic.TypeAdapter.create({:array, :string})
    {adapter_time, _} = :timer.tc(fn ->
      for _ <- 1..iterations do
        Exdantic.TypeAdapter.Instance.validate(adapter, data)
      end
    end)

    IO.puts("Performance comparison (#{iterations} iterations):")
    IO.puts("  Root Schema: #{root_time / 1000} ms")
    IO.puts("  TypeAdapter: #{adapter_time / 1000} ms")
    IO.puts("  Difference: #{abs(root_time - adapter_time) / 1000} ms")

    IO.puts("")
  end
end

# Run the examples
RootSchemaExamples.run()
