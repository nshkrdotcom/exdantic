# Phase 6: Enhanced JSON Schema Resolution Tests
# File: test/exdantic/json_schema/enhanced_resolver_test.exs

defmodule Exdantic.JsonSchema.EnhancedResolverTest do
  use ExUnit.Case, async: true
  doctest Exdantic.JsonSchema.EnhancedResolver

  alias Exdantic.{EnhancedValidator, JsonSchema, Runtime}
  alias Exdantic.JsonSchema.{EnhancedResolver, Resolver}

  # Test schemas for comprehensive testing
  defmodule FullFeaturedSchema do
    use Exdantic, define_struct: true

    schema "Schema with all features" do
      field(:name, :string, required: true, min_length: 2)
      field(:email, :string, required: true, format: ~r/@/)
      field(:age, :integer, optional: true, gt: 0)

      model_validator(:normalize_email)

      model_validator(fn input ->
        if input.age && input.age < 13 do
          {:error, "Must be at least 13 years old"}
        else
          {:ok, input}
        end
      end)

      computed_field(:email_domain, :string, :extract_domain)

      computed_field(:age_group, :string, fn input ->
        cond do
          is_nil(input.age) -> {:ok, "unknown"}
          input.age < 18 -> {:ok, "minor"}
          input.age < 65 -> {:ok, "adult"}
          true -> {:ok, "senior"}
        end
      end)

      config do
        title("Full Featured User Schema")
        config_description("Demonstrates all Exdantic features")
        strict(true)
      end
    end

    def normalize_email(input) do
      {:ok, %{input | email: String.downcase(input.email)}}
    end

    def extract_domain(input) do
      domain = input.email |> String.split("@") |> List.last()
      {:ok, domain}
    end
  end

  defmodule SimpleSchema do
    use Exdantic

    schema do
      field(:name, :string)
      field(:count, :integer)
    end
  end

  describe "resolve_enhanced/2" do
    test "handles compile-time schema with all features" do
      schema = EnhancedResolver.resolve_enhanced(FullFeaturedSchema)

      assert schema["type"] == "object"
      assert schema["x-exdantic-enhanced"] == true
      assert schema["x-model-validators"] == 2
      assert schema["x-computed-fields"] == 2
      assert schema["x-schema-type"] == :compiled_schema
      assert schema["x-supports-struct"] == true

      # Check that computed fields are marked as readOnly
      assert schema["properties"]["email_domain"]["readOnly"] == true
      assert schema["properties"]["age_group"]["readOnly"] == true

      # Check model validator metadata
      assert schema["x-has-model-validation"] == true
      assert schema["x-has-computed-fields"] == true
    end

    test "handles simple schema without enhanced features" do
      schema = EnhancedResolver.resolve_enhanced(SimpleSchema)

      assert schema["type"] == "object"
      assert schema["x-exdantic-enhanced"] == true
      assert Map.get(schema, "x-model-validators", 0) == 0
      assert Map.get(schema, "x-computed-fields", 0) == 0
      assert schema["x-supports-struct"] == false

      # Should not have enhancement flags for features not present
      refute Map.has_key?(schema, "x-has-model-validation")
      refute Map.has_key?(schema, "x-has-computed-fields")
    end

    test "handles runtime DynamicSchema" do
      fields = [
        {:name, :string, [required: true]},
        {:age, :integer, [optional: true, gt: 0]}
      ]

      runtime_schema = Runtime.create_schema(fields, title: "Runtime Schema")
      schema = EnhancedResolver.resolve_enhanced(runtime_schema)

      assert schema["type"] == "object"
      assert schema["title"] == "Runtime Schema"
      assert schema["x-exdantic-enhanced"] == true
      assert schema["x-schema-type"] == :dynamic_schema
      assert schema["x-supports-struct"] == false
    end

    test "handles runtime EnhancedSchema" do
      fields = [{:name, :string, [required: true]}]
      validators = [fn data -> {:ok, %{data | name: String.trim(data.name)}} end]
      computed = [{:display_name, :string, fn data -> {:ok, String.upcase(data.name)} end}]

      enhanced_schema =
        Runtime.create_enhanced_schema(fields,
          model_validators: validators,
          computed_fields: computed
        )

      schema = EnhancedResolver.resolve_enhanced(enhanced_schema)

      assert schema["type"] == "object"
      assert schema["x-exdantic-enhanced"] == true
      assert schema["x-schema-type"] == :enhanced_schema
      assert schema["x-model-validators"] == 1
      assert schema["x-computed-fields"] == 1
      assert schema["properties"]["display_name"]["readOnly"] == true
    end

    test "provider optimization for OpenAI" do
      schema =
        EnhancedResolver.resolve_enhanced(FullFeaturedSchema,
          optimize_for_provider: :openai
        )

      assert schema["additionalProperties"] == false
      assert is_list(schema["required"])
    end

    test "provider optimization for Anthropic" do
      schema =
        EnhancedResolver.resolve_enhanced(FullFeaturedSchema,
          optimize_for_provider: :anthropic
        )

      assert schema["additionalProperties"] == false
      assert is_list(schema["required"])
    end

    test "excludes metadata when requested" do
      schema =
        EnhancedResolver.resolve_enhanced(FullFeaturedSchema,
          include_model_validators: false,
          include_computed_fields: false
        )

      refute Map.has_key?(schema, "x-model-validators")
      refute Map.has_key?(schema, "x-computed-fields")
      refute Map.has_key?(schema, "x-has-model-validation")
      refute Map.has_key?(schema, "x-has-computed-fields")
    end

    test "flattens schema for LLM when requested" do
      schema =
        EnhancedResolver.resolve_enhanced(FullFeaturedSchema,
          flatten_for_llm: true
        )

      # Should still be a valid schema but potentially flattened
      assert schema["type"] == "object"
      assert is_map(schema["properties"])
    end
  end

  describe "comprehensive_analysis/3" do
    test "provides complete analysis for full-featured schema" do
      sample_data = %{
        name: "John Doe",
        email: "JOHN@EXAMPLE.COM",
        age: 30
      }

      report =
        EnhancedResolver.comprehensive_analysis(
          FullFeaturedSchema,
          sample_data,
          include_validation_test: true,
          test_llm_providers: [:openai, :anthropic]
        )

      assert report.schema_type == :compiled_schema
      assert report.features.struct_support == true
      assert report.features.field_count == 3
      assert report.features.computed_field_count == 2
      assert report.features.model_validator_count == 2

      assert is_map(report.json_schema)
      assert report.json_schema["x-exdantic-enhanced"] == true

      # Validation test should succeed
      assert {:ok, result} = report.validation_test
      assert %FullFeaturedSchema{} = result
      # normalized by model validator
      assert result.email == "john@example.com"
      # computed field
      assert result.email_domain == "example.com"
      # computed field
      assert result.age_group == "adult"

      # LLM compatibility should be tested
      assert Map.has_key?(report.llm_compatibility, :openai)
      assert Map.has_key?(report.llm_compatibility, :anthropic)
      assert report.llm_compatibility.openai.compatible == true
      assert report.llm_compatibility.anthropic.compatible == true

      # Performance metrics
      assert is_map(report.performance_metrics)
      assert is_number(report.performance_metrics.complexity_score)
      assert is_binary(report.performance_metrics.estimated_validation_time)

      # Should have recommendations
      assert is_list(report.recommendations)

      # Should have generation timestamp
      assert %DateTime{} = report.generated_at
    end

    test "handles validation failures gracefully" do
      # Too short
      invalid_data = %{name: ""}

      report =
        EnhancedResolver.comprehensive_analysis(
          FullFeaturedSchema,
          invalid_data,
          include_validation_test: true
        )

      assert {:error, _errors} = report.validation_test
    end

    test "works without sample data" do
      report = EnhancedResolver.comprehensive_analysis(FullFeaturedSchema)

      assert report.schema_type == :compiled_schema
      assert is_nil(report.validation_test)
      assert is_map(report.performance_metrics)
    end

    test "analyzes runtime schemas" do
      fields = [{:name, :string}, {:count, :integer}]
      runtime_schema = Runtime.create_schema(fields)

      report = EnhancedResolver.comprehensive_analysis(runtime_schema)

      assert report.schema_type == :dynamic_schema
      assert report.features.struct_support == false
      assert report.features.field_count == 2
      assert report.features.computed_field_count == 0
    end
  end

  describe "optimize_for_dspy/2" do
    test "optimizes schema for DSPy patterns" do
      schema =
        EnhancedResolver.optimize_for_dspy(FullFeaturedSchema,
          signature_mode: true,
          strict_types: true,
          field_descriptions: true
        )

      assert schema["additionalProperties"] == false
      assert schema["x-dspy-optimized"] == true
      assert schema["x-dspy-signature-mode"] == true

      # All fields should have descriptions
      Enum.each(schema["properties"], fn {_field, field_schema} ->
        assert Map.has_key?(field_schema, "description")
      end)
    end

    test "removes computed fields when requested" do
      schema =
        EnhancedResolver.optimize_for_dspy(FullFeaturedSchema,
          remove_computed_fields: true
        )

      refute Map.has_key?(schema["properties"], "email_domain")
      refute Map.has_key?(schema["properties"], "age_group")
    end

    test "adds auto-generated descriptions" do
      schema =
        EnhancedResolver.optimize_for_dspy(SimpleSchema,
          field_descriptions: true
        )

      assert String.contains?(schema["properties"]["name"]["description"], "name field")
      assert String.contains?(schema["properties"]["count"]["description"], "count field")
    end

    test "enforces strict types" do
      schema =
        EnhancedResolver.optimize_for_dspy(FullFeaturedSchema,
          strict_types: true
        )

      assert schema["additionalProperties"] == false

      # Should not have default values in strict mode
      Enum.each(schema["properties"], fn {_field, field_schema} ->
        refute Map.has_key?(field_schema, "default")
      end)
    end
  end

  describe "validate_schema_compatibility/2" do
    test "validates compatible schema" do
      assert :ok = EnhancedResolver.validate_schema_compatibility(FullFeaturedSchema)
    end

    test "validates simple schema" do
      assert :ok = EnhancedResolver.validate_schema_compatibility(SimpleSchema)
    end

    test "validates runtime schemas" do
      fields = [{:name, :string}, {:age, :integer}]
      runtime_schema = Runtime.create_schema(fields)

      assert :ok = EnhancedResolver.validate_schema_compatibility(runtime_schema)
    end

    test "detects missing model validator functions" do
      defmodule BrokenValidatorSchema do
        use Exdantic

        schema do
          field(:name, :string)

          model_validator(:nonexistent_function)
        end
      end

      assert {:error, issues} =
               EnhancedResolver.validate_schema_compatibility(BrokenValidatorSchema)

      assert Enum.any?(issues, &String.contains?(&1, "nonexistent_function"))
    end

    test "detects missing computed field functions" do
      defmodule BrokenComputedFieldSchema do
        use Exdantic

        schema do
          field(:name, :string)

          computed_field(:computed, :string, :nonexistent_function)
        end
      end

      assert {:error, issues} =
               EnhancedResolver.validate_schema_compatibility(BrokenComputedFieldSchema)

      assert Enum.any?(issues, &String.contains?(&1, "nonexistent_function"))
    end

    test "detects high complexity schemas" do
      # Create a schema with many fields to trigger complexity warning
      many_fields = for i <- 1..50, do: {:"field_#{i}", :string}
      complex_schema = Runtime.create_schema(many_fields)

      assert {:error, issues} =
               EnhancedResolver.validate_schema_compatibility(
                 complex_schema,
                 include_performance_check: true
               )

      assert Enum.any?(issues, &String.contains?(&1, "complexity"))
    end

    test "validates empty runtime schema" do
      empty_schema = Runtime.create_schema([])

      assert {:error, issues} = EnhancedResolver.validate_schema_compatibility(empty_schema)
      assert Enum.any?(issues, &String.contains?(&1, "no fields"))
    end

    test "rejects invalid schema types" do
      assert {:error, issues} = EnhancedResolver.validate_schema_compatibility("not a schema")
      assert Enum.any?(issues, &String.contains?(&1, "Invalid schema type"))
    end
  end

  describe "integration with existing functionality" do
    test "works with existing JSON schema generation" do
      # Test that enhanced resolver doesn't break existing functionality
      basic_schema = JsonSchema.from_schema(SimpleSchema)
      enhanced_schema = EnhancedResolver.resolve_enhanced(SimpleSchema)

      # Should have same basic structure
      assert basic_schema["type"] == enhanced_schema["type"]
      assert basic_schema["properties"] == enhanced_schema["properties"]

      # But enhanced should have additional metadata
      assert enhanced_schema["x-exdantic-enhanced"] == true
    end

    test "works with EnhancedValidator" do
      data = %{name: "John", email: "JOHN@EXAMPLE.COM", age: 25}

      # Test that schemas enhanced by this resolver still work with EnhancedValidator
      {:ok, validated} = EnhancedValidator.validate(FullFeaturedSchema, data)

      assert %FullFeaturedSchema{} = validated
      # Model validator normalization
      assert validated.email == "john@example.com"
      # Computed field
      assert validated.email_domain == "example.com"
      # Computed field
      assert validated.age_group == "adult"
    end

    test "maintains backward compatibility with existing resolvers" do
      # Test that enhanced resolver can work alongside existing resolver
      standard_resolved =
        Resolver.resolve_references(JsonSchema.from_schema(FullFeaturedSchema))

      enhanced_resolved = EnhancedResolver.resolve_enhanced(FullFeaturedSchema)

      # Both should be valid JSON schemas
      assert standard_resolved["type"] == "object"
      assert enhanced_resolved["type"] == "object"

      # Enhanced should have additional metadata
      assert enhanced_resolved["x-exdantic-enhanced"] == true
      refute Map.has_key?(standard_resolved, "x-exdantic-enhanced")
    end
  end

  describe "performance considerations" do
    test "handles large schemas efficiently" do
      # Create a moderately large schema
      large_fields =
        for i <- 1..20 do
          {:"field_#{i}", :string, [required: true]}
        end

      large_schema = Runtime.create_schema(large_fields)

      # Should complete in reasonable time
      start_time = System.monotonic_time(:millisecond)
      schema = EnhancedResolver.resolve_enhanced(large_schema)
      end_time = System.monotonic_time(:millisecond)

      duration = end_time - start_time
      # Should complete in less than 100ms
      assert duration < 100

      # Should produce valid schema
      assert schema["type"] == "object"
      assert map_size(schema["properties"]) == 20
    end

    test "performance analysis provides useful metrics" do
      report = EnhancedResolver.comprehensive_analysis(FullFeaturedSchema)
      metrics = report.performance_metrics

      assert is_number(metrics.complexity_score)
      assert metrics.complexity_score > 0

      assert is_binary(metrics.estimated_validation_time)
      assert is_binary(metrics.memory_overhead)
      assert is_list(metrics.optimization_suggestions)
    end
  end

  describe "LLM provider compatibility" do
    test "OpenAI optimization produces compatible schema" do
      schema =
        EnhancedResolver.resolve_enhanced(FullFeaturedSchema,
          optimize_for_provider: :openai
        )

      # OpenAI requirements
      assert schema["additionalProperties"] == false
      assert Map.has_key?(schema, "properties")
      assert Map.has_key?(schema, "required")
      assert schema["type"] == "object"
    end

    test "Anthropic optimization produces compatible schema" do
      schema =
        EnhancedResolver.resolve_enhanced(FullFeaturedSchema,
          optimize_for_provider: :anthropic
        )

      # Anthropic requirements
      assert schema["additionalProperties"] == false
      assert Map.has_key?(schema, "required")
      assert schema["type"] == "object"
    end

    test "compatibility testing through comprehensive analysis" do
      analysis = EnhancedResolver.comprehensive_analysis(FullFeaturedSchema)

      assert is_map(analysis.llm_compatibility)
      assert Map.has_key?(analysis.llm_compatibility, :openai)
      assert Map.has_key?(analysis.llm_compatibility, :anthropic)

      # Each provider should have compatibility info
      Enum.each(analysis.llm_compatibility, fn {_provider, info} ->
        assert is_map(info)
        assert Map.has_key?(info, :compatible)
      end)
    end
  end

  describe "error handling" do
    test "handles invalid provider gracefully" do
      # Should not crash on unknown provider
      schema =
        EnhancedResolver.resolve_enhanced(SimpleSchema,
          optimize_for_provider: :unknown_provider
        )

      # Should still produce valid schema
      assert schema["type"] == "object"
    end

    test "handles malformed schemas gracefully" do
      # This should not crash the resolver
      assert {:error, _} = EnhancedResolver.validate_schema_compatibility(nil)
    end

    test "comprehensive_analysis handles errors gracefully" do
      # Should handle schemas that can't be validated
      invalid_schema = fn -> raise "boom" end

      # Should not crash
      report = EnhancedResolver.comprehensive_analysis(invalid_schema)
      assert is_map(report)
    end
  end
end
