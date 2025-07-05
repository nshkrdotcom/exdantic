# test/test_helper.exs

ExUnit.start()

# Load test support modules
Code.require_file("support/model_validator_test_schemas.ex", __DIR__)

# Additional test configuration and helpers
ExUnit.configure(
  exclude: [:slow, :integration, :performance, :memory_profile],
  timeout: 30_000,
  max_failures: 10
)

# Add Stream data for property-based testing if available
if Code.ensure_loaded?(StreamData) do
  # Deterministic for property tests
  ExUnit.configure(seed: 0)
end

if System.get_env("COVERAGE") do
  ExUnit.configure(
    include: [:performance, :integration],
    formatters: [ExUnit.CLIFormatter, ExUnit.Formatter.HTML]
  )
end

defmodule TestHelpers do
  @moduledoc """
  Helper functions for Exdantic tests.
  """

  import ExUnit.Assertions

  @doc """
  Creates a temporary test schema for testing purposes.
  """
  def create_test_schema(fields \\ nil) do
    default_fields = [
      {:name, :string, [required: true, min_length: 1]},
      {:age, :integer, [required: false, gt: 0]},
      {:email, :string, [required: true, format: ~r/@/]}
    ]

    Exdantic.Runtime.create_schema(fields || default_fields, title: "Test Schema")
  end

  @doc """
  Creates test data that matches the default test schema.
  """
  def create_test_data(overrides \\ %{}) do
    default_data = %{
      name: "John Doe",
      age: 30,
      email: "john@example.com"
    }

    Map.merge(default_data, overrides)
  end

  @doc """
  Asserts that a validation result is successful and returns the validated data.
  """
  def assert_valid(result) do
    case result do
      {:ok, validated} ->
        validated

      {:error, errors} ->
        flunk("Expected validation to succeed, but got errors: #{inspect(errors)}")
    end
  end

  @doc """
  Asserts that a validation result failed with the expected error code.
  """
  def assert_invalid(result, expected_code \\ nil) do
    case result do
      {:error, errors} when is_list(errors) ->
        if expected_code do
          assert Enum.any?(errors, &(&1.code == expected_code)),
                 "Expected error code #{expected_code}, but got: #{inspect(Enum.map(errors, & &1.code))}"
        end

        errors

      {:error, error} ->
        if expected_code do
          assert error.code == expected_code,
                 "Expected error code #{expected_code}, but got: #{error.code}"
        end

        error

      {:ok, _} ->
        flunk("Expected validation to fail, but it succeeded")
    end
  end

  @doc """
  Measures execution time of a function in microseconds.
  """
  def measure_time(fun) when is_function(fun, 0) do
    :timer.tc(fun)
  end

  @doc """
  Asserts that execution time is within expected bounds.
  """
  def assert_performance(fun, max_time_us) when is_function(fun, 0) do
    {time_us, result} = measure_time(fun)

    assert time_us <= max_time_us,
           "Execution took #{time_us}μs, expected <= #{max_time_us}μs"

    result
  end

  @doc """
  Creates a large dataset for performance testing.
  """
  def create_large_dataset(size \\ 1000) do
    for i <- 1..size do
      %{
        "id" => i,
        "name" => "item_#{i}",
        "value" => :rand.uniform(100),
        "active" => rem(i, 2) == 0,
        "tags" => ["tag_#{rem(i, 5)}", "tag_#{rem(i, 3)}"]
      }
    end
  end

  @doc """
  Runs a function concurrently across multiple processes.
  """
  def run_concurrent(fun, count \\ 10) when is_function(fun, 1) do
    tasks =
      for i <- 1..count do
        Task.async(fn -> fun.(i) end)
      end

    Task.await_many(tasks, 30_000)
  end

  @doc """
  Asserts that all results in a list are successful.
  """
  def assert_all_valid(results) do
    for result <- results do
      assert_valid(result)
    end
  end

  @doc """
  Creates a complex nested type specification for testing.
  """
  def complex_type_spec do
    {:map,
     {:string,
      {:union,
       [
         :string,
         :integer,
         {:array, :string},
         {:map, {:string, :any}}
       ]}}}
  end

  @doc """
  Creates complex nested test data.
  """
  def complex_test_data do
    %{
      "simple_string" => "value",
      "simple_number" => 42,
      "array_data" => ["item1", "item2", "item3"],
      "nested_map" => %{
        "inner_key" => "inner_value",
        "inner_number" => 123
      }
    }
  end

  @doc """
  Validates that a JSON schema has the expected structure.
  """
  def assert_valid_json_schema(schema) do
    # Basic JSON Schema validation
    assert is_map(schema)

    assert Map.has_key?(schema, "type") or Map.has_key?(schema, "oneOf") or
             Map.has_key?(schema, "anyOf")

    # If it's an object schema, should have properties
    if schema["type"] == "object" do
      assert Map.has_key?(schema, "properties")
      assert is_map(schema["properties"])
    end

    # If it has required fields, they should be a list
    if Map.has_key?(schema, "required") do
      assert is_list(schema["required"])
    end

    schema
  end

  @doc """
  Creates a test configuration with common settings.
  """
  def test_config(overrides \\ %{}) do
    base_config = %{
      strict: false,
      extra: :allow,
      coercion: :safe,
      error_format: :detailed
    }

    Exdantic.Config.create(Map.merge(base_config, overrides))
  end

  @doc """
  Asserts that two schemas are equivalent (ignoring field order).
  """
  def assert_schemas_equivalent(schema1, schema2) do
    # Normalize both schemas for comparison
    norm1 = normalize_schema(schema1)
    norm2 = normalize_schema(schema2)

    assert norm1 == norm2, """
    Schemas are not equivalent:
    Schema 1: #{inspect(norm1)}
    Schema 2: #{inspect(norm2)}
    """
  end

  @doc """
  Normalizes a schema for comparison by sorting maps and lists.
  """
  def normalize_schema(schema) when is_map(schema) do
    schema
    |> Enum.sort()
    |> Enum.map(fn {k, v} -> {k, normalize_schema(v)} end)
    |> Map.new()
  end

  def normalize_schema(schema) when is_list(schema) do
    Enum.map(schema, &normalize_schema/1)
  end

  def normalize_schema(schema), do: schema

  @doc """
  Creates mock LLM provider configurations for testing.
  """
  def mock_llm_providers do
    %{
      openai: %{
        supports_additional_properties: false,
        supports_refs: false,
        max_depth: 3,
        unsupported_formats: [:date, :time]
      },
      anthropic: %{
        supports_additional_properties: false,
        supports_refs: true,
        max_depth: 5,
        unsupported_formats: [:uri, :uuid]
      },
      generic: %{
        supports_additional_properties: true,
        supports_refs: true,
        max_depth: 10,
        unsupported_formats: []
      }
    }
  end

  @doc """
  Generates random test data for stress testing.
  """
  def random_test_data(type_spec, count \\ 100) do
    for _ <- 1..count do
      generate_random_value(type_spec)
    end
  end

  defp generate_random_value(:string) do
    "test_string_#{:rand.uniform(1000)}"
  end

  defp generate_random_value(:integer) do
    :rand.uniform(1000)
  end

  defp generate_random_value(:boolean) do
    :rand.uniform(2) == 1
  end

  defp generate_random_value(:float) do
    :rand.uniform() * 100
  end

  defp generate_random_value({:array, inner_type}) do
    size = :rand.uniform(5)

    for _ <- 1..size do
      generate_random_value(inner_type)
    end
  end

  defp generate_random_value({:map, {key_type, value_type}}) do
    size = :rand.uniform(3)

    for _i <- 1..size do
      {generate_random_value(key_type), generate_random_value(value_type)}
    end
    |> Map.new()
  end

  defp generate_random_value({:union, types}) do
    random_type = Enum.random(types)
    generate_random_value(random_type)
  end

  defp generate_random_value(_), do: "unknown_type"

  # Helper functions for enhanced schema tests
  def trim_name(data) do
    {:ok, %{data | name: String.trim(data.name)}}
  end

  def upcase_name(data) do
    {:ok, String.upcase(data.name)}
  end

  def validate_name(data) do
    if String.length(data.name) > 0 do
      {:ok, data}
    else
      {:error, "name cannot be empty"}
    end
  end
