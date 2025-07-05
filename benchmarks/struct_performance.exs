defmodule StructBenchmarks do
  @moduledoc """
  Performance benchmarks for struct pattern functionality.
  """

  # Define test schemas
  defmodule BenchMapSchema do
    use Exdantic, define_struct: false
    
    schema do
      field :name, :string, required: true
      field :age, :integer, required: true
      field :email, :string, required: true
      field :active, :boolean, default: true
    end
  end

  defmodule BenchStructSchema do
    use Exdantic, define_struct: true
    
    schema do
      field :name, :string, required: true
      field :age, :integer, required: true
      field :email, :string, required: true
      field :active, :boolean, default: true
    end
  end

  def run do
    data = %{
      name: "John Doe",
      age: 30,
      email: "john@example.com"
    }

    Benchee.run(
      %{
        "map_validation" => fn -> BenchMapSchema.validate(data) end,
        "struct_validation" => fn -> BenchStructSchema.validate(data) end,
        "struct_dump" => fn -> 
          {:ok, struct} = BenchStructSchema.validate(data)
          BenchStructSchema.dump(struct)
        end
      },
      time: 10,
      memory_time: 2,
      formatters: [
        Benchee.Formatters.HTML,
        Benchee.Formatters.Console
      ]
    )
  end
end

StructBenchmarks.run()