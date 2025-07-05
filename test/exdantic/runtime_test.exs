defmodule Exdantic.RuntimeTest do
  use ExUnit.Case, async: true

  alias Exdantic.Error
  alias Exdantic.Runtime
  alias Exdantic.Runtime.DynamicSchema

  describe "create_schema/2" do
    test "creates schema with basic field definitions" do
      fields = [
        {:name, :string, [required: true]},
        {:age, :integer, [required: false]}
      ]

      schema = Runtime.create_schema(fields)

      assert %DynamicSchema{} = schema
      assert schema.fields[:name].type == {:type, :string, []}
      assert schema.fields[:name].required == true
      assert schema.fields[:age].type == {:type, :integer, []}
      assert schema.fields[:age].required == false
    end

    test "creates schema with complex nested types" do
      fields = [
        {:tags, {:array, :string}, [required: true, min_items: 1]},
        {:metadata, {:map, {:string, :any}}, [required: false]},
        {:choice, {:union, [:string, :integer]}, [required: true]}
      ]

      schema = Runtime.create_schema(fields)

      assert schema.fields[:tags].type == {:array, {:type, :string, []}, [min_items: 1]}

      assert schema.fields[:metadata].type ==
               {:map, {{:type, :string, []}, {:type, :any, []}}, []}

      assert schema.fields[:choice].type ==
               {:union, [{:type, :string, []}, {:type, :integer, []}], []}
    end

    test "creates schema with constraints and validations" do
      fields = [
        {:email, :string, [required: true, format: ~r/@/, min_length: 5]},
        {:score, :integer, [required: true, gt: 0, lteq: 100]}
      ]

      schema = Runtime.create_schema(fields)

      assert schema.fields[:email].type == {:type, :string, [format: ~r/@/, min_length: 5]}
      assert schema.fields[:score].type == {:type, :integer, [gt: 0, lteq: 100]}
    end

    test "creates schema with custom configuration" do
      fields = [{:name, :string}]
      opts = [title: "Test Schema", description: "A test schema", strict: true]

      schema = Runtime.create_schema(fields, opts)

      assert schema.config[:title] == "Test Schema"
      assert schema.config[:description] == "A test schema"
      assert schema.config[:strict] == true
    end

    test "handles default values correctly" do
      fields = [
        {:name, :string, [required: true]},
        {:active, :boolean, [default: true]},
        {:count, :integer, [default: 0]}
      ]

      schema = Runtime.create_schema(fields)

      assert schema.fields[:name].required == true
      assert schema.fields[:active].required == false
      assert schema.fields[:active].default == true
      assert schema.fields[:count].required == false
      assert schema.fields[:count].default == 0
    end
  end

  describe "validate/3" do
    setup do
      fields = [
        {:name, :string, [required: true, min_length: 2]},
        {:age, :integer, [required: false, gt: 0]},
        {:email, :string, [required: true, format: ~r/@/]},
        {:active, :boolean, [default: true]}
      ]

      schema = Runtime.create_schema(fields)
      {:ok, schema: schema}
    end

    test "validates valid data successfully", %{schema: schema} do
      data = %{
        name: "John Doe",
        age: 30,
        email: "john@example.com"
      }

      assert {:ok, validated} = Runtime.validate(data, schema)
      assert validated.name == "John Doe"
      assert validated.age == 30
      assert validated.email == "john@example.com"
      # default value
      assert validated.active == true
    end

    test "validates with string keys", %{schema: schema} do
      data = %{
        "name" => "Jane Doe",
        "email" => "jane@example.com"
      }

      assert {:ok, validated} = Runtime.validate(data, schema)
      assert validated.name == "Jane Doe"
      assert validated.email == "jane@example.com"
    end

    test "fails validation with missing required fields", %{schema: schema} do
      # missing required email
      data = %{name: "John"}

      assert {:error, [error]} = Runtime.validate(data, schema)
      assert %Error{code: :required} = error
    end

    test "fails validation with invalid field values", %{schema: schema} do
      data = %{
        # too short
        name: "J",
        email: "john@example.com"
      }

      assert {:error, [error]} = Runtime.validate(data, schema)
      assert %Error{code: :min_length} = error
    end

    test "preserves field paths in error messages", %{schema: schema} do
      data = %{
        name: "John",
        # no @ symbol
        email: "invalid-email"
      }

      assert {:error, [error]} = Runtime.validate(data, schema)
      assert error.path == [:email]
      assert error.code == :format
    end

    test "validates with strict mode enabled" do
      fields = [{:name, :string, [required: true]}]
      schema = Runtime.create_schema(fields, strict: true)

      data = %{name: "John", extra_field: "not allowed"}

      assert {:error, [error]} = Runtime.validate(data, schema)
      assert error.code == :additional_properties
    end

    test "allows extra fields in non-strict mode" do
      fields = [{:name, :string, [required: true]}]
      schema = Runtime.create_schema(fields, strict: false)

      data = %{name: "John", extra_field: "allowed"}

      assert {:ok, validated} = Runtime.validate(data, schema)
      assert validated.name == "John"
    end
  end

  describe "to_json_schema/2" do
    test "generates valid JSON Schema for basic types" do
      fields = [
        {:name, :string, [min_length: 1]},
        {:age, :integer, [gt: 0, optional: true]}
      ]

      schema = Runtime.create_schema(fields)
      json_schema = Runtime.to_json_schema(schema)

      assert json_schema["type"] == "object"
      assert json_schema["properties"]["name"]["type"] == "string"
      assert json_schema["properties"]["name"]["minLength"] == 1
      assert json_schema["properties"]["age"]["type"] == "integer"
      assert json_schema["properties"]["age"]["exclusiveMinimum"] == 0
      assert json_schema["required"] == ["name"]
    end

    test "generates JSON Schema for complex types" do
      fields = [
        {:tags, {:array, :string}, [min_items: 1]},
        {:metadata, {:map, {:string, :integer}}}
      ]

      schema = Runtime.create_schema(fields)
      json_schema = Runtime.to_json_schema(schema)

      tags_schema = json_schema["properties"]["tags"]
      assert tags_schema["type"] == "array"
      assert tags_schema["items"]["type"] == "string"
      assert tags_schema["minItems"] == 1

      metadata_schema = json_schema["properties"]["metadata"]
      assert metadata_schema["type"] == "object"
      assert metadata_schema["additionalProperties"]["type"] == "integer"
    end

    test "includes schema metadata" do
      fields = [{:name, :string}]
      opts = [title: "Test Schema", description: "A test"]

      schema = Runtime.create_schema(fields, opts)
      json_schema = Runtime.to_json_schema(schema)

      assert json_schema["title"] == "Test Schema"
      assert json_schema["description"] == "A test"
    end

    test "handles strict mode in JSON Schema" do
      fields = [{:name, :string}]
      schema = Runtime.create_schema(fields, strict: true)

      json_schema = Runtime.to_json_schema(schema)

      assert json_schema["additionalProperties"] == false
    end
  end

  describe "integration scenarios" do
    test "supports all field types" do
      fields = [
        {:str_field, :string},
        {:int_field, :integer},
        {:float_field, :float},
        {:bool_field, :boolean},
        {:atom_field, :atom},
        {:any_field, :any},
        {:map_field, :map},
        {:array_field, {:array, :string}},
        {:typed_map, {:map, {:string, :integer}}},
        {:union_field, {:union, [:string, :integer]}}
      ]

      schema = Runtime.create_schema(fields)

      data = %{
        str_field: "test",
        int_field: 42,
        float_field: 3.14,
        bool_field: true,
        atom_field: :test,
        any_field: %{nested: "value"},
        map_field: %{key: "value"},
        array_field: ["a", "b", "c"],
        typed_map: %{"key1" => 1, "key2" => 2},
        union_field: "string_value"
      }

      assert {:ok, validated} = Runtime.validate(data, schema)
      assert validated.str_field == "test"
      assert validated.int_field == 42
      assert validated.union_field == "string_value"
    end

    test "complex nested validation" do
      fields = [
        {:user, {:map, {:string, :any}}, [required: true]},
        {:roles, {:array, :string}, [min_items: 1, max_items: 5]},
        {:settings, {:map, {:string, {:union, [:string, :boolean, :integer]}}}}
      ]

      schema = Runtime.create_schema(fields)

      data = %{
        user: %{"name" => "John", "id" => 123},
        roles: ["admin", "user"],
        settings: %{"theme" => "dark", "notifications" => true, "timeout" => 300}
      }

      assert {:ok, validated} = Runtime.validate(data, schema)
      assert validated.user["name"] == "John"
      assert length(validated.roles) == 2
      assert validated.settings["theme"] == "dark"
    end
  end
end
