#!/usr/bin/env elixir

# DSPy Integration Pattern Example
# Run with: elixir examples/dspy_integration.exs

Mix.install([{:exdantic, path: "."}])

IO.puts("""
🔮 Exdantic DSPy Integration Pattern Example
==========================================

This example demonstrates how to use Exdantic's enhanced features to replicate
common DSPy patterns for LLM program validation and structured output.
""")

# Example 1: DSPy create_model Pattern
IO.puts("\n🏗️ Example 1: DSPy create_model Pattern")

# DSPy Pattern: pydantic.create_model("DSPyProgramOutputs", **fields)
# Exdantic equivalent:

defmodule DSPyProgram do
  @doc """
  Create output schema dynamically based on program requirements
  """
  def create_output_schema(program_name, field_specs) do
    fields = for {name, type, constraints} <- field_specs do
      {name, type, [required: true] ++ constraints}
    end
    
    Exdantic.Runtime.create_schema(fields,
      title: "#{program_name}Outputs",
      description: "Output schema for #{program_name} program",
      strict: true
    )
  end
  
  @doc """
  Validate LLM output against the schema
  """
  def validate_output(schema, raw_output, opts \\ []) do
    config = Exdantic.Config.create(%{
      strict: true,
      extra: :forbid,
      coercion: Keyword.get(opts, :coercion, :safe),
      error_format: :detailed
    })
    
    Exdantic.EnhancedValidator.validate(schema, raw_output, config: config)
  end
  
  @doc """
  Generate JSON schema for LLM structured output
  """
  def generate_llm_schema(schema, provider \\ :openai) do
    json_schema = Exdantic.Runtime.to_json_schema(schema)
    
    json_schema
    |> Exdantic.JsonSchema.Resolver.resolve_references()
    |> Exdantic.JsonSchema.Resolver.enforce_structured_output(provider: provider)
    |> Exdantic.JsonSchema.Resolver.optimize_for_llm(
      remove_descriptions: false,
      simplify_unions: true
    )
  end
end

# Create a reasoning program schema
reasoning_fields = [
  {:thought, :string, [description: "Chain of thought reasoning", min_length: 10]},
  {:answer, :string, [description: "Final answer to the question"]},
  {:confidence, :float, [description: "Confidence score", gteq: 0.0, lteq: 1.0]},
  {:sources, {:array, :string}, [description: "Referenced sources", required: false]}
]

reasoning_schema = DSPyProgram.create_output_schema("ReasoningProgram", reasoning_fields)

IO.puts("✅ Created DSPy-style output schema: #{reasoning_schema.name}")
IO.puts("   Required fields: #{inspect(Exdantic.Runtime.DynamicSchema.required_fields(reasoning_schema))}")

# Test with valid LLM output
valid_output = %{
  thought: "The user is asking about the capital of France. This is a straightforward geography question.",
  answer: "The capital of France is Paris.",
  confidence: 0.95,
  sources: ["Geography textbook", "Encyclopedia"]
}

case DSPyProgram.validate_output(reasoning_schema, valid_output) do
  {:ok, _validated} ->
    IO.puts("✅ Valid LLM output accepted")
  {:error, errors} ->
    IO.puts("❌ Valid output rejected: #{inspect(errors)}")
end

# Example 2: TypeAdapter Pattern for Quick Validation
IO.puts("\n🔧 Example 2: TypeAdapter Pattern for Quick Validation")

# DSPy Pattern: TypeAdapter(type(value)).validate_python(value)
# Exdantic equivalent:

defmodule QuickValidation do
  @doc """
  Quick validation without schema definition
  """
  def validate_type(type_spec, value, opts \\ []) do
    Exdantic.TypeAdapter.validate(type_spec, value, opts)
  end
  
  @doc """
  Validate and coerce common LLM output types
  """
  def validate_llm_primitive(type, value) do
    case type do
      :confidence_score ->
        Exdantic.TypeAdapter.validate(:float, value, coerce: true)
        |> case do
          {:ok, score} when score >= 0.0 and score <= 1.0 -> {:ok, score}
          {:ok, _} -> {:error, "confidence must be between 0.0 and 1.0"}
          error -> error
        end
      
      :string_list ->
        Exdantic.TypeAdapter.validate({:array, :string}, value, coerce: true)
      
      :yes_no ->
        case Exdantic.TypeAdapter.validate(:string, value, coerce: true) do
          {:ok, str} ->
            normalized = String.downcase(String.trim(str))
            if normalized in ["yes", "no", "true", "false", "y", "n"] do
              {:ok, normalized in ["yes", "true", "y"]}
            else
              {:error, "must be yes/no response"}
            end
          error -> error
        end
      
      other ->
        Exdantic.TypeAdapter.validate(other, value, coerce: true)
    end
  end
