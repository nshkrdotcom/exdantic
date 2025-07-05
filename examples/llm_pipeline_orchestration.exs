#!/usr/bin/env elixir

# LLM Pipeline Orchestration Examples
# Demonstrates comprehensive patterns for LLM pipeline orchestration with Exdantic

defmodule LLMPipelineOrchestrationExamples do
  @moduledoc """
  Complete examples for LLM Pipeline Orchestration functionality in Exdantic.

  This module demonstrates:
  - Multi-step LLM validation pipelines
  - Stage-based validation with error recovery
  - Complex business logic validation chains
  - Quality assessment integration
  - Performance optimization patterns
  - Error handling and retry logic
  """

  # Example 1: Basic Pipeline Stage Definition
  defmodule PipelineStage do
    use Exdantic, define_struct: true

    schema "Pipeline stage configuration" do
      field :stage_name, :string, required: true
      field :input_schema, :any, required: true  # Schema module or runtime schema
      field :output_schema, :any, required: true
      field :llm_config, :map, default: %{}
      field :validation_config, :map, default: %{}
      field :retry_config, :map, default: %{max_retries: 3, backoff: :exponential}

      model_validator :validate_stage_configuration
    end

    def validate_stage_configuration(input) do
      # Validate that schemas are properly defined
      cond do
        is_nil(input.input_schema) ->
          {:error, "Input schema cannot be nil"}
        is_nil(input.output_schema) ->
          {:error, "Output schema cannot be nil"}
        true ->
          {:ok, input}
      end
    end
  end

  # Example 2: Pipeline Definition
  defmodule Pipeline do
    use Exdantic, define_struct: true

    schema "Multi-stage LLM pipeline" do
      field :pipeline_id, :string, required: true
      field :stages, {:array, PipelineStage}, min_items: 1
      field :global_config, :map, default: %{}
      field :error_handling, :string, choices: ["fail_fast", "continue", "retry_stage"], default: "fail_fast"

      model_validator :validate_pipeline_flow
      computed_field :stage_count, :integer, :count_stages
    end

    def validate_pipeline_flow(input) do
      # Validate that output of stage N matches input of stage N+1
      stage_pairs = Enum.zip(input.stages, tl(input.stages))

      validation_errors = Enum.reduce(stage_pairs, [], fn {current_stage, next_stage}, errors ->
        if schemas_compatible?(current_stage.output_schema, next_stage.input_schema) do
          errors
        else
          error_msg = "Stage '#{current_stage.stage_name}' output incompatible with '#{next_stage.stage_name}' input"
          [error_msg | errors]
        end
      end)

      if validation_errors == [] do
        {:ok, input}
      else
        {:error, Enum.join(validation_errors, "; ")}
      end
    end

    def count_stages(input) do
      {:ok, length(input.stages)}
    end

    defp schemas_compatible?(output_schema, input_schema) do
      # Simple compatibility check - in practice, this would be more sophisticated
      output_schema == input_schema or
      (is_atom(output_schema) and is_atom(input_schema))
    end
  end

  # Example 3: Input/Output Schemas for Different Stages
  defmodule AnalysisInputSchema do
    use Exdantic

    schema "Analysis stage input" do
      field :raw_data, :string, required: true, min_length: 10
      field :analysis_type, :string, choices: ["sentiment", "entity", "summary", "classification"]
      field :context, :string, optional: true
    end
  end

  defmodule AnalysisOutputSchema do
    use Exdantic

    schema "Analysis stage output" do
      field :analysis_result, :string, required: true, min_length: 10
      field :confidence, :float, gteq: 0.0, lteq: 1.0
      field :key_findings, {:array, :string}, optional: true
      field :metadata, :map, default: %{}
    end
  end

  defmodule SynthesisOutputSchema do
    use Exdantic

    schema "Synthesis stage output" do
      field :synthesis, :string, required: true, min_length: 20
      field :recommendations, {:array, :string}, min_items: 1
      field :confidence, :float, gteq: 0.0, lteq: 1.0
      field :supporting_evidence, {:array, :string}, optional: true
    end
  end

  defmodule ValidationOutputSchema do
    use Exdantic

    schema "Final validation stage output" do
      field :validation_result, :string, required: true
      field :approved, :boolean, required: true
      field :final_score, :float, gteq: 0.0, lteq: 1.0
      field :quality_metrics, :map, default: %{}
    end
  end

  # Example 4: Quality Assessment Schema
  defmodule QualityMetrics do
    use Exdantic, define_struct: true

    schema "Quality assessment metrics" do
      field :coherence_score, :float, gteq: 0.0, lteq: 1.0
      field :relevance_score, :float, gteq: 0.0, lteq: 1.0
      field :factual_accuracy, :float, gteq: 0.0, lteq: 1.0
      field :completeness_score, :float, gteq: 0.0, lteq: 1.0
      field :clarity_score, :float, gteq: 0.0, lteq: 1.0

      computed_field :overall_quality, :float, :calculate_overall_quality
      computed_field :quality_grade, :string, :assign_quality_grade
    end

    def calculate_overall_quality(input) do
      scores = [
        input.coherence_score,
        input.relevance_score,
        input.factual_accuracy,
        input.completeness_score,
        input.clarity_score
      ]

      overall = Enum.sum(scores) / length(scores)
      {:ok, overall}
    end

    def assign_quality_grade(input) do
      grade = cond do
        input.overall_quality >= 0.9 -> "A"
        input.overall_quality >= 0.8 -> "B"
        input.overall_quality >= 0.7 -> "C"
        input.overall_quality >= 0.6 -> "D"
        true -> "F"
      end
      {:ok, grade}
    end
  end

  # Example 5: Pipeline Execution Engine
  defmodule PipelineExecutor do
    def execute_pipeline(pipeline_config, initial_input) do
      config = Exdantic.Config.create(coercion: :safe, strict: true)

      with {:ok, validated_pipeline} <- Exdantic.EnhancedValidator.validate(Pipeline, pipeline_config, config: config),
           {:ok, final_result} <- execute_stages(validated_pipeline.stages, initial_input, validated_pipeline) do
        {:ok, final_result}
      else
        {:error, reason} -> {:error, reason}
      end
    end

    defp execute_stages(stages, input, pipeline) do
      Enum.reduce_while(stages, {:ok, input}, fn stage, {:ok, current_input} ->
        case execute_single_stage(stage, current_input, pipeline) do
          {:ok, stage_output} ->
            {:cont, {:ok, stage_output}}
          {:error, reason} ->
            case pipeline.error_handling do
              "fail_fast" -> {:halt, {:error, {stage.stage_name, reason}}}
              "continue" -> {:cont, {:ok, current_input}}  # Skip failed stage
              "retry_stage" -> handle_stage_retry(stage, current_input, pipeline)
            end
        end
      end)
    end

    defp execute_single_stage(stage, input, _pipeline) do
          validation_config = Exdantic.Config.create(
      coercion: Map.get(stage.validation_config, :coercion, :safe),
      strict: Map.get(stage.validation_config, :strict, true)
    )

      with {:ok, validated_input} <- validate_stage_input(stage, input, validation_config),
           {:ok, llm_output} <- call_llm_for_stage(stage, validated_input),
           {:ok, validated_output} <- validate_stage_output(stage, llm_output, validation_config) do
        {:ok, validated_output}
      else
        {:error, reason} -> {:error, reason}
      end
    end

    defp validate_stage_input(stage, input, config) do
      Exdantic.EnhancedValidator.validate(stage.input_schema, input, config: config)
    end

    defp validate_stage_output(stage, output, config) do
      Exdantic.EnhancedValidator.validate(stage.output_schema, output, config: config)
    end

    defp call_llm_for_stage(stage, validated_input) do
      # Mock LLM call - in practice, this would call actual LLM APIs
      case stage.stage_name do
        "analysis" ->
          {:ok, %{
            "analysis_result" => "Comprehensive analysis of #{validated_input.analysis_type} completed",
            "confidence" => 0.85,
            "key_findings" => ["finding1", "finding2", "finding3"],
            "metadata" => %{"processing_time" => 1.2, "model_used" => "gpt-4"}
          }}
        "synthesis" ->
          {:ok, %{
            "synthesis" => "Combined analysis shows positive trends with strong supporting evidence",
            "recommendations" => ["action1", "action2", "action3"],
            "confidence" => 0.9,
            "supporting_evidence" => ["evidence1", "evidence2"]
          }}
        "validation" ->
          {:ok, %{
            "validation_result" => "All quality checks passed with high confidence",
            "approved" => true,
            "final_score" => 0.88,
            "quality_metrics" => %{
              "coherence" => 0.9,
              "relevance" => 0.85,
              "accuracy" => 0.92
            }
          }}
        _ ->
          {:error, "Unknown stage type: #{stage.stage_name}"}
      end
    end

    defp handle_stage_retry(stage, input, pipeline) do
      max_retries = get_in(stage.retry_config, [:max_retries]) || 3
      attempt_stage_with_retries(stage, input, pipeline, max_retries)
    end

    defp attempt_stage_with_retries(stage, input, pipeline, retries_left) do
      case execute_single_stage(stage, input, pipeline) do
        {:ok, result} ->
          {:cont, {:ok, result}}
        {:error, _reason} when retries_left > 0 ->
          # Implement backoff strategy
          :timer.sleep(1000)  # Simple linear backoff
          attempt_stage_with_retries(stage, input, pipeline, retries_left - 1)
        {:error, reason} ->
          {:halt, {:error, {stage.stage_name, "Failed after retries: #{reason}"}}}
      end
    end
  end

  # Example 6: Quality Assessment Integration
  defmodule QualityAssessor do
    def assess_pipeline_quality(pipeline_result, original_input) do
      # Simulate quality assessment
      quality_data = %{
        "coherence_score" => assess_coherence(pipeline_result),
        "relevance_score" => assess_relevance(pipeline_result, original_input),
        "factual_accuracy" => assess_accuracy(pipeline_result),
        "completeness_score" => assess_completeness(pipeline_result),
        "clarity_score" => assess_clarity(pipeline_result)
      }

      config = Exdantic.Config.create(coercion: :safe, strict: true)
      Exdantic.EnhancedValidator.validate(QualityMetrics, quality_data, config: config)
    end

    defp assess_coherence(result) do
      # Simple heuristic based on result structure
      if is_map(result) and Map.has_key?(result, "synthesis") do
        0.85 + :rand.uniform() * 0.1  # 0.85-0.95
      else
        0.7 + :rand.uniform() * 0.2   # 0.7-0.9
      end
    end

    defp assess_relevance(result, _original_input) do
      # Check if result addresses the input
      if is_map(result) and Map.has_key?(result, "recommendations") do
        0.8 + :rand.uniform() * 0.15  # 0.8-0.95
      else
        0.65 + :rand.uniform() * 0.25  # 0.65-0.9
      end
    end

    defp assess_accuracy(result) do
      # Check for factual consistency indicators
      if is_map(result) and Map.get(result, "confidence", 0) > 0.8 do
        0.88 + :rand.uniform() * 0.1   # 0.88-0.98
      else
        0.7 + :rand.uniform() * 0.2    # 0.7-0.9
      end
    end

    defp assess_completeness(result) do
      # Check if all expected fields are present
      required_fields = ["validation_result", "approved", "final_score"]
      present_fields = if is_map(result) do
        Enum.count(required_fields, &Map.has_key?(result, &1))
      else
        0
      end

      present_fields / length(required_fields)
    end

    defp assess_clarity(result) do
      # Simple length and structure check
      if is_map(result) do
        validation_result = Map.get(result, "validation_result", "")
        if String.length(validation_result) > 20 do
          0.8 + :rand.uniform() * 0.15  # 0.8-0.95
        else
          0.6 + :rand.uniform() * 0.3   # 0.6-0.9
        end
      else
        0.5
      end
    end
  end

  def run do
    IO.puts("=== LLM Pipeline Orchestration Examples ===\n")

    # Example 1: Basic Pipeline Definition
    basic_pipeline_definition()

    # Example 2: Pipeline Execution
    pipeline_execution()

    # Example 3: Error Handling Strategies
    error_handling_strategies()

    # Example 4: Quality Assessment Integration
    quality_assessment_integration()

    # Example 5: Performance Analysis
    performance_analysis()

    # Example 6: Complex Multi-Stage Pipeline
    complex_multi_stage_pipeline()

    IO.puts("\n=== LLM Pipeline Orchestration Examples Complete ===")
  end

  defp basic_pipeline_definition do
    IO.puts("1. Basic Pipeline Definition")
    IO.puts("----------------------------")

    # Define pipeline stages
    analysis_stage = %{
      "stage_name" => "analysis",
      "input_schema" => AnalysisInputSchema,
      "output_schema" => AnalysisOutputSchema,
      "llm_config" => %{"model" => "gpt-4", "temperature" => 0.2},
      "validation_config" => %{"strict" => true, "coercion" => :safe}
    }

    synthesis_stage = %{
      "stage_name" => "synthesis",
      "input_schema" => AnalysisOutputSchema,
      "output_schema" => SynthesisOutputSchema,
      "llm_config" => %{"model" => "gpt-4", "temperature" => 0.3}
    }

    validation_stage = %{
      "stage_name" => "validation",
      "input_schema" => SynthesisOutputSchema,
      "output_schema" => ValidationOutputSchema,
      "llm_config" => %{"model" => "gpt-3.5-turbo", "temperature" => 0.1}
    }

    # Define complete pipeline
    pipeline_config = %{
      "pipeline_id" => "market_analysis_pipeline",
      "stages" => [analysis_stage, synthesis_stage, validation_stage],
      "global_config" => %{"timeout" => 30000, "max_tokens" => 2000},
      "error_handling" => "retry_stage"
    }

    IO.puts("Pipeline configuration:")
    case Exdantic.EnhancedValidator.validate(Pipeline, pipeline_config) do
      {:ok, validated_pipeline} ->
        IO.puts("  ✅ Pipeline validated successfully")
        IO.puts("     Pipeline ID: #{validated_pipeline.pipeline_id}")
        IO.puts("     Stages: #{validated_pipeline.stage_count}")
        IO.puts("     Error handling: #{validated_pipeline.error_handling}")
      {:error, errors} ->
        IO.puts("  ❌ Pipeline validation failed:")
        Enum.each(errors, &IO.puts("     #{Exdantic.Error.format(&1)}"))
    end

    IO.puts("")
  end

  defp pipeline_execution do
    IO.puts("2. Pipeline Execution")
    IO.puts("---------------------")

    # Create a valid pipeline
    pipeline_config = create_sample_pipeline()

    # Initial input data
    initial_data = %{
      "raw_data" => "Q4 financial reports show strong growth in renewable energy sector with 15% increase in revenue",
      "analysis_type" => "sentiment",
      "context" => "Market analysis for investment decisions"
    }

    IO.puts("Executing pipeline with input:")
    IO.puts("  Raw data: #{initial_data["raw_data"]}")
    IO.puts("  Analysis type: #{initial_data["analysis_type"]}")

    case PipelineExecutor.execute_pipeline(pipeline_config, initial_data) do
      {:ok, final_result} ->
        IO.puts("  ✅ Pipeline completed successfully")
        IO.puts("     Final result: #{inspect(final_result)}")
      {:error, {stage_name, reason}} ->
        IO.puts("  ❌ Pipeline failed at stage '#{stage_name}': #{reason}")
      {:error, reason} ->
        IO.puts("  ❌ Pipeline validation failed: #{inspect(reason)}")
    end

    IO.puts("")
  end

  defp error_handling_strategies do
    IO.puts("3. Error Handling Strategies")
    IO.puts("----------------------------")

    # Test different error handling strategies
    strategies = ["fail_fast", "continue", "retry_stage"]

    Enum.each(strategies, fn strategy ->
      IO.puts("Testing '#{strategy}' error handling:")

      pipeline_config = create_sample_pipeline()
      |> Map.put("error_handling", strategy)

      # Simulate problematic input that might cause stage failures
      problematic_input = %{
        "raw_data" => "Short",  # Too short, might cause validation errors
        "analysis_type" => "invalid_type"  # Invalid choice
      }

      case PipelineExecutor.execute_pipeline(pipeline_config, problematic_input) do
        {:ok, result} ->
          IO.puts("  ✅ Pipeline completed with strategy '#{strategy}'")
          IO.puts("     Result: #{inspect(result)}")
        {:error, {stage, reason}} ->
          IO.puts("  ❌ Pipeline failed at stage '#{stage}' with strategy '#{strategy}': #{reason}")
        {:error, reason} ->
          IO.puts("  ❌ Pipeline error with strategy '#{strategy}': #{inspect(reason)}")
      end

      IO.puts("")
    end)
  end

  defp quality_assessment_integration do
    IO.puts("4. Quality Assessment Integration")
    IO.puts("---------------------------------")

    # Execute pipeline and assess quality
    pipeline_config = create_sample_pipeline()
    initial_data = %{
      "raw_data" => "Comprehensive market analysis reveals positive trends in renewable energy adoption",
      "analysis_type" => "summary",
      "context" => "Investment strategy development"
    }

    case PipelineExecutor.execute_pipeline(pipeline_config, initial_data) do
      {:ok, pipeline_result} ->
        IO.puts("Pipeline execution completed, assessing quality...")

        case QualityAssessor.assess_pipeline_quality(pipeline_result, initial_data) do
          {:ok, quality_metrics} ->
            IO.puts("  ✅ Quality assessment completed")
            IO.puts("     Overall quality: #{quality_metrics.overall_quality}")
            IO.puts("     Quality grade: #{quality_metrics.quality_grade}")
            IO.puts("     Coherence: #{quality_metrics.coherence_score}")
            IO.puts("     Relevance: #{quality_metrics.relevance_score}")
            IO.puts("     Accuracy: #{quality_metrics.factual_accuracy}")
          {:error, errors} ->
            IO.puts("  ❌ Quality assessment failed:")
            Enum.each(errors, &IO.puts("     #{Exdantic.Error.format(&1)}"))
        end
      {:error, reason} ->
        IO.puts("  ❌ Pipeline failed, cannot assess quality: #{inspect(reason)}")
    end

    IO.puts("")
  end

  defp performance_analysis do
    IO.puts("5. Performance Analysis")
    IO.puts("-----------------------")

    pipeline_config = create_sample_pipeline()
    test_data = %{
      "raw_data" => "Performance test data for pipeline execution timing analysis",
      "analysis_type" => "classification",
      "context" => "Performance benchmarking"
    }

    iterations = 5

    IO.puts("Running performance analysis (#{iterations} iterations)...")

    {total_time, results} = :timer.tc(fn ->
      for i <- 1..iterations do
        {time, result} = :timer.tc(fn ->
          PipelineExecutor.execute_pipeline(pipeline_config, test_data)
        end)
        {i, time / 1000, result}  # Convert to milliseconds
      end
    end)

    successful_runs = Enum.count(results, fn {_, _, result} ->
      match?({:ok, _}, result)
    end)

    execution_times = Enum.map(results, fn {_, time, _} -> time end)
    avg_time = Enum.sum(execution_times) / length(execution_times)
    min_time = Enum.min(execution_times)
    max_time = Enum.max(execution_times)

    IO.puts("Performance Results:")
    IO.puts("  Total time: #{total_time / 1000} ms")
    IO.puts("  Successful runs: #{successful_runs}/#{iterations}")
    IO.puts("  Average execution time: #{Float.round(avg_time, 2)} ms")
    IO.puts("  Min execution time: #{Float.round(min_time, 2)} ms")
    IO.puts("  Max execution time: #{Float.round(max_time, 2)} ms")

    IO.puts("")
  end

  defp complex_multi_stage_pipeline do
    IO.puts("6. Complex Multi-Stage Pipeline")
    IO.puts("-------------------------------")

    # Create a more complex pipeline with additional stages
    complex_pipeline = %{
      "pipeline_id" => "complex_analysis_pipeline",
      "stages" => [
        %{
          "stage_name" => "preprocessing",
          "input_schema" => AnalysisInputSchema,
          "output_schema" => AnalysisOutputSchema,
          "llm_config" => %{"model" => "gpt-3.5-turbo", "temperature" => 0.1}
        },
        %{
          "stage_name" => "analysis",
          "input_schema" => AnalysisOutputSchema,
          "output_schema" => AnalysisOutputSchema,
          "llm_config" => %{"model" => "gpt-4", "temperature" => 0.2}
        },
        %{
          "stage_name" => "synthesis",
          "input_schema" => AnalysisOutputSchema,
          "output_schema" => SynthesisOutputSchema,
          "llm_config" => %{"model" => "gpt-4", "temperature" => 0.3}
        },
        %{
          "stage_name" => "validation",
          "input_schema" => SynthesisOutputSchema,
          "output_schema" => ValidationOutputSchema,
          "llm_config" => %{"model" => "gpt-4", "temperature" => 0.1}
        }
      ],
      "global_config" => %{
        "timeout" => 60000,
        "max_tokens" => 4000,
        "retry_delay" => 2000
      },
      "error_handling" => "retry_stage"
    }

    complex_input = %{
      "raw_data" => "Complex multi-dimensional analysis of market trends, consumer behavior, and economic indicators for strategic planning",
      "analysis_type" => "summary",
      "context" => "Strategic business planning and risk assessment"
    }

    IO.puts("Executing complex multi-stage pipeline...")
    IO.puts("  Input: #{complex_input["raw_data"]}")
    IO.puts("  Stages: #{length(complex_pipeline["stages"])}")

    case PipelineExecutor.execute_pipeline(complex_pipeline, complex_input) do
      {:ok, final_result} ->
        IO.puts("  ✅ Complex pipeline completed successfully")

        # Assess quality of complex pipeline result
        case QualityAssessor.assess_pipeline_quality(final_result, complex_input) do
          {:ok, quality_metrics} ->
            IO.puts("     Final result quality: #{quality_metrics.quality_grade} (#{Float.round(quality_metrics.overall_quality, 3)})")
          {:error, _} ->
            IO.puts("     Quality assessment failed")
        end

      {:error, {stage, reason}} ->
        IO.puts("  ❌ Complex pipeline failed at stage '#{stage}': #{reason}")
      {:error, reason} ->
        IO.puts("  ❌ Complex pipeline failed: #{inspect(reason)}")
    end

    IO.puts("")
  end

  # Helper function to create sample pipeline
  defp create_sample_pipeline do
    %{
      "pipeline_id" => "sample_pipeline",
      "stages" => [
        %{
          "stage_name" => "analysis",
          "input_schema" => AnalysisInputSchema,
          "output_schema" => AnalysisOutputSchema,
          "llm_config" => %{"model" => "gpt-4", "temperature" => 0.2}
        },
        %{
          "stage_name" => "synthesis",
          "input_schema" => AnalysisOutputSchema,
          "output_schema" => SynthesisOutputSchema,
          "llm_config" => %{"model" => "gpt-4", "temperature" => 0.3}
        },
        %{
          "stage_name" => "validation",
          "input_schema" => SynthesisOutputSchema,
          "output_schema" => ValidationOutputSchema,
          "llm_config" => %{"model" => "gpt-3.5-turbo", "temperature" => 0.1}
        }
      ],
      "global_config" => %{"timeout" => 30000},
      "error_handling" => "fail_fast"
    }
  end
end

# Run the examples
LLMPipelineOrchestrationExamples.run()
