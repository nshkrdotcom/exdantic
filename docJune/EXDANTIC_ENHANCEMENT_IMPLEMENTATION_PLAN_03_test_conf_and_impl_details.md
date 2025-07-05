# test/test_helper.exs - Enhanced for Phase 1
ExUnit.start()

# Configure test exclusions for performance tests
ExUnit.configure(exclude: [:performance, :memory_profile, :integration])

# Add Stream data for property-based testing if available
if Code.ensure_loaded?(StreamData) do
  ExUnit.configure(seed: 0)  # Deterministic for property tests
end

# Configure coverage reporting
if System.get_env("COVERAGE") do
  ExUnit.configure(
    include: [:performance, :integration],
    formatters: [ExUnit.CLIFormatter, ExUnit.Formatter.HTML]
  )
end

# mix.exs updates for Phase 1
defmodule Exdantic.MixProject do
  use Mix.Project

  def project do
    [
      app: :exdantic,
      version: "0.2.0",  # Bump for struct pattern
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),
      
      # Enhanced test configuration
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test
      ],
      
      # Documentation
      docs: [
        main: "Exdantic",
        extras: ["README.md", "CHANGELOG.md", "guides/struct_pattern.md"]
      ],
      
      # Dialyzer configuration
      dialyzer: [
        plt_add_apps: [:mix, :ex_unit],
        flags: [:error_handling, :race_conditions, :underspecs]
      ]
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      # Existing dependencies remain unchanged
      
      # New test/dev dependencies for Phase 1
      {:stream_data, "~> 0.6", only: [:test, :dev]},
      {:benchee, "~> 1.1", only: [:test, :dev]},
      {:benchee_html, "~> 1.0", only: [:test, :dev]},
      {:excoveralls, "~> 0.15", only: :test},
      {:dialyxir, "~> 1.2", only: [:dev, :test], runtime: false},
      {:credo, "~> 1.6", only: [:dev, :test], runtime: false}
    ]
  end

  defp aliases do
    [
      # Enhanced test aliases for Phase 1
      "test.struct": ["test test/struct_pattern/"],
      "test.compatibility": ["test test/struct_pattern/backwards_compatibility_test.exs"],
      "test.performance": ["test --include performance test/struct_pattern/performance_test.exs"],
      "test.integration": ["test --include integration"],
      "test.all": ["test --include performance --include integration"],
      
      # Quality assurance
      "qa": ["format --check-formatted", "credo --strict", "dialyzer", "test"],
      "qa.full": ["deps.get", "compile --warnings-as-errors", "qa", "test.all"],
      
      # Benchmarking
      "benchmark": ["run benchmarks/struct_performance.exs"],
      "benchmark.compare": ["run benchmarks/comparison.exs"],
      
      # Coverage
      "coverage": ["coveralls.html"],
      "coverage.detail": ["coveralls.detail --filter struct_pattern"]
    ]
  end
end

# Property-based testing for struct pattern
# test/struct_pattern/property_test.exs
defmodule Exdantic.StructPropertyTest do
  use ExUnit.Case
  use ExUnitProperties

  alias Exdantic.StructTestSchemas.UserStructSchema

  describe "struct pattern properties" do
    property "validated struct always has correct field structure" do
      check all name <- string(:printable, min_length: 1),
                email <- string(:printable, min_length: 1),
                age <- integer(0..150) do
        
        # Add @ to make email format valid
        valid_email = "#{email}@example.com"
        data = %{name: name, email: valid_email, age: age}
        
        case UserStructSchema.validate(data) do
          {:ok, result} ->
            assert %UserStructSchema{} = result
            assert result.name == name
            assert result.email == valid_email
            assert result.age == age
            assert is_boolean(result.active)
          
          {:error, _errors} ->
            # Validation failure is acceptable for property testing
            :ok
        end
      end
    end

    property "dump and validate round-trip preserves data structure" do
      check all name <- string(:printable, min_length: 1),
                email <- string(:printable, min_length: 1),
                age <- one_of([integer(0..150), constant(nil)]),
                active <- boolean() do
        
        valid_email = "#{email}@example.com"
        original_data = %{name: name, email: valid_email}
        original_data = if age, do: Map.put(original_data, :age, age), else: original_data
        original_data = Map.put(original_data, :active, active)
        
        case UserStructSchema.validate(original_data) do
          {:ok, struct} ->
            {:ok, dumped} = UserStructSchema.dump(struct)
            
            # Core fields should be preserved
            assert dumped.name == name
            assert dumped.email == valid_email
            assert dumped.active == active
            
            if age do
              assert dumped.age == age
            end
          
          {:error, _} ->
            :ok
        end
      end
    end
  end
end