end

# Test quick validations
quick_tests = [
  {:confidence_score, "0.85", "String confidence to float"},
  {:string_list, ["item1", "item2"], "Array of strings"},
  {:yes_no, "YES", "Yes/no response"},
  {:integer, "42", "String to integer"},
  {{:array, :integer}, ["1", "2", "3"], "String array to integer array"}
]

for {type, value, description} <- quick_tests do
  case QuickValidation.validate_llm_primitive(type, value) do
    {:ok, validated} ->
      IO.puts("✅ #{description}: #{inspect(value)} -> #{inspect(validated)}")
    {:error, reason} ->
      IO.puts("❌ #{description}: #{inspect(value)} -> #{reason}")
  end
end

# Example 3: Wrapper Model Pattern for Complex Coercion
IO.puts("\n🎁 Example 3: Wrapper Model Pattern for Complex Coercion")

# DSPy Pattern: create_model("Wrapper", value=(target_type, ...))
# Exdantic equivalent:

defmodule LLMCoercion do
  @doc """
  Create temporary wrapper for complex type coercion
  """
  def coerce_llm_output(field_name, type_spec, raw_value, constraints \\ []) do
    Exdantic.Wrapper.wrap_and_validate(field_name, type_spec, raw_value,
      coerce: true,
      constraints: constraints
    )
  end
  
  @doc """
  Handle multiple field coercion for LLM responses
  """
  def coerce_response_fields(field_specs, raw_response) do
    wrappers = Exdantic.Wrapper.create_multiple_wrappers(
      for {name, type, constraints} <- field_specs do
        {name, type, [coerce: true, constraints: constraints]}
      end
    )
    
    case Exdantic.Wrapper.validate_multiple(wrappers, raw_response) do
      {:ok, validated} -> {:ok, validated}
      {:error, errors_by_field} ->
        formatted_errors = for {field, errors} <- errors_by_field do
          "#{field}: #{hd(errors).message}"
        end
        {:error, formatted_errors}
    end
  end
end

# Test complex coercion scenarios
coercion_tests = [
  {:score, :integer, "85", [gteq: 0, lteq: 100]},
  {:percentage, :float, "87.5%", [gteq: 0.0, lteq: 100.0]},  # Note: % will cause failure
  {:tags, {:array, :string}, "tag1,tag2,tag3", []},  # Comma-separated string (will fail without preprocessing)
  {:priority, :string, "HIGH", [choices: ["LOW", "MEDIUM", "HIGH"]]}
]

for {field, type, value, constraints} <- coercion_tests do
  case LLMCoercion.coerce_llm_output(field, type, value, constraints) do
    {:ok, coerced} ->
      IO.puts("✅ #{field}: #{inspect(value)} -> #{inspect(coerced)}")
    {:error, errors} ->
      IO.puts("❌ #{field}: #{inspect(value)} -> #{hd(errors).message}")
  end
end

# Example 4: Configuration Patterns for Different LLM Scenarios
IO.puts("\n⚙️ Example 4: Configuration Patterns for Different LLM Scenarios")

# DSPy Pattern: ConfigDict(extra="forbid", frozen=True)
# Exdantic equivalent:

defmodule LLMConfigs do
  def strict_structured_output do
    Exdantic.Config.create(%{
      strict: true,
      extra: :forbid,
      coercion: :none,
      frozen: true,
      error_format: :detailed
    })
  end
  
  def lenient_chat_response do
    Exdantic.Config.create(%{
      strict: false,
      extra: :allow,
      coercion: :aggressive,
      error_format: :simple,
      case_sensitive: false
    })
  end
  
  def function_calling do
    Exdantic.Config.builder()
    |> Exdantic.Config.Builder.strict(true)
    |> Exdantic.Config.Builder.forbid_extra()
    |> Exdantic.Config.Builder.safe_coercion()
    |> Exdantic.Config.Builder.detailed_errors()
    |> Exdantic.Config.Builder.build()
  end
  
  def json_mode do
    Exdantic.Config.preset(:json_schema)
  end
