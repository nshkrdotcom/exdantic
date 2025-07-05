defmodule Exdantic.ValidationErrorEdgeCasesTest do
  use ExUnit.Case, async: true
  alias Exdantic.{Error, ValidationError}

  describe "ValidationError edge cases" do
    test "handles empty error list" do
      error = %ValidationError{errors: []}
      assert ValidationError.message(error) == ""
    end

    test "handles single error" do
      single_error = Error.new([:field], :required, "field is required")
      validation_error = %ValidationError{errors: [single_error]}

      expected = "field: field is required"
      assert ValidationError.message(validation_error) == expected
    end

    test "handles multiple errors with proper formatting" do
      errors = [
        Error.new([:name], :required, "name is required"),
        Error.new([:email], :format, "invalid email format"),
        Error.new([:age], :gt, "age must be greater than 0")
      ]

      validation_error = %ValidationError{errors: errors}
      message = ValidationError.message(validation_error)

      assert String.contains?(message, "name: name is required")
      assert String.contains?(message, "email: invalid email format")
      assert String.contains?(message, "age: age must be greater than 0")

      # Should be separated by newlines
      lines = String.split(message, "\n")
      assert length(lines) == 3
    end

    test "handles deeply nested error paths" do
      nested_errors = [
        Error.new([:user, :profile, :addresses, 0, :street], :required, "street is required"),
        Error.new([:user, :profile, :addresses, 1, :city], :min_length, "city too short"),
        Error.new([:settings, :notifications, :email, :frequency], :choices, "invalid frequency")
      ]

      validation_error = %ValidationError{errors: nested_errors}
      message = ValidationError.message(validation_error)

      assert String.contains?(message, "user.profile.addresses.0.street: street is required")
      assert String.contains?(message, "user.profile.addresses.1.city: city too short")

      assert String.contains?(
               message,
               "settings.notifications.email.frequency: invalid frequency"
             )
    end

    test "handles unicode in error messages" do
      unicode_errors = [
        Error.new([:名前], :required, "名前は必須です"),
        Error.new([:メール], :format, "メール形式が無効です")
      ]

      validation_error = %ValidationError{errors: unicode_errors}
      message = ValidationError.message(validation_error)

      assert String.contains?(message, "名前: 名前は必須です")
      assert String.contains?(message, "メール: メール形式が無効です")
    end

    test "handles very large number of errors" do
      many_errors =
        Enum.map(1..1000, fn i ->
          Error.new([:"field_#{i}"], :invalid, "error #{i}")
        end)

      validation_error = %ValidationError{errors: many_errors}
      message = ValidationError.message(validation_error)

      lines = String.split(message, "\n")
      assert length(lines) == 1000
      assert String.contains?(message, "field_1: error 1")
      assert String.contains?(message, "field_1000: error 1000")
    end

    test "handles errors with special characters in messages" do
      special_errors = [
        Error.new([:field1], :format, "Invalid format: expected /^\\d+$/ but got 'abc123'"),
        Error.new([:field2], :custom, "Error with \"quotes\" and 'apostrophes'"),
        Error.new(
          [:field3],
          :regex,
          "Pattern match failed: \n\t- Expected: [a-zA-Z]\n\t- Got: 123"
        )
      ]

      validation_error = %ValidationError{errors: special_errors}
      message = ValidationError.message(validation_error)

      assert String.contains?(message, "Invalid format: expected /^\\d+$/ but got 'abc123'")
      assert String.contains?(message, "Error with \"quotes\" and 'apostrophes'")

      assert String.contains?(
               message,
               "Pattern match failed: \n\t- Expected: [a-zA-Z]\n\t- Got: 123"
             )
    end
  end

  describe "Exception behavior" do
    test "can be raised as exception" do
      errors = [Error.new([:test], :invalid, "test error")]

      assert_raise ValidationError, "test: test error", fn ->
        raise ValidationError, errors: errors
      end
    end

    test "exception with multiple errors shows all" do
      errors = [
        Error.new([:field1], :required, "field1 required"),
        Error.new([:field2], :format, "field2 invalid")
      ]

      expected_message = "field1: field1 required\nfield2: field2 invalid"

      assert_raise ValidationError, expected_message, fn ->
        raise ValidationError, errors: errors
      end
    end
  end
end