end

# Performance test configuration
defmodule PerformanceTestHelpers do
  @moduledoc """
  Helpers specifically for performance testing.
  """

  @doc """
  Runs a benchmark and returns timing statistics.
  """
  def benchmark(name, fun, iterations \\ 100) do
    IO.puts("Running benchmark: #{name}")

    times =
      for _ <- 1..iterations do
        {time, _result} = :timer.tc(fun)
        time
      end

    avg_time = Enum.sum(times) / length(times)
    min_time = Enum.min(times)
    max_time = Enum.max(times)

    IO.puts("  Average: #{Float.round(avg_time, 2)}μs")
    IO.puts("  Min: #{min_time}μs")
    IO.puts("  Max: #{max_time}μs")

    %{
      name: name,
      average: avg_time,
      min: min_time,
      max: max_time,
      iterations: iterations
    }
  end

  @doc """
  Compares performance between two functions.
  """
  def compare_performance(name1, fun1, name2, fun2, iterations \\ 100) do
    result1 = benchmark(name1, fun1, iterations)
    result2 = benchmark(name2, fun2, iterations)

    ratio = result1.average / result2.average

    IO.puts("\nPerformance comparison:")
    IO.puts("  #{name1}: #{Float.round(result1.average, 2)}μs")
    IO.puts("  #{name2}: #{Float.round(result2.average, 2)}μs")
    IO.puts("  Ratio: #{Float.round(ratio, 2)}x")

    %{
      first: result1,
      second: result2,
      ratio: ratio
    }
  end
end

# Memory test helpers
defmodule MemoryTestHelpers do
  @moduledoc """
  Helpers for testing memory usage and garbage collection.
  """

  import ExUnit.Assertions

  @doc """
  Measures memory usage before and after running a function.
  """
  def measure_memory(fun) do
    :erlang.garbage_collect()
    {memory_before, _} = :erlang.process_info(self(), :memory)

    result = fun.()

    :erlang.garbage_collect()
    {memory_after, _} = :erlang.process_info(self(), :memory)

    memory_used = memory_after - memory_before

    {result, memory_used}
  end

  @doc """
  Asserts that memory usage is within acceptable bounds.
  """
  def assert_memory_usage(fun, max_memory_bytes) do
    {result, memory_used} = measure_memory(fun)

    assert memory_used <= max_memory_bytes,
           "Memory usage #{memory_used} bytes exceeded limit #{max_memory_bytes} bytes"

    result
  end
end
