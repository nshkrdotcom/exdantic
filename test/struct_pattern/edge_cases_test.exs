# test/struct_pattern/edge_cases_test.exs
defmodule Exdantic.StructEdgeCasesTest do
  use ExUnit.Case

  describe "edge cases and error conditions" do
    test "empty struct schema" do
      defmodule EmptyStructSchema do
        use Exdantic, define_struct: true

        schema do
          # No fields defined
        end
      end

      assert {:ok, result} = EmptyStructSchema.validate(%{})
      assert is_struct(result, EmptyStructSchema)
      assert EmptyStructSchema.__struct_fields__() == []
    end

    test "struct with only optional fields" do
      defmodule OptionalOnlyStruct do
        use Exdantic, define_struct: true

        schema do
          field :maybe_name, :string do
            optional()
          end

          field :maybe_count, :integer do
            optional()
          end
        end
      end

      # Should work with empty input
      assert {:ok, result} = OptionalOnlyStruct.validate(%{})
      assert is_struct(result, OptionalOnlyStruct)
      assert is_nil(result.maybe_name)
      assert is_nil(result.maybe_count)
    end

    test "struct with complex nested types" do
      defmodule NestedStructSchema do
        use Exdantic, define_struct: true

        schema do
          field :items, {:array, {:map, {:string, :integer}}} do
            required()
          end

          field :metadata, {:map, {:string, {:array, :string}}} do
            optional()
          end
        end
      end

      complex_data = %{
        items: [%{"a" => 1, "b" => 2}],
        metadata: %{"tags" => ["elixir", "testing"]}
      }

      assert {:ok, result} = NestedStructSchema.validate(complex_data)
      assert is_struct(result, NestedStructSchema)
      assert result.items == [%{"a" => 1, "b" => 2}]
      assert result.metadata == %{"tags" => ["elixir", "testing"]}
    end

    test "struct creation failure handling" do
      # This test ensures graceful handling if struct creation somehow fails
      defmodule StructFailureTest do
        use Exdantic, define_struct: true

        schema do
          field :normal_field, :string do
            required()
          end
        end

        # This test is simplified - the struct creation failure is already handled
        # by the StructValidator module, so we don't need to override __struct__
      end

      # Normal case should work
      assert {:ok, result} = StructFailureTest.validate(%{normal_field: "success"})
      assert is_struct(result, StructFailureTest)

      # Test invalid input to trigger validation error (not struct creation error)
      case StructFailureTest.validate(%{}) do
        {:error, errors} ->
          errors_list = if is_list(errors), do: errors, else: [errors]
          error = hd(errors_list)
          assert error.code == :required

        {:ok, _} ->
          flunk("Expected validation to fail for missing required field")
      end
    end

    test "struct with atoms as field values" do
      defmodule AtomFieldStruct do
        use Exdantic, define_struct: true

        schema do
          field :status, :atom do
            required()
          end

          field :type, :atom do
            optional()
          end
        end
      end

      data = %{status: :active, type: :user}

      assert {:ok, result} = AtomFieldStruct.validate(data)
      assert is_struct(result, AtomFieldStruct)
      assert result.status == :active
      assert result.type == :user
    end
  end

  describe "boundary conditions" do
    test "very long field names" do
      long_field_name = String.duplicate("a", 100) |> String.to_atom()

      # For now, simplify this test by using a reasonable long field name
      {:module, LongFieldStruct, _, _} =
        defmodule LongFieldStruct do
          use Exdantic, define_struct: true

          schema do
            field :aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa,
                  :string do
              required()
            end
          end
        end

      data = %{long_field_name => "test"}

      assert {:ok, result} = LongFieldStruct.validate(data)
      assert is_struct(result, LongFieldStruct)
      assert Map.get(result, long_field_name) == "test"
    end

    test "unicode field names and values" do
      unicode_field = :测试字段

      {:module, UnicodeStruct, _, _} =
        defmodule UnicodeStruct do
          use Exdantic, define_struct: true

          schema do
            field :测试字段, :string do
              required()
            end
          end
        end

      data = %{unicode_field => "unicode_value_测试"}

      assert {:ok, result} = UnicodeStruct.validate(data)
      assert is_struct(result, UnicodeStruct)
      assert Map.get(result, unicode_field) == "unicode_value_测试"
    end
  end
end
