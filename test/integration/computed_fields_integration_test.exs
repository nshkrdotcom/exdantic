defmodule Exdantic.ComputedFieldsIntegrationTest do
  use ExUnit.Case, async: true

  describe "computed fields with existing Exdantic features" do
    # Test interaction with TypeAdapter
    test "computed fields work with TypeAdapter validation" do
      defmodule ProductSchema do
        use Exdantic, define_struct: true

        schema do
          field(:name, :string, required: true)
          field(:price, :float, required: true)
          field(:quantity, :integer, required: true)

          computed_field(:total_value, :float, :calculate_total_value)
          computed_field(:display_price, :string, :format_price)
        end

        def calculate_total_value(data) do
          {:ok, data.price * data.quantity}
        end

        def format_price(data) do
          {:ok, "$#{:erlang.float_to_binary(data.price, decimals: 2)}"}
        end
      end

      # Test that TypeAdapter can validate the schema type
      type_spec = {:ref, ProductSchema}
      data = %{name: "Widget", price: 9.99, quantity: 5}

      assert {:ok, validated} = Exdantic.TypeAdapter.validate(type_spec, data)

      # Should include computed fields
      assert validated.total_value == 49.95
      assert validated.display_price == "$9.99"
    end

    # Test interaction with Runtime schemas
    test "computed fields behavior with Runtime.create_schema" do
      # Runtime schemas don't support computed fields yet (that's Phase 5)
      # But we should ensure they don't break
      fields = [
        {:name, :string, [required: true]},
        {:email, :string, [required: true]}
      ]

      runtime_schema = Exdantic.Runtime.create_schema(fields)
      data = %{name: "John", email: "john@example.com"}

      assert {:ok, validated} = Exdantic.Runtime.validate(data, runtime_schema)
      assert validated.name == "John"
      assert validated.email == "john@example.com"

      # No computed fields should be present
      refute Map.has_key?(validated, :computed_field)
    end

    # Test interaction with EnhancedValidator
    test "computed fields work with EnhancedValidator" do
      defmodule UserProfileSchema do
        use Exdantic, define_struct: true

        schema do
          field(:username, :string, required: true)
          field(:bio, :string, required: false)
          field(:follower_count, :integer, required: false, default: 0)

          computed_field(:profile_summary, :string, :create_profile_summary)
          computed_field(:influence_level, :string, :calculate_influence)
        end

        def create_profile_summary(data) do
          bio_text = data.bio || "No bio provided"
          {:ok, "#{data.username}: #{bio_text}"}
        end

        def calculate_influence(data) do
          level =
            case data.follower_count do
              count when count < 100 -> "beginner"
              count when count < 1000 -> "growing"
              count when count < 10_000 -> "influencer"
              _ -> "celebrity"
            end

          {:ok, level}
        end
      end

      config = Exdantic.Config.create(strict: true, coercion: :safe)
      data = %{username: "johndoe", bio: "Software developer", follower_count: 1500}

      assert {:ok, validated} =
               Exdantic.EnhancedValidator.validate(UserProfileSchema, data, config: config)

      assert validated.username == "johndoe"
      assert validated.profile_summary == "johndoe: Software developer"
      assert validated.influence_level == "influencer"
    end

    # Test interaction with Config and validation options
    test "computed fields work with different validation configurations" do
      defmodule ConfigurableSchema do
        use Exdantic, define_struct: true

        schema do
          field(:input_text, :string, required: true)

          computed_field(:processed_text, :string, :process_text)
        end

        def process_text(data) do
          processed = String.upcase(String.trim(data.input_text))
          {:ok, processed}
        end
      end

      # Test with strict config
      strict_config = Exdantic.Config.create(strict: true, extra: :forbid)
      data = %{input_text: "  hello world  "}

      assert {:ok, result} =
               Exdantic.EnhancedValidator.validate(ConfigurableSchema, data,
                 config: strict_config
               )

      assert result.processed_text == "HELLO WORLD"

      # Test with lenient config
      lenient_config = Exdantic.Config.create(strict: false, extra: :allow)
      data_with_extra = %{input_text: "test", extra_field: "ignored"}

      assert {:ok, result} =
               Exdantic.EnhancedValidator.validate(ConfigurableSchema, data_with_extra,
                 config: lenient_config
               )

      assert result.processed_text == "TEST"
    end

    # Test interaction with Wrapper functionality
    test "computed fields work with Wrapper validation" do
      defmodule WrappedComputedSchema do
        use Exdantic, define_struct: true

        schema do
          field(:raw_data, :string, required: true)

          computed_field(:processed_data, :string, :transform_data)
        end

        def transform_data(data) do
          {:ok, "PROCESSED: #{data.raw_data}"}
        end
      end

      # Create wrapper for the entire schema
      wrapper =
        Exdantic.Wrapper.create_wrapper(:result, {:ref, WrappedComputedSchema}, coerce: false)

      input_data = %{raw_data: "test input"}

      assert {:ok, validated} =
               Exdantic.Wrapper.validate_and_extract(wrapper, input_data, :result)

      assert validated.raw_data == "test input"
      assert validated.processed_data == "PROCESSED: test input"
    end

    # Test computed fields with complex types
    test "computed fields with complex type validation" do
      defmodule ComplexTypeSchema do
        use Exdantic, define_struct: true

        schema do
          field(:numbers, {:array, :integer}, required: true)
          field(:metadata, {:map, {:string, :any}}, required: false, default: %{})

          computed_field(:statistics, {:map, {:string, :float}}, :calculate_statistics)
          computed_field(:summary_list, {:array, :string}, :create_summary_list)
        end

        def calculate_statistics(data) do
          numbers = data.numbers
          count = length(numbers)
          sum = Enum.sum(numbers)
          avg = if count > 0, do: sum / count, else: 0.0

          stats = %{
            "count" => count * 1.0,
            "sum" => sum * 1.0,
            "average" => avg
          }

          {:ok, stats}
        end

        def create_summary_list(data) do
          summary = [
            "#{length(data.numbers)} numbers provided",
            "Sum: #{Enum.sum(data.numbers)}",
            "Metadata keys: #{Map.keys(data.metadata) |> Enum.join(", ")}"
          ]

          {:ok, summary}
        end
      end

      data = %{
        numbers: [1, 2, 3, 4, 5],
        metadata: %{"source" => "test", "version" => "1.0"}
      }

      assert {:ok, validated} = ComplexTypeSchema.validate(data)

      # Verify complex computed field types
      assert is_map(validated.statistics)
      assert validated.statistics["count"] == 5.0
      assert validated.statistics["average"] == 3.0

      assert is_list(validated.summary_list)
      assert length(validated.summary_list) == 3
      assert hd(validated.summary_list) == "5 numbers provided"
    end

    # Test computed fields with union types
    test "computed fields with union type validation" do
      defmodule UnionTypeSchema do
        use Exdantic, define_struct: true

        schema do
          field(:value, {:union, [:string, :integer]}, required: true)

          computed_field(:value_type, :string, :determine_value_type)
          computed_field(:formatted_value, {:union, [:string, :integer]}, :format_value)
        end

        def determine_value_type(data) do
          type =
            case data.value do
              val when is_binary(val) -> "string"
              val when is_integer(val) -> "integer"
              _ -> "unknown"
            end

          {:ok, type}
        end

        def format_value(data) do
          case data.value do
            val when is_binary(val) -> {:ok, String.upcase(val)}
            val when is_integer(val) -> {:ok, val * 2}
            _ -> {:error, "unsupported value type"}
          end
        end
      end

      # Test with string input
      assert {:ok, result1} = UnionTypeSchema.validate(%{value: "hello"})
      assert result1.value_type == "string"
      assert result1.formatted_value == "HELLO"

      # Test with integer input
      assert {:ok, result2} = UnionTypeSchema.validate(%{value: 42})
      assert result2.value_type == "integer"
      assert result2.formatted_value == 84
    end
  end

  describe "computed fields performance and edge cases" do
    test "computed fields with large data sets" do
      defmodule LargeDataSchema do
        use Exdantic, define_struct: true

        schema do
          field(:items, {:array, :integer}, required: true)

          computed_field(:item_count, :integer, :count_items)
          computed_field(:item_sum, :integer, :sum_items)
          computed_field(:item_stats, {:map, {:string, :float}}, :calculate_comprehensive_stats)
        end

        def count_items(data) do
          {:ok, length(data.items)}
        end

        def sum_items(data) do
          {:ok, Enum.sum(data.items)}
        end

        def calculate_comprehensive_stats(data) do
          items = data.items
          count = length(items)

          if count == 0 do
            {:ok, %{"count" => 0.0, "sum" => 0.0, "mean" => 0.0, "median" => 0.0}}
          else
            sum = Enum.sum(items)
            mean = sum / count
            sorted = Enum.sort(items)

            median =
              if rem(count, 2) == 0 do
                mid1 = Enum.at(sorted, div(count, 2) - 1)
                mid2 = Enum.at(sorted, div(count, 2))
                (mid1 + mid2) / 2
              else
                Enum.at(sorted, div(count, 2))
              end

            stats = %{
              "count" => count * 1.0,
              "sum" => sum * 1.0,
              "mean" => mean,
              "median" => median * 1.0
            }

            {:ok, stats}
          end
        end
      end

      # Test with moderately large dataset
      large_data = %{items: Enum.to_list(1..1000)}

      start_time = System.monotonic_time(:microsecond)
      assert {:ok, result} = LargeDataSchema.validate(large_data)
      end_time = System.monotonic_time(:microsecond)

      # Validation should complete in reasonable time (less than 100ms)
      duration_ms = (end_time - start_time) / 1000
      assert duration_ms < 100

      # Verify computed results
      assert result.item_count == 1000
      # sum of 1..1000
      assert result.item_sum == 500_500
      assert result.item_stats["count"] == 1000.0
      assert result.item_stats["mean"] == 500.5
    end

    test "computed fields with nested data access" do
      defmodule NestedDataSchema do
        use Exdantic, define_struct: true

        schema do
          field(:user, {:map, {:string, :any}}, required: true)
          field(:preferences, {:map, {:string, :any}}, required: false, default: %{})

          computed_field(:user_display, :string, :format_user_display)
          computed_field(:theme_preference, :string, :extract_theme)
        end

        def format_user_display(data) do
          user = data.user
          name = Map.get(user, "name", "Unknown")
          email = Map.get(user, "email", "no-email")
          {:ok, "#{name} (#{email})"}
        end

        def extract_theme(data) do
          theme = get_in(data.preferences, ["ui", "theme"]) || "default"
          {:ok, theme}
        end
      end

      data = %{
        user: %{"name" => "John Doe", "email" => "john@example.com"},
        preferences: %{"ui" => %{"theme" => "dark", "language" => "en"}}
      }

      assert {:ok, result} = NestedDataSchema.validate(data)
      assert result.user_display == "John Doe (john@example.com)"
      assert result.theme_preference == "dark"
    end

    test "computed field error isolation" do
      defmodule ErrorIsolationSchema do
        use Exdantic, define_struct: true

        schema do
          field(:name, :string, required: true)

          computed_field(:good_field, :string, :working_computation)
          computed_field(:error_field, :string, :failing_computation)
          computed_field(:another_good_field, :string, :another_working_computation)
        end

        def working_computation(data) do
          {:ok, "#{data.name}_processed"}
        end

        def failing_computation(_data) do
          {:error, "This computation fails"}
        end

        def another_working_computation(data) do
          {:ok, "#{data.name}_also_processed"}
        end
      end

      data = %{name: "test"}
      assert {:error, errors} = ErrorIsolationSchema.validate(data)

      # Should have exactly one error for the failing computed field
      assert length(errors) == 1
      error = hd(errors)
      assert error.path == [:error_field]
      assert error.code == :computed_field
      assert error.message == "This computation fails"
    end

    test "computed fields with data dependencies" do
      defmodule DependentComputedSchema do
        use Exdantic, define_struct: true

        schema do
          field(:base_price, :float, required: true)
          field(:tax_rate, :float, required: true)
          field(:discount_percent, :integer, required: false, default: 0)

          computed_field(:discount_amount, :float, :calculate_discount)
          computed_field(:tax_amount, :float, :calculate_tax)
          computed_field(:final_price, :float, :calculate_final_price)
        end

        def calculate_discount(data) do
          discount = data.base_price * (data.discount_percent / 100.0)
          {:ok, discount}
        end

        def calculate_tax(data) do
          # Note: This computation depends on discount being calculated,
          # but computed fields don't see each other's results in the current implementation
          # This is intentional for Phase 3 - computed field dependencies are a future enhancement
          discounted_price = data.base_price * (1 - data.discount_percent / 100.0)
          tax = discounted_price * data.tax_rate
          {:ok, tax}
        end

        def calculate_final_price(data) do
          discounted_price = data.base_price * (1 - data.discount_percent / 100.0)
          tax = discounted_price * data.tax_rate
          final = discounted_price + tax
          {:ok, final}
        end
      end

      data = %{base_price: 100.0, tax_rate: 0.08, discount_percent: 10}
      assert {:ok, result} = DependentComputedSchema.validate(data)

      assert_in_delta result.discount_amount, 10.0, 0.01
      # 8% of $90
      assert_in_delta result.tax_amount, 7.2, 0.01
      # $90 + $7.20 tax
      assert_in_delta result.final_price, 97.2, 0.01
    end
  end

  describe "computed fields backwards compatibility" do
    test "existing schemas without computed fields continue to work" do
      # This should pass all existing tests
      # Run a sample of existing validation patterns to ensure compatibility

      defmodule LegacySchema do
        use Exdantic, define_struct: true

        schema do
          field(:name, :string, required: true)
          field(:age, :integer, required: false)
          field(:email, :string, required: true)

          config do
            title("Legacy Schema")
            strict(true)
          end
        end
      end

      data = %{name: "John", age: 30, email: "john@example.com"}
      assert {:ok, result} = LegacySchema.validate(data)

      assert result.name == "John"
      assert result.age == 30
      assert result.email == "john@example.com"

      # Should not have any computed fields
      assert LegacySchema.__schema__(:computed_fields) == []
    end

    test "JSON schema generation for legacy schemas unchanged" do
      defmodule LegacySchemaForJSON do
        use Exdantic

        schema do
          field(:name, :string, required: true)
          field(:optional_field, :string, required: false)
        end
      end

      json_schema = Exdantic.JsonSchema.from_schema(LegacySchemaForJSON)

      assert json_schema["type"] == "object"
      assert Map.has_key?(json_schema["properties"], "name")
      assert Map.has_key?(json_schema["properties"], "optional_field")
      assert "name" in json_schema["required"]
      refute "optional_field" in json_schema["required"]

      # No computed fields should be present
      refute Exdantic.JsonSchema.has_computed_fields?(json_schema)
    end

    test "all existing validation patterns still work" do
      # Test various existing patterns to ensure no regressions

      # Pattern 1: Basic validation
      defmodule BasicSchema do
        use Exdantic

        schema do
          field(:name, :string, required: true)
        end
      end

      assert {:ok, %{name: "test"}} = BasicSchema.validate(%{name: "test"})

      # Pattern 2: With constraints
      defmodule ConstraintSchema do
        use Exdantic

        schema do
          field :age, :integer do
            required()
            gt(0)
            lt(150)
          end
        end
      end

      assert {:ok, %{age: 25}} = ConstraintSchema.validate(%{age: 25})
      assert {:error, _} = ConstraintSchema.validate(%{age: -5})

      # Pattern 3: With defaults
      defmodule DefaultSchema do
        use Exdantic

        schema do
          field(:name, :string, required: true)
          field(:active, :boolean, default: true)
        end
      end

      assert {:ok, result} = DefaultSchema.validate(%{name: "test"})
      assert result.active == true

      # Pattern 4: Array and map types
      defmodule ComplexSchema do
        use Exdantic

        schema do
          field(:tags, {:array, :string}, required: true)
          field(:metadata, {:map, {:string, :any}}, required: false)
        end
      end

      data = %{tags: ["tag1", "tag2"], metadata: %{"key" => "value"}}
      assert {:ok, result} = ComplexSchema.validate(data)
      assert result.tags == ["tag1", "tag2"]
    end
  end
end
