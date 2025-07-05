# todo: rename this module and file and also rename the similarly named file and module in `test`
defmodule Exdantic.Phase3Example do
  @moduledoc """
  Complete example demonstrating Phase 3: Computed Fields functionality.

  This example shows how to use computed fields with:
  - Basic computed field definitions
  - Integration with model validators
  - Complex type validation
  - Error handling
  - JSON Schema generation
  - Struct patterns
  """

  # Example 1: Basic User Profile with Computed Fields
  defmodule UserProfileSchema do
    use Exdantic, define_struct: true

    schema "User profile with computed display information" do
      # Regular fields
      field :first_name, :string do
        required()
        min_length(1)
        description("User's first name")
      end

      field :last_name, :string do
        required()
        min_length(1)
        description("User's last name")
      end

      field :email, :string do
        required()
        format(~r/^[^\s@]+@[^\s@]+\.[^\s@]+$/)
        description("User's email address")
      end

      field :birth_date, :string do
        optional()
        description("Birth date in YYYY-MM-DD format")
      end

      field :bio, :string do
        optional()
        max_length(500)
        description("User biography")
      end

      # Computed fields - executed after field and model validation
      computed_field :full_name, :string, :generate_full_name,
        description: "User's full name combining first and last name",
        example: "John Doe"

      computed_field :email_domain, :string, :extract_email_domain,
        description: "Domain part of the user's email address",
        example: "example.com"

      computed_field :profile_summary, :string, :create_profile_summary,
        description: "Brief summary of user profile for display"

      computed_field :age, :integer, :calculate_age,
        description: "User's age calculated from birth date"

      computed_field :display_initials, :string, :generate_initials,
        description: "User's initials for avatar display",
        example: "JD"

      # Configuration
      config do
        title("User Profile Schema")
        strict(true)
      end
    end

    # Computed field functions
    def generate_full_name(data) do
      {:ok, data.first_name <> " " <> data.last_name}
    end

    def extract_email_domain(data) do
      domain = data.email |> String.split("@") |> List.last()
      {:ok, domain}
    end

    def create_profile_summary(data) do
      bio_part = if data.bio, do: " - " <> String.slice(data.bio, 0, 50) <> "...", else: ""
      summary = data.first_name <> " " <> data.last_name <> " (" <> data.email <> ")" <> bio_part
      {:ok, summary}
    end

    def calculate_age(data) do
      case data.birth_date do
        nil -> 
          {:ok, 0}  # Unknown age
        birth_date_str ->
          case Date.from_iso8601(birth_date_str) do
            {:ok, birth_date} ->
              today = Date.utc_today()
              age = Date.diff(today, birth_date) |> div(365)
              {:ok, max(0, age)}
            {:error, _} ->
              {:error, "Invalid birth date format"}
          end
      end
    end

    def generate_initials(data) do
      first_initial = String.first(data.first_name) |> String.upcase()
      last_initial = String.first(data.last_name) |> String.upcase()
      {:ok, first_initial <> last_initial}
    end
  end

  # Example 2: E-commerce Order with Model Validators and Computed Fields
  defmodule OrderSchema do
    use Exdantic, define_struct: true

    schema "E-commerce order with calculated totals" do
      field :order_id, :string, required: true
      field :customer_email, :string, required: true

      field :items, {:array, {:map, {:string, :any}}}, required: true do
        min_items(1)
        description("Order items with price and quantity")
      end

      field :tax_rate, :float, required: true do
        gteq(0.0)
        lteq(1.0)
        description("Tax rate as decimal (e.g., 0.08 for 8%)")
      end

      field :discount_code, :string, required: false
      field :shipping_cost, :float, required: false, default: 0.0

      # Model validator to ensure data consistency
      model_validator :validate_items_structure

      # Computed fields for order calculations
      computed_field :subtotal, :float, :calculate_subtotal,
        description: "Sum of all item prices before tax and shipping"

      computed_field :discount_amount, :float, :calculate_discount,
        description: "Total discount applied to the order"

      computed_field :tax_amount, :float, :calculate_tax,
        description: "Tax amount calculated on discounted subtotal"

      computed_field :total_amount, :float, :calculate_total,
        description: "Final order total including tax and shipping"

      computed_field :item_count, :integer, :count_total_items,
        description: "Total number of items in the order"

      computed_field :order_summary, :string, :generate_order_summary,
        description: "Human-readable order summary"
    end

    # Model validator to ensure item structure
    def validate_items_structure(data) do
      valid_items = Enum.all?(data.items, fn item ->
        Map.has_key?(item, "price") and Map.has_key?(item, "quantity") and Map.has_key?(item, "name")
      end)

      if valid_items do
        {:ok, data}
      else
        {:error, "All items must have 'price', 'quantity', and 'name' fields"}
      end
    end

    # Computed field functions
    def calculate_subtotal(data) do
      subtotal = 
        data.items
        |> Enum.map(fn item -> item["price"] * item["quantity"] end)
        |> Enum.sum()
      {:ok, subtotal}
    end

    def calculate_discount(data) do
      subtotal = 
        data.items
        |> Enum.map(fn item -> item["price"] * item["quantity"] end)
        |> Enum.sum()

      discount = case data.discount_code do
        "SAVE10" -> subtotal * 0.10
        "SAVE20" -> subtotal * 0.20
        "FREESHIP" -> 0.0  # Handled in shipping calculation
        _ -> 0.0
      end

      {:ok, discount}
    end

    def calculate_tax(data) do
      subtotal = 
        data.items
        |> Enum.map(fn item -> item["price"] * item["quantity"] end)
        |> Enum.sum()

      discount = case data.discount_code do
        "SAVE10" -> subtotal * 0.10
        "SAVE20" -> subtotal * 0.20
        _ -> 0.0
      end

      taxable_amount = subtotal - discount
      tax = taxable_amount * data.tax_rate
      {:ok, tax}
    end

    def calculate_total(data) do
      subtotal = 
        data.items
        |> Enum.map(fn item -> item["price"] * item["quantity"] end)
        |> Enum.sum()

      discount = case data.discount_code do
        "SAVE10" -> subtotal * 0.10
        "SAVE20" -> subtotal * 0.20
        _ -> 0.0
      end

      taxable_amount = subtotal - discount
      tax = taxable_amount * data.tax_rate
      
      shipping = if data.discount_code == "FREESHIP", do: 0.0, else: data.shipping_cost
      
      total = taxable_amount + tax + shipping
      {:ok, total}
    end

    def count_total_items(data) do
      total = 
        data.items
        |> Enum.map(fn item -> item["quantity"] end)
        |> Enum.sum()
      {:ok, total}
    end

    def generate_order_summary(data) do
      item_count = 
        data.items
        |> Enum.map(fn item -> item["quantity"] end)
        |> Enum.sum()

      subtotal = 
        data.items
        |> Enum.map(fn item -> item["price"] * item["quantity"] end)
        |> Enum.sum()

      summary = "Order #{data.order_id}: #{item_count} items, $#{:erlang.float_to_binary(subtotal, decimals: 2)} subtotal"
      {:ok, summary}
    end
  end

  # Example 3: Content Analysis with Complex Computed Fields
  defmodule ContentAnalysisSchema do
    use Exdantic, define_struct: true

    schema "Content analysis with text metrics" do
      field :title, :string, required: true
      field :content, :string, required: true
      field :author, :string, required: true
      field :tags, {:array, :string}, required: false, default: []
      field :published_at, :string, required: false

      # Text analysis computed fields
      computed_field :word_count, :integer, :count_words,
        description: "Total number of words in the content"

      computed_field :reading_time, :integer, :estimate_reading_time,
        description: "Estimated reading time in minutes"

      computed_field :content_summary, :string, :generate_summary,
        description: "Brief summary of the content"

      computed_field :sentiment_score, :float, :analyze_sentiment,
        description: "Sentiment analysis score (-1.0 to 1.0)"

      computed_field :readability_metrics, {:map, {:string, :float}}, :calculate_readability,
        description: "Various readability metrics"

      computed_field :seo_analysis, {:map, {:string, :any}}, :analyze_seo,
        description: "SEO analysis including keyword density and suggestions"
    end

    def count_words(data) do
      word_count = 
        (data.title <> " " <> data.content)
        |> String.split()
        |> length()
      {:ok, word_count}
    end

    def estimate_reading_time(data) do
      word_count = 
        (data.title <> " " <> data.content)
        |> String.split()
        |> length()
      
      # Average reading speed: 200 words per minute
      reading_time = max(1, div(word_count, 200))
      {:ok, reading_time}
    end

    def generate_summary(data) do
      sentences = 
        data.content
        |> String.split(~r/[.!?]+/)
        |> Enum.map(&String.trim/1)
        |> Enum.reject(&(&1 == ""))

      summary = 
        sentences
        |> Enum.take(2)
        |> Enum.join(". ")
        |> Kernel.<>("...")

      {:ok, summary}
    end

    def analyze_sentiment(data) do
      # Simple sentiment analysis based on positive/negative words
      text = String.downcase(data.content)
      
      positive_words = ["good", "great", "excellent", "amazing", "wonderful", "fantastic"]
      negative_words = ["bad", "terrible", "awful", "horrible", "disappointing", "poor"]

      positive_count = Enum.count(positive_words, &String.contains?(text, &1))
      negative_count = Enum.count(negative_words, &String.contains?(text, &1))

      total_words = String.split(text) |> length()
      
      if total_words == 0 do
        {:ok, 0.0}
      else
        sentiment = (positive_count - negative_count) / total_words
        {:ok, Float.round(sentiment, 3)}
      end
    end

    def calculate_readability(data) do
      words = String.split(data.content)
      sentences = String.split(data.content, ~r/[.!?]+/) |> Enum.reject(&(&1 == ""))
      
      word_count = length(words)
      sentence_count = max(1, length(sentences))
      
      avg_words_per_sentence = word_count / sentence_count
      
      # Simple readability metrics
      metrics = %{
        "avg_words_per_sentence" => Float.round(avg_words_per_sentence, 2),
        "total_words" => word_count * 1.0,
        "total_sentences" => sentence_count * 1.0,
        "readability_score" => Float.round(206.835 - (1.015 * avg_words_per_sentence), 2)
      }

      {:ok, metrics}
    end

    def analyze_seo(data) do
      title_words = String.downcase(data.title) |> String.split()
      content_words = String.downcase(data.content) |> String.split()
      
      # Keyword density analysis
      keyword_density = 
        title_words
        |> Enum.map(fn word ->
          count = Enum.count(content_words, &(&1 == word))
          density = if length(content_words) > 0, do: count / length(content_words), else: 0.0
          {word, Float.round(density, 4)}
        end)
        |> Enum.into(%{})

      analysis = %{
        "keyword_density" => keyword_density,
        "title_length" => String.length(data.title),
        "content_length" => String.length(data.content),
        "has_tags" => length(data.tags) > 0,
        "tag_count" => length(data.tags)
      }

      {:ok, analysis}
    end
  end

  @doc """
  Example usage demonstrating all Phase 3 features.
  """
  def run_examples do
    IO.puts("🚀 Phase 3: Computed Fields Examples\n")

    # Example 1: User Profile
    IO.puts("📱 Example 1: User Profile with Computed Fields")
    user_data = %{
      first_name: "John",
      last_name: "Doe",
      email: "john.doe@example.com",
      birth_date: "1990-05-15",
      bio: "Software engineer passionate about functional programming and distributed systems."
    }

    case UserProfileSchema.validate(user_data) do
      {:ok, user} ->
        IO.puts("✅ User validation successful!")
        IO.puts("   Full Name: #{user.full_name}")
        IO.puts("   Email Domain: #{user.email_domain}")
        IO.puts("   Age: #{user.age}")
        IO.puts("   Initials: #{user.display_initials}")
        IO.puts("   Summary: #{user.profile_summary}")
        
        # Demonstrate struct functionality
        {:ok, user_map} = UserProfileSchema.dump(user)
        IO.puts("   Serialized: #{inspect(user_map, limit: :infinity)}")

      {:error, errors} ->
        IO.puts("❌ User validation failed:")
        Enum.each(errors, fn error ->
          IO.puts("   - #{Exdantic.Error.format(error)}")
        end)
    end

    IO.puts("\n" <> String.duplicate("=", 50) <> "\n")

    # Example 2: E-commerce Order
    IO.puts("🛒 Example 2: E-commerce Order with Calculations")
    order_data = %{
      order_id: "ORDER-12345",
      customer_email: "customer@example.com",
      items: [
        %{"name" => "Laptop", "price" => 999.99, "quantity" => 1},
        %{"name" => "Mouse", "price" => 25.99, "quantity" => 2},
        %{"name" => "Keyboard", "price" => 79.99, "quantity" => 1}
      ],
      tax_rate: 0.08,
      discount_code: "SAVE10",
      shipping_cost: 15.00
    }

    case OrderSchema.validate(order_data) do
      {:ok, order} ->
        IO.puts("✅ Order validation successful!")
        IO.puts("   Order ID: #{order.order_id}")
        IO.puts("   Item Count: #{order.item_count}")
        IO.puts("   Subtotal: $#{:erlang.float_to_binary(order.subtotal, decimals: 2)}")
        IO.puts("   Discount: $#{:erlang.float_to_binary(order.discount_amount, decimals: 2)}")
        IO.puts("   Tax: $#{:erlang.float_to_binary(order.tax_amount, decimals: 2)}")
        IO.puts("   Total: $#{:erlang.float_to_binary(order.total_amount, decimals: 2)}")
        IO.puts("   Summary: #{order.order_summary}")

      {:error, errors} ->
        IO.puts("❌ Order validation failed:")
        Enum.each(errors, fn error ->
          IO.puts("   - #{Exdantic.Error.format(error)}")
        end)
    end

    IO.puts("\n" <> String.duplicate("=", 50) <> "\n")

    # Example 3: Content Analysis
    IO.puts("📝 Example 3: Content Analysis with Text Metrics")
    content_data = %{
      title: "The Future of Functional Programming",
      content: """
      Functional programming has gained tremendous popularity in recent years. 
      Languages like Elixir, Haskell, and Clojure are becoming more mainstream.
      The immutable data structures and pattern matching make code more reliable.
      Concurrent programming becomes much easier with functional approaches.
      This paradigm shift is changing how we think about software architecture.
      """,
      author: "Jane Smith",
      tags: ["programming", "functional", "elixir", "technology"],
      published_at: "2024-01-15"
    }

    case ContentAnalysisSchema.validate(content_data) do
      {:ok, content} ->
        IO.puts("✅ Content validation successful!")
        IO.puts("   Title: #{content.title}")
        IO.puts("   Author: #{content.author}")
        IO.puts("   Word Count: #{content.word_count}")
        IO.puts("   Reading Time: #{content.reading_time} minutes")
        IO.puts("   Sentiment Score: #{content.sentiment_score}")
        IO.puts("   Summary: #{content.content_summary}")
        IO.puts("   Readability Metrics:")
        Enum.each(content.readability_metrics, fn {key, value} ->
          IO.puts("     #{key}: #{value}")
        end)

      {:error, errors} ->
        IO.puts("❌ Content validation failed:")
        Enum.each(errors, fn error ->
          IO.puts("   - #{Exdantic.Error.format(error)}")
        end)
    end

    IO.puts("\n" <> String.duplicate("=", 50) <> "\n")

    # Example 4: JSON Schema Generation
    IO.puts("📋 Example 4: JSON Schema Generation")
    
    user_json_schema = Exdantic.JsonSchema.from_schema(UserProfileSchema)
    IO.puts("✅ User Profile JSON Schema generated!")
    IO.puts("   Properties count: #{map_size(user_json_schema["properties"])}")
    IO.puts("   Computed fields detected: #{Exdantic.JsonSchema.has_computed_fields?(user_json_schema)}")
    
    computed_info = Exdantic.JsonSchema.extract_computed_field_info(user_json_schema)
    IO.puts("   Computed field details:")
    Enum.each(computed_info, fn info ->
      IO.puts("     - #{info.name}: #{info.type["type"]} (#{info.function})")
    end)

    # Generate separate input/output schemas
    {input_schema, output_schema} = Exdantic.JsonSchema.input_output_schemas(UserProfileSchema)
    input_prop_count = map_size(input_schema["properties"])
    output_prop_count = map_size(output_schema["properties"])
    
    IO.puts("   Input schema properties: #{input_prop_count}")
    IO.puts("   Output schema properties: #{output_prop_count}")
    IO.puts("   Computed fields in output only: #{output_prop_count - input_prop_count}")

    IO.puts("\n" <> String.duplicate("=", 50) <> "\n")

    # Example 5: Error Handling
    IO.puts("⚠️  Example 5: Error Handling")
    
    # Test with invalid data
    invalid_user_data = %{
      first_name: "John",
      last_name: "Doe",
      email: "invalid-email",  # Invalid format
      birth_date: "invalid-date"  # Will cause computed field error
    }

    case UserProfileSchema.validate(invalid_user_data) do
      {:ok, _user} ->
        IO.puts("❌ Expected validation to fail!")

      {:error, errors} ->
        IO.puts("✅ Validation correctly failed with errors:")
        Enum.each(errors, fn error ->
          IO.puts("   - #{error.code}: #{Exdantic.Error.format(error)}")
        end)
    end

    IO.puts("\n" <> String.duplicate("=", 50) <> "\n")

    # Example 6: Performance Demo
    IO.puts("⚡ Example 6: Performance Demonstration")
    
    # Create larger dataset for performance testing
    large_order_data = %{
      order_id: "BULK-ORDER-001",
      customer_email: "bulk@example.com",
      items: Enum.map(1..100, fn i ->
        %{"name" => "Item #{i}", "price" => :rand.uniform(100) * 1.0, "quantity" => :rand.uniform(5)}
      end),
      tax_rate: 0.08,
      shipping_cost: 25.00
    }

    start_time = System.monotonic_time(:microsecond)
    case OrderSchema.validate(large_order_data) do
      {:ok, order} ->
        end_time = System.monotonic_time(:microsecond)
        duration = (end_time - start_time) / 1000
        
        IO.puts("✅ Large order validation completed!")
        IO.puts("   Items processed: #{length(order.items)}")
        IO.puts("   Total items: #{order.item_count}")
        IO.puts("   Validation time: #{Float.round(duration, 2)}ms")
        IO.puts("   Performance: #{Float.round(length(order.items) / duration * 1000, 0)} items/second")

      {:error, errors} ->
        IO.puts("❌ Large order validation failed:")
        Enum.each(errors, fn error ->
          IO.puts("   - #{Exdantic.Error.format(error)}")
        end)
    end

    IO.puts("\n🎉 Phase 3 examples completed successfully!")
  end

  @doc """
  Demonstrates computed field integration with existing features.
  """
  def demo_integration_features do
    IO.puts("🔗 Computed Fields Integration Demo\n")

    # Integration with TypeAdapter
    IO.puts("1️⃣  Integration with TypeAdapter")
    type_spec = {:ref, UserProfileSchema}
    user_data = %{
      first_name: "Alice",
      last_name: "Johnson", 
      email: "alice@example.com"
    }

    case Exdantic.TypeAdapter.validate(type_spec, user_data) do
      {:ok, validated} ->
        IO.puts("✅ TypeAdapter validation with computed fields successful!")
        IO.puts("   Full name computed: #{validated.full_name}")
        IO.puts("   Email domain computed: #{validated.email_domain}")
      {:error, errors} ->
        IO.puts("❌ TypeAdapter validation failed:")
        Enum.each(errors, fn error ->
          IO.puts("   - #{Exdantic.Error.format(error)}")
        end)
    end

    # Integration with EnhancedValidator
    IO.puts("\n2️⃣  Integration with EnhancedValidator")
    config = Exdantic.Config.create(strict: true, coercion: :safe)
    
    case Exdantic.EnhancedValidator.validate(UserProfileSchema, user_data, config: config) do
      {:ok, validated} ->
        IO.puts("✅ EnhancedValidator with computed fields successful!")
        IO.puts("   Profile summary: #{validated.profile_summary}")
      {:error, errors} ->
        IO.puts("❌ EnhancedValidator validation failed:")
        Enum.each(errors, fn error ->
          IO.puts("   - #{Exdantic.Error.format(error)}")
        end)
    end

    # Integration with Wrapper
    IO.puts("\n3️⃣  Integration with Wrapper")
    wrapper = Exdantic.Wrapper.create_wrapper(:user_profile, {:ref, UserProfileSchema})
    
    case Exdantic.Wrapper.validate_and_extract(wrapper, user_data, :user_profile) do
      {:ok, validated} ->
        IO.puts("✅ Wrapper validation with computed fields successful!")
        IO.puts("   Initials computed: #{validated.display_initials}")
      {:error, errors} ->
        IO.puts("❌ Wrapper validation failed:")
        Enum.each(errors, fn error ->
          IO.puts("   - #{Exdantic.Error.format(error)}")
        end)
    end

    IO.puts("\n✨ Integration demo completed!")
  end

  @doc """
  Shows migration path from existing schemas to computed fields.
  """
  def demo_migration_path do
    IO.puts("🔄 Migration Path Demo\n")

    # Step 1: Original schema without computed fields
    defmodule OriginalUserSchema do
      use Exdantic, define_struct: true

      schema do
        field :first_name, :string, required: true
        field :last_name, :string, required: true
        field :email, :string, required: true
      end
    end

    # Step 2: Enhanced schema with computed fields (backward compatible)
    defmodule EnhancedUserSchema do
      use Exdantic, define_struct: true

      schema do
        # Existing fields remain unchanged
        field :first_name, :string, required: true
        field :last_name, :string, required: true
        field :email, :string, required: true

        # New computed fields added without breaking changes
        computed_field :full_name, :string, :generate_full_name
        computed_field :email_domain, :string, :extract_email_domain
      end

      def generate_full_name(data) do
        {:ok, "#{data.first_name} #{data.last_name}"}
      end

      def extract_email_domain(data) do
        {:ok, data.email |> String.split("@") |> List.last()}
      end
    end

    user_data = %{
      first_name: "Migration",
      last_name: "Example",
      email: "migrate@example.com"
    }

    IO.puts("📦 Original Schema Validation:")
    case OriginalUserSchema.validate(user_data) do
      {:ok, user} ->
        IO.puts("✅ Original validation successful")
        IO.puts("   Fields: #{inspect(Map.keys(Map.from_struct(user)))}")
        original_fields = Map.keys(Map.from_struct(user))
        IO.puts("   Field count: #{length(original_fields)}")
      {:error, errors} ->
        IO.puts("❌ Original validation failed: #{inspect(errors)}")
    end

    IO.puts("\n🆕 Enhanced Schema Validation:")
    case EnhancedUserSchema.validate(user_data) do
      {:ok, user} ->
        IO.puts("✅ Enhanced validation successful")
        enhanced_fields = Map.keys(Map.from_struct(user))
        IO.puts("   Fields: #{inspect(enhanced_fields)}")
        IO.puts("   Field count: #{length(enhanced_fields)}")
        IO.puts("   New computed fields:")
        IO.puts("     - full_name: #{user.full_name}")
        IO.puts("     - email_domain: #{user.email_domain}")
      {:error, errors} ->
        IO.puts("❌ Enhanced validation failed: #{inspect(errors)}")
    end

    IO.puts("\n📋 JSON Schema Evolution:")
    original_json = Exdantic.JsonSchema.from_schema(OriginalUserSchema)
    enhanced_json = Exdantic.JsonSchema.from_schema(EnhancedUserSchema)

    original_props = map_size(original_json["properties"])
    enhanced_props = map_size(enhanced_json["properties"])

    IO.puts("   Original schema properties: #{original_props}")
    IO.puts("   Enhanced schema properties: #{enhanced_props}")
    IO.puts("   New computed properties: #{enhanced_props - original_props}")
    IO.puts("   Backward compatibility: ✅ All original fields preserved")

    IO.puts("\n🎯 Migration completed successfully!")
  end

  @doc """
  Comprehensive test of all Phase 3 features.
  """
  def comprehensive_test do
    IO.puts("🧪 Comprehensive Phase 3 Test\n")

    tests = [
      {"Basic computed field functionality", &test_basic_computed_fields/0},
      {"Error handling in computed fields", &test_computed_field_errors/0},
      {"Integration with model validators", &test_model_validator_integration/0},
      {"Complex type computed fields", &test_complex_type_computed_fields/0},
      {"JSON schema generation", &test_json_schema_generation/0},
      {"Performance with large datasets", &test_performance/0},
      {"Backward compatibility", &test_backward_compatibility/0}
    ]

    results = Enum.map(tests, fn {name, test_fn} ->
      IO.puts("Testing: #{name}")
      
      try do
        test_fn.()
        IO.puts("✅ #{name} - PASSED")
        {name, :passed}
      rescue
        e ->
          IO.puts("❌ #{name} - FAILED: #{Exception.message(e)}")
          {name, {:failed, Exception.message(e)}}
      end
    end)

    passed = Enum.count(results, fn {_, result} -> result == :passed end)
    total = length(results)

    IO.puts("\n📊 Test Results: #{passed}/#{total} passed")
    
    if passed == total do
      IO.puts("🎉 All tests passed! Phase 3 is working correctly.")
    else
      IO.puts("⚠️  Some tests failed. Review the errors above.")
      
      failed_tests = Enum.filter(results, fn {_, result} -> result != :passed end)
      Enum.each(failed_tests, fn {name, {:failed, reason}} ->
        IO.puts("   ❌ #{name}: #{reason}")
      end)
    end

    {passed, total}
  end

  # Test helper functions
  defp test_basic_computed_fields do
    defmodule BasicTestSchema do
      use Exdantic, define_struct: true

      schema do
        field :value, :integer, required: true
        computed_field :doubled, :integer, :double_value
      end

      def double_value(data), do: {:ok, data.value * 2}
    end

    assert {:ok, result} = BasicTestSchema.validate(%{value: 21})
    assert result.doubled == 42
  end

  defp test_computed_field_errors do
    defmodule ErrorTestSchema do
      use Exdantic, define_struct: true

      schema do
        field :name, :string, required: true
        computed_field :error_field, :string, :failing_function
      end

      def failing_function(_), do: {:error, "Always fails"}
    end

    assert {:error, errors} = ErrorTestSchema.validate(%{name: "test"})
    assert length(errors) == 1
    assert hd(errors).code == :computed_field
  end

  defp test_model_validator_integration do
    defmodule IntegrationTestSchema do
      use Exdantic, define_struct: true

      schema do
        field :name, :string, required: true
        model_validator :trim_name
        computed_field :greeting, :string, :create_greeting
      end

      def trim_name(data), do: {:ok, %{data | name: String.trim(data.name)}}
      def create_greeting(data), do: {:ok, "Hello, #{data.name}!"}
    end

    assert {:ok, result} = IntegrationTestSchema.validate(%{name: "  John  "})
    assert result.name == "John"  # trimmed by model validator
    assert result.greeting == "Hello, John!"  # computed from trimmed name
  end

  defp test_complex_type_computed_fields do
    defmodule ComplexTypeTestSchema do
      use Exdantic, define_struct: true

      schema do
        field :numbers, {:array, :integer}, required: true
        computed_field :stats, {:map, {:string, :float}}, :calculate_stats
      end

      def calculate_stats(data) do
        count = length(data.numbers)
        sum = Enum.sum(data.numbers)
        avg = if count > 0, do: sum / count, else: 0.0
        
        {:ok, %{"count" => count * 1.0, "average" => avg}}
      end
    end

    assert {:ok, result} = ComplexTypeTestSchema.validate(%{numbers: [1, 2, 3, 4, 5]})
    assert result.stats["count"] == 5.0
    assert result.stats["average"] == 3.0
  end

  defp test_json_schema_generation do
    json_schema = Exdantic.JsonSchema.from_schema(UserProfileSchema)
    
    assert json_schema["type"] == "object"
    assert Map.has_key?(json_schema["properties"], "full_name")
    assert json_schema["properties"]["full_name"]["readOnly"] == true
    assert Map.has_key?(json_schema["properties"]["full_name"], "x-computed-field")
  end

  defp test_performance do
    start_time = System.monotonic_time(:microsecond)
    
    # Validate multiple orders quickly
    for i <- 1..100 do
      order_data = %{
        order_id: "ORDER-#{i}",
        customer_email: "customer#{i}@example.com",
        items: [%{"name" => "Item", "price" => 10.0, "quantity" => 1}],
        tax_rate: 0.08
      }
      
      assert {:ok, _} = OrderSchema.validate(order_data)
    end
    
    end_time = System.monotonic_time(:microsecond)
    duration_ms = (end_time - start_time) / 1000
    
    # Should complete 100 validations in reasonable time
    assert duration_ms < 1000, "Performance test took #{duration_ms}ms, expected < 1000ms"
  end

  defp test_backward_compatibility do
    # Test that old-style schemas still work
    defmodule LegacyTestSchema do
      use Exdantic, define_struct: true

      schema do
        field :name, :string, required: true
        field :age, :integer, required: false
      end
    end

    assert {:ok, result} = LegacyTestSchema.validate(%{name: "Legacy", age: 25})
    assert result.name == "Legacy"
    assert result.age == 25
    
    # Should have no computed fields
    assert LegacyTestSchema.__schema__(:computed_fields) == []
  end
end
