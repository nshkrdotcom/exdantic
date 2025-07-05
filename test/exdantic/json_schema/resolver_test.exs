defmodule Exdantic.JsonSchema.ResolverTest do
  use ExUnit.Case, async: true

  alias Exdantic.JsonSchema.Resolver

  describe "resolve_references/2" do
    test "handles simple $ref" do
      schema = %{
        "type" => "object",
        "properties" => %{
          "user" => %{"$ref" => "#/definitions/User"}
        },
        "definitions" => %{
          "User" => %{"type" => "object", "properties" => %{"name" => %{"type" => "string"}}}
        }
      }

      resolved = Resolver.resolve_references(schema)

      refute Map.has_key?(resolved, "definitions")
      assert get_in(resolved, ["properties", "user", "type"]) == "object"
      assert get_in(resolved, ["properties", "user", "properties", "name", "type"]) == "string"
    end

    test "handles nested references" do
      schema = %{
        "type" => "object",
        "properties" => %{
          "company" => %{"$ref" => "#/definitions/Company"}
        },
        "definitions" => %{
          "Company" => %{
            "type" => "object",
            "properties" => %{
              "owner" => %{"$ref" => "#/definitions/User"}
            }
          },
          "User" => %{"type" => "object", "properties" => %{"name" => %{"type" => "string"}}}
        }
      }

      resolved = Resolver.resolve_references(schema)

      refute Map.has_key?(resolved, "definitions")

      assert get_in(resolved, ["properties", "company", "properties", "owner", "type"]) ==
               "object"
    end

    test "prevents circular references" do
      schema = %{
        "type" => "object",
        "properties" => %{
          "node" => %{"$ref" => "#/definitions/Node"}
        },
        "definitions" => %{
          "Node" => %{
            "type" => "object",
            "properties" => %{
              "child" => %{"$ref" => "#/definitions/Node"}
            }
          }
        }
      }

      # Should not crash with circular reference
      resolved = Resolver.resolve_references(schema, max_depth: 2)
      assert is_map(resolved)
    end
  end

  describe "enforce_structured_output/2" do
    test "enforces OpenAI requirements" do
      schema = %{"type" => "object", "additionalProperties" => true}

      openai_schema = Resolver.enforce_structured_output(schema, provider: :openai)

      assert openai_schema["additionalProperties"] == false
      assert Map.has_key?(openai_schema, "properties")
    end

    test "enforces Anthropic requirements" do
      schema = %{"type" => "object", "properties" => %{"name" => %{"type" => "string"}}}

      anthropic_schema = Resolver.enforce_structured_output(schema, provider: :anthropic)

      assert anthropic_schema["additionalProperties"] == false
      assert Map.has_key?(anthropic_schema, "required")
    end

    test "removes unsupported formats for OpenAI" do
      schema = %{
        "type" => "object",
        "properties" => %{
          "email" => %{"type" => "string", "format" => "email"}
        }
      }

      openai_schema = Resolver.enforce_structured_output(schema, provider: :openai)

      refute Map.has_key?(openai_schema["properties"]["email"], "format")
    end
  end

  describe "flatten_schema/2" do
    test "expands references inline" do
      schema = %{
        "type" => "object",
        "properties" => %{
          "user" => %{"$ref" => "#/definitions/User"}
        },
        "definitions" => %{
          "User" => %{"type" => "string"}
        }
      }

      flattened = Resolver.flatten_schema(schema)

      assert get_in(flattened, ["properties", "user", "type"]) == "string"
      refute Map.has_key?(flattened, "definitions")
    end

    test "handles array items" do
      schema = %{
        "type" => "array",
        "items" => %{"$ref" => "#/definitions/Item"},
        "definitions" => %{
          "Item" => %{"type" => "string", "minLength" => 1}
        }
      }

      flattened = Resolver.flatten_schema(schema)

      assert flattened["items"]["type"] == "string"
      assert flattened["items"]["minLength"] == 1
    end
  end

  describe "optimize_for_llm/2" do
    test "removes descriptions when requested" do
      schema = %{
        "type" => "object",
        "description" => "A user object",
        "properties" => %{
          "name" => %{"type" => "string", "description" => "User's name"}
        }
      }

      optimized = Resolver.optimize_for_llm(schema, remove_descriptions: true)

      refute Map.has_key?(optimized, "description")
      refute Map.has_key?(optimized["properties"]["name"], "description")
    end

    test "simplifies large unions" do
      schema = %{
        "oneOf" => [
          %{"type" => "string"},
          %{"type" => "integer"},
          %{"type" => "boolean"},
          %{"type" => "array"},
          %{"type" => "object"}
        ]
      }

      optimized = Resolver.optimize_for_llm(schema, simplify_unions: true)

      assert length(optimized["oneOf"]) == 3
    end
  end
end
