defmodule Exdantic.TypesEdgeCasesTest do
  use ExUnit.Case, async: true
  alias Exdantic.Types

  describe "type normalization edge cases" do
    test "handles deeply nested array types" do
      # Array of array of array of strings
      deeply_nested = Types.array(Types.array(Types.array(Types.string())))

      expected = {:array, {:array, {:array, {:type, :string, []}, []}, []}, []}
      assert deeply_nested == expected
    end

    test "handles complex nested union types" do
      complex_union =
        Types.union([
          Types.string(),
          Types.array(Types.integer()),
          Types.map(Types.string(), Types.union([Types.boolean(), Types.float()]))
        ])

      expected =
        {:union,
         [
           {:type, :string, []},
           {:array, {:type, :integer, []}, []},
           {:map,
            {{:type, :string, []}, {:union, [{:type, :boolean, []}, {:type, :float, []}], []}},
            []}
         ], []}

      assert complex_union == expected
    end

    test "handles empty union type" do
      empty_union = Types.union([])
      assert empty_union == {:union, [], []}
    end

    test "handles union with single type" do
      single_union = Types.union([Types.string()])
      assert single_union == {:union, [{:type, :string, []}], []}
    end

    test "handles map with identical key and value types" do
      same_types = Types.map(Types.string(), Types.string())
      expected = {:map, {{:type, :string, []}, {:type, :string, []}}, []}
      assert same_types == expected
    end

    test "handles normalize_type with unknown atom" do
      # This should leave unknown atoms as literals
      unknown_type = Types.normalize_type(:UnknownType)
      assert unknown_type == :UnknownType
    end

    test "handles normalize_type with already normalized types" do
      normalized = {:type, :string, []}
      assert Types.normalize_type(normalized) == normalized

      array_type = {:array, {:type, :string, []}, []}
      assert Types.normalize_type(array_type) == array_type
    end
  end

  describe "constraint handling edge cases" do
    test "handles multiple constraints of same type" do
      # This might not be intended behavior but should be handled gracefully
      type_with_dupe_constraints =
        Types.string()
        |> Types.with_constraints([{:min_length, 3}])
        |> Types.with_constraints([{:min_length, 5}])

      expected = {:type, :string, [min_length: 3, min_length: 5]}
      assert type_with_dupe_constraints == expected
    end

    test "handles empty constraints list" do
      type_with_empty = Types.with_constraints(Types.string(), [])
      assert type_with_empty == {:type, :string, []}
    end

    test "handles very long constraints list" do
      many_constraints = Enum.map(1..100, fn i -> {:custom_constraint, i} end)
      type_with_many = Types.with_constraints(Types.string(), many_constraints)

      assert {:type, :string, constraints} = type_with_many
      assert length(constraints) == 100
      assert List.first(constraints) == {:custom_constraint, 1}
      assert List.last(constraints) == {:custom_constraint, 100}
    end

    test "handles constraints on complex nested types" do
      nested_with_constraints =
        Types.array(
          Types.map(
            Types.string() |> Types.with_constraints([{:min_length, 2}]),
            Types.integer() |> Types.with_constraints([{:gt, 0}])
          )
        )
        |> Types.with_constraints([{:min_items, 1}])

      expected =
        {:array,
         {:map,
          {
            {:type, :string, [min_length: 2]},
            {:type, :integer, [gt: 0]}
          }, []}, [min_items: 1]}

      assert nested_with_constraints == expected
    end
  end

  describe "type validation edge cases" do
    test "validates :any type accepts anything" do
      values = [
        nil,
        true,
        false,
        0,
        -1,
        1.5,
        "",
        "string",
        [],
        [1, 2, 3],
        %{},
        %{a: 1},
        {:tuple, :value}
      ]

      for value <- values do
        assert {:ok, ^value} = Types.validate(:any, value)
      end
    end

    test "handles validation of unknown type" do
      assert {:error, error} = Types.validate(:unknown_type, "value")
      assert error.code == :type
      assert String.contains?(error.message, "unknown_type")
    end

    test "validates edge case numeric values" do
      # Test integer edge cases
      assert {:ok, 0} = Types.validate(:integer, 0)
      assert {:ok, -1} = Types.validate(:integer, -1)
      assert {:ok, 999_999_999_999} = Types.validate(:integer, 999_999_999_999)

      # Test float edge cases
      assert {:ok, +0.0} = Types.validate(:float, +0.0)
      assert {:ok, -0.0} = Types.validate(:float, -0.0)
      assert {:ok, 1.0e-10} = Types.validate(:float, 1.0e-10)
      assert {:ok, 1.0e10} = Types.validate(:float, 1.0e10)
    end

    test "validates empty and whitespace strings" do
      assert {:ok, ""} = Types.validate(:string, "")
      assert {:ok, " "} = Types.validate(:string, " ")
      assert {:ok, "\n"} = Types.validate(:string, "\n")
      assert {:ok, "\t"} = Types.validate(:string, "\t")
    end

    test "validates unicode strings" do
      unicode_strings = [
        # Japanese
        "こんにちは",
        # Arabic
        "مرحبا",
        # Emojis
        "🎉🚀💯",
        # Accented characters
        "àáâãäåæçèéêë",
        # Mathematical symbols
        "Ω≈∫∆√∞"
      ]

      for unicode_string <- unicode_strings do
        assert {:ok, ^unicode_string} = Types.validate(:string, unicode_string)
      end
    end
  end

  describe "coercion edge cases" do
    test "handles coercion of edge case numbers" do
      # Integer coercion edge cases
      assert {:ok, 0} = Types.coerce(:integer, "0")
      assert {:ok, -1} = Types.coerce(:integer, "-1")
      assert {:ok, 123} = Types.coerce(:integer, "123")

      # Should fail on invalid formats
      assert {:error, _} = Types.coerce(:integer, "")
      assert {:error, _} = Types.coerce(:integer, " ")
      assert {:error, _} = Types.coerce(:integer, "123.45")
      assert {:error, _} = Types.coerce(:integer, "123abc")
      assert {:error, _} = Types.coerce(:integer, "abc123")
      assert {:error, _} = Types.coerce(:integer, "1,000")
    end

    test "handles float coercion edge cases" do
      assert {:ok, +0.0} = Types.coerce(:float, "0.0")
      assert {:ok, -1.5} = Types.coerce(:float, "-1.5")
      assert {:ok, 1.23e-4} = Types.coerce(:float, "1.23e-4")
      assert {:ok, 1.23e+4} = Types.coerce(:float, "1.23e+4")

      # Should fail on invalid formats
      assert {:error, _} = Types.coerce(:float, "")
      assert {:error, _} = Types.coerce(:float, " ")
      assert {:error, _} = Types.coerce(:float, "abc")
      assert {:error, _} = Types.coerce(:float, "1.2.3")
    end

    test "handles string coercion from numbers" do
      assert {:ok, "123"} = Types.coerce(:string, 123)
      assert {:ok, "123.45"} = Types.coerce(:string, 123.45)
      assert {:ok, "0"} = Types.coerce(:string, 0)
      assert {:ok, "-1"} = Types.coerce(:string, -1)
    end

    test "handles coercion failures gracefully" do
      # Test unsupported coercions
      unsupported_coercions = [
        {:integer, %{}},
        {:integer, []},
        {:integer, true},
        {:float, %{}},
        {:float, []},
        {:float, true},
        {:string, %{}},
        {:string, []},
        {:boolean, "true"},
        {:boolean, 1},
        {:boolean, 0}
      ]

      for {type, value} <- unsupported_coercions do
        assert {:error, message} = Types.coerce(type, value)
        assert String.contains?(message, "cannot coerce")
      end
    end
  end

  describe "type reference edge cases" do
    test "handles ref type creation" do
      ref_type = Types.ref(:MySchema)
      assert ref_type == {:ref, :MySchema}
    end

    test "handles ref with module alias" do
      # This would typically be handled by macro expansion
      ref_type = Types.ref(MyApp.MySchema)
      assert ref_type == {:ref, MyApp.MySchema}
    end
  end
end
