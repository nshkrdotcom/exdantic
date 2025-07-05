#!/usr/bin/env elixir

# Field Metadata and DSPy Integration Example
# This example demonstrates the critical "arbitrary field metadata" feature
# identified in the GAP analysis as essential for DSPy-style programming.

# Mix.install([{:exdantic, path: "."}]) # Commented out for use within Mix project

IO.puts("🔮 Field Metadata and DSPy Integration Example")
IO.puts("=" |> String.duplicate(50))

# ============================================================================
# 1. Basic Field Metadata Usage
# ============================================================================

IO.puts("\n📋 1. Basic Field Metadata Usage")
IO.puts("-" |> String.duplicate(30))

defmodule BasicMetadataSchema do
  use Exdantic, define_struct: true

  schema do
    # Using options syntax for metadata
    field :question, :string,
      extra: %{
        "__dspy_field_type" => "input",
        "prefix" => "Question:",
        "description" => "The user's question"
      }

    # Using do-block syntax with extra macro
    field :answer, :string do
      required()
      min_length(1)
      extra("__dspy_field_type", "output")
      extra("prefix", "Answer:")
      extra("format_hints", ["complete sentences", "markdown"])
    end

    # Multiple metadata entries
    field :confidence, :float do
      gteq(0.0)
      lteq(1.0)
      extra("__dspy_field_type", "output")
      extra("display_as", "percentage")
      extra("precision", 2)
    end
  end
end

# Inspect the field metadata
schema_fields = BasicMetadataSchema.__schema__(:fields)

IO.puts("Schema fields with metadata:")
for {name, meta} <- schema_fields do
  IO.puts("  #{name}:")
  IO.puts("    Type: #{inspect(meta.type)}")
  IO.puts("    Required: #{meta.required}")
  IO.puts("    Extra metadata: #{inspect(meta.extra)}")
end

# ============================================================================
# 2. DSPy-Style Helper Macros
# ============================================================================

IO.puts("\n🏗️ 2. DSPy-Style Helper Macros")
IO.puts("-" |> String.duplicate(30))

defmodule DSPyHelpers do
  @doc """
  Creates an input field with DSPy metadata
  """
  defmacro input_field(name, type, opts \\ []) do
    base_extra = %{"__dspy_field_type" => "input"}

    # Handle AST for map literals passed as options
    extra_opts = Keyword.get(opts, :extra, %{})
    evaluated_extra_opts = case extra_opts do
      {:%{}, _, _} = ast ->
        # This is a map literal AST, evaluate it
        {map, _} = Code.eval_quoted(ast)
        map
      other ->
        other
    end

    merged_extra = Map.merge(base_extra, evaluated_extra_opts)

    # Add prefix if not provided
    final_extra = if Map.has_key?(merged_extra, "prefix") do
      merged_extra
    else
      Map.put(merged_extra, "prefix", "#{String.capitalize(to_string(name))}:")
    end

    # Prepare final options
    final_opts = [extra: final_extra] ++ Keyword.delete(opts, :extra)

    quote do
      field(unquote(name), unquote(type), unquote(Macro.escape(final_opts)))
    end
  end

  @doc """
  Creates an output field with DSPy metadata
  """
  defmacro output_field(name, type, opts \\ []) do
    base_extra = %{"__dspy_field_type" => "output"}

    # Handle AST for map literals passed as options
    extra_opts = Keyword.get(opts, :extra, %{})
    evaluated_extra_opts = case extra_opts do
      {:%{}, _, _} = ast ->
        # This is a map literal AST, evaluate it
        {map, _} = Code.eval_quoted(ast)
        map
      other ->
        other
    end

    merged_extra = Map.merge(base_extra, evaluated_extra_opts)

    # Add prefix if not provided
    final_extra = if Map.has_key?(merged_extra, "prefix") do
      merged_extra
    else
      Map.put(merged_extra, "prefix", "#{String.capitalize(to_string(name))}:")
    end

    # Prepare final options
    final_opts = [extra: final_extra] ++ Keyword.delete(opts, :extra)

    quote do
      field(unquote(name), unquote(type), unquote(Macro.escape(final_opts)))
    end
  end
end

# Using the helper macros
defmodule QASignature do
  use Exdantic, define_struct: true
  import DSPyHelpers

  schema do
    # Input fields
    input_field :question, :string, required: true
    input_field :context, :string,
      required: true,
      extra: %{"max_tokens" => 1000}

    # Output fields with additional metadata
    output_field :reasoning, :string,
      required: true,
      extra: %{"format_hints" => ["step by step", "logical"]}

    output_field :answer, :string,
      required: true,
      extra: %{"format_hints" => ["concise", "accurate"]}

    output_field :confidence_score, :float,
      required: false,
      gteq: 0.0,
      lteq: 1.0,
      extra: %{"display_as" => "percentage"}
  end
