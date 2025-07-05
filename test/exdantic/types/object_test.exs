defmodule Exdantic.Types.ObjectTest do
  use ExUnit.Case, async: true

  alias Exdantic.Types
  alias Exdantic.Validator

  describe "Types.object/1" do
    test "creates object type with field definitions" do
      object_type =
        Types.object(%{
          name: Types.string(),
          age: Types.integer(),
          active: Types.boolean()
        })

      assert {:object, fields, []} = object_type

      assert %{
               name: {:type, :string, []},
               age: {:type, :integer, []},
               active: {:type, :boolean, []}
             } = fields
    end

    test "normalizes field types" do
      object_type =
        Types.object(%{
          name: :string,
          age: :integer,
          tags: {:array, :string}
        })

      assert {:object, fields, []} = object_type

      assert %{
               name: {:type, :string, []},
               age: {:type, :integer, []},
               tags: {:array, {:type, :string, []}, []}
             } = fields
    end

    test "handles nested objects" do
      address_type =
        Types.object(%{
          street: Types.string(),
          city: Types.string()
        })

      person_type =
        Types.object(%{
          name: Types.string(),
          address: address_type
        })

      assert {:object, fields, []} = person_type
      assert %{name: {:type, :string, []}, address: {:object, _, []}} = fields
    end
  end

  describe "object validation" do
    test "validates simple object successfully" do
      object_type =
        Types.object(%{
          name: Types.string(),
          age: Types.integer(),
          active: Types.boolean()
        })

      data = %{name: "John", age: 30, active: true}

      assert {:ok, validated} = Validator.validate(object_type, data)
      assert validated == data
    end

    test "validates nested objects" do
      address_type =
        Types.object(%{
          street: Types.string(),
          city: Types.string()
        })

      person_type =
        Types.object(%{
          name: Types.string(),
          address: address_type
        })

      data = %{
        name: "John",
        address: %{street: "123 Main St", city: "Springfield"}
      }

      assert {:ok, validated} = Validator.validate(person_type, data)
      assert validated == data
    end

    test "validates object with array fields" do
      object_type =
        Types.object(%{
          name: Types.string(),
          tags: Types.array(Types.string())
        })

      data = %{name: "John", tags: ["developer", "elixir"]}

      assert {:ok, validated} = Validator.validate(object_type, data)
      assert validated == data
    end

    test "validates object with union fields" do
      object_type =
        Types.object(%{
          name: Types.string(),
          value: Types.union([Types.string(), Types.integer()])
        })

      data1 = %{name: "John", value: "text"}
      data2 = %{name: "Jane", value: 42}

      assert {:ok, _} = Validator.validate(object_type, data1)
      assert {:ok, _} = Validator.validate(object_type, data2)
    end

    test "fails validation for missing fields" do
      object_type =
        Types.object(%{
          name: Types.string(),
          age: Types.integer()
        })

      # missing age
      data = %{name: "John"}

      assert {:error, [error]} = Validator.validate(object_type, data)
      assert error.path == [:age]
      assert error.code == :type
      assert error.message =~ "expected integer"
    end

    test "fails validation for wrong field types" do
      object_type =
        Types.object(%{
          name: Types.string(),
          age: Types.integer()
        })

      # age should be integer
      data = %{name: "John", age: "thirty"}

      assert {:error, [error]} = Validator.validate(object_type, data)
      assert error.path == [:age]
      assert error.code == :type
      assert error.message =~ "expected integer"
    end

    test "fails validation for non-map values" do
      object_type =
        Types.object(%{
          name: Types.string()
        })

      assert {:error, [error]} = Validator.validate(object_type, "not a map")
      assert error.path == []
      assert error.code == :type
      assert error.message =~ "expected object (map)"
    end

    test "handles nested validation errors with correct paths" do
      address_type =
        Types.object(%{
          street: Types.string(),
          zip: Types.integer()
        })

      person_type =
        Types.object(%{
          name: Types.string(),
          address: address_type
        })

      data = %{
        name: "John",
        # zip should be integer
        address: %{street: "123 Main St", zip: "invalid"}
      }

      assert {:error, [error]} = Validator.validate(person_type, data)
      assert error.path == [:address, :zip]
      assert error.code == :type
      assert error.message =~ "expected integer"
    end
  end

  describe "object with constraints" do
    test "applies constraints to validated object" do
      object_type =
        Types.object(%{
          name: Types.string(),
          age: Types.integer()
        })
        |> Types.with_constraints(size?: 2)

      data = %{name: "John", age: 30}

      assert {:ok, _} = Validator.validate(object_type, data)
    end

    test "fails constraint validation" do
      object_type =
        Types.object(%{
          name: Types.string(),
          age: Types.integer()
        })
        # expecting only 1 field, but we have 2
        |> Types.with_constraints(size?: 1)

      data = %{name: "John", age: 30}

      assert {:error, [error]} = Validator.validate(object_type, data)
      assert error.path == []
      assert error.code == :size?
      assert error.message =~ "failed size? constraint"
    end
  end

  describe "Types.normalize_type/1 with objects" do
    test "normalizes object type definition" do
      object_def = {:object, %{name: :string, age: :integer}}

      normalized = Types.normalize_type(object_def)

      assert {:object, fields, []} = normalized

      assert %{
               name: {:type, :string, []},
               age: {:type, :integer, []}
             } = fields
    end

    test "normalizes nested object definitions" do
      nested_object =
        {:object,
         %{
           person: {:object, %{name: :string}},
           count: :integer
         }}

      normalized = Types.normalize_type(nested_object)

      assert {:object, fields, []} = normalized

      assert %{
               person: {:object, %{name: {:type, :string, []}}, []},
               count: {:type, :integer, []}
             } = fields
    end
  end

  describe "edge cases" do
    test "empty object type" do
      object_type = Types.object(%{})
      data = %{}

      assert {:ok, validated} = Validator.validate(object_type, data)
      assert validated == %{}
    end

    test "object with nil field values" do
      object_type =
        Types.object(%{
          name: Types.string(),
          optional_field: Types.string()
        })

      data = %{name: "John", optional_field: nil}

      # nil is not a valid string, should fail
      assert {:error, [error]} = Validator.validate(object_type, data)
      assert error.path == [:optional_field]
      assert error.code == :type
      assert error.message =~ "expected string"
    end

    test "object with extra fields not in schema" do
      object_type =
        Types.object(%{
          name: Types.string()
        })

      data = %{name: "John", extra: "field"}

      # Current implementation only validates defined fields
      # Extra fields are ignored (similar to homogeneous maps)
      assert {:ok, validated} = Validator.validate(object_type, data)
      # only defined fields are returned
      assert validated == %{name: "John"}
    end

    test "object with atom field types" do
      object_type =
        Types.object(%{
          name: Types.string(),
          status: Types.type(:atom)
        })

      data = %{name: "John", status: :active}

      assert {:ok, validated} = Validator.validate(object_type, data)
      assert validated == data
    end
  end
end
