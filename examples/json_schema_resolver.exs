#!/usr/bin/env elixir

# JSON Schema Resolver Example
# Run with: elixir examples/json_schema_resolver.exs

Mix.install([{:exdantic, path: "."}])

IO.puts("""
🔗 Exdantic JSON Schema Resolver Example
=======================================

This example demonstrates advanced JSON schema reference resolution,
flattening, and LLM provider optimizations.
""")

# Example 1: Basic Reference Resolution
IO.puts("\n🔗 Example 1: Basic Reference Resolution")

# Create a schema with references
schema_with_refs = %{
  "type" => "object",
  "properties" => %{
    "user" => %{"$ref" => "#/definitions/User"},
    "address" => %{"$ref" => "#/definitions/Address"}
  },
  "required" => ["user"],
  "definitions" => %{
    "User" => %{
      "type" => "object",
      "properties" => %{
        "name" => %{"type" => "string"},
        "age" => %{"type" => "integer"}
      },
      "required" => ["name"]
    },
    "Address" => %{
      "type" => "object",
      "properties" => %{
        "street" => %{"type" => "string"},
        "city" => %{"type" => "string"}
      }
    }
  }
}

IO.puts("✅ Original schema with references:")
IO.puts(Jason.encode!(schema_with_refs, pretty: true))

# Resolve all references
resolved_schema = Exdantic.JsonSchema.Resolver.resolve_references(schema_with_refs)

IO.puts("\n✅ Resolved schema (references expanded):")
IO.puts(Jason.encode!(resolved_schema, pretty: true))

# Example 2: Nested Reference Resolution
IO.puts("\n🏗️ Example 2: Nested Reference Resolution")

nested_schema = %{
  "type" => "object",
  "properties" => %{
    "company" => %{"$ref" => "#/definitions/Company"}
  },
  "definitions" => %{
    "Company" => %{
      "type" => "object",
      "properties" => %{
        "name" => %{"type" => "string"},
        "owner" => %{"$ref" => "#/definitions/Person"},
        "employees" => %{
          "type" => "array",
          "items" => %{"$ref" => "#/definitions/Person"}
        }
      }
    },
    "Person" => %{
      "type" => "object",
      "properties" => %{
        "name" => %{"type" => "string"},
        "contact" => %{"$ref" => "#/definitions/Contact"}
      }
    },
    "Contact" => %{
      "type" => "object",
      "properties" => %{
        "email" => %{"type" => "string", "format" => "email"},
        "phone" => %{"type" => "string"}
      }
    }
  }
}

resolved_nested = Exdantic.JsonSchema.Resolver.resolve_references(nested_schema)

IO.puts("✅ Nested references resolved successfully")
IO.puts("   Company owner type: #{get_in(resolved_nested, ["properties", "company", "properties", "owner", "type"])}")
IO.puts("   Employee contact email type: #{get_in(resolved_nested, ["properties", "company", "properties", "employees", "items", "properties", "contact", "properties", "email", "type"])}")

# Example 3: Circular Reference Detection
IO.puts("\n🔄 Example 3: Circular Reference Detection")

circular_schema = %{
  "type" => "object",
  "properties" => %{
    "node" => %{"$ref" => "#/definitions/Node"}
  },
  "definitions" => %{
    "Node" => %{
      "type" => "object",
      "properties" => %{
        "value" => %{"type" => "string"},
        "children" => %{
          "type" => "array",
          "items" => %{"$ref" => "#/definitions/Node"}
        },
        "parent" => %{"$ref" => "#/definitions/Node"}
      }
    }
  }
}

# Resolve with depth limit to handle circular references
resolved_circular = Exdantic.JsonSchema.Resolver.resolve_references(circular_schema, max_depth: 3)

IO.puts("✅ Circular references handled with depth limit")
IO.puts("   Schema is still valid: #{Map.has_key?(resolved_circular, "type")}")

# Example 4: Schema Flattening
IO.puts("\n📄 Example 4: Schema Flattening")

complex_schema = %{
  "type" => "object",
  "properties" => %{
    "data" => %{
      "type" => "array",
      "items" => %{"$ref" => "#/definitions/Item"}
    },
    "metadata" => %{"$ref" => "#/definitions/Metadata"}
  },
  "definitions" => %{
    "Item" => %{
      "type" => "object",
      "properties" => %{
        "id" => %{"type" => "string"},
        "tags" => %{
          "type" => "array",
          "items" => %{"$ref" => "#/definitions/Tag"}
        }
      }
    },
    "Tag" => %{
      "type" => "string",
      "minLength" => 1,
      "maxLength" => 50
    },
    "Metadata" => %{
      "type" => "object",
      "properties" => %{
        "version" => %{"type" => "string"},
        "created_by" => %{"$ref" => "#/definitions/User"}
      }
    },
    "User" => %{
      "type" => "string",
      "pattern" => "^[a-zA-Z0-9_]+$"
    }
  }
}

# Flatten the schema
flattened_schema = Exdantic.JsonSchema.Resolver.flatten_schema(complex_schema,
  max_depth: 5,
  inline_simple_refs: true
)