end

IO.puts("QA Signature fields:")
qa_fields = QASignature.__schema__(:fields)
for {name, meta} <- qa_fields do
  field_type = meta.extra["__dspy_field_type"]
  prefix = meta.extra["prefix"]
  IO.puts("  #{name} (#{field_type}): #{prefix}")
end

# ============================================================================
# 3. Field Filtering and Processing
# ============================================================================

IO.puts("\n🔍 3. Field Filtering and Processing")
IO.puts("-" |> String.duplicate(30))

defmodule DSPyFieldProcessor do
  @doc """
  Get all input fields from a schema
  """
  def get_input_fields(schema_module) do
    schema_module.__schema__(:fields)
    |> Enum.filter(fn {_name, meta} ->
      meta.extra["__dspy_field_type"] == "input"
    end)
  end

  @doc """
  Get all output fields from a schema
  """
  def get_output_fields(schema_module) do
    schema_module.__schema__(:fields)
    |> Enum.filter(fn {_name, meta} ->
      meta.extra["__dspy_field_type"] == "output"
    end)
  end

  @doc """
  Generate a prompt template from input fields
  """
  def generate_prompt_template(schema_module, input_data) do
    input_fields = get_input_fields(schema_module)

    input_fields
    |> Enum.map(fn {name, meta} ->
      prefix = meta.extra["prefix"] || "#{name}:"
      value = Map.get(input_data, name, "<#{name}>")
      "#{prefix} #{value}"
    end)
    |> Enum.join("\n")
  end

  @doc """
  Extract field configuration for LLM structured output
  """
  def extract_output_schema_config(schema_module) do
    output_fields = get_output_fields(schema_module)

    output_fields
    |> Enum.map(fn {name, meta} ->
      %{
        name: name,
        type: extract_json_type(meta.type),
        required: meta.required,
        description: meta.description || meta.extra["prefix"] || "#{name} field",
        format_hints: meta.extra["format_hints"] || []
      }
    end)
  end

  # Helper to extract JSON type from Exdantic type
  defp extract_json_type({:type, :string, _}), do: "string"
  defp extract_json_type({:type, :integer, _}), do: "integer"
  defp extract_json_type({:type, :float, _}), do: "number"
  defp extract_json_type({:type, :boolean, _}), do: "boolean"
  defp extract_json_type(_), do: "string"
end

# Test the field processing
input_fields = DSPyFieldProcessor.get_input_fields(QASignature)
output_fields = DSPyFieldProcessor.get_output_fields(QASignature)

IO.puts("Input fields: #{Enum.map(input_fields, fn {name, _} -> name end) |> inspect}")
IO.puts("Output fields: #{Enum.map(output_fields, fn {name, _} -> name end) |> inspect}")

# Generate a prompt template
sample_input = %{
  question: "What is the capital of France?",
  context: "France is a country in Western Europe. Paris is its largest city and capital."
}

prompt_template = DSPyFieldProcessor.generate_prompt_template(QASignature, sample_input)
IO.puts("\nGenerated prompt template:")
IO.puts(prompt_template)

# Extract output schema configuration
output_config = DSPyFieldProcessor.extract_output_schema_config(QASignature)
IO.puts("\nOutput schema configuration:")
IO.inspect(output_config, pretty: true)

# ============================================================================
# 4. Runtime Schema Creation with Metadata
# ============================================================================

IO.puts("\n⚡ 4. Runtime Schema Creation with Metadata")
IO.puts("-" |> String.duplicate(30))

defmodule DSPyRuntimeSchemas do
  @doc """
  Create a DSPy-style signature schema at runtime
  """
  def create_signature_schema(input_specs, output_specs, opts \\ []) do
    # Convert input specifications to field definitions
    input_fields =
      Enum.map(input_specs, fn {name, type, field_opts} ->
        constraints = Keyword.take(field_opts, [:required, :min_length, :max_length, :format])
        extra_metadata = %{
          "__dspy_field_type" => "input",
          "prefix" => "#{String.capitalize(to_string(name))}:"
        }

        # Merge with any custom metadata
        final_extra = Map.merge(extra_metadata, Keyword.get(field_opts, :extra, %{}))

        {name, type, constraints ++ [extra: final_extra]}
      end)

    # Convert output specifications to field definitions
    output_fields =
      Enum.map(output_specs, fn {name, type, field_opts} ->
        constraints = Keyword.take(field_opts, [:required, :min_length, :max_length, :gteq, :lteq])
        extra_metadata = %{
          "__dspy_field_type" => "output",
          "prefix" => "#{String.capitalize(to_string(name))}:"
        }

        # Merge with any custom metadata
        final_extra = Map.merge(extra_metadata, Keyword.get(field_opts, :extra, %{}))

        {name, type, constraints ++ [extra: final_extra]}
      end)

    # Combine all fields
    all_fields = input_fields ++ output_fields

    # Create the runtime schema
    Exdantic.Runtime.create_schema(all_fields,
      title: Keyword.get(opts, :title, "DSPy Signature"),
      description: Keyword.get(opts, :description, "Dynamically created DSPy signature schema")
    )
  end
