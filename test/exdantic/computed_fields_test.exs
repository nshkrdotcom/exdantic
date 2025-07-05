defmodule Exdantic.ComputedFieldsTest do
  use ExUnit.Case, async: true
  doctest Exdantic.ComputedFieldMeta

  # Test schemas for computed fields
  defmodule UserSchema do
    use Exdantic, define_struct: true

    schema do
      field(:first_name, :string, required: true)
      field(:last_name, :string, required: true)
      field(:email, :string, required: true)
      field(:age, :integer, required: false)

      computed_field(:full_name, :string, :generate_full_name)
      computed_field(:email_domain, :string, :extract_email_domain)
      computed_field(:age_category, :string, :categorize_age)
    end

    def generate_full_name(data) do
      {:ok, "#{data.first_name} #{data.last_name}"}
    end

    def extract_email_domain(data) do
      {:ok, data.email |> String.split("@") |> List.last()}
    end

    def categorize_age(data) do
      case Map.get(data, :age) do
        nil -> {:ok, "unknown"}
        age when age < 18 -> {:ok, "minor"}
        age when age < 65 -> {:ok, "adult"}
        _ -> {:ok, "senior"}
      end
    end
  end

  defmodule UserSchemaWithErrors do
    use Exdantic, define_struct: true

    schema do
      field(:name, :string, required: true)
      field(:age, :integer, required: true)

      computed_field(:error_field, :string, :failing_computation)
      computed_field(:type_error_field, :integer, :wrong_type_computation)
    end

    def failing_computation(_data) do
      {:error, "This computation always fails"}
    end

    def wrong_type_computation(_data) do
      {:ok, "this should be an integer"}
    end
  end

  defmodule UserSchemaWithModelValidator do
    use Exdantic, define_struct: true

    schema do
      field(:first_name, :string, required: true)
      field(:last_name, :string, required: true)

      model_validator(:normalize_names)
      computed_field(:full_name, :string, :generate_full_name)
    end

    def normalize_names(data) do
      normalized = %{
        data
        | first_name: String.trim(data.first_name),
          last_name: String.trim(data.last_name)
      }

      {:ok, normalized}
    end

    def generate_full_name(data) do
      {:ok, "#{data.first_name} #{data.last_name}"}
    end
  end

  defmodule UserSchemaNoStruct do
    # define_struct: false (default)
    use Exdantic

    schema do
      field(:name, :string, required: true)
      field(:email, :string, required: true)

      computed_field(:display_name, :string, :create_display_name)
    end

    def create_display_name(data) do
      {:ok, "#{data.name} <#{data.email}>"}
    end
  end

  defmodule SchemaWithMetadata do
    use Exdantic, define_struct: true

    schema do
      field(:content, :string, required: true)

      computed_field(:word_count, :integer, :count_words,
        description: "Number of words in the content",
        example: 42
      )

      computed_field(:summary, :string, :create_summary,
        description: "A brief summary of the content",
        example: "This is a summary..."
      )
    end

    def count_words(data) do
      count = data.content |> String.split() |> length()
      {:ok, count}
    end

    def create_summary(data) do
      words = String.split(data.content)
      summary = words |> Enum.take(5) |> Enum.join(" ") |> Kernel.<>("...")
      {:ok, summary}
    end
  end

  describe "ComputedFieldMeta" do
    test "creates computed field metadata correctly" do
      meta =
        Exdantic.ComputedFieldMeta.new(
          :full_name,
          {:type, :string, []},
          :generate_full_name,
          UserSchema
        )

      assert meta.name == :full_name
      assert meta.type == {:type, :string, []}
      assert meta.function_name == :generate_full_name
      assert meta.module == UserSchema
      assert meta.readonly == true
    end

    test "adds description and example" do
      meta =
        Exdantic.ComputedFieldMeta.new(
          :full_name,
          {:type, :string, []},
          :generate_full_name,
          UserSchema
        )
        |> Exdantic.ComputedFieldMeta.with_description("User's full name")
        |> Exdantic.ComputedFieldMeta.with_example("John Doe")

      assert meta.description == "User's full name"
      assert meta.example == "John Doe"
    end

    test "validates function existence" do
      valid_meta =
        Exdantic.ComputedFieldMeta.new(
          :full_name,
          {:type, :string, []},
          :generate_full_name,
          UserSchema
        )

      assert Exdantic.ComputedFieldMeta.validate_function(valid_meta) == :ok

      invalid_meta =
        Exdantic.ComputedFieldMeta.new(
          :bad_field,
          {:type, :string, []},
          :missing_function,
          UserSchema
        )

      assert {:error, _reason} = Exdantic.ComputedFieldMeta.validate_function(invalid_meta)
    end

    test "generates function reference string" do
      meta =
        Exdantic.ComputedFieldMeta.new(
          :full_name,
          {:type, :string, []},
          :generate_full_name,
          UserSchema
        )

      assert Exdantic.ComputedFieldMeta.function_reference(meta) ==
               "Exdantic.ComputedFieldsTest.UserSchema.generate_full_name/1"
    end

    test "converts to map" do
      meta =
        Exdantic.ComputedFieldMeta.new(
          :full_name,
          {:type, :string, []},
          :generate_full_name,
          UserSchema
        )
        |> Exdantic.ComputedFieldMeta.with_description("User's full name")

      map = Exdantic.ComputedFieldMeta.to_map(meta)

      assert map.name == :full_name
      assert map.description == "User's full name"
      assert map.readonly == true
      assert String.contains?(map.function_reference, "generate_full_name/1")
    end
  end

  describe "computed field macro" do
    test "schema collects computed fields correctly" do
      computed_fields = UserSchema.__schema__(:computed_fields)

      assert length(computed_fields) == 3
      assert Enum.any?(computed_fields, fn {name, _meta} -> name == :full_name end)
      assert Enum.any?(computed_fields, fn {name, _meta} -> name == :email_domain end)
      assert Enum.any?(computed_fields, fn {name, _meta} -> name == :age_category end)
    end

    test "computed field metadata has correct structure" do
      computed_fields = UserSchema.__schema__(:computed_fields)
      {_name, meta} = Enum.find(computed_fields, fn {name, _} -> name == :full_name end)

      assert meta.name == :full_name
      assert meta.function_name == :generate_full_name
      assert meta.module == UserSchema
      assert meta.readonly == true
    end

    test "computed fields with metadata options" do
      computed_fields = SchemaWithMetadata.__schema__(:computed_fields)

      {_name, word_count_meta} =
        Enum.find(computed_fields, fn {name, _} -> name == :word_count end)

      assert word_count_meta.description == "Number of words in the content"
      assert word_count_meta.example == 42
    end

    test "computed fields with do block metadata" do
      computed_fields = SchemaWithMetadata.__schema__(:computed_fields)
      {_name, summary_meta} = Enum.find(computed_fields, fn {name, _} -> name == :summary end)

      assert summary_meta.description == "A brief summary of the content"
      assert summary_meta.example == "This is a summary..."
    end
  end

  describe "struct integration" do
    test "includes computed fields in struct definition" do
      all_fields = UserSchema.__struct_fields__()
      regular_fields = UserSchema.__regular_fields__()
      computed_fields = UserSchema.__computed_field_names__()

      assert :first_name in all_fields
      assert :full_name in all_fields
      assert :email_domain in all_fields

      assert :first_name in regular_fields
      assert :full_name not in regular_fields

      assert :full_name in computed_fields
      assert :email_domain in computed_fields
      assert :first_name not in computed_fields
    end

    test "schema info includes computed field information" do
      info = UserSchema.__schema_info__()

      assert info.has_struct == true
      # regular fields
      assert info.field_count == 4
      # computed fields
      assert info.computed_field_count == 3
      # regular + computed
      assert length(info.all_fields) == 7
      assert :full_name in info.computed_fields
      assert :first_name in info.regular_fields
    end
  end

  describe "validation with computed fields" do
    test "successful validation includes computed fields" do
      data = %{
        first_name: "John",
        last_name: "Doe",
        email: "john@example.com",
        age: 30
      }

      assert {:ok, result} = UserSchema.validate(data)

      # Check that regular fields are present
      assert result.first_name == "John"
      assert result.last_name == "Doe"
      assert result.email == "john@example.com"
      assert result.age == 30

      # Check that computed fields are present
      assert result.full_name == "John Doe"
      assert result.email_domain == "example.com"
      assert result.age_category == "adult"

      # Verify it's a struct
      assert %UserSchema{} = result
    end

    test "validation without struct returns map with computed fields" do
      data = %{name: "John", email: "john@example.com"}

      assert {:ok, result} = UserSchemaNoStruct.validate(data)

      assert result.name == "John"
      assert result.email == "john@example.com"
      assert result.display_name == "John <john@example.com>"

      # Verify it's a map, not a struct
      assert is_map(result)
      refute is_struct(result)
    end

    test "validation with missing optional field handles computed field correctly" do
      data = %{
        first_name: "Jane",
        last_name: "Smith",
        email: "jane@example.com"
        # age is missing (optional)
      }

      assert {:ok, result} = UserSchema.validate(data)

      assert result.first_name == "Jane"
      assert result.full_name == "Jane Smith"
      # handled nil age
      assert result.age_category == "unknown"
      assert is_nil(result.age)
    end

    test "computed field execution after model validation" do
      data = %{
        # will be trimmed by model validator
        first_name: "  John  ",
        # will be trimmed by model validator
        last_name: "  Doe  "
      }

      assert {:ok, result} = UserSchemaWithModelValidator.validate(data)

      # Model validator should have trimmed the names
      assert result.first_name == "John"
      assert result.last_name == "Doe"

      # Computed field should use the trimmed names
      # not "  John    Doe  "
      assert result.full_name == "John Doe"
    end

    test "field validation errors prevent computed field execution" do
      data = %{
        # missing required first_name
        last_name: "Doe",
        email: "john@example.com"
      }

      assert {:error, errors} = UserSchema.validate(data)

      # Should get field validation error, not computed field errors
      assert length(errors) == 1
      error = hd(errors)
      assert error.code == :required
      assert error.path == [:first_name]
    end
  end

  describe "computed field error handling" do
    test "computed field function returning error" do
      data = %{name: "John", age: 25}

      assert {:error, errors} = UserSchemaWithErrors.validate(data)

      error = Enum.find(errors, fn e -> e.path == [:error_field] end)
      assert error != nil
      assert error.code == :computed_field
      assert error.message == "This computation always fails"
    end

    test "computed field returning wrong type" do
      # Use a separate schema that only has the type error to test this specific error
      defmodule TypeErrorOnlySchema do
        use Exdantic, define_struct: true

        schema do
          field(:name, :string, required: true)
          field(:age, :integer, required: true)

          computed_field(:type_error_field, :integer, :wrong_type_computation)
        end

        def wrong_type_computation(_data) do
          {:ok, "this should be an integer"}
        end
      end

      data = %{name: "John", age: 25}

      assert {:error, errors} = TypeErrorOnlySchema.validate(data)

      error = Enum.find(errors, fn e -> e.path == [:type_error_field] end)
      assert error != nil
      assert error.code == :computed_field_type
      assert String.contains?(error.message, "Computed field type validation failed")
    end

    test "computed field function with invalid return format" do
      defmodule BadReturnSchema do
        use Exdantic

        schema do
          field(:name, :string, required: true)
          computed_field(:bad_field, :string, :bad_return_function)
        end

        def bad_return_function(_data) do
          # should return {:ok, value} or {:error, reason}
          "invalid return format"
        end
      end

      data = %{name: "John"}
      assert {:error, errors} = BadReturnSchema.validate(data)

      error = Enum.find(errors, fn e -> e.path == [:bad_field] end)
      assert error != nil
      assert error.code == :computed_field
      assert String.contains?(error.message, "returned invalid format")
    end

    test "computed field function that throws exception" do
      defmodule ExceptionSchema do
        use Exdantic

        schema do
          field(:name, :string, required: true)
          computed_field(:exception_field, :string, :throwing_function)
        end

        def throwing_function(_data) do
          raise "Something went wrong"
        end
      end

      data = %{name: "John"}
      assert {:error, errors} = ExceptionSchema.validate(data)

      error = Enum.find(errors, fn e -> e.path == [:exception_field] end)
      assert error != nil
      assert error.code == :computed_field
      assert String.contains?(error.message, "execution failed")
    end

    test "missing computed field function" do
      defmodule MissingFunctionSchema do
        use Exdantic

        schema do
          field(:name, :string, required: true)
          computed_field(:missing_field, :string, :nonexistent_function)
        end
      end

      data = %{name: "John"}
      assert {:error, errors} = MissingFunctionSchema.validate(data)

      error = Enum.find(errors, fn e -> e.path == [:missing_field] end)
      assert error != nil
      assert error.code == :computed_field
      assert String.contains?(error.message, "is not defined")
    end
  end

  describe "JSON Schema integration" do
    test "computed fields appear in JSON schema as readOnly" do
      json_schema = Exdantic.JsonSchema.from_schema(UserSchema)

      properties = json_schema["properties"]

      # Regular fields should not be readOnly
      refute Map.get(properties["first_name"], "readOnly")
      refute Map.get(properties["email"], "readOnly")

      # Computed fields should be readOnly
      assert properties["full_name"]["readOnly"] == true
      assert properties["email_domain"]["readOnly"] == true
      assert properties["age_category"]["readOnly"] == true
    end

    test "computed fields have correct type information" do
      json_schema = Exdantic.JsonSchema.from_schema(UserSchema)
      properties = json_schema["properties"]

      assert properties["full_name"]["type"] == "string"
      assert properties["email_domain"]["type"] == "string"
      assert properties["age_category"]["type"] == "string"
    end

    test "computed fields include x-computed-field metadata" do
      json_schema = Exdantic.JsonSchema.from_schema(UserSchema)
      properties = json_schema["properties"]

      computed_metadata = properties["full_name"]["x-computed-field"]
      assert computed_metadata["module"] == UserSchema
      assert computed_metadata["function_name"] == :generate_full_name
      assert String.contains?(computed_metadata["function"], "generate_full_name/1")
    end

    test "computed fields with metadata in JSON schema" do
      json_schema = Exdantic.JsonSchema.from_schema(SchemaWithMetadata)
      properties = json_schema["properties"]

      word_count_field = properties["word_count"]
      assert word_count_field["description"] == "Number of words in the content"
      assert word_count_field["examples"] == [42]
      assert word_count_field["readOnly"] == true

      summary_field = properties["summary"]
      assert summary_field["description"] == "A brief summary of the content"
      assert summary_field["examples"] == ["This is a summary..."]
    end

    test "computed fields are not in required array" do
      json_schema = Exdantic.JsonSchema.from_schema(UserSchema)
      required = json_schema["required"]

      # Regular required fields should be in required array
      assert "first_name" in required
      assert "last_name" in required
      assert "email" in required

      # Computed fields should not be in required array
      refute "full_name" in required
      refute "email_domain" in required
      refute "age_category" in required
    end

    test "can extract computed field information from JSON schema" do
      json_schema = Exdantic.JsonSchema.from_schema(UserSchema)
      computed_info = Exdantic.JsonSchema.extract_computed_field_info(json_schema)

      assert length(computed_info) == 3

      full_name_info = Enum.find(computed_info, fn info -> info.name == "full_name" end)
      assert full_name_info.readonly == true
      assert String.contains?(full_name_info.function, "generate_full_name/1")
    end

    test "can check if schema has computed fields" do
      user_schema = Exdantic.JsonSchema.from_schema(UserSchema)
      assert Exdantic.JsonSchema.has_computed_fields?(user_schema) == true

      simple_schema = %{"type" => "object", "properties" => %{"name" => %{"type" => "string"}}}
      assert Exdantic.JsonSchema.has_computed_fields?(simple_schema) == false
    end

    test "can remove computed fields for input validation" do
      full_schema = Exdantic.JsonSchema.from_schema(UserSchema)
      input_schema = Exdantic.JsonSchema.remove_computed_fields(full_schema)

      input_properties = input_schema["properties"]

      # Regular fields should remain
      assert Map.has_key?(input_properties, "first_name")
      assert Map.has_key?(input_properties, "email")

      # Computed fields should be removed
      refute Map.has_key?(input_properties, "full_name")
      refute Map.has_key?(input_properties, "email_domain")
    end

    @tag :pending
    test "can generate separate input and output schemas" do
      # This functionality will be implemented in a future phase
      # {input_schema, output_schema} = Exdantic.JsonSchema.input_output_schemas(UserSchema)
      #
      # input_properties = input_schema["properties"]
      # output_properties = output_schema["properties"]
      #
      # # Input schema should not have computed fields
      # refute Map.has_key?(input_properties, "full_name")
      #
      # # Output schema should have computed fields
      # assert Map.has_key?(output_properties, "full_name")
      # assert output_properties["full_name"]["readOnly"] == true

      # For now, just test the basic schema generation includes computed fields
      schema = Exdantic.JsonSchema.from_schema(UserSchema)
      properties = schema["properties"]

      # Regular fields should be present
      assert Map.has_key?(properties, "first_name")

      # Computed fields should be present and marked as readOnly
      assert Map.has_key?(properties, "full_name")
      assert properties["full_name"]["readOnly"] == true
    end

    @tag :pending
    test "validates computed field functions before JSON schema generation" do
      # This functionality will be implemented in a future phase
      # For now, just test that computed field validation works

      # Test valid computed field
      computed_fields = UserSchema.__schema__(:computed_fields)
      {_name, meta} = List.first(computed_fields)
      assert Exdantic.ComputedFieldMeta.validate_function(meta) == :ok

      # Test invalid computed field
      invalid_meta =
        Exdantic.ComputedFieldMeta.new(
          :bad_field,
          {:type, :string, []},
          :missing_function,
          String
        )

      assert {:error, _} = Exdantic.ComputedFieldMeta.validate_function(invalid_meta)
    end
  end

  describe "dump function with computed fields" do
    test "dumps struct with computed fields to map" do
      data = %{
        first_name: "John",
        last_name: "Doe",
        email: "john@example.com",
        age: 30
      }

      {:ok, user_struct} = UserSchema.validate(data)
      {:ok, dumped_map} = UserSchema.dump(user_struct)

      # Should include all fields including computed ones
      assert dumped_map.first_name == "John"
      assert dumped_map.full_name == "John Doe"
      assert dumped_map.email_domain == "example.com"
      assert dumped_map.age_category == "adult"

      # Should be a plain map
      refute is_struct(dumped_map)
    end
  end

  describe "backward compatibility" do
    test "schemas without computed fields work as before" do
      defmodule SimpleStructSchema do
        use Exdantic, define_struct: true

        schema do
          field(:name, :string, required: true)
          field(:age, :integer, required: false)
        end
      end

      data = %{name: "John", age: 30}
      assert {:ok, result} = SimpleStructSchema.validate(data)

      assert result.name == "John"
      assert result.age == 30
      assert is_struct(result)
      assert result.__struct__ == SimpleStructSchema

      # Should have empty computed fields list
      assert SimpleStructSchema.__schema__(:computed_fields) == []
      assert SimpleStructSchema.__computed_field_names__() == []
    end

    test "JSON schema generation works for schemas without computed fields" do
      defmodule SimpleJsonSchema do
        use Exdantic

        schema do
          field(:name, :string, required: true)
        end
      end

      json_schema = Exdantic.JsonSchema.from_schema(SimpleJsonSchema)
      properties = json_schema["properties"]

      assert Map.has_key?(properties, "name")
      assert properties["name"]["type"] == "string"
      refute Map.has_key?(properties["name"], "readOnly")

      # Should not have any computed fields
      assert Exdantic.JsonSchema.has_computed_fields?(json_schema) == false
    end
  end
end
