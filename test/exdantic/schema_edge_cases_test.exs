defmodule Exdantic.SchemaEdgeCasesTest do
  use ExUnit.Case, async: true

  describe "schema definition edge cases" do
    test "handles schema with no fields" do
      defmodule EmptySchema do
        use Exdantic

        schema "Empty schema for testing" do
          # No fields defined
        end
      end

      assert EmptySchema.__schema__(:fields) == []
      assert EmptySchema.__schema__(:description) == "Empty schema for testing"

      # Should validate empty maps successfully
      assert {:ok, %{}} = EmptySchema.validate(%{})

      # Should fail with strict mode when extra fields present
      defmodule StrictEmptySchema do
        use Exdantic

        schema do
          config do
            strict(true)
          end
        end
      end

      assert {:error, _} = StrictEmptySchema.validate(%{extra: "field"})
    end

    test "handles schema with duplicate field names" do
      # Elixir allows duplicate function clauses, so this will actually work
      # and both field definitions will be accumulated
      defmodule DuplicateFieldSchema do
        use Exdantic

        schema do
          field :name, :string do
            description("First name field")
          end

          field :name, :integer do
            description("Second name field")
          end
        end
      end

      fields = DuplicateFieldSchema.__schema__(:fields)
      # Should have 2 entries (accumulated), both with :name key
      name_fields = Enum.filter(fields, fn {field_name, _} -> field_name == :name end)
      assert length(name_fields) == 2
    end

    test "handles fields with extremely long names" do
      defmodule LongFieldNameSchema do
        use Exdantic

        schema do
          # Use module attribute to work around atom size limits in macro
          @long_name String.duplicate("field_", 20) |> String.to_atom()
          field(@long_name, :string)
        end
      end

      fields = LongFieldNameSchema.__schema__(:fields)
      assert length(fields) == 1
      {field_name, _meta} = List.first(fields)
      assert is_atom(field_name)
      # 20 * 6 chars
      assert String.length(Atom.to_string(field_name)) == 120
    end

    test "handles fields with unicode names" do
      defmodule UnicodeFieldSchema do
        use Exdantic

        schema do
          field :名前, :string do
            description("Name in Japanese")
          end

          field :コメント, :string do
            description("Comment in Japanese")
            optional()
          end

          field :rocket_emoji, :string do
            description("Field for emoji content, e.g., 🚀")
            optional()
          end
        end
      end

      fields = UnicodeFieldSchema.__schema__(:fields)
      field_names = Enum.map(fields, fn {name, _} -> name end)

      assert :名前 in field_names
      assert :コメント in field_names
      assert :rocket_emoji in field_names

      # Test validation works with unicode field names and emoji content
      valid_data = %{名前: "テスト", コメント: "コメント", rocket_emoji: "🚀"}
      assert {:ok, validated} = UnicodeFieldSchema.validate(valid_data)
      assert Map.get(validated, :名前) == "テスト"
      assert Map.get(validated, :rocket_emoji) == "🚀"
    end

    test "handles complex nested field types with edge cases" do
      defmodule NestedEdgeCaseSchema do
        use Exdantic

        schema do
          # Union containing array of maps containing unions
          field :complex_data,
                {:union,
                 [
                   :string,
                   {:array, {:map, {:string, {:union, [:integer, :boolean, {:array, :string}]}}}},
                   {:map, {:string, {:union, [:string, {:array, {:map, {:string, :integer}}}]}}}
                 ]} do
            description("Extremely complex nested type")
            optional()
          end

          # Array of unions of arrays
          field :array_union_array,
                {:array,
                 {:union,
                  [
                    {:array, :string},
                    {:array, :integer},
                    {:array, :boolean}
                  ]}} do
            default([])
          end
        end
      end

      # Test that field types are correctly parsed
      fields = NestedEdgeCaseSchema.__schema__(:fields)
      {_, complex_meta} = Enum.find(fields, fn {name, _} -> name == :complex_data end)
      {_, _array_meta} = Enum.find(fields, fn {name, _} -> name == :array_union_array end)

      # Verify complex nested structure
      assert {:union,
              [
                {:type, :string, []},
                {:array,
                 {:map,
                  {{:type, :string, []},
                   {:union,
                    [
                      {:type, :integer, []},
                      {:type, :boolean, []},
                      {:array, {:type, :string, []}, []}
                    ], []}}, []}, []},
                {:map,
                 {{:type, :string, []},
                  {:union,
                   [
                     {:type, :string, []},
                     {:array, {:map, {{:type, :string, []}, {:type, :integer, []}}, []}, []}
                   ], []}}, []}
              ], []} = complex_meta.type

      # Test validation of complex data
      complex_valid_data = %{
        complex_data: [
          %{"key1" => 123, "key2" => true, "key3" => ["a", "b"]},
          %{"key4" => false}
        ]
      }

      assert {:ok, _} = NestedEdgeCaseSchema.validate(complex_valid_data)
    end

    test "handles field constraints with edge case values" do
      defmodule ConstraintEdgeSchema do
        use Exdantic

        schema do
          field :zero_min, :string do
            # Minimum possible constraint
            min_length(0)
          end

          field :large_max, :string do
            # Very large constraint
            max_length(100_000)
          end

          field :negative_numbers, :integer do
            gt(-1000)
            lt(-1)
          end

          field :float_precision, :float do
            gteq(0.0000001)
            lteq(0.9999999)
          end

          field :empty_choices, :string do
            # Empty choices - nothing valid
            choices([])
            optional()
          end

          field :single_choice, :string do
            choices(["only_option"])
            default("only_option")
          end
        end
      end

      fields = ConstraintEdgeSchema.__schema__(:fields)

      # Verify constraints are applied correctly
      {_, zero_min_meta} = Enum.find(fields, fn {name, _} -> name == :zero_min end)
      assert {:type, :string, [min_length: 0]} = zero_min_meta.type

      {_, large_max_meta} = Enum.find(fields, fn {name, _} -> name == :large_max end)
      assert {:type, :string, [max_length: 100_000]} = large_max_meta.type

      # Test validation
      valid_data = %{
        # Zero length should be valid
        zero_min: "",
        # Large string within limit
        large_max: String.duplicate("a", 50_000),
        negative_numbers: -500,
        float_precision: 0.5,
        single_choice: "only_option"
      }

      assert {:ok, _} = ConstraintEdgeSchema.validate(valid_data)

      # Test edge cases fail appropriately
      assert {:error, _} =
               ConstraintEdgeSchema.validate(%{
                 zero_min: "",
                 # Exceeds max length
                 large_max: String.duplicate("a", 100_001),
                 negative_numbers: -500,
                 float_precision: 0.5,
                 single_choice: "only_option"
               })
    end

    test "handles metadata edge cases" do
      defmodule MetadataEdgeSchema do
        use Exdantic

        schema do
          field :empty_description, :string do
            # Empty description
            description("")
          end

          field :long_description, :string do
            description(String.duplicate("Very long description. ", 1000))
          end

          field :unicode_description, :string do
            description("This field contains unicode: こんにちは café")
          end

          field :many_examples, :string do
            examples(Enum.map(1..100, &"example_#{&1}"))
          end

          field :empty_examples, :string do
            examples([])
          end

          field :special_char_examples, :string do
            examples(["", " ", "\n", "\t", "line1\nline2", "with\"quotes"])
          end
        end
      end

      fields = MetadataEdgeSchema.__schema__(:fields)

      # Verify metadata is stored correctly
      {_, empty_desc_meta} = Enum.find(fields, fn {name, _} -> name == :empty_description end)
      assert empty_desc_meta.description == ""

      {_, long_desc_meta} = Enum.find(fields, fn {name, _} -> name == :long_description end)
      assert String.length(long_desc_meta.description) > 20_000

      {_, unicode_meta} = Enum.find(fields, fn {name, _} -> name == :unicode_description end)
      assert String.contains?(unicode_meta.description, "こんにちは")
      assert String.contains?(unicode_meta.description, "café")

      {_, many_examples_meta} = Enum.find(fields, fn {name, _} -> name == :many_examples end)
      assert length(many_examples_meta.examples) == 100

      {_, empty_examples_meta} = Enum.find(fields, fn {name, _} -> name == :empty_examples end)
      assert empty_examples_meta.examples == []
    end

    test "handles config edge cases" do
      defmodule ConfigEdgeSchema do
        use Exdantic

        schema do
          field(:test, :string)

          config do
            # Empty title
            title("")
            # Very long description
            config_description(String.duplicate("Long description ", 1000))
            strict(true)
          end
        end
      end

      config = ConfigEdgeSchema.__schema__(:config)
      assert config[:title] == ""
      assert String.length(config[:description]) > 15_000
      assert config[:strict] == true

      # Test that empty title doesn't break validation
      assert {:ok, _} = ConfigEdgeSchema.validate(%{test: "value"})
    end

    test "handles default value edge cases" do
      defmodule DefaultEdgeSchema do
        use Exdantic

        schema do
          field :nil_default, :string do
            # Nil default - might be problematic
            default(nil)
          end

          field :complex_default, {:map, {:string, {:array, :integer}}} do
            default(%{"numbers" => [1, 2, 3], "more" => [4, 5]})
          end

          field :large_default, :string do
            default(String.duplicate("default", 10_000))
          end

          field :unicode_default, :string do
            default("こんにちは世界 🌍")
          end
        end
      end

      # Test defaults are applied
      minimal_data = %{}
      assert {:ok, validated} = DefaultEdgeSchema.validate(minimal_data)

      assert Map.get(validated, :nil_default) == nil
      assert Map.get(validated, :complex_default) == %{"numbers" => [1, 2, 3], "more" => [4, 5]}
      assert String.length(Map.get(validated, :large_default)) > 50_000
      assert Map.get(validated, :unicode_default) == "こんにちは世界 🌍"
    end
  end

  describe "schema validation edge cases" do
    defmodule StrictValidationSchema do
      use Exdantic

      schema do
        field(:required_field, :string)

        config do
          strict(true)
        end
      end
    end

    test "handles strict validation with various extra field scenarios" do
      # Single extra field
      assert {:error, errors} =
               StrictValidationSchema.validate(%{
                 required_field: "test",
                 extra: "field"
               })

      assert length(errors) == 1
      error = hd(errors)
      assert error.code == :additional_properties

      # Multiple extra fields
      assert {:error, errors} =
               StrictValidationSchema.validate(%{
                 required_field: "test",
                 extra1: "field1",
                 extra2: "field2",
                 extra3: "field3"
               })

      assert length(errors) == 1
      error = hd(errors)
      assert String.contains?(error.message, "extra1")

      # Extra fields with special names
      assert {:error, errors} =
               StrictValidationSchema.validate(%{
                 "field-with-dashes" => "value",
                 "field.with.dots" => "value",
                 "field with spaces" => "value",
                 required_field: "test"
               })

      assert length(errors) == 1
      error = hd(errors)
      assert error.code == :additional_properties
    end

    test "handles validation with mixed atom and string keys" do
      defmodule MixedKeySchema do
        use Exdantic

        schema do
          field(:atom_field, :string)

          field :other_field, :integer do
            optional()
          end
        end
      end

      # Test various key combinations
      test_cases = [
        # atom keys
        %{atom_field: "test"},
        # string keys
        %{"atom_field" => "test"},
        # mixed keys
        %{"atom_field" => "test", "other_field" => 123},
        # mixed keys reversed
        %{"atom_field" => "test", other_field: 123}
      ]

      for test_data <- test_cases do
        assert {:ok, validated} = MixedKeySchema.validate(test_data)
        # Output should always use atom keys
        assert Map.has_key?(validated, :atom_field)
        assert validated.atom_field == "test"

        if Map.has_key?(test_data, :other_field) or Map.has_key?(test_data, "other_field") do
          assert Map.has_key?(validated, :other_field)
          assert validated.other_field == 123
        end
      end
    end

    test "handles validation of very large data structures" do
      defmodule LargeDataSchema do
        use Exdantic

        schema do
          field :large_map, {:map, {:string, :string}} do
            optional()
          end

          field :large_array, {:array, :string} do
            optional()
          end
        end
      end

      # Large map
      large_map = Map.new(1..10_000, fn i -> {"key_#{i}", "value_#{i}"} end)

      # Large array
      large_array = Enum.map(1..10_000, &"item_#{&1}")

      large_data = %{
        large_map: large_map,
        large_array: large_array
      }

      assert {:ok, validated} = LargeDataSchema.validate(large_data)
      assert map_size(validated.large_map) == 10_000
      assert length(validated.large_array) == 10_000
    end
  end
end
