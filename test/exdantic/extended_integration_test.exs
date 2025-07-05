defmodule Exdantic.ExtendedIntegrationTest do
  use ExUnit.Case, async: true

  alias Exdantic.{Config, EnhancedValidator, Runtime, TypeAdapter, Wrapper}
  alias Exdantic.JsonSchema.Resolver

  describe "runtime schema with TypeAdapter validation" do
    test "runtime schema works with TypeAdapter for complex types" do
      # Create runtime schema with complex types
      fields = [
        {:user_data, {:map, {:string, :any}}, [required: true]},
        {:scores, {:array, :integer}, [min_items: 1, max_items: 10]},
        {:status, {:union, [:string, :integer]}, [required: true]}
      ]

      schema = Runtime.create_schema(fields, title: "Complex Data Schema")

      # Validate using runtime schema
      data = %{
        user_data: %{"name" => "John", "age" => 30},
        scores: [85, 92, 78],
        status: "active"
      }

      assert {:ok, validated} = Runtime.validate(data, schema)
      assert validated.user_data["name"] == "John"
      assert length(validated.scores) == 3
      assert validated.status == "active"

      # Also validate individual fields using TypeAdapter
      assert {:ok, _} = TypeAdapter.validate({:map, {:string, :any}}, data.user_data)
      assert {:ok, _} = TypeAdapter.validate({:array, :integer}, data.scores)
      assert {:ok, _} = TypeAdapter.validate({:union, [:string, :integer]}, data.status)
    end

    test "runtime schema with TypeAdapter coercion" do
      fields = [
        {:count, :integer, [required: true]},
        {:percentage, :float, [required: true]}
      ]

      schema = Runtime.create_schema(fields)

      # Data that needs coercion
      string_data = %{count: "42", percentage: "85.5"}

      # Runtime validation with coercion via EnhancedValidator
      config = Config.create(coercion: :safe)
      assert {:ok, validated} = EnhancedValidator.validate(schema, string_data, config: config)

      assert validated.count == 42
      assert validated.percentage == 85.5
    end
  end

  describe "complex DSPy pattern simulation" do
    test "simulates DSPy create_model pattern" do
      # Simulate: pydantic.create_model("DSPyProgramOutputs", **fields)
      fields = [
        {:thought, :string, [description: "Chain of thought reasoning"]},
        {:answer, :string, [description: "Final answer"]},
        {:confidence, :float, [gt: 0.0, lteq: 1.0, description: "Confidence score"]},
        {:sources, {:array, :string}, [description: "Information sources"]}
      ]

      schema =
        Runtime.create_schema(fields,
          title: "DSPyProgramOutputs",
          description: "Output schema for DSPy program"
        )

      # Test with valid data
      output_data = %{
        thought: "To answer this question, I need to consider...",
        answer: "The answer is 42",
        confidence: 0.95,
        sources: ["source1.txt", "source2.txt"]
      }

      assert {:ok, validated} = Runtime.validate(output_data, schema)
      assert validated.thought == "To answer this question, I need to consider..."
      assert validated.confidence == 0.95
      assert length(validated.sources) == 2
    end

    test "simulates DSPy TypeAdapter pattern" do
      # Simulate: TypeAdapter(type(value)).validate_python(value)
      test_cases = [
        {:string, "hello world"},
        {{:array, :integer}, [1, 2, 3, 4, 5]},
        {{:map, {:string, :any}}, %{"key1" => "value1", "key2" => 42}},
        {{:union, [:string, :integer]}, "string_value"},
        {{:union, [:string, :integer]}, 42}
      ]

      for {type_spec, value} <- test_cases do
        assert {:ok, validated} = TypeAdapter.validate(type_spec, value)
        assert validated == value
      end
    end

    test "simulates DSPy wrapper model pattern" do
      # Simulate: create_model("Wrapper", value=(target_type, ...))
      wrapper_cases = [
        {:result, :integer, 42, []},
        {:email, :string, "user@example.com", [format: ~r/@/]},
        {:items, {:array, :string}, ["a", "b", "c"], [min_items: 1]},
        {:score, :float, 85.5, [gteq: 0.0, lteq: 100.0]}
      ]

      for {field_name, type_spec, value, constraints} <- wrapper_cases do
        assert {:ok, validated} =
                 Wrapper.wrap_and_validate(
                   field_name,
                   type_spec,
                   value,
                   constraints: constraints
                 )

        assert validated == value
      end
    end

    test "simulates DSPy config modification pattern" do
      # Simulate: ConfigDict(extra="forbid", frozen=True)
      base_config = Config.create()

      # Apply DSPy-style configuration
      dspy_config =
        Config.merge(base_config, %{
          extra: :forbid,
          frozen: true,
          strict: true,
          validate_assignment: true
        })

      assert dspy_config.extra == :forbid
      assert dspy_config.frozen == true
      assert dspy_config.strict == true

      # Test that frozen config prevents modification
      assert_raise RuntimeError, fn ->
        Config.merge(dspy_config, %{strict: false})
      end
    end
  end

  describe "JSON schema generation with all features" do
    test "generates comprehensive JSON schema with references" do
      # Create a complex schema with nested types
      fields = [
        {:user, {:map, {:string, :any}}, [required: true]},
        {:preferences, {:map, {:string, {:union, [:string, :boolean, :integer]}}},
         [required: false]},
        {:tags, {:array, :string}, [min_items: 0, max_items: 20]},
        {:metadata, {:map, {:string, :any}}, [description: "Additional metadata"]}
      ]

      schema =
        Runtime.create_schema(fields,
          title: "Complex User Schema",
          description: "A comprehensive user data schema"
        )

      json_schema = Runtime.to_json_schema(schema)

      # Verify structure
      assert json_schema["type"] == "object"
      assert json_schema["title"] == "Complex User Schema"
      assert json_schema["description"] == "A comprehensive user data schema"

      # Verify properties
      properties = json_schema["properties"]
      assert properties["user"]["type"] == "object"
      assert properties["tags"]["type"] == "array"
      assert properties["tags"]["maxItems"] == 20
      assert properties["preferences"]["type"] == "object"

      # Verify required fields
      assert "user" in json_schema["required"]
      refute "preferences" in json_schema["required"]
    end

    test "resolves and flattens complex schema references" do
      # Create schema with multiple levels of nesting
      fields = [
        {:data, {:array, {:map, {:string, {:union, [:string, :integer]}}}}, []}
      ]

      schema = Runtime.create_schema(fields)
      json_schema = Runtime.to_json_schema(schema)

      # Resolve all references
      resolved = Resolver.resolve_references(json_schema)

      # Flatten for LLM compatibility
      flattened = Resolver.flatten_schema(resolved)

      # Should be fully expanded without references
      refute has_references?(flattened)

      # Verify structure is preserved
      data_prop = flattened["properties"]["data"]
      assert data_prop["type"] == "array"
      assert Map.has_key?(data_prop, "items")
    end
  end

  # Helper function for checking references
  defp has_references?(schema) when is_map(schema) do
    Enum.any?(schema, fn {key, value} ->
      key == "$ref" or has_references?(value)
    end)
  end

  defp has_references?(value) when is_list(value) do
    Enum.any?(value, &has_references?/1)
  end

  defp has_references?(_), do: false
end