IO.puts("✅ Schema flattened successfully")
IO.puts("   Has definitions: #{Map.has_key?(flattened_schema, "definitions")}")
IO.puts("   Tag constraints inlined: #{Map.has_key?(get_in(flattened_schema, ["properties", "data", "items", "properties", "tags", "items"]) || %{}, "minLength")}")

# Example 5: OpenAI Structured Output Optimization
IO.puts("\n🤖 Example 5: OpenAI Structured Output Optimization")

openai_schema = %{
  "type" => "object",
  "properties" => %{
    "response" => %{"type" => "string"},
    "confidence" => %{"type" => "number", "minimum" => 0, "maximum" => 1},
    "metadata" => %{
      "type" => "object",
      "additionalProperties" => true
    }
  },
  "additionalProperties" => true
}

# Optimize for OpenAI
openai_optimized = Exdantic.JsonSchema.Resolver.enforce_structured_output(openai_schema,
  provider: :openai,
  remove_unsupported: true,
  add_required_fields: true
)

IO.puts("✅ OpenAI optimization applied:")
IO.puts("   Root additionalProperties: #{openai_optimized["additionalProperties"]}")
IO.puts("   Metadata additionalProperties: #{get_in(openai_optimized, ["properties", "metadata", "additionalProperties"])}")
IO.puts("   Has properties field: #{Map.has_key?(openai_optimized, "properties")}")

# Example 6: Anthropic Optimization
IO.puts("\n🧠 Example 6: Anthropic Optimization")

anthropic_schema = %{
  "type" => "object",
  "properties" => %{
    "reasoning" => %{"type" => "string"},
    "answer" => %{"type" => "string"},
    "sources" => %{
      "type" => "array",
      "items" => %{"type" => "string"}
    }
  }
}

# Optimize for Anthropic
anthropic_optimized = Exdantic.JsonSchema.Resolver.enforce_structured_output(anthropic_schema,
  provider: :anthropic,
  add_required_fields: true
)

IO.puts("✅ Anthropic optimization applied:")
IO.puts("   Has required array: #{Map.has_key?(anthropic_optimized, "required")}")
IO.puts("   Required array: #{inspect(anthropic_optimized["required"] || [])}")
IO.puts("   AdditionalProperties: #{anthropic_optimized["additionalProperties"]}")

# Example 7: Format Removal for Providers
IO.puts("\n🚫 Example 7: Format Removal for Providers")

format_schema = %{
  "type" => "object",
  "properties" => %{
    "email" => %{"type" => "string", "format" => "email"},
    "date" => %{"type" => "string", "format" => "date"},
    "url" => %{"type" => "string", "format" => "uri"},
    "uuid" => %{"type" => "string", "format" => "uuid"}
  }
}

# Remove unsupported formats for OpenAI
openai_no_formats = Exdantic.JsonSchema.Resolver.enforce_structured_output(format_schema,
  provider: :openai,
  remove_unsupported: true
)

IO.puts("✅ OpenAI format removal:")
IO.puts("   Email has format: #{Map.has_key?(get_in(openai_no_formats, ["properties", "email"]) || %{}, "format")}")
IO.puts("   Date has format: #{Map.has_key?(get_in(openai_no_formats, ["properties", "date"]) || %{}, "format")}")

# Remove unsupported formats for Anthropic
anthropic_no_formats = Exdantic.JsonSchema.Resolver.enforce_structured_output(format_schema,
  provider: :anthropic,
  remove_unsupported: true
)

IO.puts("✅ Anthropic format removal:")
IO.puts("   URL has format: #{Map.has_key?(get_in(anthropic_no_formats, ["properties", "url"]) || %{}, "format")}")
IO.puts("   UUID has format: #{Map.has_key?(get_in(anthropic_no_formats, ["properties", "uuid"]) || %{}, "format")}")

# Example 8: LLM Optimization Features
IO.puts("\n⚡ Example 8: LLM Optimization Features")

verbose_schema = %{
  "type" => "object",
  "description" => "A very detailed schema with lots of documentation that might be too verbose for LLM processing and could slow down inference times",
  "properties" => %{
    "field1" => %{
      "type" => "string",
      "description" => "This is the first field which stores string values and has various constraints"
    },
    "field2" => %{
      "type" => "integer", 
      "description" => "This is the second field for numeric values"
    },
    "union_field" => %{
      "oneOf" => [
        %{"type" => "string"},
        %{"type" => "integer"},
        %{"type" => "boolean"},
        %{"type" => "array"},
        %{"type" => "object"},
        %{"type" => "null"}
      ]
    }
  }
}

# Optimize for LLM processing
llm_optimized = Exdantic.JsonSchema.Resolver.optimize_for_llm(verbose_schema,
  remove_descriptions: true,
  simplify_unions: true,
  max_properties: 10
)

IO.puts("✅ LLM optimization applied:")
IO.puts("   Root description removed: #{!Map.has_key?(llm_optimized, "description")}")
IO.puts("   Field1 description removed: #{!Map.has_key?(get_in(llm_optimized, ["properties", "field1"]) || %{}, "description")}")
IO.puts("   Union simplified to #{length(get_in(llm_optimized, ["properties", "union_field", "oneOf"]) || [])} options")

