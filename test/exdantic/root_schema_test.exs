defmodule Exdantic.RootSchemaTest do
  use ExUnit.Case, async: true

  alias Exdantic.TypeAdapter.Instance
  alias Exdantic.ValidationError

  describe "basic RootSchema usage" do
    defmodule IntegerListSchema do
      use Exdantic.RootSchema, root: {:array, :integer}
    end

    defmodule StringSchema do
      use Exdantic.RootSchema, root: :string
    end

    defmodule EmailSchema do
      use Exdantic.RootSchema,
        root: {:type, :string, [format: ~r/^[^\s@]+@[^\s@]+\.[^\s@]+$/]}
    end

    test "validates array of integers" do
      assert {:ok, [1, 2, 3]} = IntegerListSchema.validate([1, 2, 3])
      assert {:ok, []} = IntegerListSchema.validate([])

      assert {:error, _} = IntegerListSchema.validate(["not", "integers"])
      assert {:error, _} = IntegerListSchema.validate("not an array")
    end

    test "validates string" do
      assert {:ok, "hello"} = StringSchema.validate("hello")
      assert {:ok, ""} = StringSchema.validate("")

      assert {:error, _} = StringSchema.validate(123)
      assert {:error, _} = StringSchema.validate(nil)
    end

    test "validates string with format constraint" do
      assert {:ok, "user@example.com"} = EmailSchema.validate("user@example.com")
      assert {:ok, "test@domain.org"} = EmailSchema.validate("test@domain.org")

      assert {:error, _} = EmailSchema.validate("invalid-email")
      assert {:error, _} = EmailSchema.validate("@example.com")
      assert {:error, _} = EmailSchema.validate("user@")
    end

    test "validate! raises on error" do
      assert [1, 2, 3] = IntegerListSchema.validate!([1, 2, 3])

      assert_raise ValidationError, fn ->
        IntegerListSchema.validate!(["not", "integers"])
      end
    end

    test "returns root type" do
      assert IntegerListSchema.root_type() == {:array, :integer}
      assert StringSchema.root_type() == :string
    end

    test "generates JSON schema" do
      json_schema = IntegerListSchema.json_schema()
      assert json_schema["type"] == "array"
      assert json_schema["items"]["type"] == "integer"

      string_schema = StringSchema.json_schema()
      assert string_schema["type"] == "string"
    end

    test "__schema__ introspection" do
      assert IntegerListSchema.__schema__(:root_type) == {:array, :integer}
      assert IntegerListSchema.__schema__(:type) == :root_schema
      assert is_map(IntegerListSchema.__schema__(:json_schema))
      assert IntegerListSchema.__schema__(:unknown) == nil
    end
  end

  describe "complex type RootSchemas" do
    defmodule UnionSchema do
      use Exdantic.RootSchema, root: {:union, [:string, :integer]}
    end

    defmodule NestedMapSchema do
      use Exdantic.RootSchema,
        root: {:map, {:string, {:array, :integer}}}
    end

    defmodule TupleSchema do
      use Exdantic.RootSchema, root: {:tuple, [:string, :integer, :boolean]}
    end

    test "validates union types" do
      assert {:ok, "hello"} = UnionSchema.validate("hello")
      assert {:ok, 42} = UnionSchema.validate(42)

      assert {:error, _} = UnionSchema.validate(3.14)
      assert {:error, _} = UnionSchema.validate(true)
    end

    test "validates nested map types" do
      valid_data = %{"key1" => [1, 2, 3], "key2" => [4, 5]}
      assert {:ok, ^valid_data} = NestedMapSchema.validate(valid_data)

      assert {:error, _} = NestedMapSchema.validate(%{"key1" => "not an array"})
      # non-string key
      assert {:error, _} = NestedMapSchema.validate(%{123 => [1, 2, 3]})
    end

    test "validates tuple types" do
      assert {:ok, {"hello", 42, true}} = TupleSchema.validate({"hello", 42, true})

      # wrong size
      assert {:error, _} = TupleSchema.validate({"hello", 42})
      # wrong type
      assert {:error, _} = TupleSchema.validate({"hello", "not int", true})
    end

    test "generates JSON schema for complex types" do
      union_schema = UnionSchema.json_schema()
      # Union types generate "oneOf" in JSON Schema
      assert union_schema["oneOf"]
      assert length(union_schema["oneOf"]) == 2

      map_schema = NestedMapSchema.json_schema()
      assert map_schema["type"] == "object"
      assert map_schema["additionalProperties"]["type"] == "array"
    end
  end

  describe "schema reference RootSchemas" do
    defmodule UserSchema do
      use Exdantic

      schema do
        field(:name, :string, required: true)
        field(:age, :integer, optional: true)
      end
    end

    defmodule UserListSchema do
      use Exdantic.RootSchema, root: {:array, UserSchema}
    end

    defmodule SingleUserSchema do
      use Exdantic.RootSchema, root: UserSchema
    end

    test "validates array of schema references" do
      users = [
        %{name: "John", age: 30},
        %{name: "Jane"}
      ]

      assert {:ok, validated_users} = UserListSchema.validate(users)
      assert length(validated_users) == 2
      assert Enum.all?(validated_users, &is_map/1)
    end

    test "validates single schema reference" do
      user = %{name: "John", age: 30}
      assert {:ok, validated_user} = SingleUserSchema.validate(user)
      assert validated_user.name == "John"
      assert validated_user.age == 30
    end

    test "validates schema reference with missing required field" do
      # missing required name
      invalid_user = %{age: 30}
      assert {:error, _} = SingleUserSchema.validate(invalid_user)
    end

    test "generates JSON schema with references" do
      json_schema = UserListSchema.json_schema()
      assert json_schema["type"] == "array"
      # The items should reference the UserSchema
      assert json_schema["items"]["$ref"]
    end
  end

  describe "error handling" do
    test "requires root option" do
      assert_raise ArgumentError, ~r/RootSchema requires a :root option/, fn ->
        defmodule InvalidSchema do
          use Exdantic.RootSchema
        end
      end
    end

    test "provides meaningful error messages" do
      defmodule NumberSchema do
        use Exdantic.RootSchema, root: :integer
      end

      case NumberSchema.validate("not a number") do
        {:error, error} ->
          assert error.code == :type
          assert error.message =~ "integer"

        other ->
          flunk("Expected error, got: #{inspect(other)}")
      end
    end
  end

  describe "with constraints" do
    defmodule ConstrainedArraySchema do
      use Exdantic.RootSchema,
        root: {:array, {:type, :string, [min_length: 2]}, [min_items: 1, max_items: 3]}
    end

    defmodule ConstrainedStringSchema do
      use Exdantic.RootSchema,
        root: {:type, :string, [min_length: 5, max_length: 10]}
    end

    test "validates array with item and array constraints" do
      assert {:ok, ["hello", "world"]} = ConstrainedArraySchema.validate(["hello", "world"])

      # Too few items
      assert {:error, _} = ConstrainedArraySchema.validate([])

      # Too many items
      assert {:error, _} = ConstrainedArraySchema.validate(["a", "b", "c", "d"])

      # Item too short
      assert {:error, _} = ConstrainedArraySchema.validate(["a"])
    end

    test "validates string with length constraints" do
      assert {:ok, "hello"} = ConstrainedStringSchema.validate("hello")
      assert {:ok, "1234567890"} = ConstrainedStringSchema.validate("1234567890")

      # Too short
      assert {:error, _} = ConstrainedStringSchema.validate("hi")

      # Too long
      assert {:error, _} = ConstrainedStringSchema.validate("this is too long")
    end
  end

  describe "integration with existing Exdantic features" do
    defmodule PersonSchema do
      use Exdantic

      schema do
        field(:name, :string, required: true)
        field(:email, :string, required: true)
        field(:age, :integer, optional: true)
      end
    end

    defmodule PersonListSchema do
      use Exdantic.RootSchema, root: {:array, PersonSchema}
    end

    test "works with TypeAdapter" do
      # Create a TypeAdapter for the same type
      adapter = Exdantic.TypeAdapter.create({:array, :integer})

      # Both should validate the same data successfully
      data = [1, 2, 3, 4, 5]

      defmodule IntListSchema do
        use Exdantic.RootSchema, root: {:array, :integer}
      end

      assert {:ok, validated1} = IntListSchema.validate(data)
      assert {:ok, validated2} = Instance.validate(adapter, data)
      assert validated1 == validated2
    end

    test "integrates with enhanced validation features" do
      people = [
        %{name: "John", email: "john@example.com", age: 30},
        %{name: "Jane", email: "jane@example.com"}
      ]

      assert {:ok, validated_people} = PersonListSchema.validate(people)
      assert length(validated_people) == 2

      assert Enum.all?(validated_people, fn person ->
               Map.has_key?(person, :name) and Map.has_key?(person, :email)
             end)
    end
  end

  describe "JSON Schema generation edge cases" do
    defmodule AnyTypeSchema do
      use Exdantic.RootSchema, root: :any
    end

    defmodule MapSchema do
      use Exdantic.RootSchema, root: :map
    end

    test "generates schema for any type" do
      json_schema = AnyTypeSchema.json_schema()
      # :any type should generate a permissive schema
      assert is_map(json_schema)
    end

    test "generates schema for map type" do
      json_schema = MapSchema.json_schema()
      assert json_schema["type"] == "object"
    end

    test "validates any type accepts anything" do
      assert {:ok, "string"} = AnyTypeSchema.validate("string")
      assert {:ok, 123} = AnyTypeSchema.validate(123)
      assert {:ok, [1, 2, 3]} = AnyTypeSchema.validate([1, 2, 3])
      assert {:ok, %{key: "value"}} = AnyTypeSchema.validate(%{key: "value"})
    end
  end
end
