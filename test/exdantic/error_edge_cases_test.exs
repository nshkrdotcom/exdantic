defmodule Exdantic.ErrorEdgeCasesTest do
  use ExUnit.Case, async: true
  alias Exdantic.Error

  describe "Error creation and formatting edge cases" do
    test "handles empty path" do
      error = Error.new([], :required, "field is required")
      assert error.path == []
      assert Error.format(error) == ": field is required"
    end

    test "handles deeply nested paths" do
      deep_path = [:user, :profile, :addresses, 0, :location, :coordinates, :latitude]
      error = Error.new(deep_path, :type, "invalid coordinate")

      expected = "user.profile.addresses.0.location.coordinates.latitude: invalid coordinate"
      assert Error.format(error) == expected
    end

    test "handles mixed path types (atoms, strings, integers)" do
      mixed_path = [:user, "settings", 0, :theme, "colors", 1]
      error = Error.new(mixed_path, :format, "invalid color")

      expected = "user.settings.0.theme.colors.1: invalid color"
      assert Error.format(error) == expected
    end

    test "handles unicode characters in paths and messages" do
      unicode_path = [:ユーザー, :設定]
      unicode_message = "無効な値です"
      error = Error.new(unicode_path, :invalid, unicode_message)

      expected = "ユーザー.設定: 無効な値です"
      assert Error.format(error) == expected
    end

    test "handles extremely long paths" do
      long_path = Enum.map(1..100, &:"field_#{&1}")
      error = Error.new(long_path, :deep, "very deep error")

      formatted = Error.format(error)
      assert String.contains?(formatted, "field_1.field_2")
      assert String.contains?(formatted, "field_100")
      assert String.ends_with?(formatted, ": very deep error")
    end

    test "handles nil and empty string edge cases" do
      # Test with nil message (shouldn't happen in practice but let's be safe)
      error = %Error{path: [:test], code: :nil_test, message: nil}
      assert Error.format(error) == "test: "

      # Test with empty message
      error = Error.new([:test], :empty, "")
      assert Error.format(error) == "test: "
    end

    test "handles special characters in field names" do
      special_fields = [
        :"field-with-dashes",
        :field_with_underscores,
        :"field.with.dots",
        :field@with@at
      ]

      error = Error.new(special_fields, :special, "special characters")

      expected =
        "field-with-dashes.field_with_underscores.field.with.dots.field@with@at: special characters"

      assert Error.format(error) == expected
    end

    test "handles List.wrap edge cases in new/3" do
      # Single atom
      error = Error.new(:single_field, :test, "message")
      assert error.path == [:single_field]

      # Already a list
      error = Error.new([:already, :a, :list], :test, "message")
      assert error.path == [:already, :a, :list]

      # Empty list
      error = Error.new([], :test, "message")
      assert error.path == []
    end
  end

  describe "Error code edge cases" do
    test "handles various error codes" do
      codes = [
        :required,
        :type,
        :format,
        :min_length,
        :max_length,
        :min_items,
        :max_items,
        :gt,
        :lt,
        :gteq,
        :lteq,
        :choices,
        :additional_properties,
        :custom_validation,
        :unknown_field,
        :circular_reference,
        :schema_not_found
      ]

      for code <- codes do
        error = Error.new([:test], code, "test message for #{code}")
        assert error.code == code
        assert String.contains?(Error.format(error), "test message for #{code}")
      end
    end
  end
end
