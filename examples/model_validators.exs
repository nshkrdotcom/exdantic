#!/usr/bin/env elixir

# Model Validators Examples
# Demonstrates comprehensive patterns for model validators in Exdantic schemas

defmodule ModelValidatorsExamples do
  @moduledoc """
  Complete examples for model validators functionality in Exdantic.

  This module demonstrates:
  - Named function model validators
  - Anonymous function model validators
  - Cross-field validation
  - Data transformation
  - Error handling in model validators
  - Complex business logic validation
  - Sequential validator execution
  """

  # Example 1: User Registration with Password Validation
  defmodule UserRegistrationSchema do
    use Exdantic, define_struct: true

    schema "User registration with password validation" do
      field :username, :string, min_length: 3, max_length: 20
      field :email, :string, format: ~r/^[^\s@]+@[^\s@]+\.[^\s@]+$/
      field :password, :string, min_length: 8
      field :password_confirmation, :string
      field :age, :integer, gt: 0, lt: 150
      field :terms_accepted, :boolean

      # Named function validators
      model_validator :validate_passwords_match
      model_validator :validate_age_requirements
      model_validator :validate_terms_acceptance
      model_validator :normalize_data

      # Anonymous function validator
      model_validator fn input ->
        if String.contains?(input.username, " ") do
          {:error, "Username cannot contain spaces"}
        else
          {:ok, input}
        end
      end
    end

    def validate_passwords_match(input) do
      if input.password == input.password_confirmation do
        # Remove confirmation field from final data
        {:ok, Map.delete(input, :password_confirmation)}
      else
        {:error, "Password confirmation does not match"}
      end
    end

    def validate_age_requirements(input) do
      cond do
        input.age < 13 ->
          {:error, "Users must be at least 13 years old"}
        input.age < 18 and not String.ends_with?(input.email, ".edu") ->
          {:error, "Users under 18 must use an educational email address"}
        true ->
          {:ok, input}
      end
    end

    def validate_terms_acceptance(input) do
      if input.terms_accepted do
        {:ok, input}
      else
        {:error, "Terms and conditions must be accepted"}
      end
    end

    def normalize_data(input) do
      normalized = %{
        input |
        username: String.downcase(input.username),
        email: String.downcase(input.email)
      }
      {:ok, normalized}
    end
  end

  # Example 2: Financial Transaction Validation
  defmodule TransactionSchema do
    use Exdantic, define_struct: true

    schema "Financial transaction with business rules" do
      field :from_account, :string, required: true
      field :to_account, :string, required: true
      field :amount, :float, gt: 0.0
      field :currency, :string, choices: ["USD", "EUR", "GBP", "CAD"]
      field :transaction_type, :string, choices: ["transfer", "payment", "withdrawal"]
      field :user_id, :string, required: true
      field :daily_limit, :float, default: 1000.0

      # Complex business logic validators
      model_validator :validate_account_differences
      model_validator :validate_transaction_limits
      model_validator :validate_business_rules
      model_validator :apply_transaction_fees
    end

    def validate_account_differences(input) do
      if input.from_account == input.to_account do
        {:error, "Cannot transfer money to the same account"}
      else
        {:ok, input}
      end
    end

    def validate_transaction_limits(input) do
      # Simulate checking daily transaction limit
      cond do
        input.amount > input.daily_limit ->
          {:error, "Transaction amount exceeds daily limit of #{input.daily_limit}"}
        input.amount > 10000.0 and input.transaction_type != "transfer" ->
          {:error, "Large payments require transfer type"}
        true ->
          {:ok, input}
      end
    end

    def validate_business_rules(input) do
      # Complex business logic
      case {input.transaction_type, input.currency, input.amount} do
        {"withdrawal", "USD", amount} when amount > 5000.0 ->
          {:error, "USD withdrawals over $5000 require additional verification"}
        {"payment", currency, amount} when currency != "USD" and amount > 1000.0 ->
          {:error, "International payments over equivalent of $1000 require approval"}
        _ ->
          {:ok, input}
      end
    end

    def apply_transaction_fees(input) do
      # Calculate and apply transaction fees
      fee = case input.transaction_type do
        "transfer" -> 0.0  # Free transfers
        "payment" -> input.amount * 0.025  # 2.5% fee
        "withdrawal" -> max(input.amount * 0.01, 2.50)  # 1% fee, minimum $2.50
      end

      # For demo purposes, we'll just return the input with a note about fees
      # In a real application, you'd want to add fee and total_amount fields to the schema
      if input.amount + fee > input.daily_limit do
        {:error, "Transaction amount plus fees exceeds daily limit"}
      else
        {:ok, input}
      end
    end
  end

  # Example 3: Data Import Validation
  defmodule DataImportSchema do
    use Exdantic, define_struct: true

    schema "Data import with validation and cleaning" do
      field :records, {:array, :map}, min_items: 1
      field :import_source, :string, required: true
      field :import_format, :string, choices: ["csv", "json", "xml"]
      field :strict_mode, :boolean, default: false

      model_validator :validate_record_structure
      model_validator :clean_and_normalize_data
      model_validator :validate_data_consistency
      model_validator :generate_import_summary
    end

    def validate_record_structure(input) do
      # Validate that all records have required fields
      required_fields = ["id", "name", "value"]

      invalid_records = input.records
                       |> Enum.with_index()
                       |> Enum.filter(fn {record, _index} ->
                         not Enum.all?(required_fields, &Map.has_key?(record, &1))
                       end)

      if invalid_records == [] do
        {:ok, input}
      else
        invalid_indices = Enum.map(invalid_records, fn {_, index} -> index end)
        {:error, "Records at indices #{inspect(invalid_indices)} are missing required fields"}
      end
    end

    def clean_and_normalize_data(input) do
      cleaned_records = Enum.map(input.records, fn record ->
        %{
          "id" => String.trim(to_string(Map.get(record, "id", ""))),
          "name" => String.trim(to_string(Map.get(record, "name", ""))),
          "value" => normalize_value(Map.get(record, "value")),
          "metadata" => Map.get(record, "metadata", %{})
        }
      end)

      {:ok, Map.put(input, :records, cleaned_records)}
    end

    def validate_data_consistency(input) do
      # Check for duplicate IDs
      ids = Enum.map(input.records, &Map.get(&1, "id"))
      unique_ids = Enum.uniq(ids)

      if length(ids) != length(unique_ids) do
        {:error, "Duplicate IDs found in import data"}
      else
        # Validate value ranges if in strict mode
        if input.strict_mode do
          invalid_values = Enum.filter(input.records, fn record ->
            value = Map.get(record, "value", 0)
            not is_number(value) or value < 0
          end)

          if invalid_values == [] do
            {:ok, input}
          else
            {:error, "Invalid values found in strict mode validation"}
          end
        else
          {:ok, input}
        end
      end
    end

    def generate_import_summary(input) do
      # For demo purposes, we'll just return the input
      # In a real application, you'd want to add import_summary field to the schema
      {:ok, input}
    end

    defp normalize_value(value) when is_binary(value) do
      case Float.parse(value) do
        {float_val, ""} -> float_val
        _ -> 0.0
      end
    end
    defp normalize_value(value) when is_number(value), do: value * 1.0
    defp normalize_value(_), do: 0.0
  end

  # Example 4: Runtime Schema with Model Validators
  defmodule RuntimeValidatorExample do
    def create_order_validation_schema do
      fields = [
        {:customer_id, :string, [required: true]},
        {:items, {:array, :map}, [required: true, min_items: 1]},
        {:shipping_address, :map, [required: true]},
        {:payment_method, :string, [choices: ["credit_card", "paypal", "bank_transfer"]]},
        {:priority, :string, [choices: ["standard", "express", "overnight"], default: "standard"]}
      ]

      # Named function validator (module reference)
      validators = [
        {__MODULE__, :validate_customer_exists},
        {__MODULE__, :validate_item_availability},
        {__MODULE__, :calculate_shipping_cost},
        # Anonymous function validator
        fn data ->
          # Validate shipping address has required fields
          address = data.shipping_address
          required_address_fields = ["street", "city", "postal_code", "country"]

          missing_fields = Enum.filter(required_address_fields, fn field ->
            not Map.has_key?(address, field) or Map.get(address, field) == ""
          end)

          if missing_fields == [] do
            {:ok, data}
          else
            {:error, "Missing address fields: #{Enum.join(missing_fields, ", ")}"}
          end
        end
      ]

      Exdantic.Runtime.create_enhanced_schema(fields,
        model_validators: validators,
        title: "Order Validation Schema",
        description: "Schema for validating e-commerce orders"
      )
    end

    def validate_customer_exists(data) do
      # Simulate customer lookup
      valid_customers = ["CUST001", "CUST002", "CUST003"]

      if data.customer_id in valid_customers do
        {:ok, data}
      else
        {:error, "Customer ID #{data.customer_id} not found"}
      end
    end

    def validate_item_availability(data) do
      # Simulate inventory check
      available_items = ["ITEM001", "ITEM002", "ITEM003", "ITEM004"]

      unavailable_items = Enum.filter(data.items, fn item ->
        item_id = Map.get(item, "id", "")
        item_id not in available_items
      end)

      if unavailable_items == [] do
        {:ok, data}
      else
        unavailable_ids = Enum.map(unavailable_items, &Map.get(&1, "id", "unknown"))
        {:error, "Items not available: #{Enum.join(unavailable_ids, ", ")}"}
      end
    end

    def calculate_shipping_cost(data) do
      # Calculate shipping based on priority and destination
      base_cost = case data.priority do
        "standard" -> 5.99
        "express" -> 12.99
        "overnight" -> 24.99
      end

      # International shipping surcharge
      country = Map.get(data.shipping_address, "country", "")
      international_surcharge = if country != "US", do: 10.0, else: 0.0

      _total_shipping = base_cost + international_surcharge

      # For demo purposes, we'll just return the data
      # In a real application, you'd want to add shipping_cost field to the schema
      {:ok, data}
    end
  end

  # Example 5: Complex Business Logic with Multiple Validators
  defmodule InsuranceClaimSchema do
    use Exdantic, define_struct: true

    schema "Insurance claim processing with complex validation" do
      field :claim_id, :string, required: true
      field :policy_number, :string, required: true
      field :claimant_name, :string, required: true
      field :incident_date, :string, required: true
      field :claim_amount, :float, gt: 0.0
      field :claim_type, :string, choices: ["auto", "home", "health", "life"]
      field :description, :string, min_length: 10
      field :supporting_documents, {:array, :string}, min_items: 1
      field :is_urgent, :boolean, default: false
      field :adjuster_id, :string, required: false

      # Sequential validation chain
      model_validator :validate_policy_status
      model_validator :validate_claim_eligibility
      model_validator :validate_incident_date
      model_validator :validate_claim_amount_limits
      model_validator :assign_adjuster
      model_validator :calculate_processing_priority
      model_validator :generate_claim_reference
    end

        def validate_policy_status(input) do
      # Simulate policy lookup and status check
      active_policies = ["POL001", "POL002", "POL003", "POL004", "POL005"]

      if input.policy_number in active_policies do
        {:ok, input}
      else
        {:error, "Policy #{input.policy_number} is not active or does not exist"}
      end
    end

    def validate_claim_eligibility(input) do
      # Check if claim type is covered under policy
      case {input.policy_number, input.claim_type} do
        {"POL001", "health"} -> {:error, "Health claims not covered under this policy"}
        {"POL002", "auto"} -> {:error, "Auto claims not covered under this policy"}
        _ ->
          # All other combinations are valid
          {:ok, input}
      end
    end

    def validate_incident_date(input) do
      # Parse and validate incident date
      case Date.from_iso8601(input.incident_date) do
        {:ok, incident_date} ->
          today = Date.utc_today()
          days_ago = Date.diff(today, incident_date)

          cond do
            days_ago < 0 ->
              {:error, "Incident date cannot be in the future"}
            days_ago > 365 ->
              {:error, "Claims must be filed within one year of the incident"}
            days_ago > 30 ->
              # Late filing detected but we'll continue processing
              {:ok, input}
            true ->
              {:ok, input}
          end
        {:error, _} ->
          {:error, "Invalid incident date format. Use YYYY-MM-DD"}
      end
    end

    def validate_claim_amount_limits(input) do
      # Validate claim amount against policy limits
      policy_limits = %{
        "auto" => 50000.0,
        "home" => 100000.0,
        "health" => 25000.0,
        "life" => 500000.0
      }

      max_amount = Map.get(policy_limits, input.claim_type, 10000.0)

      cond do
        input.claim_amount > max_amount ->
          {:error, "Claim amount $#{input.claim_amount} exceeds policy limit of $#{max_amount}"}
        input.claim_amount > 10000.0 ->
          # High-value claims need additional documentation
          required_docs = length(input.supporting_documents)
          if required_docs < 3 do
            {:error, "Claims over $10,000 require at least 3 supporting documents"}
          else
            {:ok, input}
          end
        true ->
          {:ok, input}
      end
    end

    def assign_adjuster(input) do
            # Auto-assign adjuster based on claim characteristics
      _adjuster = cond do
        input.claim_amount > 25000.0 -> "ADJ_SENIOR_001"
        input.claim_type == "auto" -> "ADJ_AUTO_001"
        input.claim_type == "home" -> "ADJ_PROPERTY_001"
        input.is_urgent -> "ADJ_URGENT_001"
        true -> "ADJ_GENERAL_001"
      end

      # For demo purposes, we'll just return the input
      # In a real application, you'd want to add assigned_adjuster field to the schema
      {:ok, input}
    end

    def calculate_processing_priority(input) do
      # Calculate priority score based on multiple factors
      priority_score = 0

      # Amount-based priority
      priority_score = priority_score + cond do
        input.claim_amount > 50000.0 -> 30
        input.claim_amount > 25000.0 -> 20
        input.claim_amount > 10000.0 -> 10
        true -> 0
      end

      # Urgency
      priority_score = if input.is_urgent, do: priority_score + 25, else: priority_score

      # Late filing penalty
      priority_score = if Map.get(input, :late_filing, false), do: priority_score - 10, else: priority_score

      # Type-based priority
      priority_score = priority_score + case input.claim_type do
        "life" -> 40
        "health" -> 30
        "auto" -> 15
        "home" -> 10
      end

            _priority_level = cond do
        priority_score >= 70 -> "critical"
        priority_score >= 50 -> "high"
        priority_score >= 30 -> "medium"
        true -> "low"
      end

      # For demo purposes, we'll just return the input
      # In a real application, you'd want to add priority fields to the schema
      {:ok, input}
    end

        def generate_claim_reference(input) do
      # Generate unique claim reference
      _timestamp = DateTime.utc_now() |> DateTime.to_unix()
      _type_code = case input.claim_type do
        "auto" -> "AU"
        "home" -> "HM"
        "health" -> "HL"
        "life" -> "LF"
      end

      # For demo purposes, we'll just return the input
      # In a real application, you'd want to add claim_reference field to the schema
      {:ok, input}
    end
  end

  # Example 6: Error Handling and Recovery
  defmodule ErrorHandlingSchema do
    use Exdantic, define_struct: true

    schema "Error handling and recovery patterns" do
      field :data, :map, required: true
      field :processing_mode, :string, choices: ["strict", "lenient", "recovery"]
      field :error_threshold, :integer, default: 3

      model_validator :validate_with_error_handling
      model_validator :attempt_data_recovery
      model_validator :log_processing_results
    end

    def validate_with_error_handling(input) do
      case input.processing_mode do
        "strict" ->
          # Strict mode - any error fails validation
          validate_strictly(input)
        "lenient" ->
          # Lenient mode - collect errors but continue processing
          validate_leniently(input)
        "recovery" ->
          # Recovery mode - attempt to fix errors
          validate_with_recovery(input)
      end
    end

        def attempt_data_recovery(input) do
      # For demo purposes, we'll just return the input
      # In a real application, you'd check recovery fields and perform recovery
      {:ok, input}
    end

    def log_processing_results(input) do
      # For demo purposes, we'll just return the input
      # In a real application, you'd want to add processing_log field to the schema
      {:ok, input}
    end

    defp validate_strictly(input) do
      data = input.data

      # Check for required fields
      required_fields = ["id", "name", "value"]
      missing_fields = Enum.filter(required_fields, fn field ->
        not Map.has_key?(data, field)
      end)

      if missing_fields != [] do
        {:error, "Missing required fields: #{Enum.join(missing_fields, ", ")}"}
      else
        {:ok, input}
      end
    end

    defp validate_leniently(input) do
      data = input.data
      errors = []

      # Collect all errors but don't fail
      errors = if not Map.has_key?(data, "id") do
        ["Missing ID field" | errors]
      else
        errors
      end

      _errors = if not Map.has_key?(data, "name") do
        ["Missing name field" | errors]
      else
        errors
      end

            # For demo purposes, we'll just return the input
      # In a real application, you'd want to add validation result fields to the schema
      {:ok, input}
    end

    defp validate_with_recovery(input) do
      data = input.data
      errors = []

      # Try to recover missing fields
      recovered_data = data

      {recovered_data, errors} = if not Map.has_key?(data, "id") do
        {Map.put(recovered_data, "id", generate_id()), ["Recovered missing ID" | errors]}
      else
        {recovered_data, errors}
      end

      {recovered_data, _errors} = if not Map.has_key?(data, "name") do
        {Map.put(recovered_data, "name", "Unknown"), ["Recovered missing name" | errors]}
      else
        {recovered_data, errors}
      end

      # For demo purposes, we'll just return the input with recovered data
      # In a real application, you'd want to add recovery fields to the schema
      {:ok, Map.put(input, :data, recovered_data)}
    end

    defp generate_id do
      "GEN_" <> (:crypto.strong_rand_bytes(8) |> Base.encode16())
    end
  end

  # Demo functions to run examples
  def run_examples do
    IO.puts("🔧 Model Validators Examples")
    IO.puts("=" |> String.duplicate(50))

    # Example 1: User Registration
    IO.puts("\n📝 1. User Registration Validation")
    IO.puts("-" |> String.duplicate(30))

    valid_user = %{
      username: "johndoe",
      email: "john@example.com",
      password: "securepass123",
      password_confirmation: "securepass123",
      age: 25,
      terms_accepted: true
    }

    case UserRegistrationSchema.validate(valid_user) do
      {:ok, result} ->
        IO.puts("✅ Valid user registration:")
        IO.inspect(result, pretty: true)
      {:error, errors} ->
        IO.puts("❌ Registration failed:")
        IO.inspect(errors)
    end

    # Example 2: Transaction Validation
    IO.puts("\n💰 2. Financial Transaction Validation")
    IO.puts("-" |> String.duplicate(30))

    transaction = %{
      from_account: "ACC001",
      to_account: "ACC002",
      amount: 150.0,
      currency: "USD",
      transaction_type: "payment",
      user_id: "USER123",
      daily_limit: 1000.0
    }

    case TransactionSchema.validate(transaction) do
      {:ok, result} ->
        IO.puts("✅ Transaction validated:")
        IO.puts("  Amount: $#{result.amount}")
        IO.puts("  Currency: #{result.currency}")
        IO.puts("  Type: #{result.transaction_type}")
      {:error, errors} ->
        IO.puts("❌ Transaction failed:")
        IO.inspect(errors)
    end

    # Example 3: Data Import
    IO.puts("\n📊 3. Data Import Validation")
    IO.puts("-" |> String.duplicate(30))

    import_data = %{
      records: [
        %{"id" => "1", "name" => "Item A", "value" => "10.5"},
        %{"id" => "2", "name" => "Item B", "value" => 20.0}
      ],
      import_source: "external_api",
      import_format: "json",
      strict_mode: false
    }

    case DataImportSchema.validate(import_data) do
      {:ok, result} ->
        IO.puts("✅ Data import successful:")
        IO.puts("  Records processed: #{length(result.records)}")
        IO.puts("  Source: #{result.import_source}")
        IO.puts("  Format: #{result.import_format}")
      {:error, errors} ->
        IO.puts("❌ Import failed:")
        IO.inspect(errors)
    end

    # Example 4: Runtime Schema
    IO.puts("\n🏗️ 4. Runtime Schema with Validators")
    IO.puts("-" |> String.duplicate(30))

    schema = RuntimeValidatorExample.create_order_validation_schema()

    order_data = %{
      customer_id: "CUST001",
      items: [%{"id" => "ITEM001", "quantity" => 2}],
      shipping_address: %{
        "street" => "123 Main St",
        "city" => "Anytown",
        "postal_code" => "12345",
        "country" => "US"
      },
      payment_method: "credit_card",
      priority: "express"
    }

    case Exdantic.Runtime.Validator.validate(order_data, schema) do
      {:ok, result} ->
        IO.puts("✅ Order validated:")
        IO.puts("  Customer: #{result.customer_id}")
        IO.puts("  Payment method: #{result.payment_method}")
        IO.puts("  Priority: #{result.priority}")
      {:error, errors} ->
        IO.puts("❌ Order validation failed:")
        IO.inspect(errors)
    end

    # Example 5: Insurance Claim
    IO.puts("\n🏥 5. Insurance Claim Processing")
    IO.puts("-" |> String.duplicate(30))

    claim_data = %{
      claim_id: "CLM001",
      policy_number: "POL001",
      claimant_name: "Jane Smith",
      incident_date: "2024-11-15",
      claim_amount: 5000.0,
      claim_type: "auto",
      description: "Vehicle collision on highway, front end damage",
      supporting_documents: ["police_report.pdf", "photos.zip", "estimate.pdf"],
      is_urgent: false
    }

    case InsuranceClaimSchema.validate(claim_data) do
      {:ok, result} ->
        IO.puts("✅ Claim processed:")
        IO.puts("  Claim ID: #{result.claim_id}")
        IO.puts("  Policy: #{result.policy_number}")
        IO.puts("  Amount: $#{result.claim_amount}")
        IO.puts("  Type: #{result.claim_type}")
      {:error, errors} ->
        IO.puts("❌ Claim processing failed:")
        IO.inspect(errors)
    end

    # Example 6: Error Handling
    IO.puts("\n🚨 6. Error Handling and Recovery")
    IO.puts("-" |> String.duplicate(30))

    problematic_data = %{
      data: %{"value" => 42},  # Missing id and name
      processing_mode: "recovery",
      error_threshold: 3
    }

    case ErrorHandlingSchema.validate(problematic_data) do
      {:ok, result} ->
        IO.puts("✅ Data processed with recovery:")
        IO.puts("  Processing mode: #{result.processing_mode}")
        IO.puts("  Error threshold: #{result.error_threshold}")
        IO.puts("  Final data: #{inspect(result.data)}")
      {:error, errors} ->
        IO.puts("❌ Processing failed:")
        IO.inspect(errors)
    end

    IO.puts("\n🎉 All model validator examples completed!")
  end
end

# Run examples if script is executed directly
if Path.basename(__ENV__.file) == "model_validators.exs" do
  ModelValidatorsExamples.run_examples()
end
