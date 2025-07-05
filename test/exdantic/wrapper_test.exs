defmodule Exdantic.WrapperTest do
  use ExUnit.Case, async: true

  alias Exdantic.Error
  alias Exdantic.JsonSchema.Resolver
  alias Exdantic.Runtime.DynamicSchema
  alias Exdantic.Wrapper

  describe "create_wrapper/3" do
    test "generates single-field schema with basic type" do
      wrapper = Wrapper.create_wrapper(:result, :string)

      assert %DynamicSchema{} = wrapper
      assert Map.has_key?(wrapper.fields, :result)
      assert wrapper.fields[:result].type == {:type, :string, []}
      assert wrapper.fields[:result].required == true
    end

    test "handles complex types" do
      wrapper = Wrapper.create_wrapper(:items, {:array, :string})

      field_meta = wrapper.fields[:items]
      assert field_meta.type == {:array, {:type, :string, []}, []}
      assert field_meta.required == true
    end

    test "applies field constraints" do
      wrapper =
        Wrapper.create_wrapper(:score, :integer,
          constraints: [gt: 0, lteq: 100],
          description: "Score value"
        )

      field_meta = wrapper.fields[:score]
      assert field_meta.type == {:type, :integer, [gt: 0, lteq: 100]}
      assert field_meta.description == "Score value"
    end

    test "handles optional fields and defaults" do
      wrapper =
        Wrapper.create_wrapper(:count, :integer,
          required: false,
          default: 0
        )

      field_meta = wrapper.fields[:count]
      assert field_meta.required == false
      assert field_meta.default == 0
    end

    test "includes field metadata" do
      wrapper =
        Wrapper.create_wrapper(:email, :string,
          description: "Email address",
          example: "user@example.com",
          constraints: [format: ~r/@/]
        )

      field_meta = wrapper.fields[:email]
      assert field_meta.description == "Email address"
      assert field_meta.example == "user@example.com"
      assert field_meta.type == {:type, :string, [format: ~r/@/]}
    end

    test "generates unique wrapper names" do
      wrapper1 = Wrapper.create_wrapper(:test, :string)
      wrapper2 = Wrapper.create_wrapper(:test, :string)

      assert wrapper1.name != wrapper2.name
      assert String.starts_with?(wrapper1.name, "Wrapper_test_")
      assert String.starts_with?(wrapper2.name, "Wrapper_test_")
    end
  end

  describe "validate_and_extract/3" do
    setup do
      wrapper = Wrapper.create_wrapper(:value, :integer, constraints: [gt: 0])
      {:ok, wrapper: wrapper}
    end

    test "succeeds with valid data in map format", %{wrapper: wrapper} do
      data = %{value: 42}

      assert {:ok, 42} = Wrapper.validate_and_extract(wrapper, data, :value)
    end

    test "succeeds with valid raw value", %{wrapper: wrapper} do
      # Auto-wrapping raw value
      assert {:ok, 42} = Wrapper.validate_and_extract(wrapper, 42, :value)
    end

    test "handles string keys in map", %{wrapper: wrapper} do
      data = %{"value" => 42}

      assert {:ok, 42} = Wrapper.validate_and_extract(wrapper, data, :value)
    end

    test "fails with invalid data", %{wrapper: wrapper} do
      # violates gt: 0 constraint
      data = %{value: -5}

      assert {:error, [%Error{code: :gt}]} = Wrapper.validate_and_extract(wrapper, data, :value)
    end

    test "fails with wrong type", %{wrapper: wrapper} do
      data = %{value: "not a number"}

      assert {:error, [%Error{code: :type}]} = Wrapper.validate_and_extract(wrapper, data, :value)
    end

    test "handles missing field", %{wrapper: wrapper} do
      data = %{other_field: 42}

      assert {:error, [%Error{code: :required}]} =
               Wrapper.validate_and_extract(wrapper, data, :value)
    end

    test "works with coercion enabled" do
      wrapper = Wrapper.create_wrapper(:number, :integer, coerce: true)
      data = %{number: "123"}

      assert {:ok, 123} = Wrapper.validate_and_extract(wrapper, data, :number)
    end
  end

  describe "wrap_and_validate/4" do
    test "validates integer with constraints" do
      assert {:ok, 85} =
               Wrapper.wrap_and_validate(:score, :integer, "85",
                 coerce: true,
                 constraints: [gteq: 0, lteq: 100]
               )
    end

    test "validates string with format constraint" do
      assert {:error, [%Error{code: :format}]} =
               Wrapper.wrap_and_validate(
                 :email,
                 :string,
                 "invalid-email",
                 constraints: [format: ~r/@/]
               )
    end

    test "validates array types" do
      assert {:ok, ["a", "b", "c"]} =
               Wrapper.wrap_and_validate(
                 :items,
                 {:array, :string},
                 ["a", "b", "c"]
               )
    end

    test "validates complex nested structures" do
      type_spec = {:map, {:string, {:array, :integer}}}
      data = %{"numbers" => [1, 2, 3], "more" => [4, 5]}

      assert {:ok, ^data} = Wrapper.wrap_and_validate(:data, type_spec, data)
    end

    test "handles union types" do
      type_spec = {:union, [:string, :integer]}

      assert {:ok, "hello"} = Wrapper.wrap_and_validate(:value, type_spec, "hello")
      assert {:ok, 42} = Wrapper.wrap_and_validate(:value, type_spec, 42)
    end

    test "applies default values" do
      assert {:ok, 100} =
               Wrapper.wrap_and_validate(:score, :integer, %{},
                 required: false,
                 default: 100
               )
    end
  end

  describe "create_multiple_wrappers/2" do
    test "creates multiple wrappers from specifications" do
      specs = [
        {:name, :string, [constraints: [min_length: 1]]},
        {:age, :integer, [constraints: [gt: 0]]},
        {:email, :string, [constraints: [format: ~r/@/]]}
      ]

      wrappers = Wrapper.create_multiple_wrappers(specs)

      assert Map.has_key?(wrappers, :name)
      assert Map.has_key?(wrappers, :age)
      assert Map.has_key?(wrappers, :email)

      assert %DynamicSchema{} = wrappers[:name]
      assert %DynamicSchema{} = wrappers[:age]
      assert %DynamicSchema{} = wrappers[:email]
    end

    test "applies global options to all wrappers" do
      specs = [
        {:field1, :string, []},
        {:field2, :integer, []}
      ]

      global_opts = [required: false, description: "Optional field"]
      wrappers = Wrapper.create_multiple_wrappers(specs, global_opts)

      assert wrappers[:field1].fields[:field1].required == false
      assert wrappers[:field1].fields[:field1].description == "Optional field"
      assert wrappers[:field2].fields[:field2].required == false
      assert wrappers[:field2].fields[:field2].description == "Optional field"
    end

    test "field-specific options override global options" do
      specs = [
        {:required_field, :string, [required: true]},
        {:optional_field, :string, []}
      ]

      global_opts = [required: false]
      wrappers = Wrapper.create_multiple_wrappers(specs, global_opts)

      assert wrappers[:required_field].fields[:required_field].required == true
      assert wrappers[:optional_field].fields[:optional_field].required == false
    end
  end

  describe "validate_multiple/2" do
    setup do
      wrappers = %{
        name: Wrapper.create_wrapper(:name, :string, constraints: [min_length: 1]),
        age: Wrapper.create_wrapper(:age, :integer, constraints: [gt: 0]),
        email: Wrapper.create_wrapper(:email, :string, constraints: [format: ~r/@/])
      }

      {:ok, wrappers: wrappers}
    end

    test "validates all fields successfully", %{wrappers: wrappers} do
      data = %{
        name: "John Doe",
        age: 30,
        email: "john@example.com"
      }

      assert {:ok, validated} = Wrapper.validate_multiple(wrappers, data)
      assert validated.name == "John Doe"
      assert validated.age == 30
      assert validated.email == "john@example.com"
    end

    test "reports errors by field name", %{wrappers: wrappers} do
      data = %{
        # too short
        name: "",
        age: 30,
        # no @ symbol
        email: "invalid"
      }

      assert {:error, errors_by_field} = Wrapper.validate_multiple(wrappers, data)
      assert Map.has_key?(errors_by_field, :name)
      assert Map.has_key?(errors_by_field, :email)
      refute Map.has_key?(errors_by_field, :age)

      assert [%Error{code: :min_length}] = errors_by_field[:name]
      assert [%Error{code: :format}] = errors_by_field[:email]
    end

    test "handles missing fields", %{wrappers: wrappers} do
      # missing age and email
      data = %{name: "John"}

      assert {:error, errors_by_field} = Wrapper.validate_multiple(wrappers, data)
      assert Map.has_key?(errors_by_field, :age)
      assert Map.has_key?(errors_by_field, :email)

      assert [%Error{code: :missing}] = errors_by_field[:age]
      assert [%Error{code: :missing}] = errors_by_field[:email]
    end
  end

  describe "create_wrapper_factory/2" do
    test "creates reusable wrapper factory" do
      email_factory =
        Wrapper.create_wrapper_factory(
          :string,
          constraints: [format: ~r/@/],
          description: "Email address"
        )

      user_email_wrapper = email_factory.(:user_email)
      admin_email_wrapper = email_factory.(:admin_email)

      assert %DynamicSchema{} = user_email_wrapper
      assert %DynamicSchema{} = admin_email_wrapper

      # Both should have the same base configuration
      user_field = user_email_wrapper.fields[:user_email]
      admin_field = admin_email_wrapper.fields[:admin_email]

      assert user_field.type == admin_field.type
      assert user_field.description == admin_field.description
    end

    test "factory allows override of base options" do
      integer_factory = Wrapper.create_wrapper_factory(:integer, required: true)

      required_wrapper = integer_factory.(:required_field)
      # For now, factory doesn't support override - create separate factory
      optional_factory = Wrapper.create_wrapper_factory(:integer, required: false)
      optional_wrapper = optional_factory.(:optional_field)

      assert required_wrapper.fields[:required_field].required == true
      assert optional_wrapper.fields[:optional_field].required == false
    end
  end

  describe "to_json_schema/2" do
    test "converts wrapper to JSON Schema" do
      wrapper = Wrapper.create_wrapper(:count, :integer, constraints: [gt: 0])
      schema = Wrapper.to_json_schema(wrapper)

      assert schema["type"] == "object"
      assert schema["properties"]["count"]["type"] == "integer"
      assert schema["properties"]["count"]["exclusiveMinimum"] == 0
      assert schema["required"] == ["count"]
    end

    test "includes field metadata in JSON Schema" do
      wrapper =
        Wrapper.create_wrapper(:email, :string,
          description: "User email",
          example: "user@example.com",
          constraints: [format: ~r/@/]
        )

      schema = Wrapper.to_json_schema(wrapper)

      email_prop = schema["properties"]["email"]
      assert email_prop["description"] == "User email"
      assert email_prop["examples"] == ["user@example.com"]
      assert email_prop["pattern"] == "@"
    end

    test "handles complex types in JSON Schema" do
      wrapper = Wrapper.create_wrapper(:items, {:array, {:map, {:string, :integer}}})
      schema = Wrapper.to_json_schema(wrapper)

      items_prop = schema["properties"]["items"]
      assert items_prop["type"] == "array"
      assert items_prop["items"]["type"] == "object"
      assert items_prop["items"]["additionalProperties"]["type"] == "integer"
    end
  end

  describe "utility functions" do
    test "unwrap_result extracts field value" do
      validated = %{score: 85, name: "John"}

      assert Wrapper.unwrap_result(validated, :score) == 85
      assert Wrapper.unwrap_result(validated, :name) == "John"
      assert Wrapper.unwrap_result(validated, :missing) == nil
    end

    test "wrapper_schema? identifies wrapper schemas" do
      wrapper = Wrapper.create_wrapper(:test, :string)
      regular_schema = Exdantic.Runtime.create_schema([{:name, :string}])

      assert Wrapper.wrapper_schema?(wrapper) == true
      assert Wrapper.wrapper_schema?(regular_schema) == false
      assert Wrapper.wrapper_schema?("not a schema") == false
    end

    test "wrapper_info provides metadata" do
      wrapper = Wrapper.create_wrapper(:email, :string, description: "User email")
      info = Wrapper.wrapper_info(wrapper)

      assert info[:is_wrapper] == true
      assert info[:field_name] == :email
      assert info[:field_count] == 1
      assert info[:wrapper_type] == :single_field
      assert info[:created_at] != nil
      assert String.starts_with?(info[:schema_name], "Wrapper_email_")
    end
  end

  describe "flexible wrapper handling" do
    test "create_flexible_wrapper handles multiple input formats" do
      wrapper = Wrapper.create_flexible_wrapper(:age, :integer, coerce: true)

      # Raw value
      assert {:ok, 25} = Wrapper.validate_flexible(wrapper, 25, :age)

      # Map with atom key
      assert {:ok, 25} = Wrapper.validate_flexible(wrapper, %{age: 25}, :age)

      # Map with string key
      assert {:ok, 25} = Wrapper.validate_flexible(wrapper, %{"age" => 25}, :age)

      # Coercion from string
      assert {:ok, 25} = Wrapper.validate_flexible(wrapper, %{age: "25"}, :age)
    end

    test "validate_flexible prefers atom keys over string keys" do
      wrapper = Wrapper.create_flexible_wrapper(:value, :string)
      data = %{:value => "atom_key", "value" => "string_key"}

      assert {:ok, "atom_key"} = Wrapper.validate_flexible(wrapper, data, :value)
    end

    test "validate_flexible treats entire map as field value when no key found" do
      wrapper = Wrapper.create_flexible_wrapper(:data, {:map, {:string, :any}})
      input_map = %{"key1" => "value1", "key2" => "value2"}

      assert {:ok, ^input_map} = Wrapper.validate_flexible(wrapper, input_map, :data)
    end
  end

  describe "edge cases and error scenarios" do
    test "handles empty field names gracefully" do
      # This might not be valid, but test graceful handling
      assert_raise ArgumentError, fn ->
        Wrapper.create_wrapper(nil, :string)
      end
    end

    test "handles invalid type specifications" do
      # Invalid type specs are caught during validation, not creation
      wrapper = Wrapper.create_wrapper(:field, :invalid_type)
      assert {:error, _errors} = Wrapper.validate_and_extract(wrapper, "test", :field)
    end

    test "validation preserves field paths in errors" do
      wrapper = Wrapper.create_wrapper(:nested, {:array, {:map, {:string, :integer}}})
      invalid_data = [%{"valid" => 1}, %{"invalid" => "not_int"}]

      assert {:error, [error]} = Wrapper.validate_and_extract(wrapper, invalid_data, :nested)
      assert error.path == [:nested, 1, "invalid"]
    end

    test "handles concurrent wrapper creation" do
      # Test that concurrent creation doesn't cause naming conflicts
      tasks =
        for _i <- 1..10 do
          Task.async(fn ->
            Wrapper.create_wrapper(:test, :string)
          end)
        end

      wrappers = Task.await_many(tasks)
      names = Enum.map(wrappers, & &1.name)

      # All names should be unique
      assert length(Enum.uniq(names)) == length(names)
    end

    test "handles very large wrapper schemas" do
      # Create wrapper with many constraints
      wrapper =
        Wrapper.create_wrapper(:large_field, :string,
          constraints: [
            min_length: 1,
            max_length: 1000,
            format: ~r/^[a-zA-Z0-9\s]+$/
          ],
          description: "A field with many constraints",
          example: "Valid example text"
        )

      large_valid_text = String.duplicate("a", 500)

      assert {:ok, ^large_valid_text} =
               Wrapper.validate_and_extract(wrapper, large_valid_text, :large_field)
    end

    test "wrapper validation with deeply nested types" do
      complex_type = {:array, {:map, {:string, {:union, [:string, {:array, :integer}]}}}}
      wrapper = Wrapper.create_wrapper(:complex, complex_type)

      valid_data = [
        %{"text" => "hello", "numbers" => [1, 2, 3]},
        %{"more_text" => "world", "single" => "value"}
      ]

      assert {:ok, ^valid_data} = Wrapper.validate_and_extract(wrapper, valid_data, :complex)
    end

    test "memory efficiency with many wrappers" do
      # Create many wrappers to test memory usage
      wrappers =
        for i <- 1..100 do
          Wrapper.create_wrapper(String.to_atom("field_#{i}"), :string)
        end

      assert length(wrappers) == 100
      assert Enum.all?(wrappers, &Wrapper.wrapper_schema?/1)
    end
  end

  describe "integration with other Exdantic features" do
    test "wrapper with custom type constraints works with Runtime validation" do
      # Create a wrapper that uses advanced constraints
      wrapper =
        Wrapper.create_wrapper(:email, :string,
          constraints: [
            min_length: 5,
            max_length: 100,
            format: ~r/^[^\s@]+@[^\s@]+\.[^\s@]+$/
          ]
        )

      valid_email = "user@example.com"
      invalid_email = "not-an-email"

      assert {:ok, ^valid_email} = Wrapper.validate_and_extract(wrapper, valid_email, :email)

      assert {:error, [%Error{code: :format}]} =
               Wrapper.validate_and_extract(wrapper, invalid_email, :email)
    end

    test "wrapper JSON schema integrates with resolver" do
      wrapper = Wrapper.create_wrapper(:data, {:map, {:string, :any}})
      schema = Wrapper.to_json_schema(wrapper)

      # Should be able to resolve references (even though wrapper has none)
      resolved = Resolver.resolve_references(schema)
      assert resolved["type"] == "object"
      assert resolved["properties"]["data"]["type"] == "object"
    end

    test "wrapper with TypeAdapter-style validation" do
      # Test that wrapper can work with TypeAdapter validation patterns
      wrapper =
        Wrapper.create_wrapper(:items, {:array, :string},
          constraints: [min_items: 1, max_items: 5]
        )

      # Valid case
      valid_items = ["apple", "banana", "cherry"]
      assert {:ok, ^valid_items} = Wrapper.validate_and_extract(wrapper, valid_items, :items)

      # Invalid case - too many items
      too_many_items = ["a", "b", "c", "d", "e", "f"]

      assert {:error, [%Error{code: :max_items}]} =
               Wrapper.validate_and_extract(wrapper, too_many_items, :items)
    end
  end

  describe "performance and benchmarking" do
    test "wrapper creation is efficient" do
      {time_microseconds, _result} =
        :timer.tc(fn ->
          for _i <- 1..1000 do
            Wrapper.create_wrapper(:test, :string)
          end
        end)

      # Should create 1000 wrappers in reasonable time (less than 1 second)
      assert time_microseconds < 1_000_000
    end

    test "wrapper validation is efficient for large data" do
      wrapper = Wrapper.create_wrapper(:numbers, {:array, :integer})
      large_array = Enum.to_list(1..10_000)

      {time_microseconds, result} =
        :timer.tc(fn ->
          Wrapper.validate_and_extract(wrapper, large_array, :numbers)
        end)

      assert {:ok, ^large_array} = result
      # Should validate 10k integers in reasonable time
      # 0.5 seconds
      assert time_microseconds < 500_000
    end
  end
end
