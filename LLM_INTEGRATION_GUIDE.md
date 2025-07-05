# LLM Integration Guide

This guide demonstrates how to use Exdantic for AI and Large Language Model (LLM) applications, including structured output validation, DSPy integration, and JSON Schema generation for various LLM providers.

## Table of Contents

- [Overview](#overview)
- [Structured Output Validation](#structured-output-validation)
- [DSPy Field Metadata](#dspy-field-metadata)
- [DSPy Integration Patterns](#dspy-integration-patterns)
- [Provider-Specific Optimizations](#provider-specific-optimizations)
- [Dynamic Schema Generation](#dynamic-schema-generation)
- [Chain-of-Thought Validation](#chain-of-thought-validation)
- [Function Calling Integration](#function-calling-integration)
- [Advanced LLM Patterns](#advanced-llm-patterns)

## Overview

Exdantic provides comprehensive support for LLM integration through:

- **Runtime schema generation** for dynamic prompt construction
- **Type coercion** to handle LLM string outputs
- **JSON Schema optimization** for different LLM providers
- **DSPy integration patterns** for structured programming
- **Field metadata** for DSPy-style annotations and LLM hints
- **Validation pipelines** for multi-step LLM workflows
- **Root schema validation** for non-dictionary LLM outputs

## Structured Output Validation

### Basic LLM Output Validation

```elixir
# Define output schema for LLM responses
defmodule LLMResponseSchema do
  use Exdantic, define_struct: true

  schema "LLM structured output" do
    # Input fields with DSPy metadata
    field :question, :string do
      required()
      min_length(1)
      extra("__dspy_field_type", "input")
      extra("prefix", "Question:")
    end

    field :context, :string do
      optional()
      extra("__dspy_field_type", "input")
      extra("prefix", "Context:")
    end

    # Output fields with metadata
    field :reasoning, :string do
      description("Step-by-step reasoning process")
      min_length(10)
      extra("__dspy_field_type", "output")
      extra("prefix", "Reasoning:")
    end

    field :answer, :string do
      required()
      min_length(1)
      description("Final answer to the question")
      extra("__dspy_field_type", "output")
      extra("prefix", "Answer:")
    end

    field :confidence, :float do
      required()
      gteq(0.0)
      lteq(1.0)
      extra("__dspy_field_type", "output")
    end

    field :sources, {:array, :string} do
      optional()
      extra("__dspy_field_type", "output")
      extra("render_as", "list")
    end
  end
end

# Validate LLM response with type coercion
llm_response = %{
  "reasoning" => "Based on the analysis of the data...",
  "answer" => "The result is 42",
  "confidence" => "0.95",  # String that needs coercion
  "sources" => ["source1.pdf", "source2.doc"]
}

config = Exdantic.Config.create(coercion: :safe, strict: true)

case Exdantic.EnhancedValidator.validate(LLMResponseSchema, llm_response, config: config) do
  {:ok, %LLMResponseSchema{} = response} ->
    IO.puts("Answer: #{response.answer}")
    IO.puts("Confidence: #{response.confidence}")
    IO.puts("Reasoning words: #{response.reasoning_length}")
    
  {:error, errors} ->
    IO.puts("LLM output validation failed:")
    Enum.each(errors, &IO.puts(Exdantic.Error.format(&1)))
end
```

### Runtime Schema for Dynamic Outputs

```elixir
defmodule DynamicLLMValidation do
  def create_output_schema(fields_config) do
    # Convert configuration to field definitions
    fields = Enum.map(fields_config, fn {name, type, opts} ->
      {name, type, [
        required: Keyword.get(opts, :required, true),
        description: Keyword.get(opts, :description, ""),
        min_length: Keyword.get(opts, :min_length),
        gteq: Keyword.get(opts, :min_value),
        lteq: Keyword.get(opts, :max_value)
      ] |> Enum.filter(fn {_, v} -> not is_nil(v) end)}
    end)

    Exdantic.Runtime.create_schema(fields,
      title: "Dynamic LLM Output",
      description: "Dynamically generated schema for LLM output validation"
    )
  end

  def validate_llm_output(response, fields_config) do
    schema = create_output_schema(fields_config)
    
    config = Exdantic.Config.create(
      coercion: :safe,     # Handle string inputs from LLM
      strict: true,        # Ensure no extra fields
      error_format: :detailed
    )

    Exdantic.EnhancedValidator.validate(schema, response, config: config)
  end
end

# Usage example
fields_config = [
  {:query_type, :string, [required: true, description: "Type of query processed"]},
  {:entities, {:array, :string}, [required: false, description: "Extracted entities"]},
  {:sentiment, :float, [required: true, min_value: -1.0, max_value: 1.0]},
  {:summary, :string, [required: true, min_length: 20]}
]

{:ok, validated} = DynamicLLMValidation.validate_llm_output(
  llm_response, 
  fields_config
)
```

### Root Schema for LLM List Outputs

Sometimes LLMs return arrays or other non-dictionary types at the root level:

```elixir
# Validate an array of extracted entities
defmodule EntityListSchema do
  use Exdantic.RootSchema, 
    root: {:array, {:type, :string, [min_length: 1]}}
end

# LLM returns: ["Apple Inc.", "Microsoft", "Google"]
llm_entities = ["Apple Inc.", "Microsoft", "Google"]
{:ok, validated_entities} = EntityListSchema.validate(llm_entities)

# Validate an array of structured entities
defmodule StructuredEntitySchema do
  use Exdantic

  schema do
    field :name, :string, required: true, min_length: 1
    field :type, :string, choices: ["PERSON", "ORG", "LOCATION"]
    field :confidence, :float, gteq: 0.0, lteq: 1.0
  end
end

defmodule StructuredEntityListSchema do
  use Exdantic.RootSchema, root: {:array, StructuredEntitySchema}
end

# LLM returns structured entities
llm_structured_entities = [
  %{"name" => "Apple Inc.", "type" => "ORG", "confidence" => 0.95},
  %{"name" => "Tim Cook", "type" => "PERSON", "confidence" => 0.87}
]

{:ok, validated_structured} = StructuredEntityListSchema.validate(llm_structured_entities)

# Validate classification results (single value)
defmodule ClassificationSchema do
  use Exdantic.RootSchema, 
    root: {:type, :string, [choices: ["positive", "negative", "neutral"]]}
end

# LLM returns: "positive"
{:ok, "positive"} = ClassificationSchema.validate("positive")

# Generate JSON Schema for LLM prompts
entity_list_schema = EntityListSchema.json_schema()
# Returns: %{"type" => "array", "items" => %{"type" => "string", "minLength" => 1}}
```

## DSPy Integration Patterns

### DSPy Signature Implementation

```elixir
defmodule DSPySignature do
  @moduledoc """
  Elixir implementation of DSPy signature patterns using Exdantic schemas.
  """

  def create_signature(input_fields, output_fields, opts \\ []) do
    # Create input schema (for validation before LLM call)
    input_schema = create_input_schema(input_fields, opts)
    
    # Create output schema (for validation after LLM call)
    output_schema = create_output_schema(output_fields, opts)
    
    %{
      input: input_schema,
      output: output_schema,
      instruction: Keyword.get(opts, :instruction, ""),
      examples: Keyword.get(opts, :examples, [])
    }
  end

  defp create_input_schema(fields, opts) do
    schema_fields = Enum.map(fields, fn {name, type, field_opts} ->
      {name, type, [
        required: true,
        description: Keyword.get(field_opts, :description, "Input field")
      ] ++ Keyword.take(field_opts, [:min_length, :max_length, :format])}
    end)

    Exdantic.Runtime.create_schema(schema_fields,
      title: Keyword.get(opts, :input_title, "DSPy Input"),
      strict: true
    )
  end

  defp create_output_schema(fields, opts) do
    schema_fields = Enum.map(fields, fn {name, type, field_opts} ->
      {name, type, [
        required: Keyword.get(field_opts, :required, true),
        description: Keyword.get(field_opts, :description, "Output field")
      ] ++ Keyword.take(field_opts, [:min_length, :max_length, :gteq, :lteq])}
    end)

    Exdantic.Runtime.create_schema(schema_fields,
      title: Keyword.get(opts, :output_title, "DSPy Output"),
      strict: true
    )
  end

  def validate_input(signature, input_data) do
    config = Exdantic.Config.create(strict: true, coercion: :safe)
    Exdantic.Runtime.validate(input_data, signature.input, [config: config])
  end

  def validate_output(signature, output_data) do
    config = Exdantic.Config.create(strict: true, coercion: :safe)
    Exdantic.Runtime.validate(output_data, signature.output, [config: config])
  end

  def get_input_json_schema(signature) do
    schema = Exdantic.Runtime.to_json_schema(signature.input)
    
    # Optimize for LLM understanding
    Exdantic.JsonSchema.Resolver.optimize_for_llm(schema,
      remove_descriptions: false,
      simplify_unions: true
    )
  end

  def get_output_json_schema(signature, provider \\ :openai) do
    schema = Exdantic.Runtime.to_json_schema(signature.output)
    
    # Optimize for specific provider
    Exdantic.JsonSchema.Resolver.enforce_structured_output(schema,
      provider: provider,
      remove_unsupported: true
    )
  end
end

# Example: Question Answering DSPy Signature
qa_signature = DSPySignature.create_signature(
  # Input fields
  [
    {:question, :string, [description: "The question to answer"]},
    {:context, :string, [description: "Relevant context for answering"]}
  ],
  # Output fields
  [
    {:answer, :string, [required: true, min_length: 5, description: "Direct answer to the question"]},
    {:reasoning, :string, [required: true, min_length: 20, description: "Step by step reasoning"]},
    {:confidence, :float, [required: true, gteq: 0.0, lteq: 1.0]}
  ],
  instruction: "Answer the question based on the provided context",
  input_title: "QA Input",
  output_title: "QA Output"
)

# Validate input before sending to LLM
input_data = %{
  question: "What is the capital of France?",
  context: "France is a country in Europe. Paris is its capital and largest city."
}

{:ok, validated_input} = DSPySignature.validate_input(qa_signature, input_data)

# Get JSON schema for LLM prompt
output_schema = DSPySignature.get_output_json_schema(qa_signature, :openai)

# Validate LLM response
llm_response = %{
  "answer" => "Paris",
  "reasoning" => "Based on the context provided, Paris is explicitly mentioned as the capital of France.",
  "confidence" => "0.95"
}

{:ok, validated_output} = DSPySignature.validate_output(qa_signature, llm_response)
```

### DSPy Program Implementation

```elixir
defmodule DSPyProgram do
  @moduledoc """
  Complete DSPy program implementation with multi-step validation.
  """

  defstruct [:steps, :config]

  def new(steps, config \\ []) do
    %__MODULE__{
      steps: steps,
      config: Exdantic.Config.create(Keyword.put_new(config, :coercion, :safe))
    }
  end

  def execute(program, initial_input) do
    Enum.reduce_while(program.steps, {:ok, initial_input}, fn step, {:ok, current_data} ->
      case execute_step(step, current_data, program.config) do
        {:ok, next_data} -> {:cont, {:ok, next_data}}
        {:error, reason} -> {:halt, {:error, {step, reason}}}
      end
    end)
  end

  defp execute_step({:validate, schema}, data, config) do
    Exdantic.EnhancedValidator.validate(schema, data, config: config)
  end

  defp execute_step({:transform, transform_fn}, data, _config) do
    transform_fn.(data)
  end

  defp execute_step({:llm_call, signature, llm_fn}, data, config) do
    with {:ok, validated_input} <- DSPySignature.validate_input(signature, data),
         {:ok, llm_response} <- llm_fn.(validated_input),
         {:ok, validated_output} <- DSPySignature.validate_output(signature, llm_response) do
      {:ok, Map.merge(data, validated_output)}
    end
  end
end

# Example: Multi-step reasoning program
reasoning_program = DSPyProgram.new([
  # Step 1: Validate initial input
  {:validate, input_schema},
  
  # Step 2: Extract key information
  {:llm_call, extraction_signature, &extract_key_info/1},
  
  # Step 3: Perform reasoning
  {:llm_call, reasoning_signature, &perform_reasoning/1},
  
  # Step 4: Generate final answer
  {:llm_call, answer_signature, &generate_answer/1},
  
  # Step 5: Validate final output
  {:validate, final_output_schema}
])

# Execute the program
case DSPyProgram.execute(reasoning_program, initial_data) do
  {:ok, final_result} ->
    IO.puts("Program completed successfully")
    final_result
    
  {:error, {step, reason}} ->
    IO.puts("Program failed at step #{inspect(step)}: #{inspect(reason)}")
end
```

## DSPy Field Metadata

Exdantic now supports arbitrary field metadata, which is particularly useful for DSPy-style programming patterns and LLM integrations. This feature allows you to attach custom key-value pairs to fields for various purposes.

### Basic Field Metadata

```elixir
defmodule LLMSignature do
  use Exdantic

  schema do
    # Using options syntax
    field :query, :string, extra: %{
      "__dspy_field_type" => "input",
      "prefix" => "Query:",
      "description" => "The search query"
    }

    # Using do-block syntax with extra macro
    field :response, :string do
      required()
      min_length(10)
      extra("__dspy_field_type", "output")
      extra("prefix", "Response:")
      extra("format_hints", ["complete sentences", "markdown"])
    end
  end
end
```

### Creating DSPy-Style Helper Macros

```elixir
defmodule DSPyHelpers do
  defmacro input_field(name, type, opts \\ []) do
    quote do
      field(unquote(name), unquote(type),
        extra: %{
          "__dspy_field_type" => "input",
          "prefix" => "#{unquote(name)}:"
        }
      )
    end
  end

  defmacro output_field(name, type, opts \\ []) do
    base_map = %{
      "__dspy_field_type" => "output",
      "prefix" => "#{opts[:prefix] || "#{name}:"}"
    }
    extra = Keyword.get(opts, :extra, %{})
    merged = Map.merge(base_map, extra)

    quote do
      field(unquote(name), unquote(type), extra: unquote(Macro.escape(merged)))
    end
  end
end

# Using the helper macros
defmodule QASignature do
  use Exdantic
  import DSPyHelpers

  schema do
    input_field :question, :string
    input_field :context, :string

    output_field :reasoning, :string,
      extra: %{"format_hints" => ["step by step", "logical"]}

    output_field :answer, :string,
      extra: %{"format_hints" => ["concise", "accurate"]}
  end
end
```

### Filtering Fields by Metadata

```elixir
defmodule LLMWorkflow do
  def get_input_fields(schema_module) do
    schema_module.__schema__(:fields)
    |> Enum.filter(fn {_name, meta} ->
      meta.extra["__dspy_field_type"] == "input"
    end)
  end

  def get_output_fields(schema_module) do
    schema_module.__schema__(:fields)
    |> Enum.filter(fn {_name, meta} ->
      meta.extra["__dspy_field_type"] == "output"
    end)
  end

  def generate_prompt(schema_module, input_data) do
    input_fields = get_input_fields(schema_module)
    
    input_fields
    |> Enum.map(fn {name, meta} ->
      prefix = meta.extra["prefix"] || "#{name}:"
      value = Map.get(input_data, name)
      "#{prefix} #{value}"
    end)
    |> Enum.join("\n")
  end
end
```

### Common Field Metadata Patterns

1. **DSPy Integration**:
   ```elixir
   extra: %{
     "__dspy_field_type" => "input" | "output",
     "prefix" => "Question:",
     "format_hints" => ["markdown", "complete sentences"]
   }
   ```

2. **LLM Provider Hints**:
   ```elixir
   extra: %{
     "openai_function_param" => true,
     "anthropic_tool_field" => true,
     "max_tokens" => 500
   }
   ```

3. **Rendering Instructions**:
   ```elixir
   extra: %{
     "render_as" => "list" | "table" | "code",
     "syntax_highlight" => "python",
     "collapsible" => true
   }
   ```

4. **Validation Context**:
   ```elixir
   extra: %{
     "validation_group" => "user_input",
     "sensitive" => true,
     "sanitize" => true
   }
   ```
## Provider-Specific Optimizations

### OpenAI Function Calling

```elixir
defmodule OpenAIIntegration do
  def create_function_schema(schema_module, opts \\ []) do
    # Generate base JSON schema
    json_schema = Exdantic.JsonSchema.from_schema(schema_module)
    
    # Optimize for OpenAI function calling
    optimized_schema = Exdantic.JsonSchema.Resolver.enforce_structured_output(
      json_schema,
      provider: :openai,
      remove_unsupported: true,
      add_required_fields: true
    )
    
    # Format for OpenAI API
    %{
      name: Keyword.get(opts, :name, schema_module |> Module.split() |> List.last()),
      description: Keyword.get(opts, :description, optimized_schema["description"]),
      parameters: optimized_schema
    }
  end

  def validate_function_call(schema_module, arguments) do
    config = Exdantic.Config.create(
      strict: true,
      coercion: :safe,
      extra: :forbid  # OpenAI expects strict schemas
    )
    
    Exdantic.EnhancedValidator.validate(schema_module, arguments, config: config)
  end
end

# Usage with OpenAI
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

# Generate OpenAI function definition
function_def = OpenAIIntegration.create_function_schema(WeatherQuerySchema,
  name: "get_weather",
  description: "Get current weather and optional forecast for a location"
)

# Validate function call arguments
function_args = %{
  "location" => "San Francisco, CA",
  "unit" => "celsius",
  "include_forecast" => "true"  # String that gets coerced to boolean
}

{:ok, validated_args} = OpenAIIntegration.validate_function_call(WeatherQuerySchema, function_args)
```

### Anthropic Tool Use

```elixir
defmodule AnthropicIntegration do
  def create_tool_schema(schema_module, opts \\ []) do
    json_schema = Exdantic.JsonSchema.from_schema(schema_module)
    
    # Optimize for Anthropic tool use
    anthropic_schema = Exdantic.JsonSchema.Resolver.enforce_structured_output(
      json_schema,
      provider: :anthropic
    )
    
    %{
      name: Keyword.get(opts, :name, to_snake_case(schema_module)),
      description: Keyword.get(opts, :description, anthropic_schema["description"]),
      input_schema: anthropic_schema
    }
  end

  defp to_snake_case(module) do
    module
    |> Module.split()
    |> List.last()
    |> Macro.underscore()
  end
end

# Generate Anthropic tool definition
tool_def = AnthropicIntegration.create_tool_schema(WeatherQuerySchema,
  name: "get_weather",
  description: "Retrieve weather information for any location"
)
```

### Generic LLM Optimization

```elixir
defmodule GenericLLMIntegration do
  def optimize_schema_for_llm(schema, opts \\ []) do
    provider = Keyword.get(opts, :provider, :generic)
    flatten = Keyword.get(opts, :flatten, true)
    remove_descriptions = Keyword.get(opts, :remove_descriptions, false)
    
    schema
    |> Exdantic.JsonSchema.Resolver.enforce_structured_output(provider: provider)
    |> Exdantic.JsonSchema.Resolver.optimize_for_llm(
         remove_descriptions: remove_descriptions,
         simplify_unions: true,
         max_properties: 20
       )
    |> maybe_flatten(flatten)
  end

  defp maybe_flatten(schema, true) do
    Exdantic.JsonSchema.Resolver.flatten_schema(schema, max_depth: 3)
  end
  defp maybe_flatten(schema, false), do: schema
end
```

## Dynamic Schema Generation

### Prompt-Based Schema Creation

```elixir
defmodule PromptSchemaGenerator do
  @doc """
  Generate schema from natural language description using LLM.
  """
  def generate_schema_from_prompt(description, opts \\ []) do
    # This would typically involve an LLM call to generate the schema specification
    schema_spec = call_schema_generation_llm(description, opts)
    
    # Convert LLM response to field definitions
    fields = parse_schema_specification(schema_spec)
    
    # Create runtime schema
    Exdantic.Runtime.create_schema(fields,
      title: Keyword.get(opts, :title, "Generated Schema"),
      description: description
    )
  end

  def create_adaptive_schema(sample_data, opts \\ []) do
    # Analyze sample data to infer schema
    inferred_fields = infer_fields_from_data(sample_data)
    
    # Create schema with inferred types
    Exdantic.Runtime.create_schema(inferred_fields,
      title: Keyword.get(opts, :title, "Adaptive Schema"),
      strict: Keyword.get(opts, :strict, false)
    )
  end

  defp infer_fields_from_data(data) when is_map(data) do
    Enum.map(data, fn {key, value} ->
      field_name = if is_binary(key), do: String.to_atom(key), else: key
      field_type = infer_type(value)
      {field_name, field_type, [required: true]}
    end)
  end

  defp infer_type(value) when is_binary(value), do: :string
  defp infer_type(value) when is_integer(value), do: :integer
  defp infer_type(value) when is_float(value), do: :float
  defp infer_type(value) when is_boolean(value), do: :boolean
  defp infer_type(value) when is_list(value) do
    case value do
      [] -> {:array, :any}
      [first | _] -> {:array, infer_type(first)}
    end
  end
  defp infer_type(value) when is_map(value), do: :map
  defp infer_type(_), do: :any
end

# Usage
sample_llm_output = %{
  "analysis" => "The data shows...",
  "confidence" => 0.85,
  "tags" => ["important", "urgent"],
  "metadata" => %{"processed_at" => "2024-01-01"}
}

adaptive_schema = PromptSchemaGenerator.create_adaptive_schema(sample_llm_output,
  title: "LLM Analysis Output",
  strict: true
)
```

## Chain-of-Thought Validation

### Multi-Step Reasoning Validation

```elixir
defmodule ChainOfThoughtValidation do
  defmodule ReasoningStep do
    use Exdantic, define_struct: true

    schema do
      field :step_number, :integer, gt: 0
      field :description, :string, min_length: 10
      field :reasoning, :string, min_length: 20
      field :conclusion, :string, min_length: 5
      field :confidence, :float, gteq: 0.0, lteq: 1.0
      
      computed_field :reasoning_quality, :string, :assess_reasoning_quality
    end

    def assess_reasoning_quality(step) do
      quality = cond do
        String.length(step.reasoning) > 100 && step.confidence > 0.8 -> "high"
        String.length(step.reasoning) > 50 && step.confidence > 0.6 -> "medium"
        true -> "low"
      end
      {:ok, quality}
    end
  end

  defmodule ChainOfThought do
    use Exdantic, define_struct: true

    schema do
      field :question, :string, min_length: 5
      field :reasoning_steps, {:array, ReasoningStep}, min_items: 1
      field :final_answer, :string, min_length: 1
      field :overall_confidence, :float, gteq: 0.0, lteq: 1.0
      
      model_validator :validate_reasoning_chain
      computed_field :reasoning_depth, :integer, :calculate_depth
      computed_field :average_confidence, :float, :calculate_avg_confidence
    end

    def validate_reasoning_chain(input) do
      # Validate that reasoning steps are logically connected
      steps = input.reasoning_steps
      
      # Check step numbering
      expected_numbers = 1..length(steps) |> Enum.to_list()
      actual_numbers = Enum.map(steps, & &1.step_number)
      
      if actual_numbers != expected_numbers do
        {:error, "Reasoning steps must be numbered sequentially starting from 1"}
      else
        # Validate confidence consistency
        step_confidences = Enum.map(steps, & &1.confidence)
        avg_confidence = Enum.sum(step_confidences) / length(step_confidences)
        
        if abs(input.overall_confidence - avg_confidence) > 0.3 do
          {:error, "Overall confidence must align with step confidences"}
        else
          {:ok, input}
        end
      end
    end

    def calculate_depth(input) do
      depth = length(input.reasoning_steps)
      {:ok, depth}
    end

    def calculate_avg_confidence(input) do
      if length(input.reasoning_steps) == 0 do
        {:ok, 0.0}
      else
        avg = input.reasoning_steps
              |> Enum.map(& &1.confidence)
              |> Enum.sum()
              |> Kernel./(length(input.reasoning_steps))
        {:ok, avg}
      end
    end
  end

  def validate_chain_of_thought(llm_response) do
    config = Exdantic.Config.create(coercion: :safe, strict: true)
    
    case Exdantic.EnhancedValidator.validate(ChainOfThought, llm_response, config: config) do
      {:ok, validated_cot} ->
        # Additional quality checks
        quality_score = assess_chain_quality(validated_cot)
        {:ok, validated_cot, quality_score}
        
      {:error, errors} ->
        {:error, errors}
    end
  end

  defp assess_chain_quality(chain_of_thought) do
    %{
      depth_score: min(chain_of_thought.reasoning_depth / 5.0, 1.0),
      confidence_score: chain_of_thought.average_confidence,
      consistency_score: calculate_consistency_score(chain_of_thought),
      overall_score: calculate_overall_score(chain_of_thought)
    }
  end

  defp calculate_consistency_score(cot) do
    # Measure consistency between steps and final answer
    final_confidence = cot.overall_confidence
    avg_confidence = cot.average_confidence
    1.0 - abs(final_confidence - avg_confidence)
  end

  defp calculate_overall_score(cot) do
    quality = assess_chain_quality(cot)
    (quality.depth_score + quality.confidence_score + quality.consistency_score) / 3.0
  end
end

# Example usage
llm_chain_response = %{
  "question" => "What are the environmental impacts of renewable energy?",
  "reasoning_steps" => [
    %{
      "step_number" => 1,
      "description" => "Identify types of renewable energy",
      "reasoning" => "Renewable energy includes solar, wind, hydroelectric, geothermal, and biomass. Each has different environmental footprints.",
      "conclusion" => "Multiple renewable technologies exist with varying impacts",
      "confidence" => 0.9
    },
    %{
      "step_number" => 2,
      "description" => "Analyze positive environmental impacts",
      "reasoning" => "Renewable energy reduces greenhouse gas emissions, air pollution, and dependence on fossil fuels. Solar and wind have minimal operational emissions.",
      "conclusion" => "Renewable energy significantly reduces carbon footprint",
      "confidence" => 0.85
    },
    %{
      "step_number" => 3,
      "description" => "Consider negative environmental impacts",
      "reasoning" => "Manufacturing solar panels requires rare earth metals. Wind turbines can affect bird migration. Hydroelectric dams alter ecosystems.",
      "conclusion" => "Some environmental costs exist but are generally outweighed by benefits",
      "confidence" => 0.8
    }
  ],
  "final_answer" => "Renewable energy has overwhelmingly positive environmental impacts through emission reductions, though some manufacturing and installation impacts exist.",
  "overall_confidence" => "0.83"
}

{:ok, validated_cot, quality} = ChainOfThoughtValidation.validate_chain_of_thought(llm_chain_response)
```

### Iterative Reasoning Validation

```elixir
defmodule IterativeReasoningValidation do
  def validate_iterative_process(iterations) do
    config = Exdantic.Config.create(coercion: :safe, strict: true)
    
    Enum.reduce_while(iterations, {:ok, []}, fn iteration, {:ok, acc} ->
      case validate_single_iteration(iteration, length(acc) + 1, config) do
        {:ok, validated} ->
          {:cont, {:ok, acc ++ [validated]}}
        {:error, errors} ->
          {:halt, {:error, {length(acc) + 1, errors}}}
      end
    end)
  end

  defp validate_single_iteration(iteration, iteration_number, config) do
    # Add iteration context
    iteration_with_context = Map.put(iteration, "iteration_number", iteration_number)
    
    IterationSchema.validate(iteration_with_context)
  end
end

defmodule IterationSchema do
  use Exdantic

  schema do
    field :iteration_number, :integer, gt: 0
    field :hypothesis, :string, min_length: 10
    field :evidence, {:array, :string}, min_items: 1
    field :analysis, :string, min_length: 20
    field :confidence_change, :float, gteq: -1.0, lteq: 1.0
    field :next_steps, {:array, :string}, optional: true
    
    model_validator :validate_iteration_logic
  end

  def validate_iteration_logic(input) do
    # Validate that evidence supports the analysis
    evidence_length = Enum.sum(Enum.map(input.evidence, &String.length/1))
    analysis_length = String.length(input.analysis)
    
    if analysis_length < evidence_length / 2 do
      {:error, "Analysis should be proportional to evidence provided"}
    else
      {:ok, input}
    end
  end
end
```

## Function Calling Integration

### Advanced Function Schema Generation

```elixir
defmodule FunctionCallingIntegration do
  @moduledoc """
  Advanced integration patterns for LLM function calling with full validation.
  """

  defmodule FunctionRegistry do
    use GenServer

    def start_link(opts \\ []) do
      GenServer.start_link(__MODULE__, %{}, name: Keyword.get(opts, :name, __MODULE__))
    end

    def register_function(server \\ __MODULE__, name, schema_module, handler, opts \\ []) do
      GenServer.call(server, {:register, name, schema_module, handler, opts})
    end

    def get_functions_schema(server \\ __MODULE__, provider \\ :openai) do
      GenServer.call(server, {:get_schema, provider})
    end

    def execute_function(server \\ __MODULE__, name, arguments) do
      GenServer.call(server, {:execute, name, arguments})
    end

    # GenServer callbacks
    def init(state) do
      {:ok, state}
    end

    def handle_call({:register, name, schema_module, handler, opts}, _from, state) do
      function_def = %{
        schema: schema_module,
        handler: handler,
        description: Keyword.get(opts, :description, ""),
        examples: Keyword.get(opts, :examples, [])
      }
      
      new_state = Map.put(state, name, function_def)
      {:reply, :ok, new_state}
    end

    def handle_call({:get_schema, provider}, _from, state) do
      schemas = Enum.map(state, fn {name, func_def} ->
        create_function_schema(name, func_def, provider)
      end)
      {:reply, schemas, state}
    end

    def handle_call({:execute, name, arguments}, _from, state) do
      case Map.get(state, name) do
        nil ->
          {:reply, {:error, "Function not found: #{name}"}, state}
        func_def ->
          result = execute_function_safely(func_def, arguments)
          {:reply, result, state}
      end
    end

    defp create_function_schema(name, func_def, provider) do
      json_schema = Exdantic.JsonSchema.from_schema(func_def.schema)
      
      optimized_schema = Exdantic.JsonSchema.Resolver.enforce_structured_output(
        json_schema,
        provider: provider,
        remove_unsupported: true
      )
      
      %{
        name: Atom.to_string(name),
        description: func_def.description || optimized_schema["description"] || "",
        parameters: optimized_schema
      }
    end

    defp execute_function_safely(func_def, arguments) do
      config = Exdantic.Config.create(strict: true, coercion: :safe)
      
      with {:ok, validated_args} <- Exdantic.EnhancedValidator.validate(
             func_def.schema, 
             arguments, 
             config: config
           ),
           {:ok, result} <- func_def.handler.(validated_args) do
        {:ok, result}
      else
        {:error, validation_errors} when is_list(validation_errors) ->
          {:error, "Validation failed: #{format_errors(validation_errors)}"}
        {:error, reason} ->
          {:error, reason}
      end
    end

    defp format_errors(errors) do
      errors
      |> Enum.map(&Exdantic.Error.format/1)
      |> Enum.join("; ")
    end
  end

  # Example function schemas
  defmodule WeatherFunction do
    use Exdantic

    schema "Get current weather for a location" do
      field :location, :string do
        required()
        min_length(2)
        description("City and state or country, e.g., 'San Francisco, CA' or 'London, UK'")
        example("New York, NY")
      end

      field :units, :string do
        choices(["metric", "imperial", "kelvin"])
        default("metric")
        description("Temperature units")
      end

      field :include_forecast, :boolean do
        default(false)
        description("Include 3-day weather forecast")
      end
    end
  end

  defmodule DatabaseQueryFunction do
    use Exdantic

    schema "Execute a database query with parameters" do
      field :query_type, :string do
        choices(["select", "count", "aggregate"])
        required()
        description("Type of database query to execute")
      end

      field :table_name, :string do
        required()
        min_length(1)
        format(~r/^[a-zA-Z][a-zA-Z0-9_]*$/)
        description("Database table name")
      end

      field :filters, {:map, {:string, :any}} do
        optional()
        description("Query filters as key-value pairs")
      end

      field :limit, :integer do
        optional()
        gt(0)
        lteq(1000)
        default(100)
        description("Maximum number of results")
      end

      model_validator :validate_query_safety
    end

    def validate_query_safety(input) do
      # Prevent dangerous queries
      dangerous_patterns = ["drop", "delete", "truncate", "alter"]
      
      if Enum.any?(dangerous_patterns, &String.contains?(String.downcase(input.table_name), &1)) do
        {:error, "Query contains potentially dangerous operations"}
      else
        {:ok, input}
      end
    end
  end

  # Usage example
  def setup_function_registry do
    {:ok, registry} = FunctionRegistry.start_link()

    # Register weather function
    FunctionRegistry.register_function(
      registry,
      :get_weather,
      WeatherFunction,
      &handle_weather_request/1,
      description: "Get current weather and optional forecast for any location worldwide"
    )

    # Register database function  
    FunctionRegistry.register_function(
      registry,
      :query_database,
      DatabaseQueryFunction,
      &handle_database_query/1,
      description: "Query the application database with filters and limits"
    )

    registry
  end

  defp handle_weather_request(args) do
    # Mock weather API call
    weather_data = %{
      location: args.location,
      temperature: 22.5,
      condition: "Partly cloudy",
      humidity: 65,
      units: args.units
    }

    forecast = if args.include_forecast do
      [
        %{date: "2024-01-02", high: 24, low: 18, condition: "Sunny"},
        %{date: "2024-01-03", high: 20, low: 15, condition: "Rainy"},
        %{date: "2024-01-04", high: 23, low: 17, condition: "Cloudy"}
      ]
    else
      nil
    end

    result = if forecast do
      Map.put(weather_data, :forecast, forecast)
    else
      weather_data
    end

    {:ok, result}
  end

  defp handle_database_query(args) do
    # Mock database query
    case args.query_type do
      "select" ->
        {:ok, %{
          table: args.table_name,
          results: [],
          count: 0,
          filters_applied: args.filters || %{}
        }}
      "count" ->
        {:ok, %{
          table: args.table_name,
          total_count: 1542
        }}
      "aggregate" ->
        {:ok, %{
          table: args.table_name,
          aggregations: %{
            avg: 45.7,
            sum: 12890,
            max: 150,
            min: 1
          }
        }}
    end
  end
end

# Setup and usage
registry = FunctionCallingIntegration.setup_function_registry()

# Get OpenAI-compatible function schemas
openai_functions = FunctionCallingIntegration.FunctionRegistry.get_functions_schema(registry, :openai)

# Execute function with validation
{:ok, weather_result} = FunctionCallingIntegration.FunctionRegistry.execute_function(
  registry,
  :get_weather,
  %{
    "location" => "San Francisco, CA",
    "units" => "metric",
    "include_forecast" => true
  }
)
```

## Advanced LLM Patterns

### Multi-Agent Validation

```elixir
defmodule MultiAgentValidation do
  @moduledoc """
  Validation patterns for multi-agent LLM systems with coordination.
  """

  defmodule AgentMessage do
    use Exdantic, define_struct: true

    schema do
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

  defmodule AgentCoordination do
    use Exdantic, define_struct: true

    schema do
      field :coordination_id, :string, required: true
      field :participating_agents, {:array, :string}, min_items: 2
      field :coordination_type, :string, choices: ["consensus", "delegation", "voting", "arbitration"]
      field :messages, {:array, AgentMessage}, min_items: 1
      field :resolution, :string, optional: true
      field :status, :string, choices: ["active", "resolved", "failed"], default: "active"
      
      model_validator :validate_coordination_logic
      computed_field :message_count, :integer, :count_messages
      computed_field :average_confidence, :float, :calculate_avg_confidence
    end

    def validate_coordination_logic(input) do
      # Ensure all message agents are participants
      message_agents = Enum.map(input.messages, & &1.agent_id) |> Enum.uniq()
      unauthorized_agents = message_agents -- input.participating_agents
      
      if unauthorized_agents != [] do
        {:error, "Messages from unauthorized agents: #{inspect(unauthorized_agents)}"}
      else
        # Validate status transitions
        case {input.status, input.resolution} do
          {"resolved", nil} ->
            {:error, "Resolved coordination must have a resolution"}
          {"failed", _} when length(input.messages) < 2 ->
            {:error, "Failed coordination must have at least 2 messages"}
          _ ->
            {:ok, input}
        end
      end
    end

    def count_messages(input) do
      {:ok, length(input.messages)}
    end

    def calculate_avg_confidence(input) do
      if length(input.messages) == 0 do
        {:ok, 0.0}
      else
        avg = input.messages
              |> Enum.map(& &1.confidence)
              |> Enum.sum()
              |> Kernel./(length(input.messages))
        {:ok, avg}
      end
    end
  end

  def validate_agent_interaction(coordination_data) do
    config = Exdantic.Config.create(coercion: :safe, strict: true)
    
    case Exdantic.EnhancedValidator.validate(AgentCoordination, coordination_data, config: config) do
      {:ok, validated_coordination} ->
        # Additional multi-agent validation
        quality_metrics = assess_coordination_quality(validated_coordination)
        {:ok, validated_coordination, quality_metrics}
        
      {:error, errors} ->
        {:error, errors}
    end
  end

  defp assess_coordination_quality(coordination) do
    %{
      participation_balance: calculate_participation_balance(coordination),
      confidence_consistency: calculate_confidence_consistency(coordination),
      resolution_quality: assess_resolution_quality(coordination),
      coordination_efficiency: calculate_coordination_efficiency(coordination)
    }
  end

  defp calculate_participation_balance(coordination) do
    agent_message_counts = coordination.messages
                          |> Enum.group_by(& &1.agent_id)
                          |> Enum.map(fn {_agent, messages} -> length(messages) end)
    
    if length(agent_message_counts) == 0 do
      0.0
    else
      max_messages = Enum.max(agent_message_counts)
      min_messages = Enum.min(agent_message_counts)
      1.0 - (max_messages - min_messages) / max_messages
    end
  end

  defp calculate_confidence_consistency(coordination) do
    confidences = Enum.map(coordination.messages, & &1.confidence)
    
    if length(confidences) == 0 do
      0.0
    else
      mean = Enum.sum(confidences) / length(confidences)
      variance = confidences
                |> Enum.map(&((&1 - mean) ** 2))
                |> Enum.sum()
                |> Kernel./(length(confidences))
      
      # Higher consistency = lower variance
      max(0.0, 1.0 - variance)
    end
  end

  defp assess_resolution_quality(coordination) do
    case {coordination.status, coordination.resolution} do
      {"resolved", resolution} when is_binary(resolution) ->
        # Assess resolution based on length and clarity
        length_score = min(String.length(resolution) / 100.0, 1.0)
        
        # Check for clear decision indicators
        decision_indicators = ["decided", "agreed", "concluded", "resolved"]
        clarity_score = if Enum.any?(decision_indicators, &String.contains?(String.downcase(resolution), &1)) do
          1.0
        else
          0.5
        end
        
        (length_score + clarity_score) / 2.0
        
      _ ->
        0.0
    end
  end

  defp calculate_coordination_efficiency(coordination) do
    # Efficiency based on message count relative to participants
    expected_messages = length(coordination.participating_agents) * 2  # Rough estimate
    actual_messages = length(coordination.messages)
    
    if actual_messages <= expected_messages do
      1.0
    else
      expected_messages / actual_messages
    end
  end
end

# Example usage
multi_agent_data = %{
  "coordination_id" => "coord_001",
  "participating_agents" => ["agent_analyzer", "agent_validator", "agent_synthesizer"],
  "coordination_type" => "consensus",
  "messages" => [
    %{
      "agent_id" => "agent_analyzer",
      "message_type" => "query",
      "content" => "I need analysis of the market data trends for Q4",
      "timestamp" => "2024-01-01T10:00:00Z",
      "confidence" => 0.9,
      "metadata" => %{"priority" => "high"}
    },
    %{
      "agent_id" => "agent_validator",
      "message_type" => "response", 
      "content" => "Market analysis shows strong growth in renewable energy sector, 15% increase over Q3",
      "timestamp" => "2024-01-01T10:05:00Z",
      "confidence" => 0.85,
      "metadata" => %{"data_sources" => ["nasdaq", "sp500"]}
    },
    %{
      "agent_id" => "agent_synthesizer",
      "message_type" => "coordination",
      "content" => "Combining both analyses, recommend investment strategy focusing on green tech",
      "timestamp" => "2024-01-01T10:10:00Z",
      "confidence" => 0.8,
      "metadata" => %{"synthesis_method" => "weighted_average"}
    }
  ],
  "resolution" => "Consensus reached: Increase green tech portfolio allocation by 12%",
  "status" => "resolved"
}

{:ok, validated_coordination, quality_metrics} = 
  MultiAgentValidation.validate_agent_interaction(multi_agent_data)
```

### LLM Pipeline Orchestration

```elixir
defmodule LLMPipelineOrchestration do
  @moduledoc """
  Orchestrate complex LLM pipelines with validation at each stage.
  """

  defmodule PipelineStage do
    use Exdantic, define_struct: true

    schema do
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

  defmodule Pipeline do
    use Exdantic, define_struct: true

    schema do
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

  def execute_pipeline(pipeline, initial_input) do
    config = Exdantic.Config.create(coercion: :safe, strict: true)
    
    with {:ok, validated_pipeline} <- Exdantic.EnhancedValidator.validate(Pipeline, pipeline, config: config),
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
      Map.get(stage.validation_config, :coercion, :safe),
      Map.get(stage.validation_config, :strict, true)
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
          "analysis_result" => "Comprehensive analysis completed",
          "confidence" => 0.85,
          "key_findings" => ["finding1", "finding2"]
        }}
      "synthesis" ->
        {:ok, %{
          "synthesis" => "Combined analysis shows positive trends",
          "recommendations" => ["action1", "action2"],
          "confidence" => 0.9
        }}
      "validation" ->
        {:ok, %{
          "validation_result" => "All checks passed",
          "approved" => true,
          "final_score" => 0.88
        }}
      _ ->
        {:error, "Unknown stage type"}
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

# Example pipeline definition
analysis_pipeline = %{
  "pipeline_id" => "market_analysis_pipeline",
  "stages" => [
    %{
      "stage_name" => "analysis",
      "input_schema" => AnalysisInputSchema,
      "output_schema" => AnalysisOutputSchema,
      "llm_config" => %{"model" => "gpt-4", "temperature" => 0.2},
      "validation_config" => %{"strict" => true, "coercion" => :safe}
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
  "global_config" => %{"timeout" => 30000, "max_tokens" => 2000},
  "error_handling" => "retry_stage"
}

# Execute the pipeline
initial_data = %{
  "market_data" => "Q4 financial reports...",
  "analysis_type" => "trend_analysis",
  "parameters" => %{"time_period" => "quarterly"}
}

case LLMPipelineOrchestration.execute_pipeline(analysis_pipeline, initial_data) do
  {:ok, final_result} ->
    IO.puts("Pipeline completed successfully")
    IO.inspect(final_result)
    
  {:error, {stage_name, reason}} ->
    IO.puts("Pipeline failed at stage #{stage_name}: #{reason}")
end
```

### LLM Output Quality Assessment

```elixir
defmodule LLMQualityAssessment do
  @moduledoc """
  Comprehensive quality assessment for LLM outputs across multiple dimensions.
  """

  defmodule QualityMetrics do
    use Exdantic, define_struct: true

    schema do
      field :coherence_score, :float, gteq: 0.0, lteq: 1.0
      field :relevance_score, :float, gteq: 0.0, lteq: 1.0
      field :factual_accuracy, :float, gteq: 0.0, lteq: 1.0
      field :completeness_score, :float, gteq: 0.0, lteq: 1.0
      field :clarity_score, :float, gteq: 0.0, lteq: 1.0
      field :bias_score, :float, gteq: 0.0, lteq: 1.0  # Higher = less biased
      field :toxicity_score, :float, gteq: 0.0, lteq: 1.0  # Higher = less toxic
      
      computed_field :overall_quality, :float, :calculate_overall_quality
      computed_field :quality_grade, :string, :assign_quality_grade
    end

    def calculate_overall_quality(input) do
      scores = [
        input.coherence_score,
        input.relevance_score, 
        input.factual_accuracy,
        input.completeness_score,
        input.clarity_score,
        input.bias_score,
        input.toxicity_score
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

  defmodule QualityAssessment do
    use Exdantic, define_struct: true

    schema do
      field :content, :string, required: true, min_length: 1
      field :context, :string, optional: true
      field :expected_format, :string, optional: true
      field :domain, :string, optional: true
      field :quality_metrics, QualityMetrics, required: true
      field :assessment_timestamp, :string, required: true
      field :assessor_version, :string, default: "1.0"
      
      model_validator :validate_assessment_consistency
      computed_field :content_length, :integer, :calculate_content_length
      computed_field :assessment_summary, :string, :generate_assessment_summary
    end

    def validate_assessment_consistency(input) do
      metrics = input.quality_metrics
      
      # Check for impossible metric combinations
      cond do
        metrics.factual_accuracy > 0.9 and metrics.bias_score < 0.3 ->
          {:error, "High factual accuracy with high bias is inconsistent"}
        metrics.clarity_score > 0.9 and metrics.coherence_score < 0.5 ->
          {:error, "High clarity with low coherence is inconsistent"}
        true ->
          {:ok, input}
      end
    end

    def calculate_content_length(input) do
      {:ok, String.length(input.content)}
    end

    def generate_assessment_summary(input) do
      grade = input.quality_metrics.quality_grade
      overall = Float.round(input.quality_metrics.overall_quality, 2)
      
      summary = case grade do
        "A" -> "Excellent quality output with high scores across all dimensions"
        "B" -> "Good quality output with minor areas for improvement" 
        "C" -> "Acceptable quality output with some notable issues"
        "D" -> "Below average quality output requiring significant improvement"
        "F" -> "Poor quality output not suitable for use"
      end
      
      {:ok, "#{summary} (Overall: #{overall})"}
    end
  end

  def assess_llm_output(content, context \\ nil, opts \\ []) do
    # Perform multi-dimensional quality assessment
    quality_metrics = %{
      "coherence_score" => assess_coherence(content),
      "relevance_score" => assess_relevance(content, context),
      "factual_accuracy" => assess_factual_accuracy(content, opts),
      "completeness_score" => assess_completeness(content, context),
      "clarity_score" => assess_clarity(content),
      "bias_score" => assess_bias(content),
      "toxicity_score" => assess_toxicity(content)
    }

    assessment_data = %{
      "content" => content,
      "context" => context,
      "expected_format" => Keyword.get(opts, :expected_format),
      "domain" => Keyword.get(opts, :domain),
      "quality_metrics" => quality_metrics,
      "assessment_timestamp" => DateTime.utc_now() |> DateTime.to_iso8601(),
      "assessor_version" => "1.0"
    }

    config = Exdantic.Config.create(coercion: :safe, strict: true)
    Exdantic.EnhancedValidator.validate(QualityAssessment, assessment_data, config: config)
  end

  # Quality assessment algorithms (simplified for example)
  defp assess_coherence(content) do
    # Assess logical flow and consistency
    sentences = String.split(content, ~r/[.!?]+/) |> Enum.filter(&(String.trim(&1) != ""))
    
    if length(sentences) < 2 do
      0.8  # Single sentence, assume coherent
    else
      # Simple heuristic: check for transition words and logical connections
      transition_words = ["however", "therefore", "consequently", "furthermore", "moreover"]
      transition_count = Enum.count(sentences, fn sentence ->
        Enum.any?(transition_words, &String.contains?(String.downcase(sentence), &1))
      end)
      
      base_score = 0.6
      transition_bonus = min(transition_count / length(sentences), 0.3)
      base_score + transition_bonus
    end
  end

  defp assess_relevance(content, context) do
    if is_nil(context) do
      0.7  # Default score when context unavailable
    else
      # Simple keyword overlap analysis
      content_words = extract_keywords(content)
      context_words = extract_keywords(context)
      
      common_words = MapSet.intersection(content_words, context_words)
      union_words = MapSet.union(content_words, context_words)
      
      if MapSet.size(union_words) == 0 do
        0.5
      else
        MapSet.size(common_words) / MapSet.size(union_words)
      end
    end
  end

  defp assess_factual_accuracy(content, opts) do
    domain = Keyword.get(opts, :domain)
    
    # Domain-specific fact checking (simplified)
    case domain do
      "science" -> check_scientific_facts(content)
      "history" -> check_historical_facts(content)
      "mathematics" -> check_mathematical_facts(content)
      _ -> 0.75  # Default score for general content
    end
  end

  defp assess_completeness(content, context) do
    # Assess whether content adequately addresses the context/question
    content_length = String.length(content)
    
    cond do
      content_length < 50 -> 0.4   # Too brief
      content_length < 200 -> 0.7  # Adequate
      content_length < 500 -> 0.9  # Comprehensive
      true -> 0.8  # Very long, might be verbose
    end
  end

  defp assess_clarity(content) do
    # Assess readability and clarity
    sentences = String.split(content, ~r/[.!?]+/) |> Enum.filter(&(String.trim(&1) != ""))
    
    if length(sentences) == 0 do
      0.0
    else
      avg_sentence_length = String.length(content) / length(sentences)
      
      # Optimal sentence length for clarity
      clarity_score = cond do
        avg_sentence_length < 10 -> 0.6   # Too short
        avg_sentence_length < 25 -> 0.9   # Good
        avg_sentence_length < 40 -> 0.7   # Acceptable
        true -> 0.5  # Too long
      end
      
      # Check for complex words (simplified)
      complex_word_ratio = assess_vocabulary_complexity(content)
      clarity_score * (1.0 - complex_word_ratio * 0.3)
    end
  end

  defp assess_bias(content) do
    # Detect potential bias indicators (simplified)
    bias_indicators = [
      "obviously", "clearly", "everyone knows", "it's evident that",
      "undoubtedly", "without question", "always", "never"
    ]
    
    bias_count = Enum.count(bias_indicators, fn indicator ->
      String.contains?(String.downcase(content), indicator)
    end)
    
    # Higher score = less biased
    max(0.0, 1.0 - bias_count * 0.1)
  end

  defp assess_toxicity(content) do
    # Detect toxic language patterns (simplified)
    toxic_patterns = [
      ~r/\b(hate|stupid|idiot|moron)\b/i,
      ~r/\b(kill|die|death)\b/i,
      ~r/\b(racist|sexist)\b/i
    ]
    
    toxic_matches = Enum.count(toxic_patterns, fn pattern ->
      Regex.match?(pattern, content)
    end)
    
    # Higher score = less toxic
    max(0.0, 1.0 - toxic_matches * 0.2)
  end

  # Helper functions
  defp extract_keywords(text) do
    text
    |> String.downcase()
    |> String.replace(~r/[^\w\s]/, "")
    |> String.split()
    |> Enum.filter(&(String.length(&1) > 3))
    |> MapSet.new()
  end

  defp assess_vocabulary_complexity(content) do
    words = String.split(content, ~r/\W+/)
    complex_words = Enum.count(words, &(String.length(&1) > 7))
    
    if length(words) == 0 do
      0.0
    else
      complex_words / length(words)
    end
  end

  defp check_scientific_facts(_content) do
    # Placeholder for scientific fact checking
    0.8
  end

  defp check_historical_facts(_content) do
    # Placeholder for historical fact checking  
    0.75
  end

  defp check_mathematical_facts(_content) do
    # Placeholder for mathematical fact checking
    0.9
  end
end

# Example usage
llm_output = """
Climate change is a significant global challenge that requires immediate action. 
The scientific consensus shows that human activities, particularly greenhouse gas 
emissions, are the primary driver of recent warming trends. However, there are 
various mitigation strategies available, including renewable energy adoption, 
carbon capture technologies, and policy interventions. Therefore, while the 
challenge is substantial, coordinated global efforts can make a meaningful impact.
"""

context = "Explain the current state of climate change and potential solutions"

{:ok, quality_assessment} = LLMQualityAssessment.assess_llm_output(
  llm_output, 
  context,
  domain: "science",
  expected_format: "explanatory_text"
)

IO.puts("Quality Grade: #{quality_assessment.quality_metrics.quality_grade}")
IO.puts("Overall Score: #{quality_assessment.quality_metrics.overall_quality}")
IO.puts("Assessment: #{quality_assessment.assessment_summary}")
```

## Best Practices for LLM Integration

### 1. Schema Design for LLMs

```elixir
# ✅ Good: Clear, specific schema for LLM output
defmodule LLMOptimizedSchema do
  use Exdantic

  schema "Optimized for LLM structured output" do
    field :task_type, :string do
      choices(["analysis", "summary", "extraction", "generation"])
      description("Type of task performed")
    end

    field :result, :string do
      required()
      min_length(10)
      max_length(2000)
      description("Main result or output")
    end

    field :confidence, :float do
      gteq(0.0)
      lteq(1.0)
      description("Confidence level from 0.0 to 1.0")
    end

    field :sources, {:array, :string} do
      optional()
      max_items(10)
      description("Sources or references used")
    end

    # Simple computed field for readability
    computed_field :result_length, :integer, fn input ->
      {:ok, String.length(input.result)}
    end
  end
end

# ❌ Avoid: Overly complex schemas that confuse LLMs
defmodule OverlyComplexSchema do
  use Exdantic

  schema do
    field :deeply_nested_structure, {:map, {:string, {:array, {:map, {:string, :any}}}}}
    field :complex_union, {:union, [{:map, {:string, :integer}}, {:array, :float}, :boolean]}
    field :too_many_choices, :string, choices: [
      "option1", "option2", "option3", "option4", "option5", 
      "option6", "option7", "option8", "option9", "option10"
    ]
  end
end
```

### 2. Error Handling and Retry Logic

```elixir
defmodule LLMErrorHandling do
  def validate_with_retry(schema, llm_output, max_retries \\ 3) do
    validate_with_retry_impl(schema, llm_output, max_retries, [])
  end

  defp validate_with_retry_impl(schema, llm_output, retries_left, errors_history) do
    config = Exdantic.Config.create(coercion: :aggressive, strict: false)
    
    case Exdantic.EnhancedValidator.validate(schema, llm_output, config: config) do
      {:ok, validated} ->
        {:ok, validated}
        
      {:error, errors} when retries_left > 0 ->
        # Analyze errors and provide feedback for retry
        error_feedback = generate_error_feedback(errors)
        IO.puts("Validation failed, providing feedback for retry: #{error_feedback}")
        
        # In practice, you would send the feedback back to the LLM
        # For this example, we'll simulate a corrected response
        corrected_output = simulate_llm_correction(llm_output, errors)
        validate_with_retry_impl(schema, corrected_output, retries_left - 1, [errors | errors_history])
        
      {:error, errors} ->
        {:error, {errors, errors_history}}
    end
  end

  defp generate_error_feedback(errors) do
    errors
    |> Enum.map(fn error ->
      case error.code do
        :required -> "Missing required field: #{Enum.join(error.path, ".")}"
        :type -> "Wrong type for field: #{Enum.join(error.path, ".")}"
        :format -> "Invalid format for field: #{Enum.join(error.path, ".")}"
        _ -> "Validation error: #{error.message}"
      end
    end)
    |> Enum.join("; ")
  end

  defp simulate_llm_correction(original_output, _errors) do
    # In practice, this would involve sending the errors back to the LLM
    # and getting a corrected response
    original_output
  end
end
```

### 3. Performance Optimization

```elixir
defmodule LLMPerformanceOptimization do
  # Create reusable schemas and adapters
  @output_schema Exdantic.Runtime.create_schema([
    {:result, :string, [required: true]},
    {:confidence, :float, [gteq: 0.0, lteq: 1.0]}
  ])

  @validation_config Exdantic.Config.create(coercion: :safe, strict: true)

  def validate_batch_outputs(llm_outputs) do
    Exdantic.EnhancedValidator.validate_many(@output_schema, llm_outputs, config: @validation_config)
  end

  # Cache JSON schemas for prompt generation
  @json_schema_cache :ets.new(:json_schema_cache, [:set, :public, :named_table])

  def get_cached_json_schema(schema_key, schema_module) do
    case :ets.lookup(@json_schema_cache, schema_key) do
      [{^schema_key, json_schema}] ->
        json_schema
      [] ->
        json_schema = Exdantic.JsonSchema.from_schema(schema_module)
        optimized_schema = Exdantic.JsonSchema.Resolver.optimize_for_llm(json_schema)
        :ets.insert(@json_schema_cache, {schema_key, optimized_schema})
        optimized_schema
    end
  end
end
```

### 4. Testing LLM Integration

```elixir
defmodule LLMIntegrationTest do
  use ExUnit.Case

  describe "LLM output validation" do
    test "validates correct LLM output format" do
      llm_response = %{
        "task_type" => "analysis",
        "result" => "Comprehensive analysis of market trends shows positive growth",
        "confidence" => "0.85",  # String that should be coerced
        "sources" => ["report1.pdf", "market_data.csv"]
      }

      assert {:ok, validated} = LLMOptimizedSchema.validate(llm_response)
      assert validated.task_type == "analysis"
      assert is_float(validated.confidence)
      assert validated.confidence == 0.85
    end

    test "handles malformed LLM output gracefully" do
      malformed_response = %{
        "task_type" => "invalid_type",
        "result" => "",  # Too short
        "confidence" => "not_a_number"
      }

      assert {:error, errors} = LLMOptimizedSchema.validate(malformed_response)
      assert length(errors) > 0
      
      # Check specific error types
      error_codes = Enum.map(errors, & &1.code)
      assert :choices in error_codes  # Invalid task_type
      assert :min_length in error_codes  # Empty result
    end
  end

  describe "DSPy signature compatibility" do
    test "generates DSPy-compatible JSON schema" do
      schema = DSPySignature.get_output_json_schema(qa_signature, :openai)
      
      # Verify OpenAI compatibility
      assert schema["type"] == "object"
      assert schema["additionalProperties"] == false
      assert is_map(schema["properties"])
      
      # Verify required fields
      assert is_list(schema["required"])
      assert "answer" in schema["required"]
    end
  end
end
```

## Conclusion

This comprehensive guide demonstrates how Exdantic provides powerful patterns for LLM integration:

1. **Structured Output Validation**: Robust validation of LLM responses with type coercion and error handling
2. **DSPy Integration**: Full support for DSPy programming patterns with signature validation
3. **Provider Optimization**: Specialized JSON Schema generation for different LLM providers
4. **Dynamic Schema Generation**: Runtime schema creation for adaptive LLM applications
5. **Quality Assessment**: Multi-dimensional quality analysis for LLM outputs
6. **Pipeline Orchestration**: Complex multi-stage LLM workflows with validation at each step

Key benefits of using Exdantic for LLM integration:

- **Type Safety**: Ensure LLM outputs conform to expected structure and types
- **Error Recovery**: Graceful handling of malformed LLM responses with retry logic
- **Performance**: Efficient validation with reusable schemas and batch operations
- **Flexibility**: Support for both compile-time and runtime schema definition
- **Standards Compliance**: JSON Schema generation compatible with major LLM providers
- **Quality Assurance**: Comprehensive assessment of LLM output quality across multiple dimensions

Whether you're building simple LLM-powered applications or complex multi-agent systems, Exdantic provides the validation and schema management tools needed for reliable, production-ready AI applications.

## 📚 Practical Examples

For hands-on examples of all the LLM integration patterns covered in this guide, see the [`examples/`](../examples/) directory:

- **LLM Integration Basics**: [`llm_integration.exs`](../examples/llm_integration.exs)
- **DSPy Integration**: [`dspy_integration.exs`](../examples/dspy_integration.exs)
- **Pipeline Orchestration**: [`llm_pipeline_orchestration.exs`](../examples/llm_pipeline_orchestration.exs)
- **Field Metadata for DSPy**: [`field_metadata_dspy.exs`](../examples/field_metadata_dspy.exs)
- **JSON Schema for LLMs**: [`json_schema_resolver.exs`](../examples/json_schema_resolver.exs)
- **Runtime Schema Creation**: [`runtime_schema.exs`](../examples/runtime_schema.exs)

Run any example with:
```bash
mix run examples/<example_name>.exs
```

See [`examples/README.md`](../examples/README.md) for the complete guide with detailed explanations and learning paths.

---

This completes the comprehensive LLM Integration Guide, covering all the advanced patterns and use cases for integrating Exdantic with Large Language Models, from basic output validation to sophisticated multi-agent coordination systems.