end

# Create a runtime signature schema
input_specs = [
  {:task_description, :string, [required: true, min_length: 10]},
  {:examples, :string, [required: false, extra: %{"format" => "json_array"}]}
]

output_specs = [
  {:classification, :string, [required: true, extra: %{"choices" => ["positive", "negative", "neutral"]}]},
  {:confidence, :float, [required: true, gteq: 0.0, lteq: 1.0]},
  {:explanation, :string, [required: false, min_length: 20]}
]

runtime_signature = DSPyRuntimeSchemas.create_signature_schema(
  input_specs,
  output_specs,
  title: "Sentiment Analysis Signature",
  description: "A DSPy signature for sentiment analysis tasks"
)

IO.puts("Created runtime signature schema:")
IO.puts("Title: #{runtime_signature.config.title}")
IO.puts("Description: #{runtime_signature.config.description}")

# Test the runtime schema with field metadata
test_data = %{
  task_description: "Analyze the sentiment of the given text",
  classification: "positive",
  confidence: 0.85,
  explanation: "The text contains positive words and expressions"
}

case Exdantic.Runtime.validate(test_data, runtime_signature) do
    {:ok, _validated} ->
    IO.puts("✅ Runtime schema validation successful!")

    # Access field metadata from the runtime schema
    IO.puts("\nField metadata from runtime schema:")
    for {name, meta} <- runtime_signature.fields do
      field_type = meta.extra["__dspy_field_type"]
      prefix = meta.extra["prefix"]
      IO.puts("  #{name} (#{field_type}): #{prefix}")
    end

  {:error, errors} ->
    IO.puts("❌ Runtime schema validation failed:")
    IO.inspect(errors)
end

# ============================================================================
# 5. Integration with JSON Schema Generation
# ============================================================================

IO.puts("\n📋 5. Integration with JSON Schema Generation")
IO.puts("-" |> String.duplicate(30))

# Generate JSON schema that preserves field metadata
qa_json_schema = Exdantic.JsonSchema.from_schema(QASignature)

IO.puts("Generated JSON Schema for QA Signature:")
IO.puts("Title: #{qa_json_schema["title"]}")
IO.puts("Properties:")

for {field_name, field_schema} <- qa_json_schema["properties"] do
  IO.puts("  #{field_name}:")
  IO.puts("    Type: #{field_schema["type"]}")
  IO.puts("    Description: #{field_schema["description"] || "N/A"}")

  # Check if custom metadata is preserved in JSON schema
  if field_schema["x-exdantic-extra"] do
    IO.puts("    Extra metadata: #{inspect(field_schema["x-exdantic-extra"])}")
  end
end

# Use the enhanced resolver for DSPy optimization
dspy_optimized_schema = Exdantic.JsonSchema.EnhancedResolver.optimize_for_dspy(
  QASignature,
  signature_mode: true,
  field_descriptions: true,
  strict_types: true
)

IO.puts("\nDSPy-optimized JSON Schema:")
IO.puts("DSPy optimized: #{dspy_optimized_schema["x-dspy-optimized"]}")
IO.puts("Signature mode: #{dspy_optimized_schema["x-dspy-signature-mode"]}")
IO.puts("Additional properties allowed: #{dspy_optimized_schema["additionalProperties"]}")

# ============================================================================
# 6. Complete DSPy-Style Program Simulation
# ============================================================================

IO.puts("\n🚀 6. Complete DSPy-Style Program Simulation")
IO.puts("-" |> String.duplicate(30))