end

# Test different configurations with the same data
test_response = %{
  "answer" => "42",  # String key instead of atom
  "confidence" => "0.9",  # String number
  "extra_info" => "This wasn't requested"  # Extra field
}

configurations = [
  {"Strict Structured Output", LLMConfigs.strict_structured_output()},
  {"Lenient Chat Response", LLMConfigs.lenient_chat_response()},
  {"Function Calling", LLMConfigs.function_calling()},
  {"JSON Mode", LLMConfigs.json_mode()}
]

simple_schema = Exdantic.Runtime.create_schema([
  {:answer, :string, [required: true]},
  {:confidence, :float, [required: true, gteq: 0.0, lteq: 1.0]}
])

for {name, config} <- configurations do
  case Exdantic.EnhancedValidator.validate(simple_schema, test_response, config: config) do
    {:ok, validated} ->
      IO.puts("✅ #{name}: Validation succeeded")
      answer_type = if is_binary(validated.answer), do: "string", else: "other"
      IO.puts("   Answer: #{inspect(validated.answer)} (#{answer_type})")
      if Map.has_key?(validated, :confidence) do
        conf_type = cond do
          is_float(validated.confidence) -> "float"
          is_integer(validated.confidence) -> "integer"
          is_binary(validated.confidence) -> "string"
          true -> "other"
        end
        IO.puts("   Confidence: #{inspect(validated.confidence)} (#{conf_type})")
      end
    {:error, errors} ->
      IO.puts("❌ #{name}: Validation failed")
      IO.puts("   Reason: #{hd(errors).message}")
  end
end

# Helper function
# typeof function definitions removed - replaced with inline logic above

# Example 5: Complete DSPy Program Simulation
IO.puts("\n🎯 Example 5: Complete DSPy Program Simulation")

defmodule DSPyProgramSimulation do
  @doc """
  Simulate a complete DSPy program with validation
  """
  def run_program(program_name, input_data, expected_outputs) do
    # Step 1: Create output schema
    schema = DSPyProgram.create_output_schema(program_name, expected_outputs)
    
    # Step 2: Generate JSON schema for LLM
    llm_schema = DSPyProgram.generate_llm_schema(schema, :openai)
    
    # Step 3: Simulate LLM call (in real DSPy, this would be an actual LLM call)
    llm_response = simulate_llm_call(input_data, llm_schema)
    
    # Step 4: Validate LLM response
    case DSPyProgram.validate_output(schema, llm_response, coercion: :safe) do
      {:ok, validated} ->
        {:ok, %{
          program: program_name,
          input: input_data,
          output: validated,
          schema: llm_schema
        }}
      {:error, errors} ->
        {:error, %{
          program: program_name,
          input: input_data,
          raw_output: llm_response,
          errors: errors,
          schema: llm_schema
        }}
    end
  end
  
  defp simulate_llm_call(input, _schema) do
    # Simulate different types of LLM responses
    case input.task do
      "reasoning" ->
        %{
          thought: "I need to analyze this step by step...",
          answer: "Based on the analysis, the answer is #{input.question}",
          confidence: 0.85,
          sources: ["knowledge base"]
        }
      "classification" ->
        %{
          category: "positive",
          confidence: "0.92",  # String that needs coercion
          reasoning: "The sentiment indicators suggest..."
        }
      "extraction" ->
        %{
          entities: ["New York", "Apple Inc", "2023"],
          relationships: [%{from: "Apple Inc", to: "New York", type: "headquartered_in"}]
        }
      "broken_response" ->
        %{
          incomplete: "This response is missing required fields",
          extra_field: "This shouldn't be here"
        }
    end
  end
end

