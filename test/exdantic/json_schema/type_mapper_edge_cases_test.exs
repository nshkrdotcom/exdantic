defmodule Exdantic.JsonSchema.TypeMapperEdgeCasesTest do
  use ExUnit.Case, async: true
  alias Exdantic.JsonSchema.ReferenceStore
  alias Exdantic.JsonSchema.TypeMapper
  alias Exdantic.Types

  describe "TypeMapper edge cases" do
    test "handles conversion without reference store" do
      # Basic types should work without store
      assert TypeMapper.to_json_schema(Types.string()) == %{"type" => "string"}
      assert TypeMapper.to_json_schema(Types.integer()) == %{"type" => "integer"}

      # Complex types should also work
      array_type = Types.array(Types.string())
      expected = %{"type" => "array", "items" => %{"type" => "string"}}
      assert TypeMapper.to_json_schema(array_type) == expected
    end

    test "raises error when schema reference used without store" do
      defmodule TestSchemaForError do
        use Exdantic

        schema do
          field(:name, :string)
        end
      end

      # Should raise error when trying to reference schema without store
      assert_raise RuntimeError, ~r/requires a reference store/, fn ->
        TypeMapper.to_json_schema({:ref, TestSchemaForError})
      end
    end

    test "handles custom type modules correctly" do
      defmodule CustomEmailType do
        def json_schema do
          %{
            "type" => "string",
            "format" => "email",
            "pattern" => "^[^@]+@[^@]+$"
          }
        end
      end

      # When passed as atom, should call the module's json_schema/0
      result = TypeMapper.to_json_schema(CustomEmailType)

      expected = %{
        "type" => "string",
        "format" => "email",
        "pattern" => "^[^@]+@[^@]+$"
      }

      assert result == expected
    end

    test "raises error for invalid custom type modules" do
      defmodule InvalidCustomType do
        # Missing json_schema/0 function
      end

      assert_raise RuntimeError, ~r/not a valid Exdantic type/, fn ->
        TypeMapper.to_json_schema(InvalidCustomType)
      end
    end

    test "handles __aliases__ macro expansion" do
      {:ok, store} = ReferenceStore.start_link()

      defmodule AliasTestSchema do
        use Exdantic

        schema do
          field(:name, :string)
        end
      end

      # Test with the actual module directly instead of AST
      # since __aliases__ expansion depends on the compilation context
      result = TypeMapper.to_json_schema(AliasTestSchema, store)
      assert result == %{"$ref" => "#/definitions/AliasTestSchema"}

      # Reference should be added to store
      assert ReferenceStore.has_reference?(store, AliasTestSchema)

      ReferenceStore.stop(store)
    end

    test "handles deeply nested type structures" do
      {:ok, store} = ReferenceStore.start_link()

      # Create a very deep nested structure
      deep_type =
        {:array,
         {:map,
          {
            {:type, :string, []},
            {:union,
             [
               {:type, :integer, []},
               {:array, {:type, :boolean, []}, []},
               {:map,
                {
                  {:type, :string, []},
                  {:union,
                   [
                     {:type, :string, []},
                     {:array, {:type, :float, []}, []}
                   ], []}
                }, []}
             ], []}
          }, []}, []}

      result = TypeMapper.to_json_schema(deep_type, store)

      # Verify the structure is correctly converted
      assert result["type"] == "array"
      assert result["items"]["type"] == "object"
      assert Map.has_key?(result["items"]["additionalProperties"], "oneOf")

      union_options = result["items"]["additionalProperties"]["oneOf"]
      assert length(union_options) == 3

      # Check that nested structures are properly converted
      map_option = Enum.find(union_options, &(&1["type"] == "object"))
      assert Map.has_key?(map_option["additionalProperties"], "oneOf")

      ReferenceStore.stop(store)
    end

    test "handles type with complex constraints" do
      constrained_type =
        {:type, :string,
         [
           {:min_length, 5},
           {:max_length, 100},
           {:format, ~r/^[A-Za-z0-9]+$/},
           {:choices, ["admin", "user", "guest"]},
           # Unknown constraint
           {:custom_constraint, "ignored"}
         ]}

      result = TypeMapper.to_json_schema(constrained_type)

      expected = %{
        "type" => "string",
        "minLength" => 5,
        "maxLength" => 100,
        "pattern" => "^[A-Za-z0-9]+$"
        # choices constraint not implemented in apply_constraints
        # custom_constraint should be ignored
      }

      assert result == expected
    end

    test "handles regex constraint edge cases" do
      # Test various regex patterns
      regex_patterns = [
        # Empty pattern
        ~r//,
        # Single dot
        ~r/./,
        # Start and end anchors only
        ~r/^$/,
        # Unicode character classes
        ~r/[\p{L}\p{N}]+/u,
        # Negated character class
        ~r/[^\r\n]+/,
        # Non-capturing groups
        ~r/(?:non)?capturing/,
        # Quantifiers
        ~r/\d{2,4}/,
        # Alternation
        ~r/a|b|c/,
        # Backslash literal
        ~r/\\/,
        # Quote literal
        ~r/"/
      ]

      for pattern <- regex_patterns do
        type = {:type, :string, [{:format, pattern}]}
        result = TypeMapper.to_json_schema(type)

        assert result["type"] == "string"
        assert result["pattern"] == Regex.source(pattern)
      end
    end

    test "handles array constraints edge cases" do
      # Test various array constraint combinations
      test_cases = [
        {[], %{"type" => "array", "items" => %{"type" => "string"}}},
        {[min_items: 0], %{"type" => "array", "items" => %{"type" => "string"}, "minItems" => 0}},
        {[max_items: 0], %{"type" => "array", "items" => %{"type" => "string"}, "maxItems" => 0}},
        {[min_items: 5, max_items: 5],
         %{"type" => "array", "items" => %{"type" => "string"}, "minItems" => 5, "maxItems" => 5}},
        {[min_items: 1_000_000],
         %{"type" => "array", "items" => %{"type" => "string"}, "minItems" => 1_000_000}}
      ]

      for {constraints, expected} <- test_cases do
        type = {:array, {:type, :string, []}, constraints}
        result = TypeMapper.to_json_schema(type)
        assert result == expected
      end
    end

    test "handles map type variations" do
      {:ok, store} = ReferenceStore.start_link()

      # Different key-value type combinations
      test_cases = [
        # String keys, various value types
        {{:type, :string, []}, {:type, :integer, []}},
        {{:type, :string, []}, {:array, {:type, :boolean, []}, []}},
        {{:type, :string, []}, {:union, [{:type, :string, []}, {:type, :integer, []}], []}},

        # Non-string keys
        {{:type, :integer, []}, {:type, :string, []}},
        {{:type, :float, []}, {:type, :boolean, []}},

        # Complex key types (though unusual)
        {{:union, [{:type, :string, []}, {:type, :integer, []}], []}, {:type, :string, []}}
      ]

      for {key_type, value_type} <- test_cases do
        map_type = {:map, {key_type, value_type}, []}
        result = TypeMapper.to_json_schema(map_type, store)

        assert result["type"] == "object"
        assert Map.has_key?(result, "additionalProperties")
        # The key type is ignored in JSON Schema (objects always have string keys)
        # Only the value type is used in additionalProperties
      end

      ReferenceStore.stop(store)
    end

    test "handles union type edge cases" do
      {:ok, store} = ReferenceStore.start_link()

      # Empty union
      empty_union = {:union, [], []}
      result = TypeMapper.to_json_schema(empty_union, store)
      assert result == %{"oneOf" => []}

      # Single type union
      single_union = {:union, [{:type, :string, []}], []}
      result = TypeMapper.to_json_schema(single_union, store)
      assert result == %{"oneOf" => [%{"type" => "string"}]}

      # Union with identical types (should still preserve all)
      duplicate_union =
        {:union,
         [
           {:type, :string, []},
           {:type, :string, []},
           {:type, :string, []}
         ], []}

      result = TypeMapper.to_json_schema(duplicate_union, store)

      assert result == %{
               "oneOf" => [
                 %{"type" => "string"},
                 %{"type" => "string"},
                 %{"type" => "string"}
               ]
             }

      # Union with constraints
      constrained_union =
        {:union,
         [
           {:type, :string, [{:min_length, 5}]},
           {:type, :integer, [{:gt, 0}]}
         ], [{:custom_union_constraint, "ignored"}]}

      result = TypeMapper.to_json_schema(constrained_union, store)

      expected_options = [
        %{"type" => "string", "minLength" => 5},
        %{"type" => "integer", "exclusiveMinimum" => 0}
      ]

      assert result["oneOf"] == expected_options
      # Union-level constraints should be applied to the union schema

      ReferenceStore.stop(store)
    end

    test "handles normalize_type edge cases" do
      # Test type normalization with various inputs
      assert TypeMapper.to_json_schema(:string) == %{"type" => "string"}
      assert TypeMapper.to_json_schema(:integer) == %{"type" => "integer"}

      # Array normalization
      assert TypeMapper.to_json_schema({:array, :string}) == %{
               "type" => "array",
               "items" => %{"type" => "string"}
             }

      # Map normalization
      assert TypeMapper.to_json_schema({:map, {:string, :integer}}) == %{
               "type" => "object",
               "additionalProperties" => %{"type" => "integer"}
             }

      # Union normalization
      result = TypeMapper.to_json_schema({:union, [:string, :integer]})

      assert result == %{
               "oneOf" => [
                 %{"type" => "string"},
                 %{"type" => "integer"}
               ]
             }
    end

    test "handles schema_module? predicate edge cases" do
      {:ok, store} = ReferenceStore.start_link()

      # Module that exists but is not a schema
      defmodule NotASchemaModule do
        def some_function, do: :ok
      end

      # This should raise error since it's not a valid custom type either
      assert_raise RuntimeError, ~r/not a valid Exdantic type/, fn ->
        TypeMapper.to_json_schema(NotASchemaModule, store)
      end

      # Module that doesn't exist
      non_existent = NonExistentModule

      assert_raise RuntimeError, fn ->
        TypeMapper.to_json_schema(non_existent, store)
      end

      ReferenceStore.stop(store)
    end

    test "handles concurrent type mapping" do
      {:ok, store} = ReferenceStore.start_link()

      defmodule ConcurrentTestSchema do
        use Exdantic

        schema do
          field(:name, :string)
        end
      end

      # Multiple processes trying to map the same schema reference
      tasks =
        for _i <- 1..50 do
          Task.async(fn ->
            TypeMapper.to_json_schema({:ref, ConcurrentTestSchema}, store)
          end)
        end

      results = Task.await_many(tasks, 5000)

      # All results should be identical
      expected = %{"$ref" => "#/definitions/ConcurrentTestSchema"}

      for result <- results do
        assert result == expected
      end

      # Reference should only be added once
      references = ReferenceStore.get_references(store)
      assert ConcurrentTestSchema in references

      # Count should be 1 (not 50)
      concurrent_refs = Enum.count(references, &(&1 == ConcurrentTestSchema))
      assert concurrent_refs == 1

      ReferenceStore.stop(store)
    end

    test "handles memory-intensive type structures" do
      {:ok, store} = ReferenceStore.start_link()

      # Create a type with many nested unions and arrays
      complex_type =
        Enum.reduce(1..100, {:type, :string, []}, fn i, acc ->
          if rem(i, 2) == 0 do
            {:array, acc, []}
          else
            {:union, [acc, {:type, :integer, []}], []}
          end
        end)

      # This should complete without memory issues
      result = TypeMapper.to_json_schema(complex_type, store)

      # Verify it's a valid JSON schema structure
      assert is_map(result)
      assert Map.has_key?(result, "type") or Map.has_key?(result, "oneOf")

      ReferenceStore.stop(store)
    end

    test "handles type mapping with invalid constraints" do
      # Test various invalid constraint scenarios
      invalid_constraints = [
        # Negative min length
        {:min_length, -1},
        # Negative max length
        {:max_length, -5},
        # Negative min items
        {:min_items, -10},
        # Wrong type for numeric constraint
        {:gt, "not_a_number"},
        # Wrong type for format constraint
        {:format, "not_a_regex"}
      ]

      for constraint <- invalid_constraints do
        type = {:type, :string, [constraint]}

        # Should not crash, might ignore invalid constraints
        result = TypeMapper.to_json_schema(type)
        assert result["type"] == "string"

        # Depending on implementation, invalid constraints might be ignored
        # or cause errors - this tests the robustness
      end
    end
  end

  describe "apply_constraints edge cases" do
    test "handles constraint application with nil values" do
      base_schema = %{"type" => "string"}

      # Empty constraints
      result = TypeMapper.to_json_schema({:type, :string, []})
      assert result == base_schema

      # Nil in constraints list (shouldn't happen but test robustness)
      # This would need to be tested at a lower level since the public API
      # doesn't allow nil constraints
    end

    test "handles numeric constraint boundary values" do
      # Test with very large numbers
      large_constraints = [
        {:gt, 999_999_999_999_999},
        {:lt, -999_999_999_999_999},
        {:gteq, 0},
        {:lteq, 1_000_000_000_000}
      ]

      type = {:type, :integer, large_constraints}
      result = TypeMapper.to_json_schema(type)

      assert result["exclusiveMinimum"] == 999_999_999_999_999
      assert result["exclusiveMaximum"] == -999_999_999_999_999
      assert result["minimum"] == 0
      assert result["maximum"] == 1_000_000_000_000
    end

    test "handles float constraint precision" do
      # Test with very small float values
      precision_constraints = [
        {:gteq, 0.000000000001},
        {:lteq, 0.999999999999},
        {:gt, -0.000000000001},
        {:lt, 1.000000000001}
      ]

      type = {:type, :float, precision_constraints}
      result = TypeMapper.to_json_schema(type)

      assert result["minimum"] == 0.000000000001
      assert result["maximum"] == 0.999999999999
      assert result["exclusiveMinimum"] == -0.000000000001
      assert result["exclusiveMaximum"] == 1.000000000001
    end
  end
end
