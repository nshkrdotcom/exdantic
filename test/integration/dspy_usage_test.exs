defmodule Exdantic.DSPyUsageTest do
  use ExUnit.Case, async: true
  alias Exdantic.{Types, Validator}

  describe "DSPy-style dynamic schema validation" do
    test "validates flexible LLM response formats with union types" do
      # DSPy often needs to handle various response formats from LLMs
      llm_response_type =
        Types.union([
          # Simple string response
          Types.string(),

          # Structured response
          Types.object(%{
            answer: Types.string(),
            confidence: Types.float() |> Types.with_constraints(gteq: 0.0, lteq: 1.0),
            reasoning: Types.string() |> Types.with_constraints(min_length: 10)
          }),

          # List of options
          Types.array(
            Types.object(%{
              option: Types.string(),
              score: Types.float()
            })
          )
        ])

      # Test various LLM response formats
      simple_response = "Paris is the capital of France"

      structured_response = %{
        answer: "Paris",
        confidence: 0.95,
        reasoning: "Paris is widely known as the capital city of France"
      }

      options_response = [
        %{option: "Paris", score: 0.9},
        %{option: "Lyon", score: 0.1}
      ]

      assert {:ok, _} = Validator.validate(llm_response_type, simple_response)
      assert {:ok, _} = Validator.validate(llm_response_type, structured_response)
      assert {:ok, _} = Validator.validate(llm_response_type, options_response)
    end

    test "handles partial validation for incomplete LLM outputs" do
      # DSPy needs to work with incomplete/partial responses during generation
      qa_schema_type =
        Types.object(%{
          question: Types.string() |> Types.with_constraints(min_length: 5),
          answer: Types.string() |> Types.with_constraints(min_length: 1),
          sources: Types.array(Types.string()) |> Types.with_constraints(min_items: 1)
        })

      # Complete response should pass
      complete_response = %{
        question: "What is the capital of France?",
        answer: "Paris",
        sources: ["Wikipedia", "Britannica"]
      }

      assert {:ok, _} = Validator.validate(qa_schema_type, complete_response)

      # Partial responses should provide specific field errors
      partial_response = %{
        question: "What is the capital of France?",
        # Too short
        answer: "",
        # Too few items
        sources: []
      }

      assert {:error, errors} = Validator.validate(qa_schema_type, partial_response)
      # Should have errors for answer and sources
      assert length(errors) >= 2

      error_paths = Enum.map(errors, & &1.path)
      assert [:answer] in error_paths
      assert [:sources] in error_paths
    end

    test "validates chain-of-thought reasoning structures" do
      # DSPy uses structured reasoning chains
      cot_type =
        Types.object(%{
          question: Types.string(),
          reasoning_steps:
            Types.array(
              Types.object(%{
                step: Types.integer() |> Types.with_constraints(gt: 0),
                thought: Types.string() |> Types.with_constraints(min_length: 10),
                conclusion: Types.union([Types.string(), Types.type(:atom)])
              })
            )
            |> Types.with_constraints(min_items: 1),
          final_answer: Types.string()
        })

      cot_response = %{
        question: "Is 17 a prime number?",
        reasoning_steps: [
          %{
            step: 1,
            thought: "Check if 17 is divisible by numbers from 2 to sqrt(17)",
            conclusion: "start"
          },
          %{
            step: 2,
            thought: "Test divisibility by 2: 17/2 = 8.5, not divisible",
            conclusion: "continue"
          },
          %{
            step: 3,
            thought: "Test divisibility by 3: 17/3 = 5.67, not divisible",
            conclusion: "continue"
          },
          %{
            step: 4,
            thought: "Test divisibility by 4: 17/4 = 4.25, not divisible",
            conclusion: :complete
          }
        ],
        final_answer: "Yes, 17 is a prime number"
      }

      assert {:ok, validated} = Validator.validate(cot_type, cot_response)
      assert length(validated.reasoning_steps) == 4
    end

    test "validates prompt template variable extraction" do
      # DSPy uses templates with variable placeholders
      template_vars_type =
        Types.map(
          Types.string() |> Types.with_constraints(format: ~r/^[a-zA-Z_][a-zA-Z0-9_]*$/),
          Types.union([
            Types.string(),
            Types.integer(),
            Types.float(),
            Types.boolean(),
            Types.array(Types.string())
          ])
        )

      template_vars = %{
        "user_name" => "Alice",
        "age" => 30,
        "score" => 85.5,
        "is_active" => true,
        "interests" => ["AI", "Machine Learning", "Elixir"]
      }

      assert {:ok, _} = Validator.validate(template_vars_type, template_vars)

      # Invalid variable names should fail
      invalid_vars = %{
        # Can't start with number
        "123invalid" => "value",
        "valid_name" => "value"
      }

      assert {:error, errors} = Validator.validate(template_vars_type, invalid_vars)
      assert length(errors) >= 1
    end

    test "validates nested example structures for few-shot learning" do
      # DSPy uses examples for few-shot prompting
      example_type =
        Types.object(%{
          input:
            Types.union([
              Types.string(),
              Types.object(%{
                question: Types.string(),
                context: Types.string()
              })
            ]),
          output:
            Types.union([
              Types.string(),
              Types.object(%{
                answer: Types.string(),
                explanation: Types.string()
              })
            ]),
          metadata:
            Types.object(%{
              source: Types.string(),
              difficulty:
                Types.type(:atom) |> Types.with_constraints(choices: [:easy, :medium, :hard]),
              tokens: Types.integer() |> Types.with_constraints(gt: 0)
            })
        })

      few_shot_examples = [
        %{
          input: "What is 2+2?",
          output: "4",
          metadata: %{source: "math_basics", difficulty: :easy, tokens: 15}
        },
        %{
          input: %{
            question: "Explain photosynthesis",
            context: "Biology textbook chapter 5"
          },
          output: %{
            answer:
              "Photosynthesis is the process by which plants convert light energy into chemical energy",
            explanation: "This occurs in chloroplasts using chlorophyll"
          },
          metadata: %{source: "bio_textbook", difficulty: :medium, tokens: 45}
        }
      ]

      examples_type = Types.array(example_type)
      assert {:ok, validated} = Validator.validate(examples_type, few_shot_examples)
      assert length(validated) == 2
    end

    test "validates metric evaluation structures" do
      # DSPy needs to validate evaluation metrics and scores
      evaluation_result_type =
        Types.object(%{
          predictions: Types.array(Types.string()),
          ground_truth: Types.array(Types.string()),
          metrics:
            Types.object(%{
              accuracy: Types.float() |> Types.with_constraints(gteq: 0.0, lteq: 1.0),
              f1_score: Types.float() |> Types.with_constraints(gteq: 0.0, lteq: 1.0),
              precision: Types.float() |> Types.with_constraints(gteq: 0.0, lteq: 1.0),
              recall: Types.float() |> Types.with_constraints(gteq: 0.0, lteq: 1.0)
            }),
          per_example_scores:
            Types.array(
              Types.object(%{
                prediction: Types.string(),
                target: Types.string(),
                correct: Types.boolean(),
                confidence: Types.float() |> Types.with_constraints(gteq: 0.0, lteq: 1.0)
              })
            )
        })

      eval_data = %{
        predictions: ["Paris", "London", "Berlin"],
        ground_truth: ["Paris", "Madrid", "Berlin"],
        metrics: %{
          accuracy: 0.67,
          f1_score: 0.67,
          precision: 0.67,
          recall: 0.67
        },
        per_example_scores: [
          %{prediction: "Paris", target: "Paris", correct: true, confidence: 0.95},
          %{prediction: "London", target: "Madrid", correct: false, confidence: 0.60},
          %{prediction: "Berlin", target: "Berlin", correct: true, confidence: 0.99}
        ]
      }

      assert {:ok, _} = Validator.validate(evaluation_result_type, eval_data)
    end

    test "validates optimizer configuration schemas" do
      # DSPy optimizers need configuration validation
      optimizer_config_type =
        Types.object(%{
          optimizer_type:
            Types.type(:atom)
            |> Types.with_constraints(
              choices: [:bootstrap_fewshot, :bayesian_optimization, :random_search]
            ),
          max_bootstrapped_demos: Types.integer() |> Types.with_constraints(gt: 0, lteq: 100),
          max_labeled_demos: Types.integer() |> Types.with_constraints(gt: 0, lteq: 50),
          num_candidate_programs: Types.integer() |> Types.with_constraints(gt: 0, lteq: 1000),
          num_threads: Types.integer() |> Types.with_constraints(gt: 0, lteq: 32),
          metric:
            Types.union([
              # Built-in metrics like :accuracy
              Types.type(:atom),
              # Custom metric function names
              Types.string()
            ]),
          teacher_settings:
            Types.object(%{
              model: Types.string(),
              temperature: Types.float() |> Types.with_constraints(gteq: 0.0, lteq: 2.0),
              max_tokens: Types.integer() |> Types.with_constraints(gt: 0, lteq: 4096)
            })
        })

      config = %{
        optimizer_type: :bootstrap_fewshot,
        max_bootstrapped_demos: 8,
        max_labeled_demos: 16,
        num_candidate_programs: 10,
        num_threads: 4,
        metric: :accuracy,
        teacher_settings: %{
          model: "gpt-3.5-turbo",
          temperature: 0.7,
          max_tokens: 150
        }
      }

      assert {:ok, _} = Validator.validate(optimizer_config_type, config)
    end

    test "validates LLM provider response schemas" do
      # DSPy needs to handle various LLM provider response formats
      llm_provider_response_type =
        Types.union([
          # OpenAI format
          Types.object(%{
            choices:
              Types.array(
                Types.object(%{
                  message:
                    Types.object(%{
                      content: Types.string(),
                      role: Types.string()
                    }),
                  finish_reason: Types.string()
                })
              ),
            usage:
              Types.object(%{
                prompt_tokens: Types.integer(),
                completion_tokens: Types.integer(),
                total_tokens: Types.integer()
              })
          }),

          # Anthropic format
          Types.object(%{
            content:
              Types.array(
                Types.object(%{
                  text: Types.string(),
                  type: Types.string()
                })
              ),
            usage:
              Types.object(%{
                input_tokens: Types.integer(),
                output_tokens: Types.integer()
              })
          }),

          # Simple string response
          Types.string()
        ])

      openai_response = %{
        choices: [
          %{
            message: %{content: "Paris is the capital of France", role: "assistant"},
            finish_reason: "stop"
          }
        ],
        usage: %{prompt_tokens: 10, completion_tokens: 8, total_tokens: 18}
      }

      anthropic_response = %{
        content: [%{text: "Paris is the capital of France", type: "text"}],
        usage: %{input_tokens: 10, output_tokens: 8}
      }

      assert {:ok, _} = Validator.validate(llm_provider_response_type, openai_response)
      assert {:ok, _} = Validator.validate(llm_provider_response_type, anthropic_response)
      assert {:ok, _} = Validator.validate(llm_provider_response_type, "Simple response")
    end
  end

  describe "DSPy signature and module validation" do
    test "validates DSPy signature definitions" do
      # DSPy signatures define input/output specifications
      signature_type =
        Types.object(%{
          name: Types.string(),
          doc: Types.string(),
          inputs:
            Types.map(
              # field name
              Types.string(),
              Types.object(%{
                desc: Types.string(),
                prefix: Types.string(),
                format: Types.union([Types.string(), Types.type(:atom)])
              })
            ),
          outputs:
            Types.map(
              # field name
              Types.string(),
              Types.object(%{
                desc: Types.string(),
                prefix: Types.string(),
                format: Types.union([Types.string(), Types.type(:atom)])
              })
            )
        })

      signature = %{
        name: "QuestionAnswering",
        doc: "Answer questions based on given context",
        inputs: %{
          "question" => %{desc: "The question to answer", prefix: "Question:", format: "str"},
          "context" => %{desc: "Relevant context", prefix: "Context:", format: "str"}
        },
        outputs: %{
          "answer" => %{desc: "The answer", prefix: "Answer:", format: "str"}
        }
      }

      assert {:ok, _} = Validator.validate(signature_type, signature)
    end

    test "validates module compilation results" do
      # DSPy compiles modules and needs to validate the results
      compiled_module_type =
        Types.object(%{
          predictor: Types.union([Types.string(), Types.type(:atom)]),
          signature: Types.string(),
          demos:
            Types.array(
              Types.object(%{
                question: Types.string(),
                context: Types.string(),
                answer: Types.string()
              })
            ),
          lm:
            Types.object(%{
              model: Types.string(),
              history: Types.array(Types.string())
            })
        })

      compiled_module = %{
        predictor: :chain_of_thought,
        signature: "question, context -> answer",
        demos: [
          %{
            question: "What is the capital of France?",
            context: "France is a country in Europe with Paris as its capital.",
            answer: "Paris"
          }
        ],
        lm: %{
          model: "gpt-3.5-turbo",
          history: ["System: You are a helpful assistant"]
        }
      }

      assert {:ok, _} = Validator.validate(compiled_module_type, compiled_module)
    end
  end
end
