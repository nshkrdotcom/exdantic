defmodule Exdantic.JsonSchema.TypeMapperTest do
  use ExUnit.Case, async: true
  alias Exdantic.JsonSchema.TypeMapper
  alias Exdantic.Types

  describe "basic types" do
    test "maps string type" do
      type = Types.string()
      assert TypeMapper.to_json_schema(type) == %{"type" => "string"}
    end

    test "maps integer type" do
      type = Types.integer()
      assert TypeMapper.to_json_schema(type) == %{"type" => "integer"}
    end

    test "maps float type" do
      type = Types.float()
      assert TypeMapper.to_json_schema(type) == %{"type" => "number"}
    end

    test "maps boolean type" do
      type = Types.boolean()
      assert TypeMapper.to_json_schema(type) == %{"type" => "boolean"}
    end
  end

  describe "array types" do
    test "maps simple array" do
      type = Types.array(Types.string())

      expected = %{
        "type" => "array",
        "items" => %{"type" => "string"}
      }

      assert TypeMapper.to_json_schema(type) == expected
    end

    test "maps array with constraints" do
      type =
        Types.array(Types.string())
        |> Types.with_constraints(min_items: 1, max_items: 5)

      expected = %{
        "type" => "array",
        "items" => %{"type" => "string"},
        "minItems" => 1,
        "maxItems" => 5
      }

      assert TypeMapper.to_json_schema(type) == expected
    end
  end

  describe "map types" do
    test "maps simple map" do
      type = Types.map(Types.string(), Types.integer())

      expected = %{
        "type" => "object",
        "additionalProperties" => %{"type" => "integer"}
      }

      assert TypeMapper.to_json_schema(type) == expected
    end
  end

  describe "union types" do
    test "maps union to oneOf" do
      type = Types.union([Types.string(), Types.integer()])

      expected = %{
        "oneOf" => [
          %{"type" => "string"},
          %{"type" => "integer"}
        ]
      }

      assert TypeMapper.to_json_schema(type) == expected
    end
  end

  describe "constraints" do
    test "maps string constraints" do
      type =
        Types.string()
        |> Types.with_constraints(
          min_length: 3,
          max_length: 10,
          format: ~r/^[a-z]+$/
        )

      expected = %{
        "type" => "string",
        "minLength" => 3,
        "maxLength" => 10,
        "pattern" => "^[a-z]+$"
      }

      assert TypeMapper.to_json_schema(type) == expected
    end

    test "maps number constraints" do
      type =
        Types.integer()
        |> Types.with_constraints(
          gt: 0,
          lt: 100
        )

      expected = %{
        "type" => "integer",
        "exclusiveMinimum" => 0,
        "exclusiveMaximum" => 100
      }

      assert TypeMapper.to_json_schema(type) == expected
    end
  end
end
