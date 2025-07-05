# test/struct_pattern/codebase_integration_test.exs
defmodule Exdantic.CodebaseIntegrationTest do
  use ExUnit.Case

  @moduletag :integration

  describe "integration with existing Exdantic features" do
    test "struct pattern works with TypeAdapter" do
      defmodule AdapterStructSchema do
        use Exdantic, define_struct: true

        schema do
          field :value, :integer do
            required()
          end
        end
      end

      # Should work with TypeAdapter validation
      assert {:ok, 42} = Exdantic.TypeAdapter.validate(:integer, "42", coerce: true)

      # Schema validation should still work
      assert {:ok, result} = AdapterStructSchema.validate(%{value: 42})
      assert is_struct(result, AdapterStructSchema)
    end

    test "struct pattern works with JsonSchema generation" do
      defmodule JsonStructSchema do
        use Exdantic, define_struct: true

        schema "Schema with struct" do
          field :name, :string do
            required()
          end

          field :count, :integer do
            optional()
          end
        end
      end

      json_schema = Exdantic.JsonSchema.from_schema(JsonStructSchema)

      # Should generate valid JSON schema regardless of struct option
      assert json_schema["type"] == "object"
      assert Map.has_key?(json_schema, "properties")
      assert "name" in json_schema["required"]
    end

    test "struct pattern works with EnhancedValidator" do
      defmodule EnhancedStructSchema do
        use Exdantic, define_struct: true

        schema do
          field :data, :string do
            required()
          end
        end
      end

      input = %{data: "test"}

      # Enhanced validator should handle struct schemas
      # But since EnhancedValidator doesn't know about struct creation,

      assert {:ok, result} = EnhancedStructSchema.validate(input)
      assert is_struct(result, EnhancedStructSchema)

      # Test that EnhancedValidator can validate the same input against the schema
      # (it will return a map, not a struct, which is expected behavior)
      assert {:ok, map_result} = Exdantic.EnhancedValidator.validate(EnhancedStructSchema, input)
      assert is_map(map_result)
      assert map_result.data == "test"
    end

    test "struct pattern works with Runtime schemas" do
      # Runtime schemas don't support structs, but should coexist peacefully
      fields = [{:name, :string, [required: true]}]
      runtime_schema = Exdantic.Runtime.create_schema(fields)

      data = %{name: "test"}
      assert {:ok, result} = Exdantic.Runtime.validate(data, runtime_schema)
      assert is_map(result)
      refute is_struct(result)
    end

    test "struct pattern preserves all existing error behaviors" do
      defmodule ErrorStructSchema do
        use Exdantic, define_struct: true

        schema do
          field :email, :string do
            required()
            format(~r/@/)
          end
        end
      end

      # Should produce same error structure as non-struct schemas
      assert {:error, errors} = ErrorStructSchema.validate(%{email: "invalid"})

      # Handle both single error and list of errors
      errors_list = if is_list(errors), do: errors, else: [errors]
      assert is_list(errors_list)
      assert length(errors_list) > 0

      error = hd(errors_list)
      assert %Exdantic.Error{} = error
      assert error.code == :format
      assert is_list(error.path)
    end
  end

  describe "memory and performance characteristics" do
    @tag :performance
    test "struct schemas don't significantly impact compilation time" do
      compilation_time = fn ->
        :timer.tc(fn ->
          defmodule CompileTimeTestStruct do
            use Exdantic, define_struct: true

            schema do
              Enum.each(1..50, fn i ->
                field(String.to_atom("field_#{i}"), :string, required: false)
              end)
            end
          end
        end)
      end

      {compile_time_micro, _} = compilation_time.()
      compile_time_ms = compile_time_micro / 1000

      # Should compile reasonably quickly even with many fields
      assert compile_time_ms < 1000, "Compilation took #{compile_time_ms}ms"
    end

    @tag :memory_profile
    test "struct validation memory usage is bounded" do
      defmodule MemoryTestStruct do
        use Exdantic, define_struct: true

        schema do
          field :data, :string do
            required()
          end
        end
      end

      # Measure memory before
      :erlang.garbage_collect()
      memory_before = :erlang.process_info(self(), :memory) |> elem(1)

      # Perform many validations
      data = %{data: "test data"}

      Enum.each(1..1000, fn _ ->
        {:ok, _result} = MemoryTestStruct.validate(data)
      end)

      # Force garbage collection and measure after
      :erlang.garbage_collect()
      memory_after = :erlang.process_info(self(), :memory) |> elem(1)

      memory_growth = memory_after - memory_before

      # Memory growth should be reasonable (less than 1MB for 1000 validations)
      assert memory_growth < 1_000_000, "Memory grew by #{memory_growth} bytes"
    end
  end
end
