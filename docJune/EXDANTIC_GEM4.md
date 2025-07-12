# Exdantic: Advanced Types and Constraints

Exdantic includes a rich set of types and constraints tailored for Machine Learning and AI applications, ensuring data integrity for complex workflows.

## 1. ML-Specific Types

These types are provided out-of-the-box and have built-in validation logic.

*   **:embedding**: Validates that the value is a non-empty list of numbers.
    ```elixir
    field :document_embedding, :embedding
    ```

*   **:probability**: Validates that the value is a number between `0.0` and `1.0`.
    ```elixir
    field :confidence, :probability
    ```

*   **:model_response**: Validates that the value is a map containing at least a `:text` key with a string value. Useful for wrapping raw LLM outputs.
    ```elixir
    field :raw_llm_output, :model_response
    ```

*   **:confidence_score**: Validates that the value is a non-negative number.
    ```elixir
    field :relevance_score, :confidence_score
    ```

## 2. Variable Constraints

When declaring variables, specific constraints are used to define the optimization space.

*   `:choices`: (For `:choice` and `:module` types) A list of allowed values.
    ```elixir
    variable :model, type: :choice, choices: ["gpt-4o", "claude-3.5-sonnet"]
    ```
*   `:range`: (For `:range` type) A two-element tuple `{min, max}` defining a numerical range.
    ```elixir
    variable :top_p, type: :range, range: {0.1, 1.0}
    ```
*   `:behavior`: (For `:module` type) An Elixir behaviour that all module choices must implement. This provides strong compile-time guarantees about the module's interface.
    ```elixir
    variable :retriever, type: :module,
      choices: [DSPEx.Retrievers.BM25, DSPEx.Retrievers.Chroma],
      behavior: DSPEx.Retriever
    ```
*   `:embedding_dim`: Validates that an embedding has a specific dimension.
    ```elixir
    field :user_embedding, :embedding, constraints: [embedding_dim: 1536]
    ```

## 3. Creating Custom Types

Exdantic is fully extensible, allowing you to define your own types with custom validation logic. A custom type is simply a module that implements the `Exdantic.Type` behaviour.

**`Exdantic.Type` Behaviour:**

*   `@callback validate(value) :: {:ok, coerced_value} | {:error, reason}`

### Example: Custom `:email` Type

```elixir
defmodule MyApp.Types.Email do
  use Exdantic.Type

  @email_regex ~r/^[^\s@]+@[^\s@]+\.[^\s@]+$/

  @impl Exdantic.Type
  def validate(value) when is_binary(value) do
    if Regex.match?(@email_regex, value) do
      {:ok, String.downcase(value)} # Coerce to lowercase on success
    else
      {:error, "is not a valid email address"}
    end
  end

  def validate(_other) do
    {:error, "must be a string"}
  end
end
```

You can now use this custom type directly in your schemas:

```elixir
defmodule User do
  use Exdantic.Schema

  defschema do
    # Use the custom type module directly
    field :email_address, MyApp.Types.Email, required: true
  end
end

Exdantic.validate(User, %{email_address: "test@example.com"})
# => {:ok, %{email_address: "test@example.com"}}

Exdantic.validate(User, %{email_address: "invalid-email"})
# => {:error, [%Exdantic.Error{...}]}
```
