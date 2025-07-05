defmodule Exdantic.FieldExtraMetadataTest do
  use ExUnit.Case, async: true

  describe "field extra metadata support" do
    test "field can have extra metadata via options" do
      defmodule ExtraMetadataSchema do
        use Exdantic, define_struct: true

        schema do
          field(:question, :string,
            extra: %{"__dspy_field_type" => "input", "prefix" => "Question:"}
          )

          field(:answer, :string,
            extra: %{"__dspy_field_type" => "output", "prefix" => "Answer:"}
          )
        end
      end

      schema_fields = ExtraMetadataSchema.__schema__(:fields)

      question_field =
        Enum.find(schema_fields, fn {name, _meta} -> name == :question end) |> elem(1)

      answer_field = Enum.find(schema_fields, fn {name, _meta} -> name == :answer end) |> elem(1)

      assert question_field.extra == %{"__dspy_field_type" => "input", "prefix" => "Question:"}
      assert answer_field.extra == %{"__dspy_field_type" => "output", "prefix" => "Answer:"}
    end

    test "field can have extra metadata set within do block" do
      defmodule ExtraMetadataDoBlockSchema do
        use Exdantic, define_struct: true

        schema do
          field :question, :string do
            extra("__dspy_field_type", "input")
            extra("prefix", "Question:")
            required()
          end

          field :answer, :string do
            extra("__dspy_field_type", "output")
            extra("prefix", "Answer:")
            optional()
          end
        end
      end

      schema_fields = ExtraMetadataDoBlockSchema.__schema__(:fields)

      question_field =
        Enum.find(schema_fields, fn {name, _meta} -> name == :question end) |> elem(1)

      answer_field = Enum.find(schema_fields, fn {name, _meta} -> name == :answer end) |> elem(1)

      assert question_field.extra == %{"__dspy_field_type" => "input", "prefix" => "Question:"}
      assert answer_field.extra == %{"__dspy_field_type" => "output", "prefix" => "Answer:"}
      assert question_field.required == true
      assert answer_field.required == false
    end

    test "field extra metadata defaults to empty map when not specified" do
      defmodule NoExtraMetadataSchema do
        use Exdantic, define_struct: true

        schema do
          field(:name, :string)

          field :age, :integer do
            gt(0)
          end
        end
      end

      schema_fields = NoExtraMetadataSchema.__schema__(:fields)

      name_field = Enum.find(schema_fields, fn {name, _meta} -> name == :name end) |> elem(1)
      age_field = Enum.find(schema_fields, fn {name, _meta} -> name == :age end) |> elem(1)

      assert name_field.extra == %{}
      assert age_field.extra == %{}
    end

    test "field extra metadata can be mixed with other constraints" do
      defmodule MixedConstraintsSchema do
        use Exdantic, define_struct: true

        schema do
          field :username, :string do
            min_length(3)
            max_length(20)
            extra("validation_group", "authentication")
            extra("display_name", "Username")
            required()
          end

          field(:password, :string, extra: %{"sensitive" => true})

          field :password_field, :string do
            min_length(8)
            description("User password")
            extra("sensitive", true)
          end
        end
      end

      schema_fields = MixedConstraintsSchema.__schema__(:fields)

      username_field =
        Enum.find(schema_fields, fn {name, _meta} -> name == :username end) |> elem(1)

      password_field =
        Enum.find(schema_fields, fn {name, _meta} -> name == :password end) |> elem(1)

      password_field_field =
        Enum.find(schema_fields, fn {name, _meta} -> name == :password_field end) |> elem(1)

      # Check extra metadata
      assert username_field.extra == %{
               "validation_group" => "authentication",
               "display_name" => "Username"
             }

      assert password_field.extra == %{"sensitive" => true}
      assert password_field_field.extra == %{"sensitive" => true}

      # Check other properties are preserved
      assert username_field.required == true
      assert password_field_field.description == "User password"

      # Check constraints are preserved
      username_constraints = username_field.type |> elem(2)
      password_field_constraints = password_field_field.type |> elem(2)

      assert Enum.member?(username_constraints, {:min_length, 3})
      assert Enum.member?(username_constraints, {:max_length, 20})
      assert Enum.member?(password_field_constraints, {:min_length, 8})
    end

    test "multiple extra calls accumulate metadata" do
      defmodule AccumulatedExtraSchema do
        use Exdantic, define_struct: true

        schema do
          field :complex_field, :string do
            extra("first_key", "first_value")
            extra("second_key", "second_value")
            extra("third_key", %{"nested" => "data"})
          end
        end
      end

      schema_fields = AccumulatedExtraSchema.__schema__(:fields)

      complex_field =
        Enum.find(schema_fields, fn {name, _meta} -> name == :complex_field end) |> elem(1)

      expected_extra = %{
        "first_key" => "first_value",
        "second_key" => "second_value",
        "third_key" => %{"nested" => "data"}
      }

      assert complex_field.extra == expected_extra
    end

    test "extra metadata can store various data types" do
      defmodule VariousTypesSchema do
        use Exdantic, define_struct: true

        schema do
          field(:data, :string,
            extra: %{
              "string_val" => "hello",
              "integer_val" => 42,
              "float_val" => 3.14,
              "boolean_val" => true,
              "list_val" => [1, 2, 3],
              "map_val" => %{"nested" => "value"},
              "atom_val" => :test_atom
            }
          )
        end
      end

      schema_fields = VariousTypesSchema.__schema__(:fields)
      data_field = Enum.find(schema_fields, fn {name, _meta} -> name == :data end) |> elem(1)

      expected_extra = %{
        "string_val" => "hello",
        "integer_val" => 42,
        "float_val" => 3.14,
        "boolean_val" => true,
        "list_val" => [1, 2, 3],
        "map_val" => %{"nested" => "value"},
        "atom_val" => :test_atom
      }

      assert data_field.extra == expected_extra
    end

    test "validation still works with extra metadata" do
      defmodule ValidationWithExtraSchema do
        use Exdantic, define_struct: true

        schema do
          field :name, :string do
            min_length(2)
            required()
            extra("type", "input")
          end

          field :age, :integer do
            gt(0)
            optional()
            extra("type", "output")
          end
        end
      end

      # Valid data should pass
      valid_data = %{"name" => "John", "age" => 25}
      assert {:ok, _} = ValidationWithExtraSchema.validate(valid_data)

      # Invalid data should fail (constraints still work)
      # name too short, age negative
      invalid_data = %{"name" => "J", "age" => -5}
      assert {:error, _} = ValidationWithExtraSchema.validate(invalid_data)

      # Test that metadata doesn't interfere with validation
      # age is optional
      partial_data = %{"name" => "John"}
      assert {:ok, result} = ValidationWithExtraSchema.validate(partial_data)
      assert result.name == "John"
    end
  end

  describe "DSPy-style field type metadata" do
    test "can create input and output fields like DSPy" do
      defmodule DSPyStyleSchema do
        use Exdantic, define_struct: true

        schema do
          field(:question, :string, extra: %{"__dspy_field_type" => "input"})
          field(:reasoning, :string, extra: %{"__dspy_field_type" => "output"})

          field(:answer, :string,
            extra: %{"__dspy_field_type" => "output", "prefix" => "Answer:"}
          )
        end
      end

      schema_fields = DSPyStyleSchema.__schema__(:fields)

      question_field =
        Enum.find(schema_fields, fn {name, _meta} -> name == :question end) |> elem(1)

      reasoning_field =
        Enum.find(schema_fields, fn {name, _meta} -> name == :reasoning end) |> elem(1)

      answer_field = Enum.find(schema_fields, fn {name, _meta} -> name == :answer end) |> elem(1)

      assert question_field.extra["__dspy_field_type"] == "input"
      assert reasoning_field.extra["__dspy_field_type"] == "output"
      assert answer_field.extra["__dspy_field_type"] == "output"
      assert answer_field.extra["prefix"] == "Answer:"
    end

    test "can filter fields by DSPy field type" do
      defmodule FilterableSchema do
        use Exdantic, define_struct: true

        schema do
          field(:question, :string, extra: %{"__dspy_field_type" => "input"})
          field(:context, :string, extra: %{"__dspy_field_type" => "input"})
          field(:reasoning, :string, extra: %{"__dspy_field_type" => "output"})
          field(:answer, :string, extra: %{"__dspy_field_type" => "output"})
          # no dspy field type
          field(:metadata, :string)
        end
      end

      schema_fields = FilterableSchema.__schema__(:fields)

      # Filter input fields
      input_fields =
        Enum.filter(schema_fields, fn {_name, meta} ->
          Map.get(meta.extra, "__dspy_field_type") == "input"
        end)

      # Filter output fields
      output_fields =
        Enum.filter(schema_fields, fn {_name, meta} ->
          Map.get(meta.extra, "__dspy_field_type") == "output"
        end)

      input_field_names = Enum.map(input_fields, fn {name, _meta} -> name end)
      output_field_names = Enum.map(output_fields, fn {name, _meta} -> name end)

      assert Enum.sort(input_field_names) == [:context, :question]
      assert Enum.sort(output_field_names) == [:answer, :reasoning]
    end

    test "can create helper macros for DSPy field types" do
      # This test shows how the extra metadata feature enables DSPy-style field creation
      defmodule DSPyHelpers do
        defmacro input_field(name, type, _opts \\ []) do
          quote do
            field(unquote(name), unquote(type),
              extra: unquote(Macro.escape(%{"__dspy_field_type" => "input"}))
            )
          end
        end

        defmacro output_field(name, type, opts \\ []) do
          base_map = %{"__dspy_field_type" => "output"}

          # Get any extra options
          extra =
            case Keyword.get(opts, :extra) do
              {:%{}, _, pairs} -> Enum.into(pairs, %{})
              extra when is_map(extra) -> extra
              nil -> %{}
            end

          merged = Map.merge(extra, base_map)

          quote do
            field(unquote(name), unquote(type), extra: unquote(Macro.escape(merged)))
          end
        end
      end

      defmodule DSPyHelperSchema do
        use Exdantic, define_struct: true
        import DSPyHelpers

        schema do
          # Using the helper macros
          input_field(:question, :string)
          output_field(:answer, :string, extra: %{"prefix" => "Answer:"})
        end
      end

      schema_fields = DSPyHelperSchema.__schema__(:fields)

      question_field =
        Enum.find(schema_fields, fn {name, _meta} -> name == :question end) |> elem(1)

      answer_field = Enum.find(schema_fields, fn {name, _meta} -> name == :answer end) |> elem(1)

      assert question_field.extra["__dspy_field_type"] == "input"
      assert answer_field.extra["__dspy_field_type"] == "output"
      assert answer_field.extra["prefix"] == "Answer:"
    end
  end
end
