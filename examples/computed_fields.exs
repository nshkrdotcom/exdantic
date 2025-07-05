#!/usr/bin/env elixir

# Computed Fields Examples
# Demonstrates comprehensive patterns for computed fields in Exdantic schemas

defmodule ComputedFieldsExamples do
  @moduledoc """
  Complete examples for computed fields functionality in Exdantic.

  This module demonstrates:
  - Named function computed fields
  - Anonymous function computed fields
  - Complex computed field calculations
  - Error handling in computed fields
  - Computed fields with dependencies
  - JSON Schema generation with computed fields
  """

  # Example 1: Basic User Profile with Computed Fields
  defmodule UserProfileSchema do
    use Exdantic, define_struct: true

    schema "User profile with computed display fields" do
      field :first_name, :string, required: true
      field :last_name, :string, required: true
      field :email, :string, required: true
      field :birth_date, :string, format: ~r/^\d{4}-\d{2}-\d{2}$/
      field :phone, :string, optional: true

      # Named function computed fields
      computed_field :full_name, :string, :generate_full_name
      computed_field :email_domain, :string, :extract_email_domain
      computed_field :age, :integer, :calculate_age
      computed_field :initials, :string, :generate_initials

      # Anonymous function computed field
      computed_field :display_name, :string, fn input ->
        display = if input.age do
          "#{input.full_name} (#{input.age})"
        else
          input.full_name
        end
        {:ok, display}
      end

      # Computed field with error handling
      computed_field :username_suggestion, :string, :suggest_username
    end

    def generate_full_name(input) do
      {:ok, "#{input.first_name} #{input.last_name}"}
    end

    def extract_email_domain(input) do
      domain = input.email |> String.split("@") |> List.last()
      {:ok, domain}
    end

    def calculate_age(input) do
      case Date.from_iso8601(input.birth_date) do
        {:ok, birth_date} ->
          today = Date.utc_today()
          age = Date.diff(today, birth_date) |> div(365)
          {:ok, age}
        {:error, _} ->
          {:error, "Invalid birth date format"}
      end
    end

    def generate_initials(input) do
      first_initial = String.first(input.first_name)
      last_initial = String.first(input.last_name)
      {:ok, "#{first_initial}#{last_initial}"}
    end

    def suggest_username(input) do
      base_username = input.email |> String.split("@") |> hd()
      # Add some variation
      suggested = "#{base_username}_#{String.slice(input.last_name, 0, 2) |> String.downcase()}"
      {:ok, suggested}
    end
  end

  # Example 2: E-commerce Order with Complex Calculations
  defmodule OrderSchema do
    use Exdantic, define_struct: true

    schema "E-commerce order with calculated totals" do
      field :items, {:array, :map}, required: true, min_items: 1
      field :discount_code, :string, optional: true
      field :tax_rate, :float, default: 0.08, gteq: 0.0, lteq: 1.0
      field :shipping_rate, :float, default: 5.99, gteq: 0.0
      field :customer_tier, :string, choices: ["bronze", "silver", "gold"], default: "bronze"

      # Complex computed field calculations
      computed_field :subtotal, :float, :calculate_subtotal
      computed_field :discount_amount, :float, :calculate_discount
      computed_field :discounted_subtotal, :float, :calculate_discounted_subtotal
      computed_field :tax_amount, :float, :calculate_tax
      computed_field :shipping_cost, :float, :calculate_shipping
      computed_field :total, :float, :calculate_total

      # Analysis computed fields
      computed_field :item_count, :integer, :count_items
      computed_field :average_item_price, :float, :calculate_average_price
      computed_field :order_category, :string, :categorize_order

      model_validator :validate_order_items
    end

    def validate_order_items(input) do
      # Ensure all items have required fields
      valid_items = Enum.all?(input.items, fn item ->
        Map.has_key?(item, "name") and
        Map.has_key?(item, "price") and
        Map.has_key?(item, "quantity")
      end)

      if valid_items do
        {:ok, input}
      else
        {:error, "All items must have name, price, and quantity"}
      end
    end

    def calculate_subtotal(input) do
      subtotal = input.items
                 |> Enum.map(fn item ->
                   Map.get(item, "price", 0) * Map.get(item, "quantity", 0)
                 end)
                 |> Enum.sum()
      {:ok, subtotal}
    end

    def calculate_discount(input) do
      discount = case input.discount_code do
        "SAVE10" -> input.subtotal * 0.10
        "SAVE20" -> input.subtotal * 0.20
        "GOLD50" when input.customer_tier == "gold" -> input.subtotal * 0.50
        _ -> 0.0
      end
      {:ok, discount}
    end

    def calculate_discounted_subtotal(input) do
      {:ok, input.subtotal - input.discount_amount}
    end

    def calculate_tax(input) do
      {:ok, input.discounted_subtotal * input.tax_rate}
    end

    def calculate_shipping(input) do
      # Free shipping for orders over $100 or gold customers
      shipping = cond do
        input.customer_tier == "gold" -> 0.0
        input.discounted_subtotal > 100.0 -> 0.0
        true -> input.shipping_rate
      end
      {:ok, shipping}
    end

    def calculate_total(input) do
      {:ok, input.discounted_subtotal + input.tax_amount + input.shipping_cost}
    end

    def count_items(input) do
      count = input.items
              |> Enum.map(&Map.get(&1, "quantity", 0))
              |> Enum.sum()
      {:ok, count}
    end

    def calculate_average_price(input) do
      if input.item_count > 0 do
        {:ok, input.subtotal / input.item_count}
      else
        {:ok, 0.0}
      end
    end

    def categorize_order(input) do
      category = cond do
        input.total < 25 -> "small"
        input.total < 100 -> "medium"
        input.total < 500 -> "large"
        true -> "enterprise"
      end
      {:ok, category}
    end
  end

  # Example 3: Analytics Report with Advanced Computed Fields
  defmodule AnalyticsReportSchema do
    use Exdantic, define_struct: true

    schema "Analytics report with statistical computations" do
      field :data_points, {:array, :float}, required: true, min_items: 1
      field :time_period, :string, required: true
      field :metric_type, :string, choices: ["revenue", "users", "conversions"]

      # Statistical computed fields
      computed_field :count, :integer, fn input ->
        {:ok, length(input.data_points)}
      end

      computed_field :sum, :float, fn input ->
        {:ok, Enum.sum(input.data_points)}
      end

      computed_field :average, :float, :calculate_average
      computed_field :median, :float, :calculate_median
      computed_field :min_value, :float, fn input ->
        {:ok, Enum.min(input.data_points)}
      end

      computed_field :max_value, :float, fn input ->
        {:ok, Enum.max(input.data_points)}
      end

      computed_field :range, :float, fn input ->
        {:ok, input.max_value - input.min_value}
      end

      computed_field :variance, :float, :calculate_variance
      computed_field :standard_deviation, :float, :calculate_std_dev

      # Trend analysis
      computed_field :trend, :string, :analyze_trend
      computed_field :growth_rate, :float, :calculate_growth_rate

      # Report metadata
      computed_field :data_quality_score, :float, :assess_data_quality
      computed_field :confidence_level, :string, :determine_confidence
    end

    def calculate_average(input) do
      if input.count > 0 do
        {:ok, input.sum / input.count}
      else
        {:ok, 0.0}
      end
    end

    def calculate_median(input) do
      sorted = Enum.sort(input.data_points)
      count = length(sorted)

      median = if rem(count, 2) == 0 do
        # Even number of elements
        mid1 = Enum.at(sorted, div(count, 2) - 1)
        mid2 = Enum.at(sorted, div(count, 2))
        (mid1 + mid2) / 2
      else
        # Odd number of elements
        Enum.at(sorted, div(count, 2))
      end

      {:ok, median}
    end

    def calculate_variance(input) do
      if input.count <= 1 do
        {:ok, 0.0}
      else
        mean = input.average
        variance = input.data_points
                   |> Enum.map(fn x -> :math.pow(x - mean, 2) end)
                   |> Enum.sum()
                   |> Kernel./(input.count - 1)
        {:ok, variance}
      end
    end

    def calculate_std_dev(input) do
      {:ok, :math.sqrt(input.variance)}
    end

    def analyze_trend(input) do
      if input.count < 2 do
        {:ok, "insufficient_data"}
      else
        # Simple trend analysis based on first and last values
        first = List.first(input.data_points)
        last = List.last(input.data_points)

        trend = cond do
          last > first * 1.1 -> "increasing"
          last < first * 0.9 -> "decreasing"
          true -> "stable"
        end

        {:ok, trend}
      end
    end

    def calculate_growth_rate(input) do
      if input.count < 2 do
        {:ok, 0.0}
      else
        first = List.first(input.data_points)
        last = List.last(input.data_points)

        if first != 0 do
          growth_rate = ((last - first) / first) * 100
          {:ok, growth_rate}
        else
          {:ok, 0.0}
        end
      end
    end

    def assess_data_quality(input) do
      # Simple data quality assessment
      score = cond do
        input.count >= 30 -> 0.9
        input.count >= 10 -> 0.7
        input.count >= 5 -> 0.5
        true -> 0.3
      end

      # Adjust for data consistency (low standard deviation = higher quality)
      if input.standard_deviation < input.average * 0.1 do
        {:ok, min(score + 0.1, 1.0)}
      else
        {:ok, score}
      end
    end

    def determine_confidence(input) do
      confidence = case input.data_quality_score do
        score when score >= 0.8 -> "high"
        score when score >= 0.6 -> "medium"
        score when score >= 0.4 -> "low"
        _ -> "very_low"
      end
      {:ok, confidence}
    end
  end

  # Example 4: Runtime Schema with Computed Fields
  defmodule RuntimeComputedFields do
    def create_enhanced_user_schema do
      # Base fields
      fields = [
        {:username, :string, [required: true, min_length: 3]},
        {:join_date, :string, [required: true, format: ~r/^\d{4}-\d{2}-\d{2}$/]},
        {:post_count, :integer, [default: 0, gteq: 0]},
        {:follower_count, :integer, [default: 0, gteq: 0]},
        {:following_count, :integer, [default: 0, gteq: 0]}
      ]

      # Model validators
      validators = [
        fn data ->
          # Normalize username
          {:ok, %{data | username: String.downcase(data.username)}}
        end
      ]

      # Computed fields with anonymous functions
      computed_fields = [
        {:days_since_join, :integer, fn data ->
          case Date.from_iso8601(data.join_date) do
            {:ok, join_date} ->
              days = Date.diff(Date.utc_today(), join_date)
              {:ok, days}
            {:error, _} ->
              {:error, "Invalid join date"}
          end
        end},

        {:engagement_ratio, :float, fn data ->
          if data.follower_count > 0 do
            ratio = data.post_count / data.follower_count
            {:ok, Float.round(ratio, 3)}
          else
            {:ok, 0.0}
          end
        end},

        {:user_tier, :string, fn data ->
          tier = cond do
            data.follower_count > 10000 -> "influencer"
            data.follower_count > 1000 -> "popular"
            data.follower_count > 100 -> "active"
            true -> "newcomer"
          end
          {:ok, tier}
        end},

        {:social_score, :float, fn data ->
          # Complex scoring algorithm
          base_score = data.post_count * 0.1
          follower_bonus = data.follower_count * 0.01
          engagement_bonus = data.engagement_ratio * 10
          longevity_bonus = min(data.days_since_join / 365, 2.0)

          total_score = base_score + follower_bonus + engagement_bonus + longevity_bonus
          {:ok, Float.round(total_score, 2)}
        end}
      ]

      Exdantic.Runtime.create_enhanced_schema(fields,
        model_validators: validators,
        computed_fields: computed_fields,
        title: "Enhanced User Profile",
        description: "User profile with computed social metrics"
      )
    end
  end

  # Example 5: Error Handling in Computed Fields
  defmodule ErrorHandlingSchema do
    use Exdantic, define_struct: true

    schema "Demonstrates error handling in computed fields" do
      field :numerator, :float, required: true
      field :denominator, :float, required: true
      field :data_source, :string, required: true

      # Computed field with division by zero handling
      computed_field :division_result, :float, :safe_divide

      # Computed field with external validation
      computed_field :data_validity, :string, :validate_data_source

      # Computed field with complex error conditions
      computed_field :risk_assessment, :string, :assess_risk
    end

    def safe_divide(input) do
      if input.denominator == 0.0 do
        {:error, "Division by zero is not allowed"}
      else
        result = input.numerator / input.denominator
        {:ok, result}
      end
    end

    def validate_data_source(input) do
      valid_sources = ["database", "api", "file", "manual"]

      if input.data_source in valid_sources do
        {:ok, "valid"}
      else
        {:error, "Invalid data source: #{input.data_source}"}
      end
    end

    def assess_risk(input) do
      cond do
        input.data_validity != "valid" ->
          {:ok, "high_risk"}
        abs(input.division_result) > 1000 ->
          {:ok, "high_risk"}
        abs(input.division_result) > 100 ->
          {:ok, "medium_risk"}
        true ->
          {:ok, "low_risk"}
      end
    rescue
      # Handle case where division_result might not be available due to error
      _ -> {:ok, "unknown_risk"}
    end
  end

  # Main demonstration function
  def run_examples do
    IO.puts("=== Computed Fields Examples ===\n")

    # Example 1: User Profile
    IO.puts("1. User Profile with Computed Fields")
    user_data = %{
      first_name: "John",
      last_name: "Doe",
      email: "john.doe@example.com",
      birth_date: "1990-05-15",
      phone: "+1-555-0123"
    }

    case UserProfileSchema.validate(user_data) do
      {:ok, user} ->
        IO.puts("✓ User profile validated with computed fields:")
        IO.puts("  Full name: #{user.full_name}")
        IO.puts("  Email domain: #{user.email_domain}")
        IO.puts("  Age: #{user.age}")
        IO.puts("  Initials: #{user.initials}")
        IO.puts("  Display name: #{user.display_name}")
        IO.puts("  Username suggestion: #{user.username_suggestion}")
      {:error, errors} ->
        IO.puts("✗ Validation failed:")
        Enum.each(errors, &IO.puts("  #{Exdantic.Error.format(&1)}"))
    end
    IO.puts("")

    # Example 2: E-commerce Order
    IO.puts("2. E-commerce Order with Complex Calculations")
    order_data = %{
      items: [
        %{"name" => "Widget A", "price" => 25.99, "quantity" => 2},
        %{"name" => "Widget B", "price" => 15.50, "quantity" => 1},
        %{"name" => "Widget C", "price" => 45.00, "quantity" => 1}
      ],
      discount_code: "SAVE10",
      tax_rate: 0.08,
      shipping_rate: 5.99,
      customer_tier: "silver"
    }

    case OrderSchema.validate(order_data) do
      {:ok, order} ->
        IO.puts("✓ Order validated with computed totals:")
        IO.puts("  Subtotal: $#{:erlang.float_to_binary(order.subtotal, decimals: 2)}")
        IO.puts("  Discount: $#{:erlang.float_to_binary(order.discount_amount, decimals: 2)}")
        IO.puts("  Tax: $#{:erlang.float_to_binary(order.tax_amount, decimals: 2)}")
        IO.puts("  Shipping: $#{:erlang.float_to_binary(order.shipping_cost, decimals: 2)}")
        IO.puts("  Total: $#{:erlang.float_to_binary(order.total, decimals: 2)}")
        IO.puts("  Item count: #{order.item_count}")
        IO.puts("  Average price: $#{:erlang.float_to_binary(order.average_item_price, decimals: 2)}")
        IO.puts("  Order category: #{order.order_category}")
      {:error, errors} ->
        IO.puts("✗ Order validation failed:")
        Enum.each(errors, &IO.puts("  #{Exdantic.Error.format(&1)}"))
    end
    IO.puts("")

    # Example 3: Analytics Report
    IO.puts("3. Analytics Report with Statistical Computations")
    analytics_data = %{
      data_points: [12.5, 15.3, 18.7, 14.2, 16.8, 20.1, 13.9, 17.4, 19.2, 16.0],
      time_period: "Q1 2024",
      metric_type: "revenue"
    }

    case AnalyticsReportSchema.validate(analytics_data) do
      {:ok, report} ->
        IO.puts("✓ Analytics report computed:")
        IO.puts("  Count: #{report.count}")
        IO.puts("  Average: #{:erlang.float_to_binary(report.average, decimals: 2)}")
        IO.puts("  Median: #{:erlang.float_to_binary(report.median, decimals: 2)}")
        IO.puts("  Range: #{:erlang.float_to_binary(report.range, decimals: 2)}")
        IO.puts("  Std Dev: #{:erlang.float_to_binary(report.standard_deviation, decimals: 2)}")
        IO.puts("  Trend: #{report.trend}")
        IO.puts("  Growth Rate: #{:erlang.float_to_binary(report.growth_rate, decimals: 1)}%")
        IO.puts("  Data Quality: #{:erlang.float_to_binary(report.data_quality_score, decimals: 2)}")
        IO.puts("  Confidence: #{report.confidence_level}")
      {:error, errors} ->
        IO.puts("✗ Analytics validation failed:")
        Enum.each(errors, &IO.puts("  #{Exdantic.Error.format(&1)}"))
    end
    IO.puts("")

    # Example 4: Runtime Schema with Computed Fields
    IO.puts("4. Runtime Schema with Enhanced Computed Fields")
    enhanced_schema = RuntimeComputedFields.create_enhanced_user_schema()

    user_social_data = %{
      username: "TechGuru",
      join_date: "2022-03-15",
      post_count: 150,
      follower_count: 2500,
      following_count: 300
    }

    case Exdantic.Runtime.validate_enhanced(user_social_data, enhanced_schema) do
      {:ok, enhanced_user} ->
        IO.puts("✓ Enhanced user profile computed:")
        IO.puts("  Username: #{enhanced_user.username}")
        IO.puts("  Days since join: #{enhanced_user.days_since_join}")
        IO.puts("  Engagement ratio: #{enhanced_user.engagement_ratio}")
        IO.puts("  User tier: #{enhanced_user.user_tier}")
        IO.puts("  Social score: #{enhanced_user.social_score}")
      {:error, errors} ->
        IO.puts("✗ Enhanced user validation failed:")
        Enum.each(errors, &IO.puts("  #{Exdantic.Error.format(&1)}"))
    end
    IO.puts("")

    # Example 5: Error Handling
    IO.puts("5. Error Handling in Computed Fields")

    # Test with valid data
    valid_data = %{
      numerator: 100.0,
      denominator: 5.0,
      data_source: "database"
    }

    case ErrorHandlingSchema.validate(valid_data) do
      {:ok, result} ->
        IO.puts("✓ Valid data processed:")
        IO.puts("  Division result: #{result.division_result}")
        IO.puts("  Data validity: #{result.data_validity}")
        IO.puts("  Risk assessment: #{result.risk_assessment}")
      {:error, errors} ->
        IO.puts("✗ Valid data failed:")
        Enum.each(errors, &IO.puts("  #{Exdantic.Error.format(&1)}"))
    end

    # Test with division by zero
    invalid_data = %{
      numerator: 100.0,
      denominator: 0.0,
      data_source: "api"
    }

    case ErrorHandlingSchema.validate(invalid_data) do
      {:ok, _result} ->
        IO.puts("✓ Unexpected success with invalid data")
      {:error, errors} ->
        IO.puts("✓ Expected error with division by zero:")
        Enum.each(errors, &IO.puts("  #{Exdantic.Error.format(&1)}"))
    end
    IO.puts("")

    # Example 6: JSON Schema Generation
    IO.puts("6. JSON Schema Generation with Computed Fields")
    json_schema = Exdantic.JsonSchema.from_schema(UserProfileSchema)

    IO.puts("✓ Generated JSON Schema includes:")
    properties = Map.get(json_schema, "properties", %{})

    # Show regular and computed fields
    regular_fields = ["first_name", "last_name", "email", "birth_date", "phone"]
    computed_fields = ["full_name", "email_domain", "age", "initials", "display_name", "username_suggestion"]

    IO.puts("  Regular fields: #{Enum.join(regular_fields, ", ")}")
    IO.puts("  Computed fields: #{Enum.join(computed_fields, ", ")}")

    # Check if computed fields are marked as readOnly
    computed_readonly = Enum.all?(computed_fields, fn field ->
      case Map.get(properties, field) do
        %{"readOnly" => true} -> true
        _ -> false
      end
    end)

    if computed_readonly do
      IO.puts("  ✓ All computed fields marked as readOnly in JSON Schema")
    else
      IO.puts("  ✗ Some computed fields not marked as readOnly")
    end

    # Remove computed fields for input validation
    input_schema = Exdantic.JsonSchema.remove_computed_fields(json_schema)
    input_properties = Map.get(input_schema, "properties", %{})

    IO.puts("  Input schema (computed fields removed): #{Map.keys(input_properties) |> Enum.join(", ")}")

    IO.puts("\n=== All Computed Fields Examples Completed ===")
  end
end

# Run the examples
ComputedFieldsExamples.run_examples()
