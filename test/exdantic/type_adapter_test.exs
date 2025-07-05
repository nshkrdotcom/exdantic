defmodule Exdantic.TypeAdapterTest do
  use ExUnit.Case, async: true

  alias Exdantic.Error
  alias Exdantic.TypeAdapter

  describe "validate/3 with basic types" do
    test "validates string types" do
      assert {:ok, "hello"} = TypeAdapter.validate(:string, "hello")
      assert {:error, [%Error{code: :type}]} = TypeAdapter.validate(:string, 123)
    end

    test "validates integer types" do
      assert {:ok, 42} = TypeAdapter.validate(:integer, 42)
      assert {:error, [%Error{code: :type}]} = TypeAdapter.validate(:integer, "not a number")
    end

    test "validates boolean types" do
      assert {:ok, true} = TypeAdapter.validate(:boolean, true)
      assert {:ok, false} = TypeAdapter.validate(:boolean, false)
      assert {:error, [%Error{code: :type}]} = TypeAdapter.validate(:boolean, "true")
    end

    test "validates float types" do
      assert {:ok, 3.14} = TypeAdapter.validate(:float, 3.14)
      assert {:error, [%Error{code: :type}]} = TypeAdapter.validate(:float, "3.14")
    end

    test "validates any type" do
      assert {:ok, "string"} = TypeAdapter.validate(:any, "string")
      assert {:ok, 123} = TypeAdapter.validate(:any, 123)
      assert {:ok, %{key: "value"}} = TypeAdapter.validate(:any, %{key: "value"})
    end
  end

  describe "validate/3 with complex types" do
    test "validates array types" do
      assert {:ok, ["a", "b", "c"]} = TypeAdapter.validate({:array, :string}, ["a", "b", "c"])
      assert {:error, _} = TypeAdapter.validate({:array, :string}, ["a", 123, "c"])
      assert {:error, _} = TypeAdapter.validate({:array, :string}, "not an array")
    end

    test "validates nested arrays" do
      type_spec = {:array, {:array, :integer}}
      value = [[1, 2], [3, 4], [5]]

      assert {:ok, ^value} = TypeAdapter.validate(type_spec, value)
    end

    test "validates map types" do
      type_spec = {:map, {:string, :integer}}
      value = %{"a" => 1, "b" => 2}

      assert {:ok, ^value} = TypeAdapter.validate(type_spec, value)
      assert {:error, _} = TypeAdapter.validate(type_spec, %{"a" => "not integer"})
    end

    test "validates union types" do
      type_spec = {:union, [:string, :integer]}

      assert {:ok, "hello"} = TypeAdapter.validate(type_spec, "hello")
      assert {:ok, 42} = TypeAdapter.validate(type_spec, 42)
      assert {:error, _} = TypeAdapter.validate(type_spec, true)
    end

    test "validates complex nested structures" do
      type_spec = {:map, {:string, {:array, {:union, [:string, :integer]}}}}

      value = %{
        "numbers" => [1, 2, 3],
        "mixed" => ["hello", 42, "world"]
      }

      assert {:ok, ^value} = TypeAdapter.validate(type_spec, value)
    end
  end

  describe "validate/3 with constraints" do
    test "validates string length constraints" do
      type_spec = {:type, :string, [min_length: 3, max_length: 10]}

      assert {:ok, "hello"} = TypeAdapter.validate(type_spec, "hello")
      assert {:error, [%Error{code: :min_length}]} = TypeAdapter.validate(type_spec, "hi")

      assert {:error, [%Error{code: :max_length}]} =
               TypeAdapter.validate(type_spec, "this is too long")
    end

    test "validates numeric range constraints" do
      type_spec = {:type, :integer, [gt: 0, lteq: 100]}

      assert {:ok, 50} = TypeAdapter.validate(type_spec, 50)
      assert {:error, [%Error{code: :gt}]} = TypeAdapter.validate(type_spec, 0)
      assert {:error, [%Error{code: :lteq}]} = TypeAdapter.validate(type_spec, 101)
    end

    test "validates array constraints" do
      type_spec = {:array, :string, [min_items: 2, max_items: 4]}

      assert {:ok, ["a", "b"]} = TypeAdapter.validate(type_spec, ["a", "b"])
      assert {:error, [%Error{code: :min_items}]} = TypeAdapter.validate(type_spec, ["a"])

      assert {:error, [%Error{code: :max_items}]} =
               TypeAdapter.validate(type_spec, ["a", "b", "c", "d", "e"])
    end

    test "validates format constraints" do
      type_spec = {:type, :string, [format: ~r/^[a-z]+$/]}

      assert {:ok, "hello"} = TypeAdapter.validate(type_spec, "hello")
      assert {:error, [%Error{code: :format}]} = TypeAdapter.validate(type_spec, "Hello123")
    end

    test "validates choices constraints" do
      type_spec = {:type, :string, [choices: ["red", "green", "blue"]]}

      assert {:ok, "red"} = TypeAdapter.validate(type_spec, "red")
      assert {:error, [%Error{code: :choices}]} = TypeAdapter.validate(type_spec, "yellow")
    end
  end

  describe "validate/3 with coercion" do
    test "coerces string to integer" do
      assert {:ok, 123} = TypeAdapter.validate(:integer, "123", coerce: true)
      assert {:error, _} = TypeAdapter.validate(:integer, "abc", coerce: true)
    end

    test "coerces string to float" do
      assert {:ok, 3.14} = TypeAdapter.validate(:float, "3.14", coerce: true)
      assert {:error, _} = TypeAdapter.validate(:float, "not a number", coerce: true)
    end

    test "coerces integer to string" do
      assert {:ok, "42"} = TypeAdapter.validate(:string, 42, coerce: true)
    end

    test "coerces array elements" do
      type_spec = {:array, :integer}
      value = ["1", "2", "3"]
      expected = [1, 2, 3]

      assert {:ok, ^expected} = TypeAdapter.validate(type_spec, value, coerce: true)
    end

    test "coerces union types" do
      type_spec = {:union, [:string, :integer]}

      assert {:ok, 123} = TypeAdapter.validate(type_spec, "123", coerce: true)
      assert {:ok, "hello"} = TypeAdapter.validate(type_spec, "hello", coerce: true)
    end
  end

  describe "dump/3" do
    test "dumps basic types" do
      assert {:ok, "hello"} = TypeAdapter.dump(:string, "hello")
      assert {:ok, 42} = TypeAdapter.dump(:integer, 42)
      assert {:ok, true} = TypeAdapter.dump(:boolean, true)
    end

    test "dumps atom as string" do
      assert {:ok, "test"} = TypeAdapter.dump(:atom, :test)
    end

    test "dumps arrays" do
      type_spec = {:array, :string}
      value = ["a", "b", "c"]

      assert {:ok, ^value} = TypeAdapter.dump(type_spec, value)
    end

    test "dumps maps" do
      type_spec = {:map, {:string, :integer}}
      value = %{"a" => 1, "b" => 2}

      assert {:ok, ^value} = TypeAdapter.dump(type_spec, value)
    end

    test "dumps complex nested structures" do
      type_spec = {:array, {:map, {:string, :string}}}
      value = [%{"name" => "John"}, %{"name" => "Jane"}]

      assert {:ok, ^value} = TypeAdapter.dump(type_spec, value)
    end

    test "excludes nil values when requested" do
      type_spec = {:array, :string}
      value = ["a", nil, "b"]
      expected = ["a", "b"]

      assert {:ok, ^expected} = TypeAdapter.dump(type_spec, value, exclude_none: true)
    end

    test "handles union types" do
      type_spec = {:union, [:string, :integer]}

      assert {:ok, "hello"} = TypeAdapter.dump(type_spec, "hello")
      assert {:ok, 42} = TypeAdapter.dump(type_spec, 42)
    end
  end

  describe "json_schema/2" do
    test "generates schema for basic types" do
      assert %{"type" => "string"} = TypeAdapter.json_schema(:string)
      assert %{"type" => "integer"} = TypeAdapter.json_schema(:integer)
      assert %{"type" => "boolean"} = TypeAdapter.json_schema(:boolean)
      assert %{"type" => "number"} = TypeAdapter.json_schema(:float)
    end

    test "generates schema for arrays" do
      schema = TypeAdapter.json_schema({:array, :string})

      assert schema["type"] == "array"
      assert schema["items"]["type"] == "string"
    end

    test "generates schema for maps" do
      schema = TypeAdapter.json_schema({:map, {:string, :integer}})

      assert schema["type"] == "object"
      assert schema["additionalProperties"]["type"] == "integer"
    end

    test "generates schema for unions" do
      schema = TypeAdapter.json_schema({:union, [:string, :integer]})

      assert schema["oneOf"]
      assert length(schema["oneOf"]) == 2
      assert Enum.any?(schema["oneOf"], &(&1["type"] == "string"))
      assert Enum.any?(schema["oneOf"], &(&1["type"] == "integer"))
    end

    test "includes constraints in schema" do
      type_spec = {:type, :string, [min_length: 3, max_length: 10]}
      schema = TypeAdapter.json_schema(type_spec)

      assert schema["type"] == "string"
      assert schema["minLength"] == 3
      assert schema["maxLength"] == 10
    end

    test "includes format constraints" do
      type_spec = {:type, :string, [format: ~r/^[a-z]+$/]}
      schema = TypeAdapter.json_schema(type_spec)

      assert schema["pattern"] == "^[a-z]+$"
    end

    test "includes custom title and description" do
      schema = TypeAdapter.json_schema(:string, title: "Name", description: "User's name")

      assert schema["title"] == "Name"
      assert schema["description"] == "User's name"
    end

    test "resolves references when requested" do
      # This would require a more complex setup with actual schema modules
      # For now, test basic reference handling
      schema = TypeAdapter.json_schema(:string, resolve_refs: true)

      assert schema["type"] == "string"
      refute Map.has_key?(schema, "$ref")
    end
  end

  describe "create/2" do
    test "creates reusable adapter instance" do
      adapter = TypeAdapter.create({:array, :string})

      assert %TypeAdapter.Instance{} = adapter
      assert {:ok, ["a", "b"]} = TypeAdapter.Instance.validate(adapter, ["a", "b"])
    end

    test "adapter instance caches JSON schema" do
      adapter = TypeAdapter.create(:string, cache_json_schema: true)

      assert adapter.json_schema != nil
      assert adapter.json_schema["type"] == "string"
    end

    test "adapter instance allows configuration override" do
      adapter = TypeAdapter.create(:integer, coerce: false)

      assert {:error, _} = TypeAdapter.Instance.validate(adapter, "123")
      assert {:ok, 123} = TypeAdapter.Instance.validate(adapter, "123", coerce: true)
    end
  end

  describe "error handling and edge cases" do
    test "handles invalid type specifications gracefully" do
      assert_raise ArgumentError, fn ->
        TypeAdapter.validate({:invalid_type, :string}, "test")
      end
    end

    test "preserves error paths for nested validation" do
      type_spec = {:array, {:map, {:string, :integer}}}
      value = [%{"valid" => 1}, %{"invalid" => "not_int"}]

      assert {:error, [error]} = TypeAdapter.validate(type_spec, value)
      assert error.path == [1, "invalid"]
    end

    test "handles deeply nested structures" do
      type_spec = {:array, {:array, {:array, :string}}}
      value = [[["a", "b"], ["c"]], [["d"]]]

      assert {:ok, ^value} = TypeAdapter.validate(type_spec, value)
    end

    test "validates empty arrays and maps" do
      assert {:ok, []} = TypeAdapter.validate({:array, :string}, [])
      assert {:ok, %{}} = TypeAdapter.validate({:map, {:string, :integer}}, %{})
    end
  end

  describe "performance and edge cases" do
    test "handles large arrays efficiently" do
      large_array = Enum.to_list(1..1000)

      assert {:ok, ^large_array} = TypeAdapter.validate({:array, :integer}, large_array)
    end

    test "handles complex nested validation efficiently" do
      type_spec = {:map, {:string, {:array, {:union, [:string, :integer]}}}}

      value = %{
        "list1" => Enum.to_list(1..100),
        "list2" => Enum.map(1..100, &to_string/1),
        "list3" => Enum.flat_map(1..50, &[&1, to_string(&1)])
      }

      assert {:ok, ^value} = TypeAdapter.validate(type_spec, value)
    end
  end
end
