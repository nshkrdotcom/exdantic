#!/usr/bin/env elixir

# Conditional and Recursive Validation Examples
# Demonstrates advanced validation patterns in Exdantic

defmodule ConditionalRecursiveValidationExamples do
  @moduledoc """
  Complete examples for conditional and recursive validation patterns in Exdantic.

  This module demonstrates:
  - Conditional validation based on field values
  - Recursive schema validation (tree structures)
  - Dynamic schema selection
  - Cross-schema validation
  - Multi-step validation pipelines
  - Complex business logic patterns
  """

  # Example 1: Conditional Validation Based on User Type
  defmodule ConditionalUserSchema do
    use Exdantic, define_struct: true

    schema "User with conditional field requirements" do
      field :user_type, :string, choices: ["individual", "business", "government"]
      field :first_name, :string, optional: true
      field :last_name, :string, optional: true
      field :business_name, :string, optional: true
      field :tax_id, :string, optional: true
      field :government_id, :string, optional: true
      field :department, :string, optional: true
      field :email, :string, required: true
      field :phone, :string, optional: true

      model_validator :validate_user_type_fields
      model_validator :validate_contact_requirements
    end

    def validate_user_type_fields(input) do
      case input.user_type do
        "individual" ->
          validate_individual_fields(input)
        "business" ->
          validate_business_fields(input)
        "government" ->
          validate_government_fields(input)
      end
    end

    def validate_contact_requirements(input) do
      # Government users must have phone
      if input.user_type == "government" and is_nil(input.phone) do
        {:error, "Government users must provide a phone number"}
      else
        {:ok, input}
      end
    end

    defp validate_individual_fields(input) do
      cond do
        is_nil(input.first_name) -> {:error, "First name required for individuals"}
        is_nil(input.last_name) -> {:error, "Last name required for individuals"}
        true -> {:ok, input}
      end
    end

    defp validate_business_fields(input) do
      cond do
        is_nil(input.business_name) -> {:error, "Business name required for businesses"}
        is_nil(input.tax_id) -> {:error, "Tax ID required for businesses"}
        true -> {:ok, input}
      end
    end

    defp validate_government_fields(input) do
      cond do
        is_nil(input.government_id) -> {:error, "Government ID required for government users"}
        is_nil(input.department) -> {:error, "Department required for government users"}
        true -> {:ok, input}
      end
    end
  end

  # Example 2: Recursive Tree Structure Validation
  defmodule TreeNodeSchema do
    use Exdantic, define_struct: true

    schema "Recursive tree node structure" do
      field :id, :string, required: true
      field :value, :any, required: true
      field :node_type, :string, choices: ["leaf", "branch"], default: "leaf"
      field :children, {:array, TreeNodeSchema}, default: []
      field :metadata, :map, default: %{}

      model_validator :validate_tree_structure
      model_validator :validate_node_consistency
      computed_field :depth, :integer, :calculate_depth
      computed_field :node_count, :integer, :count_nodes
      computed_field :is_valid_tree, :boolean, :validate_tree_integrity
    end

    def validate_tree_structure(input) do
      cond do
        input.node_type == "leaf" and length(input.children) > 0 ->
          {:error, "Leaf nodes cannot have children"}
        input.node_type == "branch" and length(input.children) == 0 ->
          {:error, "Branch nodes must have at least one child"}
        length(input.children) > 10 ->
          {:error, "Node cannot have more than 10 children"}
        true ->
          {:ok, input}
      end
    end

    def validate_node_consistency(input) do
      # Check for duplicate child IDs
      child_ids = Enum.map(input.children, & &1.id)
      unique_ids = Enum.uniq(child_ids)

      if length(child_ids) != length(unique_ids) do
        {:error, "Child nodes must have unique IDs"}
      else
        {:ok, input}
      end
    end

      def calculate_depth(input) do
    depth = if input.children == [] do
      1
    else
      max_child_depth = input.children
                       |> Enum.map(fn child ->
                         Map.get(child, :depth, 1)
                       end)
                       |> Enum.max(fn -> 0 end)
      max_child_depth + 1
    end
    {:ok, depth}
  end

      def count_nodes(input) do
    count = 1 + Enum.sum(Enum.map(input.children, fn child ->
      Map.get(child, :node_count, 1)
    end))
    {:ok, count}
  end

    def validate_tree_integrity(input) do
      # Simple integrity check - no cycles, reasonable depth
      is_valid = input.depth <= 10 and input.node_count <= 100
      {:ok, is_valid}
    end
  end

  # Example 3: Dynamic Schema Selection
  defmodule DynamicValidation do
    # Different schemas for different document types
    defmodule ArticleSchema do
      use Exdantic

      schema "Article document" do
        field :title, :string, required: true, min_length: 5
        field :content, :string, required: true, min_length: 100
        field :author, :string, required: true
        field :tags, {:array, :string}, default: []
        field :published_at, :string, optional: true
      end
    end

    defmodule ReportSchema do
      use Exdantic

      schema "Report document" do
        field :title, :string, required: true, min_length: 5
        field :executive_summary, :string, required: true, min_length: 50
        field :sections, {:array, :map}, required: true, min_items: 1
        field :author, :string, required: true
        field :reviewed_by, :string, optional: true
        field :classification, :string, choices: ["public", "internal", "confidential"]
      end
    end

    defmodule PresentationSchema do
      use Exdantic

      schema "Presentation document" do
        field :title, :string, required: true, min_length: 5
        field :slides, {:array, :map}, required: true, min_items: 1
        field :presenter, :string, required: true
        field :duration_minutes, :integer, gt: 0, lteq: 180
        field :audience, :string, required: true
      end
    end

    @schemas %{
      "article" => ArticleSchema,
      "report" => ReportSchema,
      "presentation" => PresentationSchema
    }

    def validate_by_type(data, document_type) do
      case Map.get(@schemas, document_type) do
        nil ->
          {:error, "Unknown document type: #{document_type}"}
        schema ->
          schema.validate(data)
      end
    end

    def validate_with_fallback(data, primary_type, fallback_type) do
      case validate_by_type(data, primary_type) do
        {:ok, result} ->
          {:ok, {primary_type, result}}
        {:error, _} ->
          case validate_by_type(data, fallback_type) do
            {:ok, result} ->
              {:ok, {fallback_type, result}}
            {:error, errors} ->
              {:error, "Failed both #{primary_type} and #{fallback_type} validation: #{inspect(errors)}"}
          end
      end
    end

    def auto_detect_and_validate(data) do
      # Try to auto-detect document type based on fields
      detected_type = cond do
        Map.has_key?(data, "content") and Map.has_key?(data, "tags") -> "article"
        Map.has_key?(data, "executive_summary") and Map.has_key?(data, "classification") -> "report"
        Map.has_key?(data, "slides") and Map.has_key?(data, "duration_minutes") -> "presentation"
        true -> nil
      end

      case detected_type do
        nil ->
          {:error, "Could not auto-detect document type"}
        type ->
          case validate_by_type(data, type) do
            {:ok, result} ->
              {:ok, {type, result}}
            {:error, errors} ->
              {:error, "Auto-detected as #{type} but validation failed: #{inspect(errors)}"}
          end
      end
    end
  end

  # Example 4: Cross-Schema Validation
  defmodule CrossSchemaValidation do
    defmodule UserSchema do
      use Exdantic

      schema "User account" do
        field :id, :string, required: true
        field :email, :string, required: true
        field :role, :string, choices: ["admin", "user", "viewer"]
        field :active, :boolean, default: true
        field :credit_limit, :float, default: 1000.0
      end
    end

    defmodule OrderSchema do
      use Exdantic

      schema "Order information" do
        field :id, :string, required: true
        field :user_id, :string, required: true
        field :items, {:array, :map}, required: true, min_items: 1
        field :total_amount, :float, gt: 0.0
        field :status, :string, choices: ["pending", "confirmed", "shipped", "delivered"]
      end
    end

    def validate_order_with_user(order_data, user_data) do
      with {:ok, user} <- UserSchema.validate(user_data),
           {:ok, order} <- OrderSchema.validate(order_data),
           :ok <- validate_user_can_order(user, order) do
        {:ok, {user, order}}
      else
        error -> error
      end
    end

    defp validate_user_can_order(user, order) do
      cond do
        not user.active ->
          {:error, "User account is not active"}
        user.credit_limit < order.total_amount ->
          {:error, "Order amount (#{order.total_amount}) exceeds user credit limit (#{user.credit_limit})"}
        order.user_id != user.id ->
          {:error, "Order user_id does not match provided user"}
        order.items == [] ->
          {:error, "Order must contain at least one item"}
        true ->
          :ok
      end
    end
  end

  # Example 5: Multi-Step Validation Pipeline
  defmodule ValidationPipeline do
    defmodule StepResult do
      use Exdantic, define_struct: true

      schema "Validation step result" do
        field :step_name, :string, required: true
        field :success, :boolean, required: true
        field :data, :any, required: true
        field :errors, {:array, :string}, default: []
        field :warnings, {:array, :string}, default: []
        field :metadata, :map, default: %{}
      end
    end

    defmodule PipelineResult do
      use Exdantic, define_struct: true

      schema "Complete pipeline result" do
        field :success, :boolean, required: true
        field :steps, {:array, StepResult}, required: true
        field :final_data, :any, optional: true
        field :total_errors, :integer, default: 0
        field :total_warnings, :integer, default: 0

        computed_field :step_count, :integer, :count_steps
        computed_field :success_rate, :float, :calculate_success_rate
      end

      def count_steps(input) do
        {:ok, length(input.steps)}
      end

      def calculate_success_rate(input) do
        if input.step_count == 0 do
          {:ok, 0.0}
        else
          successful_steps = Enum.count(input.steps, & &1.success)
          rate = successful_steps / input.step_count
          {:ok, rate}
        end
      end
    end

    def execute_pipeline(data, steps) do
      {final_success, step_results, final_data} = Enum.reduce(steps, {true, [], data}, fn step_config, {success_so_far, results, current_data} ->
        step_result = execute_step(step_config, current_data)
        new_success = success_so_far and step_result["success"]
        new_data = if step_result["success"], do: step_result["data"], else: current_data

        {new_success, results ++ [step_result], new_data}
      end)

      total_errors = Enum.sum(Enum.map(step_results, &length(&1["errors"])))
      total_warnings = Enum.sum(Enum.map(step_results, &length(&1["warnings"])))

      pipeline_result = %{
        "success" => final_success,
        "steps" => step_results,
        "final_data" => if(final_success, do: final_data, else: nil),
        "total_errors" => total_errors,
        "total_warnings" => total_warnings
      }

      PipelineResult.validate(pipeline_result)
    end

    defp execute_step({step_name, validator_fn}, data) do
      case validator_fn.(data) do
        {:ok, validated_data} ->
          %{
            "step_name" => step_name,
            "success" => true,
            "data" => validated_data,
            "errors" => [],
            "warnings" => [],
            "metadata" => %{"execution_time" => :os.system_time(:millisecond)}
          }
        {:error, errors} when is_list(errors) ->
          %{
            "step_name" => step_name,
            "success" => false,
            "data" => data,
            "errors" => Enum.map(errors, &to_string/1),
            "warnings" => [],
            "metadata" => %{"execution_time" => :os.system_time(:millisecond)}
          }
        {:error, error} ->
          %{
            "step_name" => step_name,
            "success" => false,
            "data" => data,
            "errors" => [to_string(error)],
            "warnings" => [],
            "metadata" => %{"execution_time" => :os.system_time(:millisecond)}
          }
      end
    end
  end

  def run do
    IO.puts("=== Conditional and Recursive Validation Examples ===\n")

    # Example 1: Conditional Validation
    conditional_validation()

    # Example 2: Recursive Tree Validation
    recursive_tree_validation()

    # Example 3: Dynamic Schema Selection
    dynamic_schema_selection()

    # Example 4: Cross-Schema Validation
    cross_schema_validation()

    # Example 5: Multi-Step Validation Pipeline
    multi_step_pipeline()

    IO.puts("\n=== Conditional and Recursive Validation Examples Complete ===")
  end

  defp conditional_validation do
    IO.puts("1. Conditional Validation Based on User Type")
    IO.puts("--------------------------------------------")

    # Test individual user
    individual_data = %{
      "user_type" => "individual",
      "first_name" => "John",
      "last_name" => "Doe",
      "email" => "john@example.com"
    }

    IO.puts("Individual user validation:")
    case ConditionalUserSchema.validate(individual_data) do
      {:ok, user} ->
        IO.puts("  ✅ Individual user validated successfully")
        IO.puts("     Name: #{user.first_name} #{user.last_name}")
      {:error, errors} ->
        IO.puts("  ❌ Individual user validation failed:")
        Enum.each(errors, &IO.puts("     #{Exdantic.Error.format(&1)}"))
    end

    # Test business user
    business_data = %{
      "user_type" => "business",
      "business_name" => "Acme Corp",
      "tax_id" => "12-3456789",
      "email" => "contact@acme.com"
    }

    IO.puts("\nBusiness user validation:")
    case ConditionalUserSchema.validate(business_data) do
      {:ok, user} ->
        IO.puts("  ✅ Business user validated successfully")
        IO.puts("     Business: #{user.business_name}")
      {:error, errors} ->
        IO.puts("  ❌ Business user validation failed:")
        Enum.each(errors, &IO.puts("     #{Exdantic.Error.format(&1)}"))
    end

    # Test invalid business user (missing required fields)
    invalid_business_data = %{
      "user_type" => "business",
      "email" => "contact@incomplete.com"
      # Missing business_name and tax_id
    }

    IO.puts("\nInvalid business user validation:")
    case ConditionalUserSchema.validate(invalid_business_data) do
      {:ok, user} ->
        IO.puts("  ✅ Unexpected success: #{inspect(user)}")
      {:error, errors} ->
        IO.puts("  ❌ Business user validation failed as expected:")
        Enum.each(errors, &IO.puts("     #{Exdantic.Error.format(&1)}"))
    end

    IO.puts("")
  end

  defp recursive_tree_validation do
    IO.puts("2. Recursive Tree Structure Validation")
    IO.puts("---------------------------------------")

    # Create a valid tree structure
    tree_data = %{
      "id" => "root",
      "value" => "Root Node",
      "node_type" => "branch",
      "children" => [
        %{
          "id" => "child1",
          "value" => "Child 1",
          "node_type" => "branch",
          "children" => [
            %{
              "id" => "grandchild1",
              "value" => "Grandchild 1",
              "node_type" => "leaf",
              "children" => []
            },
            %{
              "id" => "grandchild2",
              "value" => "Grandchild 2",
              "node_type" => "leaf",
              "children" => []
            }
          ]
        },
        %{
          "id" => "child2",
          "value" => "Child 2",
          "node_type" => "leaf",
          "children" => []
        }
      ]
    }

    IO.puts("Valid tree structure validation:")
    case TreeNodeSchema.validate(tree_data) do
      {:ok, tree} ->
        IO.puts("  ✅ Tree validated successfully")
        IO.puts("     Root ID: #{tree.id}")
        IO.puts("     Depth: #{tree.depth}")
        IO.puts("     Total nodes: #{tree.node_count}")
        IO.puts("     Valid tree: #{tree.is_valid_tree}")
      {:error, errors} ->
        IO.puts("  ❌ Tree validation failed:")
        Enum.each(errors, &IO.puts("     #{Exdantic.Error.format(&1)}"))
    end

    # Test invalid tree (leaf with children)
    invalid_tree_data = %{
      "id" => "invalid",
      "value" => "Invalid Node",
      "node_type" => "leaf",
      "children" => [
        %{
          "id" => "should_not_exist",
          "value" => "Should not exist",
          "node_type" => "leaf",
          "children" => []
        }
      ]
    }

    IO.puts("\nInvalid tree structure validation (leaf with children):")
    case TreeNodeSchema.validate(invalid_tree_data) do
      {:ok, tree} ->
        IO.puts("  ✅ Unexpected success: #{inspect(tree)}")
      {:error, errors} ->
        IO.puts("  ❌ Tree validation failed as expected:")
        Enum.each(errors, &IO.puts("     #{Exdantic.Error.format(&1)}"))
    end

    IO.puts("")
  end

  defp dynamic_schema_selection do
    IO.puts("3. Dynamic Schema Selection")
    IO.puts("---------------------------")

    # Test article validation
    article_data = %{
      "title" => "Introduction to Elixir",
      "content" => "Elixir is a dynamic, functional language designed for building maintainable and scalable applications. It leverages the Erlang Virtual Machine (BEAM) to provide fault-tolerant systems.",
      "author" => "Jane Smith",
      "tags" => ["elixir", "programming", "functional"]
    }

    IO.puts("Article validation:")
    case DynamicValidation.validate_by_type(article_data, "article") do
      {:ok, article} ->
        IO.puts("  ✅ Article validated successfully")
        IO.puts("     Title: #{article.title}")
        IO.puts("     Author: #{article.author}")
      {:error, errors} ->
        IO.puts("  ❌ Article validation failed:")
        Enum.each(errors, &IO.puts("     #{inspect(&1)}"))
    end

    # Test auto-detection
    IO.puts("\nAuto-detection validation:")
    case DynamicValidation.auto_detect_and_validate(article_data) do
      {:ok, {detected_type, validated_data}} ->
        IO.puts("  ✅ Auto-detected as '#{detected_type}' and validated successfully")
        IO.puts("     Title: #{validated_data.title}")
      {:error, reason} ->
        IO.puts("  ❌ Auto-detection failed: #{reason}")
    end

    # Test fallback validation
    IO.puts("\nFallback validation (try report, fallback to article):")
    case DynamicValidation.validate_with_fallback(article_data, "report", "article") do
      {:ok, {used_type, validated_data}} ->
        IO.puts("  ✅ Validated using '#{used_type}' schema")
        IO.puts("     Title: #{validated_data.title}")
      {:error, reason} ->
        IO.puts("  ❌ Fallback validation failed: #{reason}")
    end

    IO.puts("")
  end

  defp cross_schema_validation do
    IO.puts("4. Cross-Schema Validation")
    IO.puts("--------------------------")

    user_data = %{
      "id" => "user123",
      "email" => "john@example.com",
      "role" => "user",
      "active" => true,
      "credit_limit" => 2000.0
    }

    order_data = %{
      "id" => "order456",
      "user_id" => "user123",
      "items" => [
        %{"product" => "Widget A", "price" => 100.0, "quantity" => 2},
        %{"product" => "Widget B", "price" => 50.0, "quantity" => 1}
      ],
      "total_amount" => 250.0,
      "status" => "pending"
    }

    IO.puts("Valid cross-schema validation:")
    case CrossSchemaValidation.validate_order_with_user(order_data, user_data) do
      {:ok, {user, order}} ->
        IO.puts("  ✅ Order and user validated successfully")
        IO.puts("     User: #{user.email}")
        IO.puts("     Order: #{order.id} (#{order.total_amount})")
      {:error, reason} ->
        IO.puts("  ❌ Cross-schema validation failed: #{reason}")
    end

    # Test with order exceeding credit limit
    expensive_order_data = Map.put(order_data, "total_amount", 3000.0)

    IO.puts("\nOrder exceeding credit limit:")
    case CrossSchemaValidation.validate_order_with_user(expensive_order_data, user_data) do
      {:ok, {user, order}} ->
        IO.puts("  ✅ Unexpected success: #{user.email}, #{order.total_amount}")
      {:error, reason} ->
        IO.puts("  ❌ Cross-schema validation failed as expected: #{reason}")
    end

    IO.puts("")
  end

  defp multi_step_pipeline do
    IO.puts("5. Multi-Step Validation Pipeline")
    IO.puts("----------------------------------")

    # Define validation steps
    steps = [
      {"format_validation", fn data ->
        if is_map(data) and Map.has_key?(data, "email") do
          {:ok, data}
        else
          {:error, "Data must be a map with email field"}
        end
      end},
      {"email_format", fn data ->
        email = Map.get(data, "email", "")
        if String.contains?(email, "@") do
          {:ok, data}
        else
          {:error, "Invalid email format"}
        end
      end},
      {"normalize_email", fn data ->
        normalized_email = String.downcase(Map.get(data, "email", ""))
        {:ok, Map.put(data, "email", normalized_email)}
      end},
      {"domain_check", fn data ->
        email = Map.get(data, "email", "")
        if String.ends_with?(email, ".com") or String.ends_with?(email, ".org") do
          {:ok, data}
        else
          {:error, "Email domain not allowed"}
        end
      end}
    ]

    test_data = %{
      "email" => "John@Example.COM",
      "name" => "John Doe"
    }

    IO.puts("Multi-step pipeline validation:")
    case ValidationPipeline.execute_pipeline(test_data, steps) do
      {:ok, result} ->
        IO.puts("  ✅ Pipeline completed successfully")
        IO.puts("     Success rate: #{Float.round(result.success_rate * 100, 1)}%")
        IO.puts("     Steps: #{result.step_count}")
        IO.puts("     Errors: #{result.total_errors}")
        IO.puts("     Final email: #{get_in(result.final_data, ["email"])}")
      {:error, errors} ->
        IO.puts("  ❌ Pipeline validation failed:")
        Enum.each(errors, &IO.puts("     #{inspect(&1)}"))
    end

    # Test with invalid data
    invalid_data = %{
      "email" => "invalid-email",
      "name" => "John Doe"
    }

    IO.puts("\nPipeline with invalid data:")
    case ValidationPipeline.execute_pipeline(invalid_data, steps) do
      {:ok, result} ->
        IO.puts("  ⚠️  Pipeline completed with errors")
        IO.puts("     Success rate: #{Float.round(result.success_rate * 100, 1)}%")
        IO.puts("     Steps: #{result.step_count}")
        IO.puts("     Errors: #{result.total_errors}")
        IO.puts("     Failed at step: #{Enum.find(result.steps, &(not &1.success)).step_name}")
      {:error, errors} ->
        IO.puts("  ❌ Pipeline validation failed:")
        Enum.each(errors, &IO.puts("     #{inspect(&1)}"))
    end

    IO.puts("")
  end
end

# Run the examples
ConditionalRecursiveValidationExamples.run()
