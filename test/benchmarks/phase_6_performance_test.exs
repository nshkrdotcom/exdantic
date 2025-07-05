defmodule Exdantic.Phase6PerformanceTest do
  @moduledoc """
  Performance tests for Phase 6 enhanced features.

  These tests validate that Phase 6 enhancements don't significantly impact performance
  while providing enhanced functionality.
  """

  use ExUnit.Case, async: true

  alias Exdantic.JsonSchema.EnhancedResolver

  defmodule TestSchema do
    use Exdantic, define_struct: true

    schema "Test schema for Phase 6 performance testing" do
      field(:name, :string, required: true)
      field(:email, :string, required: true)
      field(:age, :integer, optional: true)

      model_validator(:validate_email_format)
      computed_field(:display_name, :string, :generate_display_name)
      computed_field(:email_domain, :string, :extract_email_domain)
    end

    def validate_email_format(input) do
      if String.contains?(input.email, "@") do
        {:ok, input}
      else
        {:error, "Invalid email format"}
      end
    end

    def generate_display_name(input) do
      {:ok, "#{input.name} <#{input.email}>"}
    end

    def extract_email_domain(input) do
      domain = input.email |> String.split("@") |> List.last()
      {:ok, domain}
    end
  end

  @test_data %{
    name: "John Doe",
    email: "john@example.com",
    age: 30
  }

  @tag :performance
  @tag timeout: 30_000
  test "Phase 6 enhanced schema info performance" do
    # Test that __enhanced_schema_info__ is reasonably fast
    {time, _result} =
      :timer.tc(fn ->
        for _ <- 1..1000 do
          TestSchema.__enhanced_schema_info__()
        end
      end)

    avg_time = time / 1000
    # Should be less than 1ms average
    assert avg_time < 1000, "Enhanced schema info too slow: #{avg_time}μs average"
  end

  @tag :performance
  @tag timeout: 30_000
  test "Phase 6 enhanced validation performance" do
    # Test that validate_enhanced with metrics is reasonably fast
    {time, _results} =
      :timer.tc(fn ->
        for _ <- 1..1000 do
          TestSchema.validate_enhanced(@test_data, include_performance_metrics: true)
        end
      end)

    avg_time = time / 1000
    # Should be less than 5ms average including metrics
    assert avg_time < 5000, "Enhanced validation too slow: #{avg_time}μs average"
  end

  @tag :performance
  @tag timeout: 30_000
  test "Phase 6 JSON schema generation performance" do
    # Test that enhanced JSON schema generation is reasonably fast
    {time, _results} =
      :timer.tc(fn ->
        for _ <- 1..100 do
          EnhancedResolver.resolve_enhanced(TestSchema)
        end
      end)

    avg_time = time / 100
    # Should be less than 10ms average
    assert avg_time < 10_000, "Enhanced JSON schema generation too slow: #{avg_time}μs average"
  end

  @tag :performance
  test "Phase 6 memory usage" do
    # Test that Phase 6 features don't significantly increase memory usage
    initial_memory = :erlang.memory(:total)

    # Create 1000 schemas with enhanced features
    for _ <- 1..1000 do
      TestSchema.__enhanced_schema_info__()
      TestSchema.validate_enhanced(@test_data)
    end

    :erlang.garbage_collect()
    final_memory = :erlang.memory(:total)

    memory_increase = final_memory - initial_memory
    memory_increase_mb = memory_increase / (1024 * 1024)

    # Should not increase memory by more than 10MB for this test
    assert memory_increase_mb < 10, "Memory increase too high: #{memory_increase_mb}MB"
  end

  test "Phase 6 enhanced schema info contains required fields" do
    info = TestSchema.__enhanced_schema_info__()

    # Verify Phase 6 specific fields
    assert info.exdantic_version == "Phase 6"
    assert info.phase_6_enhanced == true
    assert info.json_schema_enhanced == true
    assert info.llm_compatible == true

    # Verify structure
    assert is_map(info.dspy_ready)
    assert is_map(info.performance_profile)
    assert is_map(info.compatibility_matrix)

    # Verify backward compatibility
    assert info.has_struct == true
    assert info.field_count == 3
    assert info.computed_field_count == 2
    assert info.model_validator_count == 1
  end

  test "Phase 6 enhanced validation provides metrics" do
    {:ok, validated_data, metadata} =
      TestSchema.validate_enhanced(@test_data,
        include_performance_metrics: true,
        test_llm_compatibility: true,
        generate_enhanced_schema: true
      )

    # Verify data is still correctly validated
    assert validated_data.name == "John Doe"
    assert validated_data.email == "john@example.com"
    assert validated_data.display_name == "John Doe <john@example.com>"
    assert validated_data.email_domain == "example.com"

    # Verify metadata structure
    assert is_map(metadata.performance_metrics)
    assert is_map(metadata.llm_compatibility)
    assert is_map(metadata.enhanced_schema)

    # Verify performance metrics
    assert is_number(metadata.performance_metrics.validation_duration_microseconds)
    assert is_number(metadata.performance_metrics.validation_duration_milliseconds)
    assert is_number(metadata.performance_metrics.memory_used)
  end

  test "Phase 6 DSPy compatibility analysis" do
    info = TestSchema.__enhanced_schema_info__()
    dspy_info = info.dspy_ready

    # Verify DSPy compatibility structure
    assert is_boolean(dspy_info.ready)
    assert is_number(dspy_info.model_validators)
    assert is_number(dspy_info.computed_fields)
    assert is_list(dspy_info.recommendations)

    # This schema should be DSPy compatible (1 validator, 2 computed fields)
    assert dspy_info.ready == true
    assert dspy_info.model_validators == 1
    assert dspy_info.computed_fields == 2
  end

  test "Phase 6 performance profile analysis" do
    info = TestSchema.__enhanced_schema_info__()
    performance = info.performance_profile

    # Verify performance profile structure
    assert is_number(performance.complexity_score)
    assert is_binary(performance.estimated_validation_time)
    assert is_binary(performance.memory_footprint)
    assert performance.optimization_level in [:high, :medium, :low]

    # This simple schema should have good performance characteristics
    assert performance.complexity_score < 20
    assert performance.optimization_level == :high
  end

  test "Phase 6 compatibility matrix analysis" do
    info = TestSchema.__enhanced_schema_info__()
    compat = info.compatibility_matrix

    # Verify compatibility matrix structure
    assert compat.json_schema_generation == true
    assert is_map(compat.llm_providers)
    assert is_map(compat.dspy_patterns)
    assert is_boolean(compat.struct_support)
    assert is_boolean(compat.enhanced_features)

    # Verify LLM provider compatibility
    assert compat.llm_providers.openai == true
    assert compat.llm_providers.anthropic == true
    assert compat.llm_providers.generic == true

    # Verify DSPy pattern compatibility
    assert is_boolean(compat.dspy_patterns.signature)
    assert is_boolean(compat.dspy_patterns.chain_of_thought)
    assert compat.dspy_patterns.input_output == true
  end
end
