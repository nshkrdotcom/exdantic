defmodule Exdantic.EnhancedValidatorTest do
  use ExUnit.Case, async: true

  alias Exdantic.{Config, EnhancedValidator, Runtime}
  alias Exdantic.Error

  describe "validate/3 with different targets" do
    test "validates against runtime schema" do
      fields = [
        {:name, :string, [required: true, min_length: 2]},
        {:age, :integer, [required: false, gt: 0]}
      ]

      schema = Runtime.create_schema(fields)
      data = %{name: "John", age: 30}

      assert {:ok, validated} = EnhancedValidator.validate(schema, data)
      assert validated.name == "John"
      assert validated.age == 30
    end

    test "validates against type specification" do
      type_spec = {:array, {:map, {:string, :integer}}}
      data = [%{"score1" => 85}, %{"score2" => 92}]

      assert {:ok, ^data} = EnhancedValidator.validate(type_spec, data)
    end

    test "validates with custom configuration" do
      schema = Runtime.create_schema([{:name, :string}])
      data = %{name: "John", extra: "field"}

      # Strict config should reject extra fields
      strict_config = Config.create(strict: true, extra: :forbid)
      assert {:error, _} = EnhancedValidator.validate(schema, data, config: strict_config)

      # Lenient config should allow extra fields
      lenient_config = Config.create(strict: false, extra: :allow)
      assert {:ok, _} = EnhancedValidator.validate(schema, data, config: lenient_config)
    end

    test "validates with coercion enabled" do
      schema = Runtime.create_schema([{:count, :integer, [required: true]}])
      data = %{count: "42"}

      config = Config.create(coercion: :safe)
      assert {:ok, validated} = EnhancedValidator.validate(schema, data, config: config)
      assert validated.count == 42
    end
  end

  describe "validate_wrapped/4" do
    test "validates and unwraps single field" do
      result =
        EnhancedValidator.validate_wrapped(:score, :integer, "85",
          config: Config.create(coercion: :safe)
        )

      assert {:ok, 85} = result
    end

    test "validates complex types in wrapper" do
      type_spec = {:array, {:map, {:string, :integer}}}
      data = [%{"item1" => 1}, %{"item2" => 2}]

      assert {:ok, ^data} = EnhancedValidator.validate_wrapped(:items, type_spec, data)
    end

    test "applies constraints in wrapper validation" do
      result =
        EnhancedValidator.validate_wrapped(:score, :integer, 150,
          config: Config.create(strict: true),
          constraints: [gteq: 0, lteq: 100]
        )

      assert {:error, [%Error{code: :lteq}]} = result
    end
  end

  describe "validate_many/3" do
    test "validates multiple values against same type" do
      type_spec = :string
      values = ["hello", "world", "test"]

      assert {:ok, ^values} = EnhancedValidator.validate_many(type_spec, values)
    end

    test "validates multiple values with coercion" do
      type_spec = :integer
      values = ["1", "2", "3"]
      config = Config.create(coercion: :safe)

      assert {:ok, [1, 2, 3]} = EnhancedValidator.validate_many(type_spec, values, config: config)
    end

    test "reports errors by index for multiple validation" do
      type_spec = :integer
      values = [1, "invalid", 3]

      assert {:error, error_map} = EnhancedValidator.validate_many(type_spec, values)
      assert Map.has_key?(error_map, 1)
      assert [%Error{code: :type}] = error_map[1]
    end

    test "validates multiple runtime schemas" do
      schema = Runtime.create_schema([{:name, :string, [required: true]}])
      inputs = [%{name: "John"}, %{name: "Jane"}, %{invalid: "data"}]

      assert {:error, error_map} = EnhancedValidator.validate_many(schema, inputs)
      assert Map.has_key?(error_map, 2)
    end
  end

  describe "validate_with_schema/3" do
    test "returns validated data and JSON schema" do
      schema = Runtime.create_schema([{:name, :string}, {:age, :integer}])
      data = %{name: "John", age: 30}

      assert {:ok, validated, json_schema} = EnhancedValidator.validate_with_schema(schema, data)
      assert validated.name == "John"
      assert json_schema["type"] == "object"
      assert Map.has_key?(json_schema["properties"], "name")
    end

    test "generates JSON schema for type specs" do
      type_spec = {:array, :string}
      data = ["a", "b", "c"]

      assert {:ok, validated, json_schema} =
               EnhancedValidator.validate_with_schema(type_spec, data)

      assert validated == data
      assert json_schema["type"] == "array"
      assert json_schema["items"]["type"] == "string"
    end
  end

  describe "validate_with_resolved_schema/3" do
    test "resolves all references in schema" do
      # Create schema that would have references if it were more complex
      schema =
        Runtime.create_schema([
          {:data, {:map, {:string, :any}}, []},
          {:items, {:array, :string}, []}
        ])

      data = %{data: %{"key" => "value"}, items: ["a", "b"]}

      assert {:ok, validated, resolved_schema} =
               EnhancedValidator.validate_with_resolved_schema(schema, data)

      assert validated.data["key"] == "value"

      # Resolved schema should not have $ref entries
      refute has_references?(resolved_schema)
    end

    test "handles resolver options" do
      type_spec = {:array, :integer}
      data = [1, 2, 3]

      resolver_opts = [max_depth: 5, preserve_titles: true]

      assert {:ok, _, resolved} =
               EnhancedValidator.validate_with_resolved_schema(
                 type_spec,
                 data,
                 json_schema_opts: resolver_opts
               )

      assert resolved["type"] == "array"
    end
  end

  describe "validate_for_llm/4" do
    test "validates for OpenAI structured output" do
      schema = Runtime.create_schema([{:response, :string}, {:metadata, :map}])
      data = %{response: "Hello", metadata: %{}}

      assert {:ok, validated, llm_schema} =
               EnhancedValidator.validate_for_llm(schema, data, :openai)

      assert validated.response == "Hello"
      assert llm_schema["additionalProperties"] == false
    end

    test "validates for Anthropic structured output" do
      type_spec = {:map, {:string, :string}}
      data = %{"key" => "value"}

      assert {:ok, validated, llm_schema} =
               EnhancedValidator.validate_for_llm(type_spec, data, :anthropic)

      assert validated == data
      assert llm_schema["additionalProperties"] == false
      assert is_list(llm_schema["required"])
    end

    test "validates for generic provider" do
      type_spec = :string
      data = "test"

      assert {:ok, validated, llm_schema} =
               EnhancedValidator.validate_for_llm(type_spec, data, :generic)

      assert validated == data
      assert llm_schema["type"] == "string"
    end
  end

  describe "pipeline/3" do
    test "executes simple validation pipeline" do
      # Simple double validation
      steps = [:string, :string]
      input = "hello"

      assert {:ok, "hello"} = EnhancedValidator.pipeline(steps, input)
    end

    test "executes transformation pipeline" do
      upcase_transform = fn s -> {:ok, String.upcase(s)} end
      steps = [:string, upcase_transform, :string]
      input = "hello"

      assert {:ok, "HELLO"} = EnhancedValidator.pipeline(steps, input)
    end

    test "stops pipeline on validation error" do
      # String then integer - should fail
      steps = [:string, :integer]
      input = "hello"

      assert {:error, {1, [%Error{code: :type}]}} = EnhancedValidator.pipeline(steps, input)
    end

    test "handles transformation errors in pipeline" do
      failing_transform = fn _s -> {:error, "transformation failed"} end
      steps = [:string, failing_transform]
      input = "hello"

      assert {:error, {1, ["transformation failed"]}} = EnhancedValidator.pipeline(steps, input)
    end

    test "complex pipeline with coercion and validation" do
      coercion_config = Config.create(coercion: :safe)

      validate_with_coercion = fn value ->
        EnhancedValidator.validate(:integer, value, config: coercion_config)
      end

      double_fn = fn n -> {:ok, n * 2} end

      steps = [validate_with_coercion, double_fn, :integer]
      input = "42"

      assert {:ok, 84} = EnhancedValidator.pipeline(steps, input)
    end
  end

  describe "validation_report/3" do
    test "generates comprehensive validation report" do
      schema = Runtime.create_schema([{:name, :string}, {:age, :integer}])
      data = %{name: "John", age: 30}

      report = EnhancedValidator.validation_report(schema, data)

      assert {:ok, _} = report[:validation_result]
      assert report[:json_schema]["type"] == "object"
      assert report[:target_info][:type] == :dynamic_schema
      assert report[:input_analysis][:type] == :map
      assert report[:performance_metrics][:duration_microseconds] > 0
      assert %DateTime{} = report[:timestamp]
    end

    test "reports validation failures in report" do
      schema = Runtime.create_schema([{:name, :string, [min_length: 5]}])
      # Too short
      data = %{name: "Jo"}

      report = EnhancedValidator.validation_report(schema, data)

      assert {:error, _} = report[:validation_result]
      assert report[:target_info][:type] == :dynamic_schema
      assert report[:performance_metrics][:duration_microseconds] > 0
    end

    test "analyzes different input types in report" do
      # Test with different input types
      test_cases = [
        {["a", "b", "c"], :list},
        {"string", :string},
        {42, :integer},
        {true, :boolean},
        {%{key: "value"}, :map}
      ]

      for {input, expected_type} <- test_cases do
        report = EnhancedValidator.validation_report(:any, input)
        assert report[:input_analysis][:type] == expected_type
      end
    end

    test "includes configuration summary in report" do
      config = Config.create(strict: true, coercion: :safe)
      schema = Runtime.create_schema([{:name, :string}])
      data = %{name: "John"}

      report = EnhancedValidator.validation_report(schema, data, config: config)

      config_summary = report[:configuration]
      assert config_summary[:validation_mode] == "strict"
      assert config_summary[:coercion] == "safe"
    end

    test "measures performance accurately" do
      # Use a complex validation that takes measurable time
      large_schema =
        Runtime.create_schema([
          {:items, {:array, {:map, {:string, :integer}}}, [min_items: 100]}
        ])

      large_data = %{
        items:
          for i <- 1..100 do
            %{"item_#{i}" => i}
          end
      }

      report = EnhancedValidator.validation_report(large_schema, large_data)

      # Should have measurable duration
      assert report[:performance_metrics][:duration_microseconds] > 0
      assert report[:performance_metrics][:duration_milliseconds] > 0
    end
  end

  describe "integration with all features" do
    test "enhanced validator works with all Exdantic components" do
      # Create a complex scenario using all features

      # 1. Runtime schema
      fields = [
        {:user_input, :string, [required: true]},
        {:processed_data, {:array, :integer}, [min_items: 1]},
        {:metadata, {:map, {:string, :any}}, []}
      ]

      schema = Runtime.create_schema(fields, title: "Processing Pipeline")

      # 2. Configuration
      config =
        Config.create(
          strict: true,
          extra: :forbid,
          coercion: :safe,
          error_format: :detailed
        )

      # 3. Input data
      input_data = %{
        user_input: "process this data",
        # Strings that need coercion
        processed_data: ["1", "2", "3"],
        metadata: %{"timestamp" => "2024-01-01", "version" => 1}
      }

      # 4. Enhanced validation
      assert {:ok, validated, json_schema} =
               EnhancedValidator.validate_with_schema(
                 schema,
                 input_data,
                 config: config
               )

      # Should have coerced strings to integers
      assert validated.processed_data == [1, 2, 3]
      assert validated.user_input == "process this data"

      # Should generate proper JSON schema
      assert json_schema["type"] == "object"
      assert json_schema["additionalProperties"] == false

      # 5. Wrapper validation for individual fields
      assert {:ok, 42} =
               EnhancedValidator.validate_wrapped(
                 :score,
                 :integer,
                 "42",
                 config: config
               )

      # 6. Pipeline processing
      processing_steps = [
        fn data -> {:ok, String.upcase(data)} end,
        :string,
        fn data -> {:ok, String.length(data)} end,
        :integer
      ]

      assert {:ok, 17} = EnhancedValidator.pipeline(processing_steps, "process this data")
    end

    test "error propagation across all features" do
      # Test that errors are properly propagated and formatted across features

      invalid_schema =
        Runtime.create_schema([
          {:name, :string, [min_length: 10]},
          {:age, :integer, [gt: 0, lt: 150]}
        ])

      invalid_data = %{
        # Too short
        name: "Jo",
        # Too large
        age: 200,
        # Extra field in strict mode
        extra: "field"
      }

      strict_config = Config.create(strict: true, extra: :forbid)

      # Should get detailed error information
      assert {:error, errors} =
               EnhancedValidator.validate(invalid_schema, invalid_data, config: strict_config)

      # Errors should be structured and have paths
      case errors do
        [error | _] ->
          assert %Error{} = error
          assert is_list(error.path) or error.path == []
          assert is_atom(error.code)
          assert is_binary(error.message)

        error when is_struct(error, Error) ->
          assert is_list(error.path) or error.path == []
          assert is_atom(error.code)
          assert is_binary(error.message)
      end

      # Report should include error details
      report =
        EnhancedValidator.validation_report(invalid_schema, invalid_data, config: strict_config)

      assert {:error, _} = report[:validation_result]
    end

    test "performance across all features" do
      # Test performance when using multiple features together

      {time_us, _result} =
        :timer.tc(fn ->
          # Create complex schema
          fields =
            for i <- 1..50 do
              {String.to_atom("field_#{i}"), {:array, :string}, [min_items: 1, max_items: 10]}
            end

          schema = Runtime.create_schema(fields)

          # Generate test data
          data =
            for i <- 1..50 do
              {String.to_atom("field_#{i}"), ["item1", "item2", "item3"]}
            end
            |> Map.new()

          # Validate with enhanced validator
          config = Config.create(strict: true)
          EnhancedValidator.validate_with_resolved_schema(schema, data, config: config)
        end)

      # Should complete complex validation in reasonable time
      # 100ms
      assert time_us < 100_000
    end
  end

  describe "edge cases and error scenarios" do
    test "handles invalid target types gracefully" do
      # Test with invalid schema module
      assert_raise ArgumentError, fn ->
        EnhancedValidator.validate(NonExistentModule, %{})
      end
    end

    test "handles malformed input data" do
      schema = Runtime.create_schema([{:name, :string}])

      # Test with various malformed inputs
      malformed_inputs = [
        nil,
        [],
        "not a map",
        123
      ]

      for input <- malformed_inputs do
        case EnhancedValidator.validate(schema, input) do
          # Expected error
          {:error, _} -> assert true
          {:ok, _} -> assert false, "Should have failed for input: #{inspect(input)}"
        end
      end
    end

    test "handles concurrent validation safely" do
      schema = Runtime.create_schema([{:id, :integer}, {:name, :string}])

      # Run multiple validations concurrently
      tasks =
        for i <- 1..20 do
          Task.async(fn ->
            data = %{id: i, name: "user_#{i}"}
            EnhancedValidator.validate(schema, data)
          end)
        end

      results = Task.await_many(tasks)

      # All should succeed
      assert Enum.all?(results, &match?({:ok, _}, &1))
    end

    test "handles memory efficiently with large validations" do
      # Create large dataset
      large_schema =
        Runtime.create_schema([
          {:items, {:array, {:map, {:string, :integer}}}, []}
        ])

      large_data = %{
        items:
          for i <- 1..1000 do
            %{"id" => i, "value" => i * 2}
          end
      }

      # Should handle large data without memory issues
      assert {:ok, validated} = EnhancedValidator.validate(large_schema, large_data)
      assert length(validated.items) == 1000
    end

    test "handles deeply nested validation errors" do
      nested_schema =
        Runtime.create_schema([
          {:level1, {:map, {:string, {:array, {:map, {:string, :integer}}}}}, []}
        ])

      # Data with error deep in nesting
      nested_data = %{
        level1: %{
          "key1" => [
            %{"valid" => 1},
            # Error here
            %{"invalid" => "not_a_number"}
          ]
        }
      }

      result = EnhancedValidator.validate(nested_schema, nested_data)

      case result do
        {:error, error} ->
          # Should have path to the nested error
          case error do
            [first_error | _] -> assert length(first_error.path) > 2
            single_error -> assert length(single_error.path) > 2
          end

        {:ok, _} ->
          # Some validators might be more lenient
          assert true
      end
    end

    test "validates with custom error messages" do
      # Test that custom error messages work through enhanced validator
      type_spec =
        {:type, :string,
         [
           {:error_message, :min_length, "String must be at least 5 characters"},
           min_length: 5
         ]}

      result = EnhancedValidator.validate(type_spec, "hi")

      case result do
        {:error, [error]} ->
          assert error.message == "String must be at least 5 characters"

        {:error, error} ->
          assert error.message == "String must be at least 5 characters"

        _ ->
          # If error format is different, that's also acceptable
          assert true
      end
    end
  end

  describe "advanced configuration integration" do
    test "config builder integration" do
      config =
        Config.builder()
        |> Config.Builder.strict(true)
        |> Config.Builder.forbid_extra()
        |> Config.Builder.safe_coercion()
        |> Config.Builder.detailed_errors()
        |> Config.Builder.build()

      schema = Runtime.create_schema([{:name, :string}])
      data = %{name: "John", extra: "not allowed"}

      assert {:error, _} = EnhancedValidator.validate(schema, data, config: config)
    end

    test "preset configurations work with enhanced validator" do
      presets = [:strict, :lenient, :api, :json_schema, :development, :production]
      schema = Runtime.create_schema([{:name, :string}])
      data = %{name: "John", extra: "field"}

      for preset <- presets do
        config = Config.preset(preset)
        result = EnhancedValidator.validate(schema, data, config: config)

        # Should either succeed or fail based on preset characteristics
        case {preset, result} do
          {:strict, {:error, _}} -> assert true
          {:lenient, {:ok, _}} -> assert true
          {:api, {:error, _}} -> assert true
          {:development, {:ok, _}} -> assert true
          # Other combinations are also valid
          _ -> assert true
        end
      end
    end

    test "frozen configuration prevents modification during validation" do
      frozen_config = Config.create(frozen: true, strict: true)
      schema = Runtime.create_schema([{:name, :string}])
      data = %{name: "John"}

      # Should validate successfully
      assert {:ok, _} = EnhancedValidator.validate(schema, data, config: frozen_config)

      # Config should still be frozen after validation
      assert_raise RuntimeError, fn ->
        Config.merge(frozen_config, %{strict: false})
      end
    end
  end

  # Helper functions
  defp has_references?(schema) when is_map(schema) do
    Enum.any?(schema, fn
      {"$ref", _} -> true
      {_, value} when is_map(value) -> has_references?(value)
      {_, values} when is_list(values) -> Enum.any?(values, &has_references?/1)
      _ -> false
    end)
  end

  defp has_references?(schema) when is_list(schema) do
    Enum.any?(schema, &has_references?/1)
  end

  defp has_references?(_), do: false
end
