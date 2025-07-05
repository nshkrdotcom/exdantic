defmodule Exdantic.RuntimeIntegrationTest do
  use ExUnit.Case, async: true

  alias Exdantic.Runtime
  alias Exdantic.Runtime.{EnhancedSchema, Validator}

  describe "create_enhanced_schema/2" do
    test "creates enhanced schema using Runtime module" do
      fields = [{:name, :string, [required: true]}, {:age, :integer, [optional: true]}]

      trim_validator = fn data ->
        {:ok, %{data | name: String.trim(data.name)}}
      end

      display_computer = fn data ->
        {:ok, "Name: #{data.name}, Age: #{data.age || "Unknown"}"}
      end

      schema =
        Runtime.create_enhanced_schema(fields,
          title: "Enhanced User Schema",
          model_validators: [trim_validator],
          computed_fields: [{:display, :string, display_computer}]
        )

      assert %EnhancedSchema{} = schema
      assert schema.base_schema.config[:title] == "Enhanced User Schema"
      assert length(schema.model_validators) == 1
      assert length(schema.computed_fields) == 1
    end
  end

  describe "validate_enhanced/3" do
    test "validates using Runtime module function" do
      fields = [{:name, :string, [required: true]}, {:age, :integer, [optional: true]}]

      trim_validator = fn data ->
        {:ok, %{data | name: String.trim(data.name)}}
      end

      display_computer = fn data ->
        {:ok, "Hello, #{data.name}!"}
      end

      schema =
        Runtime.create_enhanced_schema(fields,
          model_validators: [trim_validator],
          computed_fields: [{:greeting, :string, display_computer}]
        )

      data = %{name: "  John  ", age: 30}

      assert {:ok, validated} = Runtime.validate_enhanced(data, schema)
      assert validated.name == "John"
      assert validated.age == 30
      assert validated.greeting == "Hello, John!"
    end
  end

  describe "enhanced_to_json_schema/2" do
    test "generates JSON schema using Runtime module function" do
      fields = [{:name, :string, [required: true]}]

      computed_fields = [{:display_name, :string, fn data -> {:ok, String.upcase(data.name)} end}]

      schema = Runtime.create_enhanced_schema(fields, computed_fields: computed_fields)

      json_schema = Runtime.enhanced_to_json_schema(schema)

      assert json_schema["type"] == "object"
      assert json_schema["properties"]["name"]["type"] == "string"
      assert json_schema["properties"]["display_name"]["type"] == "string"
      assert json_schema["properties"]["display_name"]["readOnly"] == true
      assert json_schema["x-enhanced-schema"] == true
    end
  end

  describe "full pipeline integration" do
    test "complex validation pipeline with multiple validators and computed fields" do
      # Define a complex schema with validation pipeline
      fields = [
        {:first_name, :string, [required: true, min_length: 2]},
        {:last_name, :string, [required: true, min_length: 2]},
        {:email, :string, [required: true, format: ~r/@/]},
        {:age, :integer, [optional: true, gt: 0, lt: 150]}
      ]

      # Model validators
      normalize_names = fn data ->
        normalized = %{
          data
          | first_name: String.trim(data.first_name),
            last_name: String.trim(data.last_name),
            email: String.downcase(data.email)
        }

        {:ok, normalized}
      end

      validate_adult = fn data ->
        if Map.get(data, :age, 18) >= 18 do
          {:ok, data}
        else
          {:error, "must be at least 18 years old"}
        end
      end

      # Computed fields
      full_name_computer = fn data ->
        {:ok, "#{data.first_name} #{data.last_name}"}
      end

      email_domain_computer = fn data ->
        domain = data.email |> String.split("@") |> List.last()
        {:ok, domain}
      end

      initials_computer = fn data ->
        first_initial = String.first(data.first_name)
        last_initial = String.first(data.last_name)
        {:ok, "#{first_initial}#{last_initial}"}
      end

      # Create enhanced schema
      schema =
        Runtime.create_enhanced_schema(fields,
          title: "User Registration Schema",
          description: "Comprehensive user validation with computed fields",
          strict: true,
          model_validators: [normalize_names, validate_adult],
          computed_fields: [
            {:full_name, :string, full_name_computer},
            {:email_domain, :string, email_domain_computer},
            {:initials, :string, initials_computer}
          ]
        )

      # Test data
      input_data = %{
        first_name: "  John  ",
        last_name: "  Doe  ",
        email: "JOHN@EXAMPLE.COM",
        age: 30
      }

      # Validate
      assert {:ok, result} = Runtime.validate_enhanced(input_data, schema)

      # Check field validation results
      # Trimmed
      assert result.first_name == "John"
      # Trimmed
      assert result.last_name == "Doe"
      # Lowercased
      assert result.email == "john@example.com"
      assert result.age == 30

      # Check computed field results
      assert result.full_name == "John Doe"
      assert result.email_domain == "example.com"
      assert result.initials == "JD"

      # Check JSON schema generation
      json_schema = Runtime.enhanced_to_json_schema(schema)

      assert json_schema["title"] == "User Registration Schema"
      assert json_schema["x-enhanced-schema"] == true
      assert json_schema["x-model-validators"] == 2
      assert json_schema["x-computed-fields"] == 3

      # Regular fields
      assert json_schema["properties"]["first_name"]["type"] == "string"
      assert json_schema["properties"]["email"]["type"] == "string"

      # Computed fields marked as readOnly
      assert json_schema["properties"]["full_name"]["readOnly"] == true
      assert json_schema["properties"]["email_domain"]["readOnly"] == true
      assert json_schema["properties"]["initials"]["readOnly"] == true

      required_fields = json_schema["required"]
      assert Enum.sort(required_fields) == ["email", "first_name", "last_name"]
    end

    test "handles validation errors at different pipeline stages" do
      fields = [{:name, :string, [required: true, min_length: 3]}]

      strict_validator = fn data ->
        if String.length(data.name) >= 5 do
          {:ok, data}
        else
          {:error, "name must be at least 5 characters for strict validation"}
        end
      end

      schema =
        Runtime.create_enhanced_schema(fields,
          model_validators: [strict_validator]
        )

      # Test field validation failure
      assert {:error, [error]} = Runtime.validate_enhanced(%{}, schema)
      assert error.code == :required

      # Test field constraint failure
      assert {:error, [error]} = Runtime.validate_enhanced(%{name: "Jo"}, schema)
      assert error.message =~ "min_length"

      # Test model validation failure
      assert {:error, [error]} = Runtime.validate_enhanced(%{name: "John"}, schema)
      assert error.code == :model_validation
      assert error.message == "name must be at least 5 characters for strict validation"

      # Test success case
      assert {:ok, result} = Runtime.validate_enhanced(%{name: "Johnny"}, schema)
      assert result.name == "Johnny"
    end

    test "integrates with existing Validator module functions" do
      # Create both types of schemas
      basic_fields = [{:name, :string, [required: true]}]
      basic_schema = Runtime.create_schema(basic_fields)

      enhanced_fields = [{:name, :string, [required: true]}]

      enhanced_schema =
        Runtime.create_enhanced_schema(enhanced_fields,
          computed_fields: [
            {:display_name, :string, fn data -> {:ok, String.upcase(data.name)} end}
          ]
        )

      data = %{name: "john"}

      # Validate both using unified Validator interface
      assert {:ok, basic_result} = Validator.validate(data, basic_schema)
      assert {:ok, enhanced_result} = Validator.validate(data, enhanced_schema)

      # Basic schema returns only input fields
      assert basic_result == %{name: "john"}

      # Enhanced schema includes computed fields
      assert enhanced_result.name == "john"
      assert enhanced_result.display_name == "JOHN"

      # Schema info works for both
      basic_info = Validator.schema_info(basic_schema)
      enhanced_info = Validator.schema_info(enhanced_schema)

      assert basic_info.enhanced == false
      assert enhanced_info.enhanced == true

      # JSON schema generation works for both
      basic_json = Validator.to_json_schema(basic_schema)
      enhanced_json = Validator.to_json_schema(enhanced_schema)

      assert basic_json["properties"]["name"]["type"] == "string"
      assert enhanced_json["properties"]["name"]["type"] == "string"
      assert enhanced_json["properties"]["display_name"]["readOnly"] == true
    end
  end
end
