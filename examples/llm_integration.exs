#!/usr/bin/env elixir

# LLM Integration Examples
# Demonstrates comprehensive patterns for AI/LLM integration with Exdantic

defmodule LLMIntegrationExamples do
  @moduledoc """
  Complete examples for LLM integration patterns with Exdantic.

  This module demonstrates:
  - Structured output validation for LLM responses
  - DSPy signature patterns
  - Provider-specific optimizations (OpenAI, Anthropic)
  - Chain-of-thought validation
  - Multi-agent coordination
  - Quality assessment
  """

  # Example 1: Basic LLM Output Validation
  defmodule LLMResponseSchema do
    use Exdantic, define_struct: true

    schema "LLM structured output validation" do
      field :reasoning, :string do
        description("Step-by-step reasoning process")
        min_length(20)
      end

      field :answer, :string do
        required()
        min_length(1)
        description("Final answer to the question")
      end

      field :confidence, :float do
        required()
        gteq(0.0)
        lteq(1.0)
        description("Confidence score between 0 and 1")
      end

      field :sources, {:array, :string} do
        optional()
        description("List of sources used")
      end

      # Cross-field validation
      model_validator :validate_confidence_reasoning

      # Computed metrics
      computed_field :reasoning_word_count, :integer, :count_reasoning_words
      computed_field :answer_category, :string, :categorize_answer
    end

    def validate_confidence_reasoning(input) do
      if input.confidence > 0.8 and String.length(input.reasoning) < 50 do
        {:error, "High confidence answers must include detailed reasoning"}
      else
        {:ok, input}
      end
    end

    def count_reasoning_words(input) do
      word_count = input.reasoning |> String.split() |> length()
      {:ok, word_count}
    end

    def categorize_answer(input) do
      category = cond do
        String.length(input.answer) < 20 -> "brief"
        String.length(input.answer) < 100 -> "standard"
        true -> "detailed"
      end
      {:ok, category}
    end
  end

  # Example 2: DSPy Signature Implementation
  defmodule DSPySignature do
    def create_qa_signature do
      # Input schema for question answering
      input_fields = [
        {:question, :string, [description: "The question to answer"]},
        {:context, :string, [description: "Relevant context for answering"]}
      ]

      # Output schema for structured response
      output_fields = [
        {:answer, :string, [required: true, min_length: 5]},
        {:reasoning, :string, [required: true, min_length: 20]},
        {:confidence, :float, [required: true, gteq: 0.0, lteq: 1.0]}
      ]

      %{
        input: Exdantic.Runtime.create_schema(input_fields, title: "QA Input"),
        output: Exdantic.Runtime.create_schema(output_fields, title: "QA Output"),
        instruction: "Answer the question based on the provided context"
      }
    end

    def validate_input(signature, input_data) do
      config = Exdantic.Config.create(strict: true, coercion: :safe)
      Exdantic.Runtime.validate(input_data, signature.input, config: config)
    end

    def validate_output(signature, output_data) do
      config = Exdantic.Config.create(strict: false, coercion: :safe)
      Exdantic.Runtime.validate(output_data, signature.output, config: config)
    end

    def get_json_schema(signature, provider \\ :openai) do
      schema = Exdantic.Runtime.to_json_schema(signature.output)

      Exdantic.JsonSchema.Resolver.enforce_structured_output(schema,
        provider: provider,
        remove_unsupported: true
      )
    end
  end

  # Example 3: Chain of Thought Validation
  defmodule ChainOfThoughtSchema do
    use Exdantic, define_struct: true

    schema "Chain of thought reasoning validation" do
      field :question, :string, min_length: 5
      field :steps, {:array, :map}, min_items: 1
      field :final_answer, :string, min_length: 1
      field :overall_confidence, :float, gteq: 0.0, lteq: 1.0

      model_validator :validate_reasoning_chain
      computed_field :step_count, :integer, :count_steps
      computed_field :average_step_confidence, :float, :calculate_avg_confidence
    end

    def validate_reasoning_chain(input) do
      # Validate each step has required fields
      steps_valid = Enum.all?(input.steps, fn step ->
        Map.has_key?(step, "reasoning") and
        Map.has_key?(step, "conclusion") and
        Map.has_key?(step, "confidence")
      end)

      if not steps_valid do
        {:error, "All steps must have reasoning, conclusion, and confidence"}
      else
        # Validate confidence consistency
        step_confidences = Enum.map(input.steps, &Map.get(&1, "confidence", 0.0))
        avg_confidence = Enum.sum(step_confidences) / length(step_confidences)

        if abs(input.overall_confidence - avg_confidence) > 0.3 do
          {:error, "Overall confidence must align with step confidences"}
        else
          {:ok, input}
        end
      end
    end

    def count_steps(input) do
      {:ok, length(input.steps)}
    end

    def calculate_avg_confidence(input) do
      if length(input.steps) == 0 do
        {:ok, 0.0}
      else
        confidences = Enum.map(input.steps, &Map.get(&1, "confidence", 0.0))
        avg = Enum.sum(confidences) / length(confidences)
        {:ok, avg}
      end
    end
  end

  # Example 4: OpenAI Function Calling
  defmodule OpenAIFunctionIntegration do
    defmodule WeatherQuerySchema do
      use Exdantic

      schema "Get weather information for a location" do
        field :location, :string do
          required()
          description("City and state, e.g. San Francisco, CA")
        end

        field :unit, :string do
          choices(["celsius", "fahrenheit"])
          default("fahrenheit")
          description("Temperature unit")
        end

        field :include_forecast, :boolean do
          default(false)
          description("Include 5-day forecast")
        end
      end
    end

    def create_openai_function(schema_module, opts \\ []) do
      json_schema = Exdantic.JsonSchema.from_schema(schema_module)

      # Optimize for OpenAI function calling
      optimized_schema = Exdantic.JsonSchema.Resolver.enforce_structured_output(
        json_schema,
        provider: :openai,
        remove_unsupported: true
      )

      %{
        name: Keyword.get(opts, :name, schema_module |> Module.split() |> List.last()),
        description: Keyword.get(opts, :description, optimized_schema["description"]),
        parameters: optimized_schema
      }
    end

    def validate_function_call(schema_module, arguments) do
      config = Exdantic.Config.create(strict: false, coercion: :safe, extra: :forbid)
      Exdantic.EnhancedValidator.validate(schema_module, arguments, config: config)
    end
  end

  # Example 5: Multi-Agent Coordination
  defmodule MultiAgentSchema do
    use Exdantic, define_struct: true

    schema "Multi-agent coordination validation" do
      field :agent_id, :string, required: true
      field :message_type, :string, choices: ["query", "response", "coordination", "error"]
      field :content, :string, min_length: 1
      field :timestamp, :string, format: ~r/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$/
      field :confidence, :float, gteq: 0.0, lteq: 1.0
      field :metadata, :map, default: %{}

      computed_field :message_length, :integer, :calculate_message_length
      computed_field :urgency_level, :string, :assess_urgency
    end

    def calculate_message_length(input) do
      {:ok, String.length(input.content)}
    end

    def assess_urgency(input) do
      urgency = cond do
        input.message_type == "error" -> "high"
        input.confidence < 0.3 -> "high"
        input.message_type == "coordination" -> "medium"
        true -> "low"
      end
      {:ok, urgency}
    end
  end

  # Example 6: Quality Assessment
  defmodule QualityAssessment do
    defmodule QualityMetrics do
      use Exdantic, define_struct: true

      schema do
        field :coherence_score, :float, gteq: 0.0, lteq: 1.0
        field :relevance_score, :float, gteq: 0.0, lteq: 1.0
        field :clarity_score, :float, gteq: 0.0, lteq: 1.0
        field :completeness_score, :float, gteq: 0.0, lteq: 1.0

        computed_field :overall_quality, :float, :calculate_overall
        computed_field :quality_grade, :string, :assign_grade
      end

      def calculate_overall(input) do
        scores = [
          input.coherence_score,
          input.relevance_score,
          input.clarity_score,
          input.completeness_score
        ]
        overall = Enum.sum(scores) / length(scores)
        {:ok, overall}
      end

      def assign_grade(input) do
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

    def assess_llm_output(content, context \\ nil) do
      # Simple quality assessment algorithms
      quality_metrics = %{
        "coherence_score" => assess_coherence(content),
        "relevance_score" => assess_relevance(content, context),
        "clarity_score" => assess_clarity(content),
        "completeness_score" => assess_completeness(content)
      }

      config = Exdantic.Config.create(coercion: :safe, strict: false)
      Exdantic.EnhancedValidator.validate(QualityMetrics, quality_metrics, config: config)
    end

    defp assess_coherence(content) do
      # Simple coherence assessment based on sentence structure
      sentences = String.split(content, ~r/[.!?]+/) |> Enum.filter(&(String.trim(&1) != ""))
      if length(sentences) < 2, do: 0.8, else: 0.7 + min(length(sentences) * 0.1, 0.2)
    end

    defp assess_relevance(_content, context) do
      if is_nil(context), do: 0.7, else: 0.8  # Simplified
    end

    defp assess_clarity(content) do
      # Based on average sentence length
      sentences = String.split(content, ~r/[.!?]+/) |> Enum.filter(&(String.trim(&1) != ""))
      if length(sentences) == 0 do
        0.0
      else
        avg_length = String.length(content) / length(sentences)
        cond do
          avg_length < 10 -> 0.6
          avg_length < 25 -> 0.9
          avg_length < 40 -> 0.7
          true -> 0.5
        end
      end
    end

    defp assess_completeness(content) do
      # Based on content length
      length = String.length(content)
      cond do
        length < 50 -> 0.4
        length < 200 -> 0.7
        length < 500 -> 0.9
        true -> 0.8
      end
    end
  end

  # Example 7: Dynamic Schema Generation for LLM Outputs
  defmodule DynamicLLMSchemas do
    def create_analysis_schema(analysis_type) do
      base_fields = [
        {:input_data, :string, [required: true, description: "The data analyzed"]},
        {:analysis_result, :string, [required: true, min_length: 20]}
      ]

      type_specific_fields = case analysis_type do
        :sentiment ->
          [{:sentiment_score, :float, [gteq: -1.0, lteq: 1.0]},
           {:emotion, :string, [choices: ["positive", "negative", "neutral"]]}]
        :classification ->
          [{:category, :string, [required: true]},
           {:subcategory, :string, [optional: true]},
           {:classification_confidence, :float, [gteq: 0.0, lteq: 1.0]}]
        :extraction ->
          [{:entities, {:array, :string}, [optional: true]},
           {:keywords, {:array, :string}, [min_items: 1]}]
        _ ->
          []
      end

      all_fields = base_fields ++ type_specific_fields

      Exdantic.Runtime.create_schema(all_fields,
        title: "#{analysis_type |> Atom.to_string() |> String.capitalize()} Analysis",
        description: "Schema for #{analysis_type} analysis output"
      )
    end

    def validate_analysis_output(analysis_type, llm_response) do
      schema = create_analysis_schema(analysis_type)
      config = Exdantic.Config.create(coercion: :safe, strict: false)

      Exdantic.Runtime.validate(llm_response, schema, config: config)
    end
  end

  # Main demonstration function
  def run_examples do
    IO.puts("=== LLM Integration Examples ===\n")

    # Example 1: Basic LLM Output Validation
    IO.puts("1. Basic LLM Output Validation")
    llm_response = %{
      "reasoning" => "Based on the analysis of the data, the trend shows consistent growth",
      "answer" => "The market is experiencing positive growth",
      "confidence" => 0.85,  # Float instead of string
      "sources" => ["report1.pdf", "data.csv"]
    }

    config = Exdantic.Config.create(coercion: :safe, strict: false)
    case Exdantic.EnhancedValidator.validate(LLMResponseSchema, llm_response, config: config) do
      {:ok, validated} ->
        IO.puts("✓ LLM response validated successfully")
        IO.puts("  Answer: #{validated.answer}")
        IO.puts("  Confidence: #{validated.confidence}")
        IO.puts("  Word count: #{validated.reasoning_word_count}")
        IO.puts("  Category: #{validated.answer_category}")
      {:error, errors} ->
        IO.puts("✗ Validation failed: #{inspect(errors)}")
    end
    IO.puts("")

    # Example 2: DSPy Signature
    IO.puts("2. DSPy Signature Pattern")
    qa_signature = DSPySignature.create_qa_signature()

    input_data = %{
      question: "What is the capital of France?",
      context: "France is a country in Europe. Paris is its capital city."
    }

    {:ok, validated_input} = DSPySignature.validate_input(qa_signature, input_data)
    IO.puts("✓ DSPy input validated: #{validated_input.question}")

    # Simulate LLM response
    llm_output = %{
      "answer" => "Paris",
      "reasoning" => "Based on the context, Paris is explicitly mentioned as the capital of France.",
      "confidence" => 0.95  # Float instead of string
    }

    case DSPySignature.validate_output(qa_signature, llm_output) do
      {:ok, validated_output} ->
        IO.puts("✓ DSPy output validated: #{validated_output.answer}")

        # Generate JSON schema for LLM prompt
        _json_schema = DSPySignature.get_json_schema(qa_signature, :openai)
        IO.puts("  Generated OpenAI-compatible JSON schema")
      {:error, errors} ->
        IO.puts("✗ DSPy output validation failed: #{inspect(errors)}")
    end
    IO.puts("")

    # Example 3: Chain of Thought
    IO.puts("3. Chain of Thought Validation")
    chain_data = %{
      "question" => "What are the benefits of renewable energy?",
      "steps" => [
        %{
          "reasoning" => "Renewable energy sources like solar and wind are sustainable",
          "conclusion" => "They don't deplete natural resources",
          "confidence" => 0.9
        },
        %{
          "reasoning" => "These sources produce minimal greenhouse gas emissions",
          "conclusion" => "They help combat climate change",
          "confidence" => 0.85
        }
      ],
      "final_answer" => "Renewable energy is sustainable and environmentally friendly",
      "overall_confidence" => 0.87  # Float instead of string
    }

    config = Exdantic.Config.create(coercion: :safe, strict: false)
    case Exdantic.EnhancedValidator.validate(ChainOfThoughtSchema, chain_data, config: config) do
      {:ok, validated_chain} ->
        IO.puts("✓ Chain of thought validated")
        IO.puts("  Steps: #{validated_chain.step_count}")
        IO.puts("  Average confidence: #{validated_chain.average_step_confidence}")
      {:error, errors} ->
        IO.puts("✗ Chain validation failed: #{inspect(errors)}")
    end
    IO.puts("")

    # Example 4: OpenAI Function Calling
    IO.puts("4. OpenAI Function Calling")
    function_def = OpenAIFunctionIntegration.create_openai_function(
      OpenAIFunctionIntegration.WeatherQuerySchema,
      name: "get_weather",
      description: "Get current weather for a location"
    )

    IO.puts("✓ Generated OpenAI function definition:")
    IO.puts("  Name: #{function_def.name}")
    IO.puts("  Description: #{function_def.description}")

    # Validate function call arguments
    function_args = %{
      "location" => "San Francisco, CA",
      "unit" => "celsius",
      "include_forecast" => true  # Boolean instead of string
    }

    case OpenAIFunctionIntegration.validate_function_call(
      OpenAIFunctionIntegration.WeatherQuerySchema,
      function_args
    ) do
      {:ok, validated_args} ->
        IO.puts("✓ Function arguments validated")
        IO.puts("  Location: #{validated_args.location}")
        IO.puts("  Include forecast: #{validated_args.include_forecast}")
      {:error, errors} ->
        IO.puts("✗ Function argument validation failed: #{inspect(errors)}")
    end
    IO.puts("")

    # Example 5: Multi-Agent Message
    IO.puts("5. Multi-Agent Coordination")
    agent_message = %{
      "agent_id" => "agent_analyzer",
      "message_type" => "response",
      "content" => "Analysis complete: Market shows 15% growth in Q4",
      "timestamp" => "2024-01-01T10:00:00Z",
      "confidence" => 0.9,
      "metadata" => %{"source" => "market_data", "priority" => "high"}
    }

    config = Exdantic.Config.create(coercion: :safe, strict: false)
    case Exdantic.EnhancedValidator.validate(MultiAgentSchema, agent_message, config: config) do
      {:ok, validated_message} ->
        IO.puts("✓ Agent message validated")
        IO.puts("  Agent: #{validated_message.agent_id}")
        IO.puts("  Message length: #{validated_message.message_length}")
        IO.puts("  Urgency: #{validated_message.urgency_level}")
      {:error, errors} ->
        IO.puts("✗ Agent message validation failed: #{inspect(errors)}")
    end
    IO.puts("")

    # Example 6: Quality Assessment
    IO.puts("6. LLM Output Quality Assessment")
    content = "Climate change requires immediate action. The evidence shows rising temperatures and sea levels. Multiple solutions exist including renewable energy and policy changes."

    case QualityAssessment.assess_llm_output(content, "Explain climate change solutions") do
      {:ok, quality} ->
        IO.puts("✓ Quality assessment completed")
        IO.puts("  Overall quality: #{quality.overall_quality}")
        IO.puts("  Grade: #{quality.quality_grade}")
        IO.puts("  Coherence: #{quality.coherence_score}")
        IO.puts("  Clarity: #{quality.clarity_score}")
      {:error, errors} ->
        IO.puts("✗ Quality assessment failed: #{inspect(errors)}")
    end
    IO.puts("")

    # Example 7: Dynamic Schema Generation
    IO.puts("7. Dynamic Schema Generation")
    sentiment_response = %{
      "input_data" => "I love this new product, it's amazing!",
      "analysis_result" => "The text expresses strong positive sentiment with enthusiastic language",
      "sentiment_score" => 0.8,
      "emotion" => "positive"
    }

    case DynamicLLMSchemas.validate_analysis_output(:sentiment, sentiment_response) do
      {:ok, validated_analysis} ->
        IO.puts("✓ Sentiment analysis validated")
        IO.puts("  Result: #{validated_analysis.analysis_result}")
        IO.puts("  Sentiment score: #{validated_analysis.sentiment_score}")
        IO.puts("  Emotion: #{validated_analysis.emotion}")
      {:error, errors} ->
        IO.puts("✗ Analysis validation failed: #{inspect(errors)}")
    end

    IO.puts("\n=== All LLM Integration Examples Completed ===")
  end
end

# Run the examples
LLMIntegrationExamples.run_examples()
