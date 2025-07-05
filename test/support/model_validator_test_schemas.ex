defmodule Exdantic.ModelValidatorTestSchemas do
  @moduledoc """
  Test schemas for model validator functionality testing.
  """

  # Basic model validator with struct
  defmodule PasswordValidationStruct do
    @moduledoc """
    Schema for password validation using a struct.
    """
    use Exdantic, define_struct: true

    schema "Password validation with struct" do
      field(:password, :string, required: true)
      field(:password_confirmation, :string, required: true)

      model_validator(:validate_passwords_match)
    end

    def validate_passwords_match(data) do
      if data.password == data.password_confirmation do
        {:ok, data}
      else
        {:error, "passwords do not match"}
      end
    end
  end

  # Basic model validator with map
  defmodule PasswordValidationMap do
    @moduledoc """
    Schema for password validation using a map.
    """
    use Exdantic, define_struct: false

    schema "Password validation with map" do
      field(:password, :string, required: true)
      field(:password_confirmation, :string, required: true)

      model_validator(:validate_passwords_match)
    end

    def validate_passwords_match(data) do
      if data.password == data.password_confirmation do
        {:ok, data}
      else
        {:error, "passwords do not match"}
      end
    end
  end

  # Multiple model validators
  defmodule MultipleValidators do
    @moduledoc """
    Schema with multiple model validators for username, email, and age.
    """
    use Exdantic, define_struct: true

    schema do
      field(:username, :string, required: true)
      field(:email, :string, required: true)
      field(:age, :integer, required: true)

      model_validator(:validate_username_length)
      model_validator(:validate_email_format)
      model_validator(:validate_adult_age)
    end

    def validate_username_length(data) do
      if String.length(data.username) >= 3 do
        {:ok, data}
      else
        {:error, "username must be at least 3 characters"}
      end
    end

    def validate_email_format(data) do
      if String.contains?(data.email, "@") do
        {:ok, data}
      else
        {:error, "email must contain @ symbol"}
      end
    end

    def validate_adult_age(data) do
      if data.age >= 18 do
        {:ok, data}
      else
        {:error, "must be 18 or older"}
      end
    end
  end

  # Model validator that transforms data
  defmodule DataTransformer do
    @moduledoc """
    Schema with a model validator that transforms and normalizes data.
    """
    use Exdantic, define_struct: true

    schema do
      field(:name, :string, required: true)
      field(:email, :string, required: true)

      model_validator(:normalize_data)
    end

    def normalize_data(data) do
      normalized = %{
        data
        | name: String.trim(data.name),
          email: String.downcase(String.trim(data.email))
      }

      {:ok, normalized}
    end
  end

  # Model validator with complex business logic
  defmodule BusinessLogicValidator do
    @moduledoc """
    Schema with business logic validation for product pricing and discounts.
    """
    use Exdantic, define_struct: true

    schema do
      field(:product_type, :string, required: true)
      field(:price, :float, required: true)
      field(:discount_percentage, :float, required: false, default: 0.0)
      field(:customer_tier, :string, required: true)

      model_validator(:validate_pricing_rules)
    end

    def validate_pricing_rules(data) do
      errors = []

      # Price validation based on product type
      errors =
        case data.product_type do
          "premium" when data.price < 100.0 ->
            ["premium products must cost at least $100" | errors]

          "basic" when data.price > 50.0 ->
            ["basic products cannot cost more than $50" | errors]

          _ ->
            errors
        end

      # Discount validation based on customer tier
      errors =
        case {data.customer_tier, data.discount_percentage} do
          {"vip", discount} when discount > 30.0 ->
            ["VIP customers cannot have more than 30% discount" | errors]

          {"regular", discount} when discount > 10.0 ->
            ["regular customers cannot have more than 10% discount" | errors]

          _ ->
            errors
        end

      case errors do
        [] -> {:ok, data}
        error_list -> {:error, Enum.join(error_list, "; ")}
      end
    end
  end

  # Model validator that returns Error struct
  defmodule ErrorStructValidator do
    @moduledoc """
    Schema with a model validator that returns an Exdantic.Error struct.
    """
    use Exdantic, define_struct: true

    schema do
      field(:value, :integer, required: true)

      model_validator(:validate_with_error_struct)
    end

    def validate_with_error_struct(data) do
      if data.value > 0 do
        {:ok, data}
      else
        error = Exdantic.Error.new([:value], :custom_validation, "value must be positive")
        {:error, error}
      end
    end
  end

  # Model validator that adds additional data
  defmodule DataEnhancer do
    @moduledoc """
    Schema with a model validator that adds additional data fields.
    """
    use Exdantic, define_struct: true

    schema do
      field(:first_name, :string, required: true)
      field(:last_name, :string, required: true)
      field(:full_name, :string, required: false)

      model_validator(:add_full_name)
    end

    def add_full_name(data) do
      enhanced_data = Map.put(data, :full_name, data.first_name <> " " <> data.last_name)
      {:ok, enhanced_data}
    end
  end

  # Model validator with conditional logic
  defmodule ConditionalValidator do
    @moduledoc """
    Schema with conditional logic in the model validator.
    """
    use Exdantic, define_struct: true

    schema do
      field(:account_type, :string, required: true)
      field(:balance, :float, required: true)
      field(:credit_limit, :float, required: false)

      model_validator(:validate_account_rules)
    end

    def validate_account_rules(data) do
      case data.account_type do
        "checking" ->
          if data.balance >= 0.0 do
            {:ok, data}
          else
            {:error, "checking accounts cannot have negative balance"}
          end

        "credit" ->
          credit_limit = Map.get(data, :credit_limit)

          if credit_limit && credit_limit > 0 do
            {:ok, data}
          else
            {:error, "credit accounts must have a positive credit limit"}
          end

        "savings" ->
          if data.balance >= 100.0 do
            {:ok, data}
          else
            {:error, "savings accounts must maintain minimum $100 balance"}
          end

        _ ->
          {:error, "invalid account type"}
      end
    end
  end

  # Model validator that works with optional fields
  defmodule OptionalFieldValidator do
    @moduledoc """
    Schema with optional fields and display logic validation.
    """
    use Exdantic, define_struct: true

    schema do
      field(:name, :string, required: true)
      field(:nickname, :string, required: false)
      field(:display_preference, :string, required: false, default: "name")

      model_validator(:validate_display_logic)
    end

    def validate_display_logic(data) do
      case Map.get(data, :display_preference, "name") do
        "nickname" ->
          nickname = Map.get(data, :nickname)

          if nickname && String.length(nickname) > 0 do
            {:ok, data}
          else
            {:error, "nickname required when display_preference is 'nickname'"}
          end

        "name" ->
          {:ok, data}

        _ ->
          {:error, "display_preference must be 'name' or 'nickname'"}
      end
    end
  end

  # Schema without model validators (for compatibility testing)
  defmodule NoValidators do
    @moduledoc """
    Schema without model validators for compatibility testing.
    """
    use Exdantic, define_struct: true

    schema do
      field(:simple_field, :string, required: true)
    end
  end

  # Model validator that fails during execution
  defmodule FailingValidator do
    @moduledoc """
    Schema with a model validator that intentionally fails for testing.
    """
    use Exdantic, define_struct: true

    schema do
      field(:trigger_failure, :boolean, required: true, default: false)

      model_validator(:potentially_failing_validator)
    end

    def potentially_failing_validator(data) do
      if data.trigger_failure do
        # Simulate an unexpected error
        raise RuntimeError, "simulated validator failure"
      else
        {:ok, data}
      end
    end
  end
end