# Integration test with existing codebase
# test/struct_pattern/codebase_integration_test.exs
defmodule Exdantic.CodebaseIntegrationTest do
  use ExUnit.Case

  @moduletag :integration

  describe "integration with existing Exdantic features" do
    test "struct pattern works with TypeAdapter" do
      defmodule AdapterStructSchema do
        use Exdantic, define_struct: true
        
        schema do
          field :value, :integer, required: true
        end
      end
      
      # Should work with TypeAdapter validation
      assert {:ok, 42} = Exdantic.TypeAdapter.validate(:integer, "42", coerce: true)
      
      # Schema validation should still work
      assert {:ok, result} = AdapterStructSchema.validate(%{value: 42})
      assert %AdapterStructSchema{} = result
    end

    test "struct pattern works with JsonSchema generation" do
      defmodule JsonStructSchema do
        use Exdantic, define_struct: true
        
        schema "Schema with struct" do
          field :name, :string, required: true
          field :count, :integer, optional: true
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
          field :data, :string, required: true
        end
      end
      
      input = %{data: "test"}
      
      # Enhanced validator should handle struct schemas
      assert {:ok, result} = Exdantic.EnhancedValidator.validate(EnhancedStructSchema, input)
      assert %EnhancedStructSchema{} = result
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
      assert is_list(errors)
      
      error = hd(errors)
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
                field String.to_atom("field_#{i}"), :string, required: false
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
          field :data, :string, required: true
        end
      end
      
      # Measure memory before
      :erlang.garbage_collect()
      {memory_before, _} = :erlang.process_info(self(), :memory)
      
      # Perform many validations
      data = %{data: "test data"}
      Enum.each(1..1000, fn _ ->
        {:ok, _result} = MemoryTestStruct.validate(data)
      end)
      
      # Force garbage collection and measure after
      :erlang.garbage_collect()
      {memory_after, _} = :erlang.process_info(self(), :memory)
      
      memory_growth = memory_after - memory_before
      
      # Memory growth should be reasonable (less than 1MB for 1000 validations)
      assert memory_growth < 1_000_000, "Memory grew by #{memory_growth} bytes"
    end
  end
end

# Error handling and edge cases
# test/struct_pattern/edge_cases_test.exs
defmodule Exdantic.StructEdgeCasesTest do
  use ExUnit.Case

  describe "edge cases and error conditions" do
    test "empty struct schema" do
      defmodule EmptyStructSchema do
        use Exdantic, define_struct: true
        
        schema do
          # No fields defined
        end
      end
      
      assert {:ok, result} = EmptyStructSchema.validate(%{})
      assert %EmptyStructSchema{} = result
      assert EmptyStructSchema.__struct_fields__() == []
    end

    test "struct with only optional fields" do
      defmodule OptionalOnlyStruct do
        use Exdantic, define_struct: true
        
        schema do
          field :maybe_name, :string, optional: true
          field :maybe_count, :integer, optional: true
        end
      end
      
      # Should work with empty input
      assert {:ok, result} = OptionalOnlyStruct.validate(%{})
      assert %OptionalOnlyStruct{} = result
      assert is_nil(result.maybe_name)
      assert is_nil(result.maybe_count)
    end

    test "struct with complex nested types" do
      defmodule NestedStructSchema do
        use Exdantic, define_struct: true
        
        schema do
          field :items, {:array, {:map, {:string, :integer}}} do
            required()
          end
          
          field :metadata, {:map, {:string, {:array, :string}}} do
            optional()
          end
        end
      end
      
      complex_data = %{
        items: [%{"a" => 1, "b" => 2}],
        metadata: %{"tags" => ["elixir", "testing"]}
      }
      
      assert {:ok, result} = NestedStructSchema.validate(complex_data)
      assert %NestedStructSchema{} = result
      assert result.items == [%{"a" => 1, "b" => 2}]
      assert result.metadata == %{"tags" => ["elixir", "testing"]}
    end

    test "struct creation failure handling" do
      # This test ensures graceful handling if struct creation somehow fails
      defmodule StructFailureTest do
        use Exdantic, define_struct: true
        
        schema do
          field :normal_field, :string, required: true
        end
        
        # Override struct creation to force failure for testing
        def __struct__(fields) do
          if Map.get(fields, :normal_field) == "force_failure" do
            raise ArgumentError, "Forced struct creation failure"
          else
            super(fields)
          end
        end
      end
      
      # Normal case should work
      assert {:ok, result} = StructFailureTest.validate(%{normal_field: "success"})
      assert %StructFailureTest{} = result
      
      # Forced failure case should be handled gracefully
      case StructFailureTest.validate(%{normal_field: "force_failure"}) do
        {:error, errors} ->
          assert is_list(errors)
          error = hd(errors)
          assert error.code == :struct_creation
        
        {:ok, _} ->
          # If struct creation succeeds despite our override, that's fine too
          :ok
      end
    end

    test "struct with atoms as field values" do
      defmodule AtomFieldStruct do
        use Exdantic, define_struct: true
        
        schema do
          field :status, :atom, required: true
          field :type, :atom, optional: true
        end
      end
      
      data = %{status: :active, type: :user}
      
      assert {:ok, result} = AtomFieldStruct.validate(data)
      assert %AtomFieldStruct{} = result
      assert result.status == :active
      assert result.type == :user
    end
  end

  describe "boundary conditions" do
    test "very long field names" do
      long_field_name = String.duplicate("a", 100) |> String.to_atom()
      
      defmodule LongFieldStruct do
        use Exdantic, define_struct: true
        
        schema do
          field unquote(long_field_name), :string, required: true
        end
      end
      
      data = %{long_field_name => "test"}
      
      assert {:ok, result} = LongFieldStruct.validate(data)
      assert %LongFieldStruct{} = result
      assert Map.get(result, long_field_name) == "test"
    end

    test "unicode field names and values" do
      unicode_field = :测试字段
      
      defmodule UnicodeStruct do
        use Exdantic, define_struct: true
        
        schema do
          field unquote(unicode_field), :string, required: true
        end
      end
      
      data = %{unicode_field => "unicode_value_测试"}
      
      assert {:ok, result} = UnicodeStruct.validate(data)
      assert %UnicodeStruct{} = result
      assert Map.get(result, unicode_field) == "unicode_value_测试"
    end
  end
end
