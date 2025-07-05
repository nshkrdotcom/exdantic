defmodule Exdantic.BusinessLogicTest do
  use ExUnit.Case
  alias Exdantic.ModelValidatorTestSchemas.{BusinessLogicValidator, ConditionalValidator}

  describe "complex business logic validation" do
    test "premium product pricing validation passes" do
      data = %{
        product_type: "premium",
        price: 150.0,
        customer_tier: "vip",
        discount_percentage: 20.0
      }

      assert {:ok, result} = BusinessLogicValidator.validate(data)
      assert result.product_type == "premium"
      assert result.price == 150.0
    end

    test "premium product pricing validation fails - price too low" do
      data = %{
        product_type: "premium",
        # Too low for premium
        price: 50.0,
        customer_tier: "regular",
        discount_percentage: 5.0
      }

      assert {:error, errors} = BusinessLogicValidator.validate(data)
      assert length(errors) == 1
      assert hd(errors).message == "premium products must cost at least $100"
    end

    test "discount validation fails - VIP discount too high" do
      data = %{
        product_type: "basic",
        price: 30.0,
        customer_tier: "vip",
        # Too high for VIP
        discount_percentage: 35.0
      }

      assert {:error, errors} = BusinessLogicValidator.validate(data)
      assert length(errors) == 1
      assert hd(errors).message == "VIP customers cannot have more than 30% discount"
    end

    test "multiple business rule violations" do
      data = %{
        product_type: "basic",
        # Too high for basic
        price: 75.0,
        customer_tier: "regular",
        # Too high for regular
        discount_percentage: 15.0
      }

      assert {:error, errors} = BusinessLogicValidator.validate(data)
      assert length(errors) == 1
      # Should contain both error messages joined
      assert String.contains?(hd(errors).message, "basic products cannot cost more than $50")

      assert String.contains?(
               hd(errors).message,
               "regular customers cannot have more than 10% discount"
             )
    end
  end

  describe "conditional validation logic" do
    test "checking account with positive balance" do
      data = %{account_type: "checking", balance: 100.0}

      assert {:ok, result} = ConditionalValidator.validate(data)
      assert result.account_type == "checking"
      assert result.balance == 100.0
    end

    test "checking account with negative balance fails" do
      data = %{account_type: "checking", balance: -50.0}

      assert {:error, errors} = ConditionalValidator.validate(data)
      assert hd(errors).message == "checking accounts cannot have negative balance"
    end

    test "credit account with credit limit" do
      data = %{account_type: "credit", balance: -200.0, credit_limit: 1000.0}

      assert {:ok, result} = ConditionalValidator.validate(data)
      assert result.account_type == "credit"
      assert result.credit_limit == 1000.0
    end

    test "credit account without credit limit fails" do
      data = %{account_type: "credit", balance: 0.0}

      assert {:error, errors} = ConditionalValidator.validate(data)
      assert hd(errors).message == "credit accounts must have a positive credit limit"
    end

    test "savings account with sufficient balance" do
      data = %{account_type: "savings", balance: 500.0}

      assert {:ok, result} = ConditionalValidator.validate(data)
      assert result.balance == 500.0
    end

    test "savings account with insufficient balance fails" do
      data = %{account_type: "savings", balance: 50.0}

      assert {:error, errors} = ConditionalValidator.validate(data)
      assert hd(errors).message == "savings accounts must maintain minimum $100 balance"
    end
  end
end
