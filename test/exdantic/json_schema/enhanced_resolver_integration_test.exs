defmodule Exdantic.JsonSchema.EnhancedResolverIntegrationTest do
  use ExUnit.Case, async: true

  alias Exdantic.EnhancedValidator
  alias Exdantic.JsonSchema.EnhancedResolver
  alias Exdantic.Runtime

  # Define test schemas at module level to avoid cyclic references
  defmodule WorkflowTestSchema do
    use Exdantic, define_struct: true

    schema "Complete workflow test" do
      field(:user_id, :integer, required: true, gt: 0)
      field(:username, :string, required: true, min_length: 3, max_length: 20)
      field(:email, :string, required: true, format: ~r/@/)
      field(:preferences, {:map, {:string, :any}}, optional: true)

      model_validator(:validate_unique_username)

      model_validator(fn input ->
        if String.contains?(input.email, input.username) do
          {:ok, input}
        else
          {:error, "Email should contain username"}
        end
      end)

      computed_field(:display_name, :string, :generate_display_name)

      computed_field(:user_type, :string, fn input ->
        if input.user_id < 1000 do
          {:ok, "admin"}
        else
          {:ok, "regular"}
        end
      end)
    end

    def validate_unique_username(input) do
      # Simulate username uniqueness check
      if input.username == "admin" do
        {:error, "Username 'admin' is reserved"}
      else
        {:ok, input}
      end
    end

    def generate_display_name(input) do
      {:ok, "#{input.username} (#{input.user_id})"}
    end
  end

  defmodule AddressSchema do
    use Exdantic, define_struct: true

    schema do
      field(:street, :string, required: true)
      field(:city, :string, required: true)
      field(:postal_code, :string, required: true)

      computed_field(:full_address, :string, :format_address)
    end

    def format_address(input) do
      {:ok, "#{input.street}, #{input.city} #{input.postal_code}"}
    end
  end

  defmodule PersonSchema do
    use Exdantic, define_struct: true

    schema do
      field(:name, :string, required: true)
      field(:address, AddressSchema, required: true)
      field(:contacts, {:array, :string}, optional: true)

      computed_field(:summary, :string, :generate_summary)
    end

    def generate_summary(input) do
      contact_count = length(input.contacts || [])

      # Handle case where nested computed field might not be available
      address_str =
        case input.address do
          %{full_address: addr} when is_binary(addr) -> addr
          %{street: street, city: city, postal_code: postal} -> "#{street}, #{city} #{postal}"
          _ -> "Unknown address"
        end

      {:ok, "#{input.name} at #{address_str} (#{contact_count} contacts)"}
    end
  end

  defmodule DSPySignatureSchema do
    use Exdantic

    schema "DSPy signature optimized" do
      field(:input, :string, required: true)
      field(:output, :string, required: true)

      # Minimal computed fields for DSPy compatibility
      computed_field(:signature_id, :string, fn input ->
        {:ok, :crypto.hash(:md5, input.input) |> Base.encode16() |> String.slice(0, 8)}
      end)
    end
  end

  defmodule DSPyProcessingSchema do
    use Exdantic, define_struct: true

    schema "DSPy processing optimized" do
      field(:query, :string, required: true)
      field(:context, {:array, :string}, optional: true)
      field(:response, :string, required: true)

      # Single model validator for DSPy compatibility
      model_validator(:validate_query_response_relevance)

      computed_field(:relevance_score, :float, :calculate_relevance)
      computed_field(:processing_id, :string, :generate_processing_id)
    end

    def validate_query_response_relevance(input) do
      # Simple relevance check
      if String.contains?(String.downcase(input.response), String.downcase(input.query)) do
        {:ok, input}
      else
        {:error, "Response doesn't seem relevant to query"}
      end
    end

    def calculate_relevance(input) do
      # Simple relevance calculation
      query_words = String.split(String.downcase(input.query))
      response_words = String.split(String.downcase(input.response))

      common_words = Enum.count(query_words, fn word -> word in response_words end)
      score = common_words / max(length(query_words), 1)

      {:ok, min(score, 1.0)}
    end

    def generate_processing_id(_input) do
      timestamp = System.system_time(:millisecond)
      {:ok, "proc_#{timestamp}"}
    end
  end

  defmodule ChainOfThoughtSchema do
    use Exdantic

    schema "Chain of thought optimized" do
      field(:problem, :string, required: true)
      field(:reasoning_steps, {:array, :string}, required: true)
      field(:conclusion, :string, required: true)

      # Multiple validators for chain of thought pattern
      model_validator(:validate_reasoning_coherence)
      model_validator(:validate_conclusion_follows)

      computed_field(:step_count, :integer, :count_reasoning_steps)
      computed_field(:reasoning_complexity, :string, :assess_complexity)
      computed_field(:confidence_level, :string, :estimate_confidence)
    end

    def validate_reasoning_coherence(input) do
      if length(input.reasoning_steps) >= 2 do
        {:ok, input}
      else
        {:error, "Chain of thought requires at least 2 reasoning steps"}
      end
    end

    def validate_conclusion_follows(input) do
      # Simple check that conclusion mentions the problem
      if String.contains?(String.downcase(input.conclusion), String.downcase(input.problem)) do
        {:ok, input}
      else
        {:error, "Conclusion should relate to the problem"}
      end
    end

    def count_reasoning_steps(input) do
      {:ok, length(input.reasoning_steps)}
    end

    def assess_complexity(input) do
      step_count = length(input.reasoning_steps)
      total_length = Enum.sum(Enum.map(input.reasoning_steps, &String.length/1))

      cond do
        step_count > 5 and total_length > 500 -> {:ok, "high"}
        step_count > 3 and total_length > 200 -> {:ok, "medium"}
        true -> {:ok, "low"}
      end
    end

    def estimate_confidence(input) do
      # Estimate confidence based on reasoning detail
      avg_step_length =
        Enum.sum(Enum.map(input.reasoning_steps, &String.length/1)) /
          max(length(input.reasoning_steps), 1)

      cond do
        avg_step_length > 50 -> {:ok, "high"}
        avg_step_length > 25 -> {:ok, "medium"}
        true -> {:ok, "low"}
      end
    end
  end

  # Test schemas for edge cases
  defmodule CircularRefSchema do
    use Exdantic

    schema do
      field(:name, :string, required: true)
      field(:parent, CircularRefSchema, optional: true)
    end
  end

  defmodule ProblematicComputedSchema do
    use Exdantic

    schema do
      field(:base, :string, required: true)

      # Too many computed fields for DSPy compatibility
      computed_field(:computed1, :string, fn _ -> {:ok, "1"} end)
      computed_field(:computed2, :string, fn _ -> {:ok, "2"} end)
      computed_field(:computed3, :string, fn _ -> {:ok, "3"} end)
      computed_field(:computed4, :string, fn _ -> {:ok, "4"} end)
      computed_field(:computed5, :string, fn _ -> {:ok, "5"} end)
      computed_field(:computed6, :string, fn _ -> {:ok, "6"} end)
    end
  end

  defmodule LegacyStyleSchema do
    use Exdantic

    schema do
      field(:old_field, :string, required: true)
      field(:deprecated_field, :string, optional: true)
    end
  end

  describe "end-to-end integration" do
    test "complete workflow: schema definition -> enhancement -> validation -> JSON schema" do
      # Step 1: Generate enhanced JSON schema
      enhanced_schema =
        EnhancedResolver.resolve_enhanced(WorkflowTestSchema,
          optimize_for_provider: :openai,
          include_model_validators: true,
          include_computed_fields: true
        )

      # Verify enhanced schema structure
      assert enhanced_schema["type"] == "object"
      assert enhanced_schema["x-exdantic-enhanced"] == true
      assert enhanced_schema["x-model-validators"] == 2
      assert enhanced_schema["x-computed-fields"] == 2
      assert is_map(enhanced_schema["properties"])

      # Step 2: Test validation with valid data
      valid_data = %{
        user_id: 1001,
        username: "johndoe",
        email: "johndoe@example.com",
        preferences: %{"theme" => "dark"}
      }

      {:ok, validated} = EnhancedValidator.validate(WorkflowTestSchema, valid_data)

      assert %WorkflowTestSchema{} = validated
      assert validated.user_id == 1001
      assert validated.username == "johndoe"
      # computed field
      assert validated.display_name == "johndoe (1001)"
      # computed field
      assert validated.user_type == "regular"

      # Step 3: Test validation with invalid data
      invalid_data = %{
        user_id: 999,
        # reserved username
        username: "admin",
        email: "test@example.com"
      }

      assert {:error, _errors} = EnhancedValidator.validate(WorkflowTestSchema, invalid_data)

      # Step 4: Test DSPy optimization
      dspy_schema =
        EnhancedResolver.optimize_for_dspy(WorkflowTestSchema,
          signature_mode: true,
          strict_types: true
        )

      assert dspy_schema["x-dspy-optimized"] == true
      assert dspy_schema["additionalProperties"] == false

      # Step 5: Test comprehensive analysis
      analysis =
        EnhancedResolver.comprehensive_analysis(
          WorkflowTestSchema,
          valid_data,
          include_validation_test: true,
          test_llm_providers: [:openai, :anthropic, :generic]
        )

      assert analysis.schema_type == :compiled_schema
      assert is_map(analysis.performance_metrics)
      assert is_map(analysis.llm_compatibility)
      assert is_list(analysis.recommendations)
      assert is_tuple(analysis.validation_test)
    end

    test "cross-schema references and complex nesting" do
      # Generate enhanced schema for nested structure
      enhanced_schema = EnhancedResolver.resolve_enhanced(PersonSchema)

      assert enhanced_schema["type"] == "object"
      assert enhanced_schema["x-computed-fields"] == 1

      # Address should be referenced
      address_property = enhanced_schema["properties"]["address"]

      assert Map.has_key?(address_property, "$ref") or
               Map.get(address_property, "type") == "object"

      # Test validation of nested data
      nested_data = %{
        name: "Jane Smith",
        address: %{
          street: "123 Main St",
          city: "Springfield",
          postal_code: "12345"
        },
        contacts: ["jane@email.com", "+1-555-0123"]
      }

      {:ok, validated} = EnhancedValidator.validate(PersonSchema, nested_data)

      assert %PersonSchema{} = validated
      assert validated.name == "Jane Smith"
      assert is_map(validated.address)
      assert validated.address.street == "123 Main St"
      assert validated.address.city == "Springfield"
      assert validated.address.postal_code == "12345"
      assert String.contains?(validated.summary, "Jane Smith")
      assert String.contains?(validated.summary, "2 contacts")

      # Test comprehensive analysis for nested schemas
      analysis = EnhancedResolver.comprehensive_analysis(PersonSchema, nested_data)

      assert analysis.schema_type == :compiled_schema
      assert is_map(analysis.features)
      assert analysis.features.field_count > 0
    end

    test "DSPy pattern optimization and compatibility" do
      # Test signature pattern optimization
      signature_schema =
        EnhancedResolver.optimize_for_dspy(DSPySignatureSchema,
          signature_mode: true,
          remove_computed_fields: false,
          strict_types: true
        )

      assert signature_schema["x-dspy-optimized"] == true
      assert signature_schema["type"] == "object"
      assert signature_schema["additionalProperties"] == false

      # Test processing pattern optimization
      processing_schema =
        EnhancedResolver.optimize_for_dspy(DSPyProcessingSchema,
          signature_mode: false,
          field_descriptions: true
        )

      assert processing_schema["x-dspy-optimized"] == true
      assert processing_schema["type"] == "object"

      # Test chain of thought compatibility
      cot_analysis = EnhancedResolver.comprehensive_analysis(ChainOfThoughtSchema)

      assert cot_analysis.schema_type == :compiled_schema
      # has many computed fields
      assert cot_analysis.features.computed_field_count == 3
      # complex schema
      assert cot_analysis.performance_metrics.complexity_score > 10
    end

    test "performance and scalability analysis" do
      # Test performance analysis for different schema complexities
      simple_analysis = EnhancedResolver.comprehensive_analysis(DSPySignatureSchema)
      complex_analysis = EnhancedResolver.comprehensive_analysis(ChainOfThoughtSchema)

      # Simple schema should have better performance characteristics
      assert simple_analysis.performance_metrics.complexity_score <
               complex_analysis.performance_metrics.complexity_score

      # Test memory footprint estimation
      assert String.contains?(simple_analysis.performance_metrics.memory_overhead, "KB")
      assert String.contains?(complex_analysis.performance_metrics.memory_overhead, "KB")
    end

    test "edge cases and error handling" do
      # Test circular reference handling
      circular_schema = EnhancedResolver.resolve_enhanced(CircularRefSchema)
      assert circular_schema["type"] == "object"
      # Should handle circular references gracefully

      # Test problematic computed field count
      problematic_analysis = EnhancedResolver.comprehensive_analysis(ProblematicComputedSchema)
      assert is_map(problematic_analysis.features)
      assert problematic_analysis.features.computed_field_count == 6

      assert String.contains?(
               problematic_analysis.recommendations |> Enum.join(" ") |> String.downcase(),
               "computed fields"
             )

      # Test legacy schema compatibility
      legacy_schema = EnhancedResolver.resolve_enhanced(LegacyStyleSchema)
      assert legacy_schema["type"] == "object"
      assert legacy_schema["x-exdantic-enhanced"] == true
    end

    test "LLM provider compatibility and optimization" do
      # Test OpenAI optimization
      openai_schema =
        EnhancedResolver.resolve_enhanced(WorkflowTestSchema,
          optimize_for_provider: :openai,
          flatten_for_llm: true
        )

      assert openai_schema["x-exdantic-enhanced"] == true
      assert openai_schema["type"] == "object"

      # Test Anthropic optimization
      anthropic_schema =
        EnhancedResolver.resolve_enhanced(WorkflowTestSchema,
          optimize_for_provider: :anthropic,
          flatten_for_llm: true
        )

      assert anthropic_schema["x-exdantic-enhanced"] == true
      assert anthropic_schema["type"] == "object"

      # Test generic optimization
      generic_schema =
        EnhancedResolver.resolve_enhanced(WorkflowTestSchema,
          optimize_for_provider: :generic
        )

      assert generic_schema["x-exdantic-enhanced"] == true

      # Verify all providers are compatible
      compatibility_analysis = EnhancedResolver.comprehensive_analysis(WorkflowTestSchema)
      assert compatibility_analysis.llm_compatibility.openai.compatible == true
      assert compatibility_analysis.llm_compatibility.anthropic.compatible == true
      assert compatibility_analysis.llm_compatibility.generic.compatible == true
    end

    test "backward compatibility with existing resolvers" do
      # Test that enhanced resolver works with existing schema patterns
      legacy_json_schema = Exdantic.JsonSchema.from_schema(LegacyStyleSchema)
      enhanced_json_schema = EnhancedResolver.resolve_enhanced(LegacyStyleSchema)

      # Should maintain same basic structure
      assert legacy_json_schema["type"] == enhanced_json_schema["type"]
      assert legacy_json_schema["properties"] == enhanced_json_schema["properties"]

      # But enhanced version has additional metadata
      assert Map.has_key?(enhanced_json_schema, "x-exdantic-enhanced")
      refute Map.has_key?(legacy_json_schema, "x-exdantic-enhanced")
    end
  end

  describe "runtime integration" do
    test "basic runtime schema creation and validation" do
      # Test basic runtime schema functionality
      fields = [
        {:name, :string},
        {:email, :string},
        {:age, :integer}
      ]

      schema = Runtime.create_schema(fields)
      assert is_map(schema.fields)
      assert schema.fields[:name].type == {:type, :string, []}

      # Test basic validation
      data = %{name: "Test User", email: "test@example.com", age: 25}
      {:ok, validated} = Runtime.validate(data, schema)
      assert validated.name == "Test User"
    end
  end
end