# Example 9: Complex Integration Example
IO.puts("\n🎯 Example 9: Complex Integration Example")

# Start with a complex schema from a runtime Exdantic schema
runtime_schema = Exdantic.Runtime.create_schema([
  {:user_id, :string, [required: true]},
  {:profile, {:map, {:string, :any}}, [required: true]},
  {:settings, {:array, {:map, {:string, :string}}}, [required: false]}
])

# Generate JSON schema
base_json_schema = Exdantic.Runtime.to_json_schema(runtime_schema)

IO.puts("✅ Generated base JSON schema from runtime schema")

# Apply full processing pipeline
processed_schema = base_json_schema
|> Exdantic.JsonSchema.Resolver.resolve_references()
|> Exdantic.JsonSchema.Resolver.flatten_schema()
|> Exdantic.JsonSchema.Resolver.enforce_structured_output(provider: :openai)
|> Exdantic.JsonSchema.Resolver.optimize_for_llm(remove_descriptions: false, simplify_unions: true)

IO.puts("✅ Applied full processing pipeline")
IO.puts("   Final schema type: #{processed_schema["type"]}")
IO.puts("   Properties count: #{map_size(processed_schema["properties"] || %{})}")

# Example 10: Error Handling and Edge Cases
IO.puts("\n🚨 Example 10: Error Handling and Edge Cases")

# Test with malformed schema
malformed_schema = %{
  "type" => "object",
  "properties" => %{
    "broken_ref" => %{"$ref" => "#/definitions/NonExistent"}
  },
  "definitions" => %{
    "ValidDef" => %{"type" => "string"}
  }
}

# Attempt to resolve (should handle gracefully)
result = Exdantic.JsonSchema.Resolver.resolve_references(malformed_schema)
IO.puts("✅ Malformed schema handled gracefully")
IO.puts("   Result is still a map: #{is_map(result)}")

# Test with empty schema
empty_schema = %{}
empty_result = Exdantic.JsonSchema.Resolver.resolve_references(empty_schema)
IO.puts("✅ Empty schema handled: #{inspect(empty_result)}")

# Test provider optimization with unknown provider
_generic_result = Exdantic.JsonSchema.Resolver.enforce_structured_output(base_json_schema, provider: :unknown)
IO.puts("✅ Unknown provider handled gracefully")

# Example 11: Performance Benchmarking
IO.puts("\n⚡ Example 11: Performance Benchmarking")

# Create a moderately complex schema for benchmarking
benchmark_schema = %{
  "type" => "object",
  "properties" => Enum.into(1..50, %{}, fn i ->
    {"field#{i}", %{"$ref" => "#/definitions/CommonType"}}
  end),
  "definitions" => %{
    "CommonType" => %{
      "type" => "object",
      "properties" => %{
        "value" => %{"type" => "string"},
        "metadata" => %{"$ref" => "#/definitions/Metadata"}
      }
    },
    "Metadata" => %{
      "type" => "object",
      "properties" => %{
        "created" => %{"type" => "string"},
        "updated" => %{"type" => "string"}
      }
    }
  }
}

# Benchmark reference resolution
{time_resolve_us, _} = :timer.tc(fn ->
  for _ <- 1..100 do
    Exdantic.JsonSchema.Resolver.resolve_references(benchmark_schema)
  end
end)

# Benchmark flattening
{time_flatten_us, _} = :timer.tc(fn ->
  for _ <- 1..100 do
    Exdantic.JsonSchema.Resolver.flatten_schema(benchmark_schema)
  end
end)

# Benchmark optimization
{time_optimize_us, _} = :timer.tc(fn ->
  for _ <- 1..100 do
    Exdantic.JsonSchema.Resolver.optimize_for_llm(benchmark_schema)
  end
end)

IO.puts("✅ Performance benchmarks (100 iterations each):")
IO.puts("   Reference resolution: #{Float.round(time_resolve_us / 1000, 2)}ms")
IO.puts("   Schema flattening: #{Float.round(time_flatten_us / 1000, 2)}ms")
IO.puts("   LLM optimization: #{Float.round(time_optimize_us / 1000, 2)}ms")

IO.puts("""

🎯 Summary
==========
This example demonstrated:
1. 🔗 Basic JSON schema reference resolution ($ref expansion)
2. 🏗️ Nested reference resolution with multiple levels
3. 🔄 Circular reference detection and depth limiting
4. 📄 Schema flattening for simplified structure
5. 🤖 OpenAI structured output optimization
6. 🧠 Anthropic-specific schema requirements
7. 🚫 Provider-specific format removal
8. ⚡ LLM optimization (description removal, union simplification)
9. 🎯 Complex integration with runtime schemas
10. 🚨 Error handling for malformed schemas
11. ⚡ Performance benchmarking and optimization

JSON Schema Resolver provides advanced schema manipulation capabilities
for LLM integration, ensuring compatibility with different providers
while maintaining schema validity and optimization.
""")

# Clean exit
:ok
