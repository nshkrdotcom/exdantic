defmodule Exdantic.ValidatorEdgeCasesTest do
  use ExUnit.Case, async: true
  alias Exdantic.{Types, Validator}

  describe "constraint validation edge cases" do
    test "handles regex constraint with special characters" do
      type =
        Types.string() |> Types.with_constraints([{:format, ~r/^[a-zA-Z0-9!@#$%^&*()_+-=]+$/}])

      assert {:ok, "test123!@#"} = Validator.validate(type, "test123!@#")
      assert {:error, _} = Validator.validate(type, "test with spaces")
      assert {:error, _} = Validator.validate(type, "test\nwith\nnewlines")
    end

    test "handles empty regex pattern" do
      type = Types.string() |> Types.with_constraints([{:format, ~r//}])

      # Empty regex should match everything
      assert {:ok, "anything"} = Validator.validate(type, "anything")
      assert {:ok, ""} = Validator.validate(type, "")
    end

    test "handles unicode regex patterns" do
      # Pattern for Japanese characters
      japanese_pattern = ~r/^[\p{Hiragana}\p{Katakana}\p{Han}]+$/u
      type = Types.string() |> Types.with_constraints([{:format, japanese_pattern}])

      assert {:ok, "こんにちは"} = Validator.validate(type, "こんにちは")
      assert {:error, _} = Validator.validate(type, "hello")
      assert {:error, _} = Validator.validate(type, "こんにちはhello")
    end

    test "handles numeric constraints at boundaries" do
      # Test exactly at boundaries
      type = Types.integer() |> Types.with_constraints([{:gt, 0}, {:lt, 10}])

      # exactly at gt boundary
      assert {:error, _} = Validator.validate(type, 0)
      # just above gt boundary
      assert {:ok, 1} = Validator.validate(type, 1)
      # just below lt boundary
      assert {:ok, 9} = Validator.validate(type, 9)
      # exactly at lt boundary
      assert {:error, _} = Validator.validate(type, 10)
    end

    test "handles gteq/lteq constraints at boundaries" do
      type = Types.integer() |> Types.with_constraints([{:gteq, 0}, {:lteq, 10}])

      # exactly at gteq boundary
      assert {:ok, 0} = Validator.validate(type, 0)
      # exactly at lteq boundary
      assert {:ok, 10} = Validator.validate(type, 10)
      # below gteq boundary
      assert {:error, _} = Validator.validate(type, -1)
      # above lteq boundary
      assert {:error, _} = Validator.validate(type, 11)
    end

    test "handles conflicting numeric constraints" do
      # gt: 10, lt: 5 - impossible to satisfy
      type = Types.integer() |> Types.with_constraints([{:gt, 10}, {:lt, 5}])

      # All values should fail
      for value <- [0, 5, 6, 7, 8, 9, 10, 11, 15] do
        assert {:error, _} = Validator.validate(type, value)
      end
    end

    test "handles string length constraints at boundaries" do
      type = Types.string() |> Types.with_constraints([{:min_length, 3}, {:max_length, 5}])

      # length 2, below min
      assert {:error, _} = Validator.validate(type, "ab")
      # length 3, at min
      assert {:ok, "abc"} = Validator.validate(type, "abc")
      # length 5, at max
      assert {:ok, "abcde"} = Validator.validate(type, "abcde")
      # length 6, above max
      assert {:error, _} = Validator.validate(type, "abcdef")
    end

    test "handles array constraints at boundaries" do
      type =
        Types.array(Types.string()) |> Types.with_constraints([{:min_items, 2}, {:max_items, 4}])

      # 1 item, below min
      assert {:error, _} = Validator.validate(type, ["a"])
      # 2 items, at min
      assert {:ok, ["a", "b"]} = Validator.validate(type, ["a", "b"])
      # 4 items, at max
      assert {:ok, ["a", "b", "c", "d"]} = Validator.validate(type, ["a", "b", "c", "d"])
      # 5 items, above max
      assert {:error, _} = Validator.validate(type, ["a", "b", "c", "d", "e"])
    end

    test "handles choices constraint with edge cases" do
      # Empty choices list
      empty_choices = Types.string() |> Types.with_constraints([{:choices, []}])
      assert {:error, _} = Validator.validate(empty_choices, "anything")

      # Single choice
      single_choice = Types.string() |> Types.with_constraints([{:choices, ["only"]}])
      assert {:ok, "only"} = Validator.validate(single_choice, "only")
      assert {:error, _} = Validator.validate(single_choice, "other")

      # Choices with special values
      special_choices =
        Types.string() |> Types.with_constraints([{:choices, ["", " ", "\n", "\t"]}])

      assert {:ok, ""} = Validator.validate(special_choices, "")
      assert {:ok, " "} = Validator.validate(special_choices, " ")
      assert {:ok, "\n"} = Validator.validate(special_choices, "\n")
      assert {:ok, "\t"} = Validator.validate(special_choices, "\t")
    end

    test "handles unknown constraint types" do
      # This shouldn't break the validator, just be ignored
      type = {:type, :string, [{:unknown_constraint, "value"}]}

      # Should still validate the base type
      assert {:ok, "test"} = Validator.validate(type, "test")
      assert {:error, _} = Validator.validate(type, 123)
    end
  end

  describe "array validation edge cases" do
    test "handles empty arrays" do
      type = Types.array(Types.string())
      assert {:ok, []} = Validator.validate(type, [])
    end

    test "handles arrays with nil values" do
      type = Types.array(Types.string())
      assert {:error, errors} = Validator.validate(type, [nil])
      assert length(errors) == 1
      assert List.first(errors).path == [0]
    end

    test "handles mixed type arrays" do
      type = Types.array(Types.string())
      mixed_array = ["string", 123, true, %{}, []]

      assert {:error, errors} = Validator.validate(type, mixed_array)
      # Should have errors for all non-string items
      assert length(errors) == 4

      # Check error paths
      error_paths = Enum.map(errors, & &1.path)
      # integer at index 1
      assert [1] in error_paths
      # boolean at index 2
      assert [2] in error_paths
      # map at index 3
      assert [3] in error_paths
      # array at index 4
      assert [4] in error_paths
    end

    test "handles deeply nested arrays with errors" do
      type = Types.array(Types.array(Types.array(Types.string())))

      # Valid deeply nested
      valid_data = [[["a", "b"], ["c"]], [["d", "e", "f"]]]
      assert {:ok, ^valid_data} = Validator.validate(type, valid_data)

      # Invalid at different levels
      invalid_data = [[["a", 123], ["c"]], [["d", "e", true]]]
      assert {:error, errors} = Validator.validate(type, invalid_data)

      # Should have errors at the correct deep paths
      error_paths = Enum.map(errors, & &1.path)
      # 123 at [0][0][1]
      assert [0, 0, 1] in error_paths
      # true at [1][0][2]
      assert [1, 0, 2] in error_paths
    end

    test "handles very large arrays" do
      type = Types.array(Types.integer())
      large_array = Enum.to_list(1..10_000)

      assert {:ok, ^large_array} = Validator.validate(type, large_array)

      # Test with some invalid values mixed in
      large_invalid = Enum.map(1..1000, fn i -> if rem(i, 100) == 0, do: "invalid", else: i end)
      assert {:error, errors} = Validator.validate(type, large_invalid)
      # Every 100th element is invalid
      assert length(errors) == 10
    end

    test "handles sparse arrays (arrays with gaps)" do
      # Elixir lists don't have gaps, but test conceptually similar cases
      type = Types.array(Types.union([Types.string(), Types.integer()]))
      sparse_like = [1, "", 2, "", 3, ""]

      assert {:ok, ^sparse_like} = Validator.validate(type, sparse_like)
    end
  end

  describe "map validation edge cases" do
    test "handles empty maps" do
      type = Types.map(Types.string(), Types.integer())
      assert {:ok, %{}} = Validator.validate(type, %{})
    end

    test "handles maps with special key types" do
      # Integer keys
      int_key_type = Types.map(Types.integer(), Types.string())

      assert {:ok, %{1 => "one", 2 => "two"}} =
               Validator.validate(int_key_type, %{1 => "one", 2 => "two"})

      assert {:error, _} = Validator.validate(int_key_type, %{"1" => "one"})

      # Float keys
      float_key_type = Types.map(Types.float(), Types.string())

      assert {:ok, %{1.5 => "one-five"}} =
               Validator.validate(float_key_type, %{1.5 => "one-five"})
    end

    test "handles maps with unicode keys and values" do
      type = Types.map(Types.string(), Types.string())
      unicode_map = %{"こんにちは" => "世界", "🚀" => "rocket", "café" => "coffee"}

      assert {:ok, ^unicode_map} = Validator.validate(type, unicode_map)
    end

    test "handles maps with very long keys and values" do
      type = Types.map(Types.string(), Types.string())
      long_key = String.duplicate("k", 10_000)
      long_value = String.duplicate("v", 10_000)
      long_map = %{long_key => long_value}

      assert {:ok, ^long_map} = Validator.validate(type, long_map)
    end

    test "handles nested map validation errors" do
      type = Types.map(Types.string(), Types.map(Types.string(), Types.integer()))

      invalid_nested = %{
        "valid" => %{"num" => 123},
        "invalid" => %{"not_num" => "string"}
      }

      assert {:error, errors} = Validator.validate(type, invalid_nested)
      assert length(errors) == 1

      error = List.first(errors)
      assert error.path == ["invalid", "not_num"]
    end

    test "handles map size constraints" do
      type = Types.map(Types.string(), Types.integer()) |> Types.with_constraints([{:size?, 2}])

      assert {:ok, %{"a" => 1, "b" => 2}} = Validator.validate(type, %{"a" => 1, "b" => 2})
      assert {:error, _} = Validator.validate(type, %{"a" => 1})
      assert {:error, _} = Validator.validate(type, %{"a" => 1, "b" => 2, "c" => 3})
    end

    test "handles non-map values" do
      type = Types.map(Types.string(), Types.integer())

      non_maps = [[], "string", 123, true, nil]

      for non_map <- non_maps do
        assert {:error, errors} = Validator.validate(type, non_map)
        assert length(errors) == 1
        assert List.first(errors).code == :type
      end
    end
  end

  describe "union validation edge cases" do
    test "handles union with overlapping types" do
      # Union where integer and float might both match in some cases
      type = Types.union([Types.integer(), Types.float()])

      assert {:ok, 123} = Validator.validate(type, 123)
      assert {:ok, 123.45} = Validator.validate(type, 123.45)
      assert {:error, _} = Validator.validate(type, "123")
    end

    test "handles union validation order preference" do
      # First matching type should be used
      type =
        Types.union([
          Types.string() |> Types.with_constraints([{:min_length, 5}]),
          Types.string() |> Types.with_constraints([{:min_length, 3}])
        ])

      # "test" (length 4) should match the second constraint
      assert {:ok, "test"} = Validator.validate(type, "test")

      # "ab" (length 2) should fail both
      assert {:error, _} = Validator.validate(type, "ab")
    end

    test "handles union with no matching types" do
      type = Types.union([Types.integer(), Types.boolean()])

      assert {:error, errors} = Validator.validate(type, "string")
      assert length(errors) == 1
      assert List.first(errors).code == :type
      assert String.contains?(List.first(errors).message, "union")
    end

    test "handles empty union" do
      type = Types.union([])

      assert {:error, errors} = Validator.validate(type, "anything")
      assert length(errors) == 1
      assert List.first(errors).code == :type
    end

    test "handles deeply nested union types" do
      type =
        Types.union([
          Types.array(Types.string()),
          Types.map(Types.string(), Types.union([Types.integer(), Types.boolean()]))
        ])

      # Should match first type (array of strings)
      assert {:ok, ["a", "b"]} = Validator.validate(type, ["a", "b"])

      # Should match second type (map with union values)
      assert {:ok, %{"key1" => 123, "key2" => true}} =
               Validator.validate(type, %{"key1" => 123, "key2" => true})

      # Should fail both
      assert {:error, _} = Validator.validate(type, 123)
    end

    test "handles union with complex constraint combinations" do
      type =
        Types.union([
          Types.string() |> Types.with_constraints([{:min_length, 10}, {:format, ~r/^[A-Z]+$/}]),
          Types.integer() |> Types.with_constraints([{:gt, 100}, {:lt, 1000}])
        ])

      assert {:ok, "HELLOWORLD"} = Validator.validate(type, "HELLOWORLD")
      assert {:ok, 500} = Validator.validate(type, 500)

      # Should fail - string too short
      assert {:error, _} = Validator.validate(type, "HELLO")
      # Should fail - string wrong format
      assert {:error, _} = Validator.validate(type, "hello world")
      # Should fail - integer too small
      assert {:error, _} = Validator.validate(type, 50)
      # Should fail - integer too large
      assert {:error, _} = Validator.validate(type, 2000)
    end
  end

  describe "validation path tracking edge cases" do
    test "tracks paths correctly in complex nested structures" do
      type =
        Types.array(
          Types.map(
            Types.string(),
            Types.union([
              Types.string(),
              Types.array(Types.integer())
            ])
          )
        )

      invalid_data = [
        %{"key1" => "valid"},
        # "invalid" should cause error at [1, "key2", 1]
        %{"key2" => [1, "invalid", 3]},
        # %{} should cause union error at [2, "key3"]
        %{"key3" => %{}}
      ]

      assert {:error, errors} = Validator.validate(type, invalid_data)

      error_paths = Enum.map(errors, & &1.path)
      assert [1, "key2", 1] in error_paths
      assert [2, "key3"] in error_paths
    end

    test "handles path tracking with special characters in keys" do
      type = Types.map(Types.string(), Types.string())

      invalid_data = %{
        "normal-key" => "valid",
        # Should cause error
        "key.with.dots" => 123,
        # Should cause error
        "key with spaces" => true,
        # Should cause error
        "key@with@symbols" => []
      }

      assert {:error, errors} = Validator.validate(type, invalid_data)

      error_paths = Enum.map(errors, & &1.path)
      assert ["key.with.dots"] in error_paths
      assert ["key with spaces"] in error_paths
      assert ["key@with@symbols"] in error_paths
    end
  end

  describe "memory and performance edge cases" do
    test "handles validation of very deep nesting without stack overflow" do
      # Create a deeply nested structure (but not too deep to avoid actual stack overflow in tests)
      deep_type =
        Enum.reduce(1..50, Types.string(), fn _, acc ->
          Types.array(acc)
        end)

      # Create matching deeply nested data
      deep_data = Enum.reduce(1..50, "leaf", fn _, acc -> [acc] end)

      assert {:ok, ^deep_data} = Validator.validate(deep_type, deep_data)
    end

    test "handles validation of wide structures" do
      # Array with many elements
      type = Types.array(Types.string())
      wide_data = Enum.map(1..1000, &"item_#{&1}")

      assert {:ok, ^wide_data} = Validator.validate(type, wide_data)

      # Map with many keys
      map_type = Types.map(Types.string(), Types.string())
      wide_map = Map.new(1..1000, fn i -> {"key_#{i}", "value_#{i}"} end)

      assert {:ok, ^wide_map} = Validator.validate(map_type, wide_map)
    end
  end
end
