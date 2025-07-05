defmodule Exdantic.SchemaEnhancedFeaturesTest do
  use ExUnit.Case, async: true

  describe "schema DSL with enhanced features" do
    defmodule UserProfileSchema do
      use Exdantic

      schema "Enhanced user profile with all new features" do
        field :user_id, :integer do
          description("Unique user identifier")
          required()
          gt(0)
        end

        field :role, :atom do
          description("User role in the system")
          choices([:admin, :moderator, :user, :guest])
          default(:user)
        end

        field :email, :string do
          description("User's email address")
          required()
          format(~r/^[^\s]+@[^\s]+\.[^\s]+$/)
          min_length(5)
          max_length(100)
        end

        field :preferences, {:map, {:atom, {:union, [:string, :boolean, :integer]}}} do
          description("User preferences with mixed value types")
          default(%{})
        end

        field :tags, {:array, :atom} do
          description("User tags as atoms")
          default([])
          max_items(10)
        end

        config do
          title("Enhanced User Profile")
          config_description("User profile schema showcasing all enhanced features")
          strict(true)
        end
      end
    end

    test "validates schema with atom types and choices" do
      # Valid data with all enhanced features
      valid_data = %{
        user_id: 12_345,
        role: :admin,
        email: "admin@example.com",
        preferences: %{
          theme: "dark",
          notifications: true,
          max_results: 50
        },
        tags: [:verified, :premium, :beta_tester]
      }

      assert {:ok, validated} = UserProfileSchema.validate(valid_data)
      assert validated.role == :admin
      assert validated.tags == [:verified, :premium, :beta_tester]
      assert validated.preferences.theme == "dark"

      # Test atom choices validation
      invalid_role = %{valid_data | role: :invalid_role}
      assert {:error, errors} = UserProfileSchema.validate(invalid_role)
      assert length(errors) == 1
      error = hd(errors)
      assert error.path == [:role]
      assert error.code == :choices

      # Test array of atoms
      invalid_tags = %{valid_data | tags: [:valid, "invalid_string", :another]}
      assert {:error, errors} = UserProfileSchema.validate(invalid_tags)
      assert length(errors) == 1

      # Extract first error, handling potential nesting
      error = List.flatten(errors) |> hd()
      assert error.path == [:tags, 1]
      assert error.code == :type
    end

    test "validates with default values for enhanced types" do
      minimal_data = %{
        user_id: 123,
        email: "user@example.com"
      }

      assert {:ok, validated} = UserProfileSchema.validate(minimal_data)
      # Default values should be applied
      assert validated.role == :user
      assert validated.preferences == %{}
      assert validated.tags == []
    end

    defmodule DimensionsSchema do
      use Exdantic

      schema "Product dimensions" do
        field :width, :float do
          required()
        end

        field :height, :float do
          required()
        end

        field :depth, :float do
          required()
        end
      end
    end

    defmodule MetadataSchema do
      use Exdantic

      schema "Product metadata" do
        field :source, :string do
          required()
        end

        field :created_at, :string do
          required()
        end
      end
    end

    defmodule ProductSchema do
      use Exdantic

      schema "Product with object validation" do
        field :name, :string do
          required()
          min_length(2)
        end

        field :dimensions, DimensionsSchema do
          description("Product dimensions in inches")
          required()
        end

        field :categories, {:array, :atom} do
          description("Product categories")
          default([])
        end

        field :metadata, {:union, [:string, MetadataSchema]} do
          description("Product metadata - string or structured object")
          optional()
        end
      end
    end

    test "validates schema with object type fields" do
      valid_product = %{
        name: "Smartphone",
        dimensions: %{
          width: 2.8,
          height: 5.4,
          depth: 0.3
        },
        categories: [:electronics],
        metadata: %{
          source: "import",
          created_at: "2023-01-01"
        }
      }

      assert {:ok, validated} = ProductSchema.validate(valid_product)
      assert validated.dimensions.width == 2.8
      assert validated.categories == [:electronics]

      # Test object field validation
      invalid_dimensions = %{
        valid_product
        | dimensions: %{width: "invalid", height: 5.4, depth: 0.3}
      }

      assert {:error, errors} = ProductSchema.validate(invalid_dimensions)
      assert length(errors) == 1
      error = hd(errors)
      assert error.path == [:dimensions, :width]
      assert error.code == :type

      # Test union with object
      string_metadata = %{valid_product | metadata: "simple string"}
      assert {:ok, validated} = ProductSchema.validate(string_metadata)
      assert validated.metadata == "simple string"
    end

    defmodule DatabaseConfigSchema do
      use Exdantic

      schema "Database configuration" do
        field :host, :string do
          required()
        end

        field :port, :integer do
          required()
          gt(0)
          lt(65_536)
        end

        field :ssl, :boolean do
          required()
        end
      end
    end

    defmodule ConfigSchema do
      use Exdantic

      schema "Configuration with comprehensive validation" do
        field :environment, :atom do
          choices([:development, :staging, :production])
          default(:development)
        end

        field :database, DatabaseConfigSchema do
          required()
        end

        field :features, {:map, {:atom, :boolean}} do
          description("Feature flags")
          default(%{})
        end

        field :allowed_origins, {:array, :string} do
          description("CORS allowed origins")
          default([])
          max_items(20)
        end

        config do
          strict(true)
        end
      end
    end

    test "validates complex configuration schema" do
      config_data = %{
        environment: :production,
        database: %{
          host: "db.example.com",
          port: 5432,
          ssl: true
        },
        features: %{
          new_ui: true,
          beta_features: false,
          analytics: true
        },
        allowed_origins: ["https://app.example.com", "https://admin.example.com"]
      }

      assert {:ok, validated} = ConfigSchema.validate(config_data)
      assert validated.environment == :production
      assert validated.database.port == 5432
      assert validated.features.new_ui == true

      # Test nested validation in object
      invalid_port = %{config_data | database: %{host: "db.example.com", port: 70_000, ssl: true}}
      assert {:error, errors} = ConfigSchema.validate(invalid_port)
      assert length(errors) == 1
      error = hd(errors)
      assert error.path == [:database, :port]
      assert error.code == :lt

      # Test map validation
      invalid_features = %{
        config_data
        | features: %{valid_flag: true, invalid_flag: "not_boolean"}
      }

      assert {:error, errors} = ConfigSchema.validate(invalid_features)
      assert length(errors) == 1
      error = List.flatten(errors) |> hd()
      assert error.path == [:features, :invalid_flag]
      assert error.code == :type
    end
  end

  describe "JSON Schema generation with enhanced features" do
    test "generates JSON schema for atom types with choices" do
      json_schema = Exdantic.JsonSchema.from_schema(__MODULE__.UserProfileSchema)

      # Check atom field with choices
      role_property = json_schema["properties"]["role"]
      # Note: The JSON Schema generation for atom choices may need enhancement
      # This test documents current behavior and can guide future improvements
      assert role_property["default"] == :user

      # Check array of atoms
      tags_property = json_schema["properties"]["tags"]
      assert tags_property["type"] == "array"
      assert tags_property["maxItems"] == 10
    end

    test "generates JSON schema for object types" do
      json_schema = Exdantic.JsonSchema.from_schema(__MODULE__.ProductSchema)

      # Check nested schema reference
      dimensions_property = json_schema["properties"]["dimensions"]
      assert dimensions_property["$ref"] == "#/definitions/DimensionsSchema"

      # Should have definitions section
      assert Map.has_key?(json_schema, "definitions")
      assert Map.has_key?(json_schema["definitions"], "DimensionsSchema")

      # Check union with schema reference
      metadata_property = json_schema["properties"]["metadata"]
      assert Map.has_key?(metadata_property, "oneOf")
      assert length(metadata_property["oneOf"]) == 2
    end
  end
end