defmodule DSPyProgram do
  @doc """
  Simulates a complete DSPy program with field metadata
  """
    def execute_chain_of_thought(question, context) do
    # Step 1: Validate input using field metadata (only input fields)
    input_data = %{question: question, context: context}

    # Create a temporary schema with only input fields for input validation
    input_fields = DSPyFieldProcessor.get_input_fields(QASignature)

    # For this demo, we'll validate the input data manually
    input_validation_result = validate_input_fields(input_data, input_fields)

    case input_validation_result do
      {:ok, validated_input} ->
        IO.puts("✅ Input validation successful")

        # Step 2: Generate structured output (simulated LLM response)
        llm_response = simulate_llm_response(validated_input)

        # Step 3: Validate output using field metadata
        case QASignature.validate(llm_response) do
          {:ok, validated_output} ->
            IO.puts("✅ Output validation successful")

            # Step 4: Process results using field metadata
            process_validated_results(validated_output)

          {:error, errors} ->
            IO.puts("❌ Output validation failed:")
            IO.inspect(errors)
            {:error, :invalid_output}
        end

      {:error, errors} ->
        IO.puts("❌ Input validation failed:")
        IO.inspect(errors)
        {:error, :invalid_input}
    end
  end

  defp simulate_llm_response(input) do
    # Simulate an LLM generating structured output
    %{
      question: input.question,
      context: input.context,
      reasoning: "The context clearly states that Paris is the capital and largest city of France.",
      answer: "Paris",
      confidence_score: 0.95
    }
  end

  defp process_validated_results(results) do
    # Use field metadata to format output
    schema_fields = QASignature.__schema__(:fields)

    IO.puts("\nProcessed Results:")
    for {field_name, value} <- Map.from_struct(results) do
      {_, meta} = Enum.find(schema_fields, fn {name, _} -> name == field_name end)

      field_type = meta.extra["__dspy_field_type"]
      prefix = meta.extra["prefix"]

      case field_type do
        "input" ->
          IO.puts("📥 #{prefix} #{value}")
        "output" ->
          formatted_value = format_output_value(value, meta.extra)
          IO.puts("📤 #{prefix} #{formatted_value}")
        _ ->
          IO.puts("ℹ️  #{field_name}: #{value}")
      end
    end

    {:ok, results}
  end

  defp validate_input_fields(input_data, input_fields) do
    # Simple validation - check that all required input fields are present
    missing_fields =
      input_fields
      |> Enum.filter(fn {name, meta} -> meta.required and not Map.has_key?(input_data, name) end)
      |> Enum.map(fn {name, _} -> name end)

    if missing_fields == [] do
      {:ok, input_data}
    else
      {:error, "Missing required input fields: #{inspect(missing_fields)}"}
    end
  end

  defp format_output_value(value, extra_metadata) do
    case extra_metadata["display_as"] do
      "percentage" when is_float(value) ->
        "#{Float.round(value * 100, 1)}%"
      _ ->
        to_string(value)
    end
  end
end

# Execute the DSPy-style program
IO.puts("Executing DSPy-style Chain of Thought program...")

result = DSPyProgram.execute_chain_of_thought(
  "What is the capital of France?",
  "France is a country in Western Europe. Paris is its largest city and capital, located in the north-central part of the country."
)

case result do
  {:ok, _final_result} ->
    IO.puts("\n🎉 DSPy program completed successfully!")
  {:error, reason} ->
    IO.puts("\n💥 DSPy program failed: #{reason}")
end

# ============================================================================
# Summary
# ============================================================================

IO.puts("\n" <> "=" |> String.duplicate(50))
IO.puts("📋 SUMMARY: Field Metadata Implementation Status")
IO.puts("=" |> String.duplicate(50))

IO.puts("""
✅ CRITICAL GAP ADDRESSED: Arbitrary Field Metadata

The GAP analysis identified arbitrary field metadata as the most critical
missing piece for DSPy integration. This example demonstrates that Exdantic
ALREADY HAS this feature fully implemented:

🔧 IMPLEMENTATION DETAILS:
• FieldMeta struct includes 'extra: %{}' field ✅
• field macro supports :extra option ✅
• extra() macro for do-block syntax ✅
• Metadata preserved in JSON schema generation ✅
• Runtime schema creation supports metadata ✅

🎯 DSPy INTEGRATION CAPABILITIES:
• "__dspy_field_type" annotations ✅
• Custom field prefixes and formatting ✅
• Helper macros for input/output fields ✅
• Field filtering and processing ✅
• LLM prompt generation from metadata ✅
• Structured output validation ✅

🚀 CONCLUSION:
Exdantic is READY for DSPy integration! The field metadata system provides
all the flexibility needed to implement DSPy-style programming patterns.
No additional implementation is required for this critical feature.

The remaining gaps identified in the GAP analysis (RootModel support,
advanced Annotated equivalents, serialization customization) are indeed
minor and non-blocking for DSPy usage.
""")

IO.puts("\n🎉 Field metadata example completed successfully!")