# Test different program scenarios
program_scenarios = [
  {
    "ReasoningProgram",
    %{task: "reasoning", question: "What is the capital of France?"},
    [
      {:thought, :string, [min_length: 10]},
      {:answer, :string, []},
      {:confidence, :float, [gteq: 0.0, lteq: 1.0]},
      {:sources, {:array, :string}, [required: false]}
    ]
  },
  {
    "ClassificationProgram", 
    %{task: "classification", text: "I love this product!"},
    [
      {:category, :string, [choices: ["positive", "negative", "neutral"]]},
      {:confidence, :float, [gteq: 0.0, lteq: 1.0]},
      {:reasoning, :string, []}
    ]
  },
  {
    "ExtractionProgram",
    %{task: "extraction", text: "Apple Inc is headquartered in New York as of 2023"},
    [
      {:entities, {:array, :string}, []},
      {:relationships, {:array, {:map, {:string, :string}}}, [required: false]}
    ]
  },
  {
    "BrokenProgram",
    %{task: "broken_response", text: "This will fail validation"},
    [
      {:required_field, :string, []},
      {:another_required, :integer, []}
    ]
  }
]

for {program_name, input, expected_outputs} <- program_scenarios do
  IO.puts("\n--- Running #{program_name} ---")
  
  case DSPyProgramSimulation.run_program(program_name, input, expected_outputs) do
    {:ok, result} ->
      IO.puts("✅ Program succeeded:")
      IO.puts("   Input: #{inspect(result.input.task)}")
      IO.puts("   Output keys: #{inspect(Map.keys(result.output))}")
      
    {:error, error_result} ->
      IO.puts("❌ Program failed:")
      IO.puts("   Input: #{inspect(error_result.input.task)}")
      IO.puts("   Errors:")
      Enum.each(error_result.errors, &IO.puts("     - #{Exdantic.Error.format(&1)}"))
  end
end

# Example 6: Advanced JSON Schema Generation for Different Providers
IO.puts("\n🤖 Example 6: Advanced JSON Schema Generation for Different Providers")

# Create a comprehensive schema for LLM output
llm_output_fields = [
  {:reasoning_steps, {:array, :string}, [description: "Step-by-step reasoning", min_items: 1]},
  {:final_answer, :string, [description: "Conclusive answer"]},
  {:confidence_score, :float, [description: "Confidence level", gteq: 0.0, lteq: 1.0]},
  {:alternative_answers, {:array, :string}, [description: "Other possible answers", required: false]},
  {:metadata, {:map, {:string, :any}}, [description: "Additional context", required: false]}
]

comprehensive_schema = DSPyProgram.create_output_schema("ComprehensiveLLM", llm_output_fields)

# Generate provider-specific schemas
providers = [:openai, :anthropic, :generic]

for provider <- providers do
  llm_schema = DSPyProgram.generate_llm_schema(comprehensive_schema, provider)
  
  IO.puts("✅ #{String.upcase(to_string(provider))} Schema:")
  IO.puts("   AdditionalProperties: #{llm_schema["additionalProperties"]}")
  IO.puts("   Has Required: #{Map.has_key?(llm_schema, "required")}")
  IO.puts("   Properties count: #{map_size(llm_schema["properties"] || %{})}")
  
  # Check for provider-specific optimizations
  case provider do
    :openai ->
      IO.puts("   OpenAI optimized: #{llm_schema["additionalProperties"] == false}")
    :anthropic ->
      required_list = llm_schema["required"] || []
      IO.puts("   Anthropic required fields: #{length(required_list)}")
    :generic ->
      IO.puts("   Generic schema (no specific optimizations)")
  end
end

# Example 7: Error Recovery and Retry Patterns
IO.puts("\n🔄 Example 7: Error Recovery and Retry Patterns")

defmodule DSPyRetryPattern do
  @doc """
  Implement retry logic with progressive relaxation
  """
  def validate_with_retry(schema, raw_output, max_attempts \\ 3) do
    configs = [
      # Attempt 1: Strict validation
      Exdantic.Config.create(%{strict: true, extra: :forbid, coercion: :none}),
      # Attempt 2: Allow coercion
      Exdantic.Config.create(%{strict: true, extra: :forbid, coercion: :safe}),
      # Attempt 3: Lenient validation
      Exdantic.Config.create(%{strict: false, extra: :allow, coercion: :aggressive})
    ]
    
    Enum.with_index(configs)
    |> Enum.take(max_attempts)
    |> Enum.reduce_while({:error, []}, fn {config, attempt}, _acc ->
      case Exdantic.EnhancedValidator.validate(schema, raw_output, config: config) do
        {:ok, validated} ->
          {:halt, {:ok, validated, attempt + 1}}
        {:error, errors} ->
          if attempt + 1 == max_attempts do
            {:halt, {:error, errors}}
          else
            {:cont, {:error, errors}}
          end
      end
    end)
  end
