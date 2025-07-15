# Production Error Handling Guide

This guide covers production-ready error handling patterns for Exdantic applications, including API development, logging, monitoring, and error recovery strategies.

## Table of Contents

- [Error Structure Overview](#error-structure-overview)
- [API Error Response Patterns](#api-error-response-patterns)
- [Bulk Operation Error Handling](#bulk-operation-error-handling)
- [Error Recovery Strategies](#error-recovery-strategies)
- [Logging and Monitoring](#logging-and-monitoring)
- [Configuration-Based Error Handling](#configuration-based-error-handling)
- [Testing Error Scenarios](#testing-error-scenarios)
- [Performance Considerations](#performance-considerations)

## Error Structure Overview

Exdantic provides structured error information designed for production use:

```elixir
%Exdantic.Error{
  path: [:user, :address, :zip_code],  # Exact location of error
  code: :format,                       # Machine-readable error type
  message: "invalid zip code format"   # Human-readable message
}
```

### Error Codes Reference

| Code | Description | Common Causes |
|------|-------------|---------------|
| `:type` | Type mismatch | String provided where integer expected |
| `:required` | Missing required field | Field not provided in input |
| `:format` | Invalid format | Regex validation failure |
| `:min_length` | String too short | Below minimum length constraint |
| `:max_length` | String too long | Above maximum length constraint |
| `:gt`, `:lt`, `:gteq`, `:lteq` | Numeric constraints | Number outside valid range |
| `:choices` | Invalid choice | Value not in allowed choices list |
| `:additional_properties` | Extra fields in strict mode | Unknown fields provided |
| `:model_validation` | Model validator failure | Cross-field validation failed |
| `:computed_field` | Computed field error | Error during field computation |

## API Error Response Patterns

### Phoenix/Plug Web Applications

```elixir
defmodule MyAppWeb.UserController do
  use MyAppWeb, :controller
  
  def create(conn, params) do
    case UserSchema.validate(params) do
      {:ok, user} ->
        # Success path
        case UserService.create_user(user) do
          {:ok, created_user} ->
            conn
            |> put_status(:created)
            |> json(%{data: created_user})
            
          {:error, changeset} ->
            conn
            |> put_status(:unprocessable_entity)
            |> json(%{errors: format_changeset_errors(changeset)})
        end
        
      {:error, validation_errors} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{
          errors: format_validation_errors(validation_errors),
          message: "Validation failed"
        })
    end
  end
  
  # Format Exdantic errors for API consumption
  defp format_validation_errors(errors) when is_list(errors) do
    Enum.map(errors, &format_single_error/1)
  end
  
  defp format_validation_errors(error) do
    [format_single_error(error)]
  end
  
  defp format_single_error(%Exdantic.Error{} = error) do
    %{
      field: format_field_path(error.path),
      code: error.code,
      message: error.message,
      path: error.path
    }
  end
  
  defp format_field_path([]), do: nil
  defp format_field_path(path), do: Enum.join(path, ".")
end
```

### JSON API Specification Compliance

```elixir
defmodule MyApp.ErrorFormatter do
  @moduledoc """
  Formats Exdantic validation errors according to JSON API error specification.
  """
  
  def format_for_json_api(validation_errors) when is_list(validation_errors) do
    %{
      errors: Enum.map(validation_errors, &to_json_api_error/1)
    }
  end
  
  def format_for_json_api(validation_error) do
    %{
      errors: [to_json_api_error(validation_error)]
    }
  end
  
  defp to_json_api_error(%Exdantic.Error{} = error) do
    %{
      id: generate_error_id(),
      status: determine_http_status(error.code),
      code: error.code,
      title: format_error_title(error.code),
      detail: error.message,
      source: %{
        pointer: format_json_pointer(error.path)
      },
      meta: %{
        timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
      }
    }
  end
  
  defp format_json_pointer([]), do: "/"
  defp format_json_pointer(path) do
    "/" <> Enum.join(path, "/")
  end
  
  defp determine_http_status(:required), do: "422"
  defp determine_http_status(:type), do: "422"
  defp determine_http_status(:format), do: "422"
  defp determine_http_status(:additional_properties), do: "422"
  defp determine_http_status(_), do: "422"
  
  defp format_error_title(:required), do: "Missing required field"
  defp format_error_title(:type), do: "Invalid data type"
  defp format_error_title(:format), do: "Invalid format"
  defp format_error_title(:additional_properties), do: "Unknown field"
  defp format_error_title(_), do: "Validation error"
  
  defp generate_error_id do
    :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)
  end
end
```

### REST API Error Responses

```elixir
defmodule MyApp.APIErrorHandler do
  @moduledoc """
  Standardized error responses for REST APIs.
  """
  
  def handle_validation_error(conn, validation_errors) do
    error_response = %{
      success: false,
      error: %{
        type: "validation_error",
        message: "Request validation failed",
        details: format_validation_details(validation_errors),
        timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
        request_id: get_request_id(conn)
      }
    }
    
    conn
    |> put_status(:unprocessable_entity)
    |> json(error_response)
  end
  
  defp format_validation_details(errors) when is_list(errors) do
    errors
    |> Enum.group_by(& &1.path)
    |> Enum.map(fn {path, field_errors} ->
      %{
        field: format_field_path(path),
        errors: Enum.map(field_errors, & &1.message)
      }
    end)
  end
  
  defp get_request_id(conn) do
    case get_req_header(conn, "x-request-id") do
      [request_id] -> request_id
      _ -> generate_request_id()
    end
  end
  
  defp generate_request_id do
    System.unique_integer([:positive]) |> to_string()
  end
end
```

## Bulk Operation Error Handling

### Batch Validation with Partial Success

```elixir
defmodule MyApp.BulkProcessor do
  @moduledoc """
  Handles bulk operations with detailed error reporting.
  """
  
  def process_batch(items, schema_module) do
    {successes, failures} = 
      items
      |> Enum.with_index()
      |> Enum.reduce({[], []}, fn {item, index}, {successes, failures} ->
        case schema_module.validate(item) do
          {:ok, validated_item} ->
            success = %{
              index: index,
              data: validated_item,
              original: item
            }
            {[success | successes], failures}
            
          {:error, errors} ->
            failure = %{
              index: index,
              errors: errors,
              original: item,
              error_summary: summarize_errors(errors)
            }
            {successes, [failure | failures]}
        end
      end)
    
    %{
      total_count: length(items),
      success_count: length(successes),
      failure_count: length(failures),
      successes: Enum.reverse(successes),
      failures: Enum.reverse(failures),
      success_rate: calculate_success_rate(successes, items)
    }
  end
  
  def process_batch_with_recovery(items, primary_schema, fallback_schema) do
    results = 
      items
      |> Enum.with_index()
      |> Enum.map(fn {item, index} ->
        case primary_schema.validate(item) do
          {:ok, validated_item} ->
            {:success, index, validated_item, :primary}
            
          {:error, primary_errors} ->
            case fallback_schema.validate(item) do
              {:ok, validated_item} ->
                {:success, index, validated_item, :fallback}
                
              {:error, fallback_errors} ->
                {:failure, index, item, %{
                  primary_errors: primary_errors,
                  fallback_errors: fallback_errors
                }}
            end
        end
      end)
    
    summarize_batch_results(results)
  end
  
  defp summarize_errors(errors) when is_list(errors) do
    error_counts = 
      errors
      |> Enum.group_by(& &1.code)
      |> Enum.map(fn {code, errors} -> {code, length(errors)} end)
      |> Enum.into(%{})
    
    %{
      total_errors: length(errors),
      error_types: Map.keys(error_counts),
      error_counts: error_counts,
      most_common_error: find_most_common_error(error_counts)
    }
  end
  
  defp calculate_success_rate(successes, items) do
    if length(items) > 0 do
      Float.round(length(successes) / length(items) * 100, 2)
    else
      0.0
    end
  end
end
```

### Streaming Validation for Large Datasets

```elixir
defmodule MyApp.StreamValidator do
  @moduledoc """
  Memory-efficient validation for large datasets using streams.
  """
  
  def validate_stream(data_stream, schema_module, opts \\ []) do
    chunk_size = Keyword.get(opts, :chunk_size, 1000)
    max_errors = Keyword.get(opts, :max_errors, :infinity)
    
    data_stream
    |> Stream.with_index()
    |> Stream.chunk_every(chunk_size)
    |> Stream.transform(
      %{errors: [], error_count: 0}, 
      &process_chunk(&1, &2, schema_module, max_errors)
    )
  end
  
  defp process_chunk(chunk, acc, schema_module, max_errors) do
    if acc.error_count >= max_errors do
      {:halt, acc}
    else
      chunk_results = 
        chunk
        |> Enum.map(fn {item, index} ->
          case schema_module.validate(item) do
            {:ok, validated} -> {:ok, index, validated}
            {:error, errors} -> {:error, index, errors}
          end
        end)
      
      {successes, new_errors} = 
        Enum.split_with(chunk_results, fn
          {:ok, _, _} -> true
          _ -> false
        end)
      
      updated_acc = %{
        errors: acc.errors ++ new_errors,
        error_count: acc.error_count + length(new_errors)
      }
      
      success_data = Enum.map(successes, fn {:ok, _index, data} -> data end)
      
      {[success_data], updated_acc}
    end
  end
end
```

## Error Recovery Strategies

### Graceful Degradation

```elixir
defmodule MyApp.FallbackValidator do
  @moduledoc """
  Implements fallback validation strategies for robust error handling.
  """
  
  def validate_with_fallback(data, primary_schema, fallback_configs \\ []) do
    case primary_schema.validate(data) do
      {:ok, result} -> 
        {:ok, result, :primary}
        
      {:error, primary_errors} ->
        attempt_fallbacks(data, fallback_configs, primary_errors)
    end
  end
  
  defp attempt_fallbacks(data, [], primary_errors) do
    {:error, %{
      strategy: :no_fallback_succeeded,
      primary_errors: primary_errors,
      attempted_fallbacks: 0
    }}
  end
  
  defp attempt_fallbacks(data, [config | rest], primary_errors) do
    case apply_fallback_config(data, config) do
      {:ok, result} ->
        {:ok, result, {:fallback, config.name}}
        
      {:error, fallback_errors} ->
        updated_primary = %{
          primary_errors: primary_errors,
          failed_fallbacks: [%{
            name: config.name,
            errors: fallback_errors
          }]
        }
        attempt_fallbacks(data, rest, updated_primary)
    end
  end
  
  defp apply_fallback_config(data, %{schema: schema, transform: transform}) do
    transformed_data = transform.(data)
    schema.validate(transformed_data)
  end
  
  defp apply_fallback_config(data, %{schema: schema}) do
    schema.validate(data)
  end
end

# Usage example
fallback_configs = [
  %{
    name: :lenient_validation,
    schema: LenientUserSchema,
    transform: &remove_unknown_fields/1
  },
  %{
    name: :minimal_validation,
    schema: MinimalUserSchema
  }
]

case MyApp.FallbackValidator.validate_with_fallback(
  user_data, 
  StrictUserSchema, 
  fallback_configs
) do
  {:ok, user, :primary} -> 
    # Validated with strict schema
  {:ok, user, {:fallback, :lenient_validation}} -> 
    # Used lenient fallback
  {:error, details} -> 
    # All validation attempts failed
end
```

### Error Correction and Retry

```elixir
defmodule MyApp.ErrorCorrection do
  @moduledoc """
  Attempts automatic error correction for common validation failures.
  """
  
  def validate_with_correction(data, schema, correction_rules \\ []) do
    case schema.validate(data) do
      {:ok, result} -> 
        {:ok, result, []}
        
      {:error, errors} ->
        attempt_corrections(data, schema, errors, correction_rules)
    end
  end
  
  defp attempt_corrections(data, schema, errors, rules) do
    corrections = 
      errors
      |> Enum.flat_map(&find_applicable_corrections(&1, rules))
      |> Enum.reduce(data, &apply_correction/2)
    
    case schema.validate(corrections) do
      {:ok, result} -> 
        applied_corrections = find_applied_corrections(data, corrections)
        {:ok, result, applied_corrections}
        
      {:error, remaining_errors} ->
        {:error, %{
          original_errors: errors,
          remaining_errors: remaining_errors,
          attempted_corrections: find_applied_corrections(data, corrections)
        }}
    end
  end
  
  defp find_applicable_corrections(error, rules) do
    Enum.filter(rules, fn rule ->
      rule.applies_to_error?(error)
    end)
  end
  
  defp apply_correction(correction_rule, data) do
    correction_rule.apply(data)
  end
end

# Example correction rules
string_trimming_rule = %{
  applies_to_error?: fn error -> 
    error.code in [:min_length, :max_length, :format] and 
    is_binary(get_in(data, error.path))
  end,
  apply: fn data, error ->
    update_in(data, error.path, &String.trim/1)
  end
}

type_coercion_rule = %{
  applies_to_error?: fn error -> 
    error.code == :type
  end,
  apply: fn data, error ->
    attempt_type_coercion(data, error)
  end
}
```

## Logging and Monitoring

### Structured Logging

```elixir
defmodule MyApp.ValidationLogger do
  require Logger
  
  @moduledoc """
  Structured logging for validation events and errors.
  """
  
  def log_validation_success(schema, data, result, duration_ms) do
    Logger.info("Validation succeeded", %{
      event: "validation_success",
      schema: schema_name(schema),
      duration_ms: duration_ms,
      data_size: estimate_data_size(data),
      result_size: estimate_data_size(result),
      timestamp: DateTime.utc_now()
    })
  end
  
  def log_validation_failure(schema, data, errors, duration_ms) do
    error_summary = analyze_errors(errors)
    
    Logger.warning("Validation failed", %{
      event: "validation_failure",
      schema: schema_name(schema),
      duration_ms: duration_ms,
      data_size: estimate_data_size(data),
      error_count: length(errors),
      error_summary: error_summary,
      errors: format_errors_for_logging(errors),
      timestamp: DateTime.utc_now()
    })
  end
  
  def log_batch_validation(results) do
    Logger.info("Batch validation completed", %{
      event: "batch_validation_completed",
      total_items: results.total_count,
      success_count: results.success_count,
      failure_count: results.failure_count,
      success_rate: results.success_rate,
      timestamp: DateTime.utc_now()
    })
  end
  
  defp analyze_errors(errors) when is_list(errors) do
    error_codes = Enum.map(errors, & &1.code)
    
    %{
      total_errors: length(errors),
      unique_error_codes: Enum.uniq(error_codes),
      error_distribution: Enum.frequencies(error_codes),
      most_common_error: Enum.max_by(Enum.frequencies(error_codes), &elem(&1, 1))
    }
  end
  
  defp format_errors_for_logging(errors) when length(errors) <= 10 do
    Enum.map(errors, fn error ->
      %{
        path: error.path,
        code: error.code,
        message: error.message
      }
    end)
  end
  
  defp format_errors_for_logging(errors) do
    # Truncate for large error lists
    sample = Enum.take(errors, 5)
    %{
      sample_errors: format_errors_for_logging(sample),
      total_errors: length(errors),
      truncated: true
    }
  end
end
```

### Metrics and Telemetry

```elixir
defmodule MyApp.ValidationTelemetry do
  @moduledoc """
  Telemetry events for validation monitoring and metrics.
  """
  
  def emit_validation_event(event_name, measurements, metadata \\ %{}) do
    :telemetry.execute(
      [:myapp, :validation, event_name],
      measurements,
      metadata
    )
  end
  
  def measure_validation(schema, data, fun) do
    start_time = System.monotonic_time(:millisecond)
    
    result = fun.()
    
    end_time = System.monotonic_time(:millisecond)
    duration_ms = end_time - start_time
    
    measurements = %{
      duration_ms: duration_ms,
      data_size_bytes: estimate_data_size(data)
    }
    
    metadata = %{
      schema: schema_name(schema),
      success: match?({:ok, _}, result)
    }
    
    case result do
      {:ok, validated} ->
        emit_validation_event(:success, measurements, metadata)
        
      {:error, errors} ->
        error_metadata = Map.merge(metadata, %{
          error_count: length(errors),
          error_codes: Enum.map(errors, & &1.code)
        })
        emit_validation_event(:failure, measurements, error_metadata)
    end
    
    result
  end
end

# Telemetry handler setup
:telemetry.attach_many(
  "validation-metrics",
  [
    [:myapp, :validation, :success],
    [:myapp, :validation, :failure]
  ],
  &MyApp.ValidationMetrics.handle_event/4,
  nil
)

defmodule MyApp.ValidationMetrics do
  def handle_event([:myapp, :validation, :success], measurements, metadata, _config) do
    :prometheus_counter.inc(:validation_success_total, [metadata.schema])
    :prometheus_histogram.observe(:validation_duration_ms, [metadata.schema], measurements.duration_ms)
  end
  
  def handle_event([:myapp, :validation, :failure], measurements, metadata, _config) do
    :prometheus_counter.inc(:validation_failure_total, [metadata.schema])
    :prometheus_histogram.observe(:validation_duration_ms, [metadata.schema], measurements.duration_ms)
    
    for error_code <- metadata.error_codes do
      :prometheus_counter.inc(:validation_error_total, [metadata.schema, error_code])
    end
  end
end
```

## Configuration-Based Error Handling

### Environment-Specific Error Handling

```elixir
defmodule MyApp.ValidationConfig do
  @moduledoc """
  Environment-specific validation configuration and error handling.
  """
  
  def get_validation_config(env \\ Application.get_env(:myapp, :env)) do
    case env do
      :prod -> production_config()
      :staging -> staging_config()
      :dev -> development_config()
      :test -> test_config()
    end
  end
  
  defp production_config do
    %{
      validation: Exdantic.Config.create(
        strict: true,
        extra: :forbid,
        coercion: :safe,
        error_format: :simple
      ),
      error_handling: %{
        log_level: :warning,
        include_sensitive_data: false,
        max_error_details: 5,
        enable_telemetry: true
      }
    }
  end
  
  defp development_config do
    %{
      validation: Exdantic.Config.create(
        strict: false,
        extra: :allow,
        coercion: :aggressive,
        error_format: :detailed
      ),
      error_handling: %{
        log_level: :info,
        include_sensitive_data: true,
        max_error_details: :unlimited,
        enable_telemetry: false
      }
    }
  end
  
  defp staging_config do
    production_config()
    |> put_in([:error_handling, :log_level], :info)
    |> put_in([:error_handling, :include_sensitive_data], true)
  end
  
  defp test_config do
    %{
      validation: Exdantic.Config.create(
        strict: true,
        extra: :forbid,
        coercion: :none,
        error_format: :detailed
      ),
      error_handling: %{
        log_level: :debug,
        include_sensitive_data: true,
        max_error_details: :unlimited,
        enable_telemetry: false
      }
    }
  end
end
```

### Circuit Breaker Pattern

```elixir
defmodule MyApp.ValidationCircuitBreaker do
  use GenServer
  
  @moduledoc """
  Circuit breaker pattern for validation to prevent cascading failures.
  """
  
  defstruct [
    :name,
    :schema,
    state: :closed,
    failure_count: 0,
    failure_threshold: 10,
    reset_timeout: 60_000,
    last_failure_time: nil
  ]
  
  def start_link(opts) do
    name = Keyword.fetch!(opts, :name)
    GenServer.start_link(__MODULE__, opts, name: name)
  end
  
  def validate(circuit_breaker, data) do
    GenServer.call(circuit_breaker, {:validate, data})
  end
  
  def init(opts) do
    state = %__MODULE__{
      name: Keyword.fetch!(opts, :name),
      schema: Keyword.fetch!(opts, :schema),
      failure_threshold: Keyword.get(opts, :failure_threshold, 10),
      reset_timeout: Keyword.get(opts, :reset_timeout, 60_000)
    }
    
    {:ok, state}
  end
  
  def handle_call({:validate, data}, _from, %{state: :open} = state) do
    if should_attempt_reset?(state) do
      attempt_validation(data, %{state | state: :half_open})
    else
      {:reply, {:error, :circuit_breaker_open}, state}
    end
  end
  
  def handle_call({:validate, data}, _from, state) do
    attempt_validation(data, state)
  end
  
  defp attempt_validation(data, state) do
    case state.schema.validate(data) do
      {:ok, result} ->
        new_state = %{state | state: :closed, failure_count: 0}
        {:reply, {:ok, result}, new_state}
        
      {:error, errors} ->
        new_failure_count = state.failure_count + 1
        
        new_state = %{
          state | 
          failure_count: new_failure_count,
          last_failure_time: System.monotonic_time(:millisecond)
        }
        
        if new_failure_count >= state.failure_threshold do
          new_state = %{new_state | state: :open}
          {:reply, {:error, :circuit_breaker_tripped}, new_state}
        else
          {:reply, {:error, errors}, new_state}
        end
    end
  end
  
  defp should_attempt_reset?(%{last_failure_time: nil}), do: false
  defp should_attempt_reset?(state) do
    current_time = System.monotonic_time(:millisecond)
    current_time - state.last_failure_time >= state.reset_timeout
  end
end
```

## Testing Error Scenarios

### Comprehensive Error Testing

```elixir
defmodule MyApp.ValidationErrorTest do
  use ExUnit.Case
  
  describe "error handling patterns" do
    test "handles missing required fields gracefully" do
      incomplete_data = %{name: "John"}  # Missing email
      
      assert {:error, errors} = UserSchema.validate(incomplete_data)
      assert length(errors) == 1
      
      error = List.first(errors)
      assert error.code == :required
      assert error.path == [:email]
      assert String.contains?(error.message, "required")
    end
    
    test "provides detailed path information for nested errors" do
      invalid_nested = %{
        name: "John",
        email: "john@example.com",
        address: %{
          street: "123 Main St",
          zip_code: "invalid"  # Should be integer
        }
      }
      
      assert {:error, errors} = UserSchema.validate(invalid_nested)
      
      error = Enum.find(errors, &(&1.path == [:address, :zip_code]))
      assert error.code == :type
      assert error.message =~ "expected integer"
    end
    
    test "batches multiple errors for single validation" do
      invalid_data = %{
        name: "",              # Too short
        email: "invalid",      # Invalid format
        age: -5,              # Below minimum
        extra_field: "value"   # Not allowed in strict mode
      }
      
      config = Exdantic.Config.create(strict: true)
      assert {:error, errors} = UserSchema.validate(invalid_data, config: config)
      
      assert length(errors) >= 3
      error_codes = Enum.map(errors, & &1.code)
      assert :min_length in error_codes
      assert :format in error_codes
      assert :gt in error_codes
    end
  end
  
  describe "error formatting for different contexts" do
    test "formats errors for JSON API responses" do
      errors = [
        %Exdantic.Error{path: [:email], code: :format, message: "Invalid email format"},
        %Exdantic.Error{path: [:age], code: :gt, message: "Must be greater than 0"}
      ]
      
      formatted = MyApp.ErrorFormatter.format_for_json_api(errors)
      
      assert %{errors: json_api_errors} = formatted
      assert length(json_api_errors) == 2
      
      email_error = Enum.find(json_api_errors, &(&1.source.pointer == "/email"))
      assert email_error.code == :format
      assert email_error.status == "422"
    end
    
    test "formats errors for human consumption" do
      errors = [
        %Exdantic.Error{path: [:user, :email], code: :format, message: "Invalid email"},
        %Exdantic.Error{path: [], code: :type, message: "Expected object"}
      ]
      
      formatted = Enum.map(errors, &Exdantic.Error.format/1)
      
      assert "user.email: Invalid email" in formatted
      assert "Expected object" in formatted
    end
  end
  
  describe "error recovery mechanisms" do
    test "successfully falls back to lenient schema" do
      strict_data = %{
        name: "John",
        email: "john@example.com",
        unexpected_field: "value"
      }
      
      # Should fail with strict schema
      assert {:error, _} = StrictUserSchema.validate(strict_data)
      
      # Should succeed with fallback
      assert {:ok, result, :fallback} = 
        MyApp.FallbackValidator.validate_with_fallback(
          strict_data,
          StrictUserSchema,
          [%{name: :lenient, schema: LenientUserSchema}]
        )
      
      assert result.name == "John"
      assert result.email == "john@example.com"
    end
  end
end
```

### Property-Based Error Testing

```elixir
defmodule MyApp.ValidationPropertyTest do
  use ExUnit.Case
  use ExUnitProperties
  
  describe "validation error properties" do
    property "all validation errors have required fields" do
      check all schema_module <- member_of([UserSchema, ProductSchema, OrderSchema]),
                invalid_data <- invalid_data_generator(schema_module) do
        
        case schema_module.validate(invalid_data) do
          {:error, errors} when is_list(errors) ->
            for error <- errors do
              assert %Exdantic.Error{} = error
              assert is_list(error.path)
              assert is_atom(error.code)
              assert is_binary(error.message)
              assert error.message != ""
            end
            
          {:error, error} ->
            assert %Exdantic.Error{} = error
            
          {:ok, _result} ->
            # This shouldn't happen with invalid data, but not an error
            :ok
        end
      end
    end
    
    property "error paths are always valid" do
      check all schema_module <- member_of([UserSchema, ProductSchema]),
                invalid_data <- invalid_data_generator(schema_module) do
        
        case schema_module.validate(invalid_data) do
          {:error, errors} when is_list(errors) ->
            for error <- errors do
              # Path should be a list of atoms or strings
              assert Enum.all?(error.path, fn segment ->
                is_atom(segment) or is_binary(segment) or is_integer(segment)
              end)
            end
            
          _ -> :ok
        end
      end
    end
  end
end
```

## Performance Considerations

### Error Handling Performance

```elixir
defmodule MyApp.ValidationPerformance do
  @moduledoc """
  Performance optimization strategies for validation error handling.
  """
  
  def benchmark_error_scenarios do
    # Test different error volumes
    scenarios = [
      {:single_error, generate_single_error_data()},
      {:multiple_errors, generate_multiple_error_data()},
      {:deep_nested_errors, generate_nested_error_data()},
      {:large_batch_errors, generate_large_batch_data()}
    ]
    
    Enum.each(scenarios, fn {scenario_name, data} ->
      {time, _result} = :timer.tc(fn ->
        UserSchema.validate(data)
      end)
      
      IO.puts("#{scenario_name}: #{time}μs")
    end)
  end
  
  def optimize_error_collection(validation_errors) do
    # Limit error collection for performance
    max_errors = Application.get_env(:myapp, :max_validation_errors, 100)
    
    validation_errors
    |> Enum.take(max_errors)
    |> Enum.map(&optimize_single_error/1)
  end
  
  defp optimize_single_error(%Exdantic.Error{} = error) do
    # Truncate long error messages for performance
    max_message_length = 200
    
    optimized_message = 
      if String.length(error.message) > max_message_length do
        String.slice(error.message, 0, max_message_length) <> "..."
      else
        error.message
      end
    
    %{error | message: optimized_message}
  end
  
  def lazy_error_formatting(errors) do
    # Use streams for large error collections
    errors
    |> Stream.map(&Exdantic.Error.format/1)
    |> Stream.take(50)  # Limit for display
    |> Enum.to_list()
  end
end
```

### Memory-Efficient Error Handling

```elixir
defmodule MyApp.MemoryEfficientValidation do
  @moduledoc """
  Memory-efficient strategies for handling large validation operations.
  """
  
  def validate_large_dataset(data_stream, schema_module) do
    data_stream
    |> Stream.chunk_every(1000)
    |> Stream.map(fn chunk ->
      chunk
      |> Task.async_stream(
        &validate_with_memory_limit(&1, schema_module), 
        max_concurrency: System.schedulers_online(),
        timeout: 5000
      )
      |> Enum.map(fn {:ok, result} -> result end)
    end)
    |> Stream.concat()
  end
  
  defp validate_with_memory_limit(data, schema_module) do
    # Monitor memory usage during validation
    {result, memory_info} = :erlang.process_info(self(), :memory)
    
    validation_result = schema_module.validate(data)
    
    # Log memory usage if it exceeds threshold
    if memory_info > 50_000_000 do  # 50MB
      Logger.warning("High memory usage during validation", %{
        memory_bytes: memory_info,
        schema: schema_module
      })
    end
    
    validation_result
  end
end
```

---

## Summary

This guide provides production-ready error handling patterns for Exdantic applications. Key takeaways:

1. **Structure your error responses** consistently across your application
2. **Use appropriate logging levels** and structured logging for monitoring
3. **Implement fallback strategies** for graceful degradation
4. **Monitor validation performance** and optimize for your use case
5. **Test error scenarios** comprehensively, including edge cases
6. **Consider memory and performance** impacts in high-throughput scenarios

For more information on Exdantic's validation features, see the main [README](README.md) and [Advanced Features Guide](ADVANCED_FEATURES_GUIDE.md).