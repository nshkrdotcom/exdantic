defmodule Exdantic.SchemaTest do
  use ExUnit.Case, async: true

  describe "basic schema definition" do
    defmodule BasicSchema do
      use Exdantic

      schema "Test schema" do
        field :name, :string do
          description("User's name")
        end

        field :age, :integer do
          description("User's age")
          optional()
        end
      end
    end

    test "stores schema description" do
      assert BasicSchema.__schema__(:description) == "Test schema"
    end

    test "registers fields correctly" do
      fields = BasicSchema.__schema__(:fields)

      assert {:name, name_meta} = Enum.find(fields, fn {name, _} -> name == :name end)
      assert {:age, age_meta} = Enum.find(fields, fn {name, _} -> name == :age end)

      # Required field
      assert name_meta.description == "User's name"
      assert name_meta.required == true
      assert name_meta.type == {:type, :string, []}

      # Optional field
      assert age_meta.description == "User's age"
      assert age_meta.required == false
      assert age_meta.type == {:type, :integer, []}
    end
  end

  describe "complex type definitions" do
    defmodule AddressSchema do
      use Exdantic

      schema "Address information" do
        field(:street, :string)

        field :city, :string do
          required()
          description("City name")
        end

        field :country, :string do
          required()
          description("Country name")
        end
      end
    end

    defmodule ComplexSchema do
      use Exdantic

      schema do
        field :tags, {:array, {:map, {:string, {:union, [:string, :integer]}}}} do
          description("List of tagged metadata")
          default([])
          min_items(1)
          max_items(10)
        end

        field :id, {:union, [:string, :integer, {:array, :float}]} do
          description("User ID (string, integer or array of floats)")
          required()
          example("user_123")
          examples([123, [1.0, 2.5, 3.14]])
        end

        field :metadata, {:map, {:string, {:array, {:map, {:string, :any}}}}} do
          description("Nested metadata structure")
          optional()
          default(%{})
        end

        field :settings, {:map, {:string, {:union, [:string, :boolean, {:array, :integer}]}}} do
          description("User settings with various value types")
          required()
        end

        field :address, {:union, [:string, {:array, AddressSchema}]} do
          description("User's address (string or list of addresses)")
          required()
        end
      end
    end

    test "handles complex array type correctly" do
      fields = ComplexSchema.__schema__(:fields)
      {:tags, tags_meta} = Enum.find(fields, fn {name, _} -> name == :tags end)

      assert tags_meta.type ==
               {:array,
                {:map,
                 {{:type, :string, []},
                  {:union, [{:type, :string, []}, {:type, :integer, []}], []}}, []},
                [min_items: 1, max_items: 10]}

      assert tags_meta.default == []
    end

    test "handles complex union type correctly" do
      fields = ComplexSchema.__schema__(:fields)
      {:id, id_meta} = Enum.find(fields, fn {name, _} -> name == :id end)

      assert id_meta.type ==
               {:union,
                [{:type, :string, []}, {:type, :integer, []}, {:array, {:type, :float, []}, []}],
                []}

      assert id_meta.required == true
      assert id_meta.example == "user_123"
      assert id_meta.examples == [123, [1.0, 2.5, 3.14]]
    end

    test "handles nested map types correctly" do
      fields = ComplexSchema.__schema__(:fields)
      {:metadata, meta_meta} = Enum.find(fields, fn {name, _} -> name == :metadata end)
      {:settings, settings_meta} = Enum.find(fields, fn {name, _} -> name == :settings end)

      assert meta_meta.type ==
               {:map,
                {{:type, :string, []},
                 {:array, {:map, {{:type, :string, []}, {:type, :any, []}}, []}, []}}, []}

      assert settings_meta.type ==
               {:map,
                {{:type, :string, []},
                 {:union,
                  [
                    {:type, :string, []},
                    {:type, :boolean, []},
                    {:array, {:type, :integer, []}, []}
                  ], []}}, []}

      assert meta_meta.required == false
      assert settings_meta.required == true
    end

    test "handles schema references correctly" do
      fields = ComplexSchema.__schema__(:fields)
      {:address, address_meta} = Enum.find(fields, fn {name, _} -> name == :address end)

      assert address_meta.type ==
               {:union,
                [{:type, :string, []}, {:array, {:ref, Exdantic.SchemaTest.AddressSchema}, []}],
                []}

      assert address_meta.required == true
      assert address_meta.description == "User's address (string or list of addresses)"
    end
  end

  describe "validation rules" do
    defmodule ValidationSchema do
      use Exdantic

      schema do
        field :password, :string do
          required()
        end

        field :password_confirmation, :string do
          required()
        end
      end

      def validate_passwords(data) do
        if data.password == data.password_confirmation do
          :ok
        else
          {:error, "passwords must match"}
        end
      end
    end

    test "validation function works" do
      valid_data = %{
        password: "secret",
        password_confirmation: "secret"
      }

      invalid_data = %{
        password: "secret",
        password_confirmation: "different"
      }

      assert :ok = ValidationSchema.validate_passwords(valid_data)
      assert {:error, "passwords must match"} = ValidationSchema.validate_passwords(invalid_data)
    end
  end

  describe "default values" do
    defmodule DefaultSchema do
      use Exdantic

      schema do
        field :name, :string do
          required()
        end

        field :status, :string do
          default("active")
        end
      end
    end

    test "field with default value is optional" do
      valid_data = %{
        name: "test"
      }

      # Validate the data
      assert {:ok, validated} = DefaultSchema.validate(valid_data)
      assert validated.status == "active"

      # Get field metadata and verify default value
      fields = DefaultSchema.__schema__(:fields)
      {_, status_meta} = Enum.find(fields, fn {name, _} -> name == :status end)
      assert status_meta.default == "active"

      # Verify field is optional
      assert status_meta.required == false
    end
  end
end
