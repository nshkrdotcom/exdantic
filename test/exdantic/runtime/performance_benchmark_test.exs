defmodule Exdantic.Runtime.PerformanceBenchmarkTest do
  # Don't run async for more accurate timing
  use ExUnit.Case, async: false

  alias Exdantic.Runtime
  alias Exdantic.Runtime.{EnhancedSchema, Validator}

  @moduletag :benchmark

  describe "performance benchmarks" do
    @tag :performance
    test "basic validation performance comparison" do
      # Create comparable schemas
      fields = [
        {:name, :string, [required: true, min_length: 2]},
        {:age, :integer, [optional: true, gt: 0, lt: 150]},
        {:email, :string, [required: true, format: ~r/@/]}
      ]

      dynamic_schema = Runtime.create_schema(fields)
      enhanced_schema = EnhancedSchema.create(fields)

      data = %{name: "John Doe", age: 30, email: "john@example.com"}

      # Benchmark dynamic schema validation
      {dynamic_time, _} =
        :timer.tc(fn ->
          Enum.each(1..1000, fn _ ->
            {:ok, _} = Runtime.validate(data, dynamic_schema)
          end)
        end)

      # Benchmark enhanced schema validation (without enhancements)
      {enhanced_time, _} =
        :timer.tc(fn ->
          Enum.each(1..1000, fn _ ->
            {:ok, _} = EnhancedSchema.validate(data, enhanced_schema)
          end)
        end)

      # Enhanced schema without actual enhancements should be comparable to dynamic schema
      performance_ratio = enhanced_time / dynamic_time

      assert performance_ratio < 1.5,
             "Enhanced schema is #{performance_ratio}x slower than dynamic schema"

      IO.puts("Dynamic schema: #{dynamic_time}μs for 1000 validations")
      IO.puts("Enhanced schema (no enhancements): #{enhanced_time}μs for 1000 validations")
      IO.puts("Performance ratio: #{Float.round(performance_ratio, 2)}x")
    end

    @tag :performance
    test "model validator performance impact" do
      fields = [{:name, :string, [required: true]}, {:value, :integer, [required: true]}]

      # Create schemas with different numbers of model validators
      no_validators = EnhancedSchema.create(fields)

      single_validator =
        EnhancedSchema.create(fields,
          model_validators: [fn data -> {:ok, %{data | name: String.trim(data.name)}} end]
        )

      multiple_validators =
        EnhancedSchema.create(fields,
          model_validators: [
            fn data -> {:ok, %{data | name: String.trim(data.name)}} end,
            fn data -> {:ok, %{data | name: String.upcase(data.name)}} end,
            fn data -> {:ok, %{data | value: data.value + 1}} end
          ]
        )

      data = %{name: "  john  ", value: 10}

      # Benchmark each configuration
      {no_validator_time, _} =
        :timer.tc(fn ->
          Enum.each(1..1000, fn _ ->
            {:ok, _} = EnhancedSchema.validate(data, no_validators)
          end)
        end)

      {single_validator_time, _} =
        :timer.tc(fn ->
          Enum.each(1..1000, fn _ ->
            {:ok, _} = EnhancedSchema.validate(data, single_validator)
          end)
        end)

      {multiple_validator_time, _} =
        :timer.tc(fn ->
          Enum.each(1..1000, fn _ ->
            {:ok, _} = EnhancedSchema.validate(data, multiple_validators)
          end)
        end)

      # Calculate overhead
      single_overhead = (single_validator_time - no_validator_time) / no_validator_time
      multiple_overhead = (multiple_validator_time - no_validator_time) / no_validator_time

      # Overhead should be reasonable
      assert single_overhead < 1.5,
             "Single validator adds #{Float.round(single_overhead * 100, 1)}% overhead"

      assert multiple_overhead < 3.0,
             "Multiple validators add #{Float.round(multiple_overhead * 100, 1)}% overhead"

      IO.puts("No validators: #{no_validator_time}μs")

      IO.puts(
        "Single validator: #{single_validator_time}μs (#{Float.round(single_overhead * 100, 1)}% overhead)"
      )

      IO.puts(
        "Multiple validators: #{multiple_validator_time}μs (#{Float.round(multiple_overhead * 100, 1)}% overhead)"
      )
    end

    @tag :performance
    test "computed field performance impact" do
      fields = [{:first_name, :string, [required: true]}, {:last_name, :string, [required: true]}]

      # Create schemas with different numbers of computed fields
      no_computed = EnhancedSchema.create(fields)

      single_computed =
        EnhancedSchema.create(fields,
          computed_fields: [
            {:full_name, :string, fn data -> {:ok, "#{data.first_name} #{data.last_name}"} end}
          ]
        )

      multiple_computed =
        EnhancedSchema.create(fields,
          computed_fields: [
            {:full_name, :string, fn data -> {:ok, "#{data.first_name} #{data.last_name}"} end},
            {:initials, :string,
             fn data ->
               {:ok, "#{String.first(data.first_name)}#{String.first(data.last_name)}"}
             end},
            {:name_length, :integer,
             fn data -> {:ok, String.length("#{data.first_name} #{data.last_name}")} end}
          ]
        )

      data = %{first_name: "John", last_name: "Doe"}

      # Benchmark each configuration
      {no_computed_time, _} =
        :timer.tc(fn ->
          Enum.each(1..1000, fn _ ->
            {:ok, _} = EnhancedSchema.validate(data, no_computed)
          end)
        end)

      {single_computed_time, _} =
        :timer.tc(fn ->
          Enum.each(1..1000, fn _ ->
            {:ok, _} = EnhancedSchema.validate(data, single_computed)
          end)
        end)

      {multiple_computed_time, _} =
        :timer.tc(fn ->
          Enum.each(1..1000, fn _ ->
            {:ok, _} = EnhancedSchema.validate(data, multiple_computed)
          end)
        end)

      # Calculate overhead
      single_overhead = (single_computed_time - no_computed_time) / no_computed_time
      multiple_overhead = (multiple_computed_time - no_computed_time) / no_computed_time

      # Overhead should be reasonable
      assert single_overhead < 2.0,
             "Single computed field adds #{Float.round(single_overhead * 100, 1)}% overhead"

      assert multiple_overhead < 3.0,
             "Multiple computed fields add #{Float.round(multiple_overhead * 100, 1)}% overhead"

      IO.puts("No computed fields: #{no_computed_time}μs")

      IO.puts(
        "Single computed field: #{single_computed_time}μs (#{Float.round(single_overhead * 100, 1)}% overhead)"
      )

      IO.puts(
        "Multiple computed fields: #{multiple_computed_time}μs (#{Float.round(multiple_overhead * 100, 1)}% overhead)"
      )
    end

    @tag :performance
    test "JSON schema generation performance" do
      # Create schemas with varying complexity
      simple_fields = [{:name, :string, [required: true]}]

      complex_fields = [
        {:name, :string, [required: true, min_length: 2, max_length: 50]},
        {:age, :integer, [optional: true, gt: 0, lt: 150]},
        {:email, :string, [required: true, format: ~r/@/]},
        {:tags, {:array, :string}, [optional: true, min_items: 1]},
        {:metadata, {:map, {:string, :any}}, [optional: true]}
      ]

      simple_dynamic = Runtime.create_schema(simple_fields)
      complex_dynamic = Runtime.create_schema(complex_fields)

      simple_enhanced =
        EnhancedSchema.create(simple_fields,
          computed_fields: [
            {:display_name, :string, fn data -> {:ok, String.upcase(data.name)} end}
          ]
        )

      complex_enhanced =
        EnhancedSchema.create(complex_fields,
          model_validators: [fn data -> {:ok, %{data | name: String.trim(data.name)}} end],
          computed_fields: [
            {:full_display, :string,
             fn data -> {:ok, "#{data.name} (#{data.age || "unknown"})"} end},
            {:tag_count, :integer, fn data -> {:ok, length(Map.get(data, :tags, []))} end}
          ]
        )

      # Benchmark JSON schema generation
      schemas = [
        {"Simple Dynamic", simple_dynamic},
        {"Complex Dynamic", complex_dynamic},
        {"Simple Enhanced", simple_enhanced},
        {"Complex Enhanced", complex_enhanced}
      ]

      results =
        Enum.map(schemas, fn {name, schema} ->
          {time, _} =
            :timer.tc(fn ->
              Enum.each(1..100, fn _ ->
                _json = Validator.to_json_schema(schema)
              end)
            end)

          {name, time}
        end)

      Enum.each(results, fn {name, time} ->
        IO.puts("#{name}: #{time}μs for 100 generations")
      end)

      # Enhanced schemas should not be significantly slower for JSON generation
      [
        {"Simple Dynamic", simple_dynamic_time},
        {"Complex Dynamic", complex_dynamic_time},
        {"Simple Enhanced", simple_enhanced_time},
        {"Complex Enhanced", complex_enhanced_time}
      ] = results

      simple_ratio = simple_enhanced_time / simple_dynamic_time
      complex_ratio = complex_enhanced_time / complex_dynamic_time

      assert simple_ratio < 3.0,
             "Simple enhanced schema JSON generation is #{simple_ratio}x slower"

      assert complex_ratio < 2.0,
             "Complex enhanced schema JSON generation is #{complex_ratio}x slower"
    end

    @tag :performance
    test "memory usage comparison" do
      # Test memory usage of different schema types
      fields = [
        {:name, :string, [required: true]},
        {:age, :integer, [optional: true]},
        {:email, :string, [required: true]}
      ]

      # Force garbage collection before measurement
      :erlang.garbage_collect()
      initial_memory = :erlang.memory(:total)

      # Create many dynamic schemas
      dynamic_schemas =
        Enum.map(1..100, fn i ->
          Runtime.create_schema(fields, title: "Schema #{i}")
        end)

      :erlang.garbage_collect()
      dynamic_memory = :erlang.memory(:total)

      # Create many enhanced schemas
      enhanced_schemas =
        Enum.map(1..100, fn i ->
          validator = fn data -> {:ok, %{data | name: String.trim(data.name)}} end
          computer = fn data -> {:ok, "User: #{data.name}"} end

          EnhancedSchema.create(fields,
            title: "Enhanced Schema #{i}",
            model_validators: [validator],
            computed_fields: [{:display, :string, computer}]
          )
        end)

      :erlang.garbage_collect()
      enhanced_memory = :erlang.memory(:total)

      # Calculate memory usage
      dynamic_usage = dynamic_memory - initial_memory
      enhanced_usage = enhanced_memory - dynamic_memory

      # Enhanced schemas will use more memory due to function storage, but should be reasonable
      memory_ratio = enhanced_usage / dynamic_usage

      assert memory_ratio < 5.0,
             "Enhanced schemas use #{memory_ratio}x more memory than dynamic schemas"

      IO.puts("Dynamic schemas (100): #{dynamic_usage} bytes")
      IO.puts("Enhanced schemas (100): #{enhanced_usage} bytes")
      IO.puts("Memory ratio: #{Float.round(memory_ratio, 2)}x")

      # Clean up references to allow garbage collection
      _cleanup = {dynamic_schemas, enhanced_schemas}
    end

    @tag :performance
    test "validation scalability with field count" do
      # Test how validation performance scales with number of fields
      field_counts = [5, 10, 20, 50]

      results =
        Enum.map(field_counts, fn count ->
          # Create fields
          fields =
            1..count
            |> Enum.map(fn i ->
              {:"field_#{i}", :string, [required: true, min_length: 1]}
            end)

          # Create test data
          data =
            1..count
            |> Enum.map(fn i -> {:"field_#{i}", "value_#{i}"} end)
            |> Map.new()

          # Create schemas
          dynamic_schema = Runtime.create_schema(fields)
          enhanced_schema = EnhancedSchema.create(fields)

          # Benchmark validation
          {dynamic_time, _} =
            :timer.tc(fn ->
              Enum.each(1..500, fn _ ->
                {:ok, _} = Runtime.validate(data, dynamic_schema)
              end)
            end)

          {enhanced_time, _} =
            :timer.tc(fn ->
              Enum.each(1..500, fn _ ->
                {:ok, _} = EnhancedSchema.validate(data, enhanced_schema)
              end)
            end)

          {count, dynamic_time, enhanced_time}
        end)

      IO.puts("\nValidation scalability (500 validations each):")

      Enum.each(results, fn {count, dynamic_time, enhanced_time} ->
        ratio = enhanced_time / dynamic_time

        IO.puts(
          "#{count} fields: Dynamic #{dynamic_time}μs, Enhanced #{enhanced_time}μs (#{Float.round(ratio, 2)}x)"
        )
      end)

      # Check that scaling is roughly linear
      [
        {5, _time5_d, _time5_e},
        {10, time10_d, time10_e},
        {20, time20_d, time20_e},
        {50, time50_d, time50_e}
      ] = results

      # Dynamic schema scaling should be roughly linear
      assert time20_d / time10_d < 3.0, "Dynamic schema scaling is not linear"
      assert time50_d / time20_d < 4.0, "Dynamic schema scaling is not linear"

      # Enhanced schema scaling should also be roughly linear
      assert time20_e / time10_e < 3.0, "Enhanced schema scaling is not linear"
      assert time50_e / time20_e < 4.0, "Enhanced schema scaling is not linear"
    end
  end

  describe "stress tests" do
    test "handles rapid schema creation and destruction" do
      # Create and destroy schemas rapidly to test memory management
      Enum.each(1..1000, fn i ->
        fields = [{:value, :integer, [required: true]}]

        validator = fn data -> {:ok, %{data | value: data.value + i}} end
        computer = fn data -> {:ok, data.value * 2} end

        schema =
          EnhancedSchema.create(fields,
            model_validators: [validator],
            computed_fields: [{:doubled, :integer, computer}]
          )

        # Use schema briefly
        data = %{value: i}
        {:ok, result} = EnhancedSchema.validate(data, schema)

        # Verify result
        # Original + increment
        assert result.value == i + i
        assert result.doubled == (i + i) * 2
      end)

      # Force garbage collection to clean up
      :erlang.garbage_collect()

      # Test should complete without memory errors
      assert true
    end

    test "handles concurrent schema creation" do
      # Create schemas concurrently to test thread safety
      tasks =
        1..50
        |> Enum.map(fn i ->
          Task.async(fn ->
            fields = [{:id, :integer, [required: true]}, {:name, :string, [required: true]}]

            validator = fn data -> {:ok, %{data | name: "User_#{data.id}"}} end
            computer = fn data -> {:ok, "ID: #{data.id}, Name: #{data.name}"} end

            schema =
              EnhancedSchema.create(fields,
                model_validators: [validator],
                computed_fields: [{:display, :string, computer}]
              )

            # Test the schema
            data = %{id: i, name: "test"}
            {:ok, result} = EnhancedSchema.validate(data, schema)

            {i, result}
          end)
        end)

      results = Task.await_many(tasks)

      # All tasks should succeed
      assert length(results) == 50

      # Verify results
      Enum.each(results, fn {i, result} ->
        assert result.id == i
        assert result.name == "User_#{i}"
        assert result.display == "ID: #{i}, Name: User_#{i}"
      end)
    end

    test "handles large data structures in validation" do
      # Test with large nested data structures
      fields = [
        {:items, {:array, {:map, {:string, :any}}}, [required: true]},
        {:metadata, {:map, {:string, :any}}, [optional: true]}
      ]

      # Create large test data
      large_items =
        1..1000
        |> Enum.map(fn i ->
          %{
            "id" => i,
            "name" => "Item #{i}",
            "description" => String.duplicate("x", 100),
            "tags" => ["tag1", "tag2", "tag3"],
            "nested" => %{
              "level1" => %{
                "level2" => %{
                  "value" => i * 100
                }
              }
            }
          }
        end)

      large_metadata =
        1..100
        |> Enum.map(fn i -> {"key_#{i}", "value_#{i}"} end)
        |> Map.new()

      data = %{
        items: large_items,
        metadata: large_metadata
      }

      # Create enhanced schema with processor
      item_processor = fn validated_data ->
        processed_items =
          Enum.map(validated_data.items, fn item ->
            Map.put(item, "processed", true)
          end)

        {:ok, %{validated_data | items: processed_items}}
      end

      item_counter = fn validated_data ->
        {:ok, length(validated_data.items)}
      end

      schema =
        EnhancedSchema.create(fields,
          model_validators: [item_processor],
          computed_fields: [{:item_count, :integer, item_counter}]
        )

      # Validate large data structure
      {time, {:ok, result}} =
        :timer.tc(fn ->
          EnhancedSchema.validate(data, schema)
        end)

      # Verify processing worked
      assert length(result.items) == 1000
      assert result.item_count == 1000
      assert Enum.all?(result.items, fn item -> item["processed"] == true end)

      # Performance should be reasonable (less than 1 second)
      assert time < 1_000_000, "Large data validation took #{time}μs (> 1 second)"

      IO.puts("Large data validation (1000 items): #{time}μs")
    end
  end
end