end

# Test retry patterns
problematic_responses = [
  %{
    # Missing required field
    final_answer: "Partial response",
    confidence_score: 0.8
  },
  %{
    # Has all fields but with type issues
    reasoning_steps: "Single string instead of array",
    final_answer: "Complete answer",
    confidence_score: "0.9",  # String instead of float
    extra_field: "Not in schema"
  },
  %{
    # Completely malformed
    wrong_field: "This doesn't match schema at all"
  }
]

for {response, index} <- Enum.with_index(problematic_responses) do
  IO.puts("\n--- Testing retry pattern #{index + 1} ---")
  
  case DSPyRetryPattern.validate_with_retry(comprehensive_schema, response) do
    {:ok, validated, attempts} ->
      IO.puts("✅ Succeeded after #{attempts} attempt(s)")
      IO.puts("   Final keys: #{inspect(Map.keys(validated))}")
    {:error, final_errors} ->
      IO.puts("❌ Failed after all retry attempts")
      IO.puts("   Final error: #{hd(final_errors).message}")
  end
end

# Example 8: Performance Analysis for Production Use
IO.puts("\n⚡ Example 8: Performance Analysis for Production Use")

# Create test scenarios
performance_schema = DSPyProgram.create_output_schema("PerformanceTest", [
  {:result, :string, []},
  {:score, :float, [gteq: 0.0, lteq: 1.0]},
  {:tags, {:array, :string}, []}
])

test_data = for i <- 1..1000 do
  %{
    result: "Result #{i}",
    score: i / 1000.0,
    tags: ["tag#{rem(i, 10)}", "category#{rem(i, 5)}"]
  }
end

# Benchmark different validation approaches
{time_enhanced_us, _} = :timer.tc(fn ->
  config = Exdantic.Config.preset(:production)
  Enum.each(test_data, fn data ->
    Exdantic.EnhancedValidator.validate(performance_schema, data, config: config)
  end)
end)

{time_runtime_us, _} = :timer.tc(fn ->
  Enum.each(test_data, fn data ->
    Exdantic.Runtime.validate(data, performance_schema)
  end)
end)

{time_batch_us, _} = :timer.tc(fn ->
  Exdantic.EnhancedValidator.validate_many(performance_schema, test_data)
end)

IO.puts("✅ Performance analysis (1000 validations):")
IO.puts("   Enhanced Validator: #{Float.round(time_enhanced_us / 1000, 2)}ms")
IO.puts("   Runtime Direct: #{Float.round(time_runtime_us / 1000, 2)}ms")
IO.puts("   Batch Validation: #{Float.round(time_batch_us / 1000, 2)}ms")
IO.puts("   Batch speedup: #{Float.round(time_enhanced_us / time_batch_us, 2)}x")

IO.puts("""

🎯 Summary
==========
This example demonstrated complete DSPy integration patterns:

1. 🏗️ Dynamic schema creation (create_model equivalent)
2. 🔧 TypeAdapter for quick validation (TypeAdapter equivalent)
3. 🎁 Wrapper models for complex coercion (Wrapper pattern)
4. ⚙️ Configuration patterns for different LLM scenarios
5. 🎯 Complete DSPy program simulation with validation
6. 🤖 Provider-specific JSON schema optimization
7. 🔄 Error recovery and retry patterns
8. ⚡ Performance analysis for production deployment

Key DSPy Patterns Implemented:
✅ pydantic.create_model("DSPyProgramOutputs", **fields)
✅ TypeAdapter(type(value)).validate_python(value)  
✅ create_model("Wrapper", value=(target_type, ...))
✅ ConfigDict(extra="forbid", frozen=True)
✅ Structured output for OpenAI/Anthropic
✅ Progressive validation with retry logic
✅ Production-ready performance optimization

Exdantic now provides complete feature parity with Pydantic for DSPy use cases!
""")

# Clean exit
:ok
