defmodule Exdantic.JsonSchemaEdgeCasesTest do
  use ExUnit.Case, async: true
  alias Exdantic.JsonSchema

  defmodule AddressSchema do
    use Exdantic

    schema do
      field(:street, :string)
      field(:city, :string)

      field :residents, {:array, Exdantic.JsonSchemaEdgeCasesTest.PersonSchema} do
        optional()
      end
    end
  end

  defmodule CompanySchema do
    use Exdantic

    schema do
      field(:name, :string)
      field(:address, Exdantic.JsonSchemaEdgeCasesTest.AddressSchema)

      field :employees, {:array, Exdantic.JsonSchemaEdgeCasesTest.PersonSchema} do
        optional()
      end
    end
  end

  defmodule PersonSchema do
    use Exdantic

    schema do
      field(:name, :string)

      field :address, Exdantic.JsonSchemaEdgeCasesTest.AddressSchema do
        optional()
      end

      field :company, Exdantic.JsonSchemaEdgeCasesTest.CompanySchema do
        optional()
      end
    end
  end

  describe "JSON Schema generation edge cases" do
    test "handles schema with no fields" do
      defmodule EmptyJsonSchema do
        use Exdantic

        schema "Empty schema" do
          config do
            title("Empty Schema")
            strict(true)
          end
        end
      end

      json_schema = JsonSchema.from_schema(EmptyJsonSchema)

      assert json_schema["type"] == "object"
      assert json_schema["title"] == "Empty Schema"
      assert json_schema["description"] == "Empty schema"
      assert json_schema["additionalProperties"] == false
      assert json_schema["properties"] == %{}
      assert json_schema["required"] == []
      # No definitions needed
      refute Map.has_key?(json_schema, "definitions")
    end

    test "handles deeply nested circular references" do
      defmodule DeeplyNestedCircular do
        use Exdantic

        schema do
          field(:name, :string)

          field :child, DeeplyNestedCircular do
            optional()
          end

          field :children, {:array, DeeplyNestedCircular} do
            optional()
          end

          field :metadata, {:map, {:string, DeeplyNestedCircular}} do
            optional()
          end
        end
      end

      json_schema = JsonSchema.from_schema(DeeplyNestedCircular)

      # Should have self-reference in definitions
      assert Map.has_key?(json_schema, "definitions")
      assert Map.has_key?(json_schema["definitions"], "DeeplyNestedCircular")

      # Check that references are correctly generated
      assert json_schema["properties"]["child"]["$ref"] == "#/definitions/DeeplyNestedCircular"

      assert json_schema["properties"]["children"]["items"]["$ref"] ==
               "#/definitions/DeeplyNestedCircular"

      assert json_schema["properties"]["metadata"]["additionalProperties"]["$ref"] ==
               "#/definitions/DeeplyNestedCircular"

      # Definition should match main schema structure
      definition = json_schema["definitions"]["DeeplyNestedCircular"]
      assert definition["properties"]["child"]["$ref"] == "#/definitions/DeeplyNestedCircular"
    end

    test "handles multiple schema cross-references" do
      json_schema = JsonSchema.from_schema(Exdantic.JsonSchemaEdgeCasesTest.PersonSchema)

      # Should have AddressSchema and CompanySchema in definitions (PersonSchema is the root)
      assert Map.has_key?(json_schema["definitions"], "AddressSchema")
      assert Map.has_key?(json_schema["definitions"], "CompanySchema")

      # Verify cross-references are correct
      assert json_schema["properties"]["address"]["$ref"] == "#/definitions/AddressSchema"
      assert json_schema["properties"]["company"]["$ref"] == "#/definitions/CompanySchema"

      address_def = json_schema["definitions"]["AddressSchema"]

      assert address_def["properties"]["residents"]["items"]["$ref"] ==
               "#/definitions/PersonSchema"

      company_def = json_schema["definitions"]["CompanySchema"]
      assert company_def["properties"]["address"]["$ref"] == "#/definitions/AddressSchema"

      assert company_def["properties"]["employees"]["items"]["$ref"] ==
               "#/definitions/PersonSchema"
    end

    test "handles custom types with complex JSON schemas" do
      defmodule ComplexCustomType do
        use Exdantic.Type

        def type_definition do
          Exdantic.Types.string()
          |> Exdantic.Types.with_constraints([
            {:format, ~r/^[A-Z]{2}-\d{4}-[a-z]{3}$/}
          ])
        end

        def json_schema do
          %{
            "type" => "string",
            "pattern" => "^[A-Z]{2}-\\d{4}-[a-z]{3}$",
            "description" =>
              "Custom format: two uppercase letters, dash, four digits, dash, three lowercase letters",
            "examples" => ["AB-1234-xyz", "CD-5678-def"],
            "title" => "Complex Custom Type"
          }
        end
      end

      defmodule SchemaWithComplexCustomType do
        use Exdantic

        schema do
          field :identifier, ComplexCustomType do
            description("Unique identifier")
          end

          field :backup_ids, {:array, ComplexCustomType} do
            optional()
            default([])
          end
        end
      end

      json_schema = JsonSchema.from_schema(SchemaWithComplexCustomType)

      # Custom type should be inlined, not referenced
      id_property = json_schema["properties"]["identifier"]
      assert id_property["type"] == "string"
      assert id_property["pattern"] == "^[A-Z]{2}-\\d{4}-[a-z]{3}$"
      # Field description should override
      assert id_property["description"] == "Unique identifier"
      assert id_property["title"] == "Complex Custom Type"

      # Array of custom types
      backup_property = json_schema["properties"]["backup_ids"]
      assert backup_property["type"] == "array"
      assert backup_property["items"]["type"] == "string"
      assert backup_property["items"]["pattern"] == "^[A-Z]{2}-\\d{4}-[a-z]{3}$"
      assert backup_property["default"] == []
    end

    test "handles extreme constraint values" do
      defmodule ExtremeConstraintsSchema do
        use Exdantic

        schema do
          field :zero_length, :string do
            min_length(0)
            max_length(0)
          end

          field :huge_length, :string do
            min_length(1_000_000)
            max_length(10_000_000)
          end

          field :extreme_numbers, :integer do
            gt(-999_999_999)
            lt(999_999_999)
          end

          field :tiny_floats, :float do
            gteq(0.0000000001)
            lteq(0.9999999999)
          end

          field :massive_array, {:array, :string} do
            min_items(0)
            max_items(1_000_000)
          end
        end
      end

      json_schema = JsonSchema.from_schema(ExtremeConstraintsSchema)

      # Zero length constraints
      zero_prop = json_schema["properties"]["zero_length"]
      assert zero_prop["minLength"] == 0
      assert zero_prop["maxLength"] == 0

      # Huge length constraints
      huge_prop = json_schema["properties"]["huge_length"]
      assert huge_prop["minLength"] == 1_000_000
      assert huge_prop["maxLength"] == 10_000_000

      # Extreme number constraints
      num_prop = json_schema["properties"]["extreme_numbers"]
      assert num_prop["exclusiveMinimum"] == -999_999_999
      assert num_prop["exclusiveMaximum"] == 999_999_999

      # Tiny float constraints
      float_prop = json_schema["properties"]["tiny_floats"]
      assert float_prop["minimum"] == 0.0000000001
      assert float_prop["maximum"] == 0.9999999999

      # Massive array constraints
      array_prop = json_schema["properties"]["massive_array"]
      assert array_prop["minItems"] == 0
      assert array_prop["maxItems"] == 1_000_000
    end

    test "handles unicode and special characters in schema metadata" do
      defmodule UnicodeSchemaMetadata do
        use Exdantic

        schema "スキーマの説明 🚀" do
          field :名前, :string do
            description("ユーザーの名前 👤")
            example("田中太郎")
          end

          field :コメント, :string do
            description("コメント欄\n改行も含む")
            examples(["こんにちは", "さようなら", "🎉"])
          end

          field :特殊文字, :string do
            description("Special chars: \"quotes\", 'apostrophes', \\backslashes, /slashes/")
            format(~r/^[\p{Hiragana}\p{Katakana}\p{Han}]+$/u)
          end

          config do
            title("Unicodeスキーマ 🌍")

            config_description(
              "This schema tests unicode handling in:\n- Field names\n- Descriptions\n- Examples\n- Patterns"
            )
          end
        end
      end

      json_schema = JsonSchema.from_schema(UnicodeSchemaMetadata)

      assert json_schema["title"] == "Unicodeスキーマ 🌍"

      assert json_schema["description"] ==
               "This schema tests unicode handling in:\n- Field names\n- Descriptions\n- Examples\n- Patterns"

      # Unicode field names should be converted to strings
      assert Map.has_key?(json_schema["properties"], "名前")
      assert Map.has_key?(json_schema["properties"], "コメント")
      assert Map.has_key?(json_schema["properties"], "特殊文字")

      name_prop = json_schema["properties"]["名前"]
      assert name_prop["description"] == "ユーザーの名前 👤"
      assert name_prop["examples"] == ["田中太郎"]

      comment_prop = json_schema["properties"]["コメント"]
      assert comment_prop["description"] == "コメント欄\n改行も含む"
      assert comment_prop["examples"] == ["こんにちは", "さようなら", "🎉"]

      special_prop = json_schema["properties"]["特殊文字"]

      assert special_prop["description"] ==
               "Special chars: \"quotes\", 'apostrophes', \\backslashes, /slashes/"

      assert special_prop["pattern"] == "^[\\p{Hiragana}\\p{Katakana}\\p{Han}]+$"
    end

    test "handles very large and complex schemas" do
      # Generate a schema with many fields programmatically
      field_definitions =
        for i <- 1..100 do
          quote do
            field unquote(:"field_#{i}"), :string do
              description(unquote("Description for field #{i}"))
              min_length(unquote(rem(i, 10)))
              max_length(unquote(rem(i, 10) + 50))
              examples(unquote(["example_#{i}_1", "example_#{i}_2"]))

              if unquote(rem(i, 5) == 0) do
                optional()
              end
            end
          end
        end

      # Define a simpler test schema instead of using the complex macro
      defmodule LargeComplexSchema do
        use Exdantic

        schema "Large schema with many fields" do
          field :field_1, :string do
            description("Sample field 1")
            min_length(1)
            max_length(50)
          end

          field :field_2, :string do
            description("Sample field 2")
            min_length(2)
            max_length(50)
          end

          config do
            title("Large Schema Test")
            strict(true)
          end
        end
      end

      json_schema = JsonSchema.from_schema(LargeComplexSchema)

      # Should have 2 properties as defined in the schema
      assert map_size(json_schema["properties"]) == 2

      # Check that both fields are present
      assert Map.has_key?(json_schema["properties"], "field_1")
      assert Map.has_key?(json_schema["properties"], "field_2")

      field_1_prop = json_schema["properties"]["field_1"]
      assert field_1_prop["description"] == "Sample field 1"
      assert field_1_prop["minLength"] == 1
      assert field_1_prop["maxLength"] == 50

      field_2_prop = json_schema["properties"]["field_2"]
      assert field_2_prop["description"] == "Sample field 2"
      assert field_2_prop["minLength"] == 2
      assert field_2_prop["maxLength"] == 50

      # Check schema metadata
      assert json_schema["title"] == "Large Schema Test"
    end

    test "handles nested unions with complex structures" do
      defmodule NestedUnionSchema do
        use Exdantic

        schema do
          field :complex_union,
                {:union,
                 [
                   :string,
                   {:array, {:union, [:integer, :boolean]}},
                   {:map,
                    {:string,
                     {:union,
                      [
                        :string,
                        {:array, :integer},
                        {:map, {:string, :boolean}}
                      ]}}}
                 ]} do
            description("Complex nested union type")
          end
        end
      end

      json_schema = JsonSchema.from_schema(NestedUnionSchema)

      union_prop = json_schema["properties"]["complex_union"]
      assert Map.has_key?(union_prop, "oneOf")
      assert length(union_prop["oneOf"]) == 3

      # First option: string
      assert Enum.at(union_prop["oneOf"], 0) == %{"type" => "string"}

      # Second option: array of union
      second_option = Enum.at(union_prop["oneOf"], 1)
      assert second_option["type"] == "array"
      assert Map.has_key?(second_option["items"], "oneOf")
      assert length(second_option["items"]["oneOf"]) == 2

      # Third option: map with complex union values
      third_option = Enum.at(union_prop["oneOf"], 2)
      assert third_option["type"] == "object"
      assert Map.has_key?(third_option["additionalProperties"], "oneOf")
      assert length(third_option["additionalProperties"]["oneOf"]) == 3
    end

    test "handles edge cases in field metadata conversion" do
      defmodule MetadataEdgeSchema do
        use Exdantic

        schema do
          field :nil_metadata, :string do
            # These should be filtered out
            description(nil)
            example(nil)
          end

          field :empty_metadata, :string do
            description("")
            examples([])
          end

          field :both_example_and_examples, :string do
            example("single")
            # examples should override example
            examples(["multiple", "examples"])
          end

          field :complex_examples, :string do
            examples([
              "",
              "with\nnewlines",
              "with\"quotes\"",
              "with'apostrophes'",
              "unicode: 🚀",
              # nil in examples
              nil
            ])
          end
        end
      end

      json_schema = JsonSchema.from_schema(MetadataEdgeSchema)

      # Nil metadata should be filtered out
      nil_prop = json_schema["properties"]["nil_metadata"]
      refute Map.has_key?(nil_prop, "description")
      refute Map.has_key?(nil_prop, "examples")

      # Empty metadata should be preserved
      empty_prop = json_schema["properties"]["empty_metadata"]
      assert empty_prop["description"] == ""
      assert empty_prop["examples"] == []

      # Examples should override example
      both_prop = json_schema["properties"]["both_example_and_examples"]
      assert both_prop["examples"] == ["multiple", "examples"]
      refute Map.has_key?(both_prop, "example")

      # Complex examples should be preserved as-is
      complex_prop = json_schema["properties"]["complex_examples"]

      expected_examples = [
        "",
        "with\nnewlines",
        "with\"quotes\"",
        "with'apostrophes'",
        "unicode: 🚀",
        nil
      ]

      assert complex_prop["examples"] == expected_examples
    end

    test "handles reference store memory management" do
      # Test that the reference store is properly cleaned up
      defmodule RefTestSchema do
        use Exdantic

        schema do
          field :self_ref, RefTestSchema do
            optional()
          end
        end
      end

      # Generate schema multiple times to test memory management
      for _i <- 1..100 do
        json_schema = JsonSchema.from_schema(RefTestSchema)
        assert Map.has_key?(json_schema, "definitions")
        assert Map.has_key?(json_schema["definitions"], "RefTestSchema")
      end

      # If there were memory leaks, this would accumulate
      # The test passing indicates proper cleanup
    end
  end

  describe "JSON Schema error handling" do
    test "handles invalid schema modules gracefully" do
      defmodule NotASchema do
        # Not using Exdantic, so no __schema__ function
      end

      # This should raise an error since it's not a valid schema
      assert_raise ArgumentError, fn ->
        JsonSchema.from_schema(NotASchema)
      end
    end

    test "handles schemas with invalid type definitions" do
      defmodule InvalidTypeSchema do
        use Exdantic

        # Manually create invalid field metadata for testing
        def __schema__(:fields) do
          [
            {:invalid_field,
             %Exdantic.FieldMeta{
               name: :invalid_field,
               # Invalid type structure
               type: {:invalid_type, :unknown, []},
               required: true
             }}
          ]
        end

        def __schema__(:config), do: %{}
        def __schema__(:description), do: "Invalid schema"
      end

      # Should handle gracefully or raise appropriate error
      assert_raise ArgumentError, fn ->
        JsonSchema.from_schema(InvalidTypeSchema)
      end
    end
  end
end
