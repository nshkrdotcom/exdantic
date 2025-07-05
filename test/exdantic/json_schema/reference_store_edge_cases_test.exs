defmodule Exdantic.JsonSchema.ReferenceStoreEdgeCasesTest do
  use ExUnit.Case, async: true
  alias Exdantic.JsonSchema.ReferenceStore

  describe "ReferenceStore edge cases" do
    test "handles concurrent access safely" do
      {:ok, store} = ReferenceStore.start_link()

      # Spawn multiple processes that try to add references simultaneously
      tasks =
        for i <- 1..100 do
          Task.async(fn ->
            module_name = :"TestModule#{i}"
            ReferenceStore.add_reference(store, module_name)
            ReferenceStore.add_definition(store, module_name, %{"type" => "object", "id" => i})
            module_name
          end)
        end

      # Wait for all tasks to complete
      _results = Task.await_many(tasks, 5000)

      # All modules should be present
      references = ReferenceStore.get_references(store)
      definitions = ReferenceStore.get_definitions(store)

      assert length(references) == 100
      assert map_size(definitions) == 100

      # Verify all expected modules are present
      for i <- 1..100 do
        module_name = :"TestModule#{i}"
        assert module_name in references
        assert ReferenceStore.has_reference?(store, module_name)
        assert ReferenceStore.has_definition?(store, module_name)
      end

      ReferenceStore.stop(store)
    end

    test "handles duplicate reference additions" do
      {:ok, store} = ReferenceStore.start_link()

      # Add same reference multiple times
      for _i <- 1..10 do
        ReferenceStore.add_reference(store, MyModule)
      end

      references = ReferenceStore.get_references(store)
      # Should only appear once due to MapSet
      assert length(references) == 1
      assert MyModule in references

      ReferenceStore.stop(store)
    end

    test "handles duplicate definition additions" do
      {:ok, store} = ReferenceStore.start_link()

      # Add same definition multiple times with different schemas
      ReferenceStore.add_definition(store, MyModule, %{"version" => 1, "type" => "object"})
      ReferenceStore.add_definition(store, MyModule, %{"version" => 2, "type" => "object"})
      ReferenceStore.add_definition(store, MyModule, %{"version" => 3, "type" => "object"})

      definitions = ReferenceStore.get_definitions(store)
      # Should only have the last definition (Map.put overwrites)
      assert definitions["MyModule"]["version"] == 3

      ReferenceStore.stop(store)
    end

    test "handles module names with special characters" do
      {:ok, store} = ReferenceStore.start_link()

      special_modules = [
        :"Module-With-Dashes",
        :"Module.With.Dots",
        :Module_With_Underscores,
        :ModuleWith123Numbers,
        :UPPERCASE_MODULE,
        :lowercase_module
      ]

      for module <- special_modules do
        ReferenceStore.add_reference(store, module)
        ReferenceStore.add_definition(store, module, %{"type" => "object"})
      end

      references = ReferenceStore.get_references(store)
      definitions = ReferenceStore.get_definitions(store)

      assert length(references) == length(special_modules)
      assert map_size(definitions) == length(special_modules)

      # Check all modules are present and paths are correct
      for module <- special_modules do
        assert module in references
        assert ReferenceStore.has_reference?(store, module)
        assert ReferenceStore.has_definition?(store, module)

        # Check ref path generation
        ref_path = ReferenceStore.ref_path(module)
        # Extract module name using the same logic as ReferenceStore
        module_name =
          case String.split(Atom.to_string(module) |> String.replace_prefix("Elixir.", ""), ".") do
            [single_name] -> single_name
            parts -> List.last(parts)
          end

        assert ref_path == "#/definitions/#{module_name}"
      end

      ReferenceStore.stop(store)
    end

    test "handles deeply nested module names" do
      {:ok, store} = ReferenceStore.start_link()

      nested_modules = [
        MyApp.Schemas.User,
        MyApp.Schemas.Admin.Profile,
        VeryLong.Deeply.Nested.Module.Structure.Schema,
        # 10 levels deep
        A.B.C.D.E.F.G.H.I.J
      ]

      for module <- nested_modules do
        ReferenceStore.add_reference(store, module)
        ReferenceStore.add_definition(store, module, %{"type" => "object"})
      end

      definitions = ReferenceStore.get_definitions(store)

      # Check that only the last part of the module name is used as the key
      assert Map.has_key?(definitions, "User")
      assert Map.has_key?(definitions, "Profile")
      assert Map.has_key?(definitions, "Schema")
      assert Map.has_key?(definitions, "J")

      # Check ref paths
      assert ReferenceStore.ref_path(MyApp.Schemas.User) == "#/definitions/User"
      assert ReferenceStore.ref_path(MyApp.Schemas.Admin.Profile) == "#/definitions/Profile"

      assert ReferenceStore.ref_path(VeryLong.Deeply.Nested.Module.Structure.Schema) ==
               "#/definitions/Schema"

      assert ReferenceStore.ref_path(A.B.C.D.E.F.G.H.I.J) == "#/definitions/J"

      ReferenceStore.stop(store)
    end

    test "handles empty state operations" do
      {:ok, store} = ReferenceStore.start_link()

      # Operations on empty store
      assert ReferenceStore.get_references(store) == []
      assert ReferenceStore.get_definitions(store) == %{}
      assert ReferenceStore.has_reference?(store, NonExistentModule) == false
      assert ReferenceStore.has_definition?(store, NonExistentModule) == false

      ReferenceStore.stop(store)
    end

    @tag :performance
    test "handles large numbers of references and definitions" do
      {:ok, store} = ReferenceStore.start_link()

      # Add many references and definitions
      modules = for i <- 1..10_000, do: :"Module#{i}"

      for module <- modules do
        ReferenceStore.add_reference(store, module)

        ReferenceStore.add_definition(store, module, %{
          "type" => "object",
          "id" => module,
          "properties" => %{"field_#{module}" => %{"type" => "string"}}
        })
      end

      references = ReferenceStore.get_references(store)
      definitions = ReferenceStore.get_definitions(store)

      assert length(references) == 10_000
      assert map_size(definitions) == 10_000

      # Spot check some entries
      assert :Module1 in references
      assert :Module5000 in references
      assert :Module10000 in references

      assert Map.has_key?(definitions, "Module1")
      assert Map.has_key?(definitions, "Module5000")
      assert Map.has_key?(definitions, "Module10000")

      # Test lookups are still fast
      start_time = System.monotonic_time(:microsecond)
      assert ReferenceStore.has_reference?(store, :Module5000) == true
      assert ReferenceStore.has_definition?(store, :Module5000) == true
      end_time = System.monotonic_time(:microsecond)

      # Lookups should be very fast even with 10k entries
      # Less than 1 millisecond
      assert end_time - start_time < 1000

      ReferenceStore.stop(store)
    end

    test "handles agent process lifecycle edge cases" do
      # Test starting and stopping multiple times
      for _i <- 1..10 do
        {:ok, store} = ReferenceStore.start_link()
        ReferenceStore.add_reference(store, TestModule)
        assert ReferenceStore.has_reference?(store, TestModule)
        ReferenceStore.stop(store)

        # Process should be dead now - operations should fail
        # Use a more specific error check since different operations may fail differently
        assert catch_exit(ReferenceStore.get_references(store))
      end
    end

    test "handles agent process crash recovery scenarios" do
      # Use Process.flag to trap exits in this test
      Process.flag(:trap_exit, true)

      {:ok, store} = ReferenceStore.start_link()

      # Add some data
      ReferenceStore.add_reference(store, TestModule)
      ReferenceStore.add_definition(store, TestModule, %{"type" => "object"})

      # Kill the process
      Process.exit(store, :kill)

      # Wait a bit for the process to die
      Process.sleep(10)

      # Verify the process is dead
      assert not Process.alive?(store)

      # Operations should now fail with exit error
      assert catch_exit(ReferenceStore.get_references(store))
      assert catch_exit(ReferenceStore.has_reference?(store, TestModule))

      # Clean up - reset trap_exit
      Process.flag(:trap_exit, false)
    end

    test "handles module name edge cases in module_name/1" do
      {:ok, store} = ReferenceStore.start_link()

      # Test various module name formats
      test_cases = [
        {Elixir.MyModule, "MyModule"},
        {:"Elixir.MyModule", "MyModule"},
        {:MyModule, "MyModule"},
        {A, "A"},
        {Very.Long.Module.Name, "Name"}
      ]

      for {module, expected_name} <- test_cases do
        ReferenceStore.add_definition(store, module, %{"type" => "test"})
        definitions = ReferenceStore.get_definitions(store)
        assert Map.has_key?(definitions, expected_name)

        ref_path = ReferenceStore.ref_path(module)
        assert ref_path == "#/definitions/#{expected_name}"
      end

      ReferenceStore.stop(store)
    end

    test "handles invalid module references gracefully" do
      {:ok, store} = ReferenceStore.start_link()

      # Test nil - this is actually an atom in Elixir, so it should work
      ReferenceStore.add_reference(store, nil)
      assert ReferenceStore.has_reference?(store, nil)

      # Test string - should raise FunctionClauseError due to guard clause
      assert_raise FunctionClauseError, fn ->
        ReferenceStore.add_reference(store, "not_an_atom")
      end

      ReferenceStore.stop(store)
    end

    test "handles memory pressure scenarios" do
      {:ok, store} = ReferenceStore.start_link()

      # Add definitions with large data structures
      for i <- 1..1000 do
        large_schema = %{
          "type" => "object",
          "properties" =>
            Map.new(1..100, fn j ->
              {"field_#{i}_#{j}",
               %{
                 "type" => "string",
                 "description" => String.duplicate("Long description ", 100),
                 "examples" => Enum.map(1..50, &"example_#{&1}")
               }}
            end)
        }

        ReferenceStore.add_definition(store, :"LargeModule#{i}", large_schema)
      end

      # Store should still be responsive
      definitions = ReferenceStore.get_definitions(store)
      assert map_size(definitions) == 1000

      # Memory usage should be reasonable (this is more of a smoke test)
      assert is_map(definitions)

      ReferenceStore.stop(store)
    end
  end

  describe "ReferenceStore state management" do
    test "maintains state consistency across operations" do
      {:ok, store} = ReferenceStore.start_link()

      # Perform mixed operations
      operations = [
        {:add_ref, ModuleA},
        {:add_def, ModuleA, %{"type" => "objectA"}},
        {:add_ref, ModuleB},
        {:add_ref, ModuleC},
        {:add_def, ModuleB, %{"type" => "objectB"}},
        {:add_def, ModuleC, %{"type" => "objectC"}},
        # Duplicate
        {:add_ref, ModuleA},
        # Overwrite
        {:add_def, ModuleA, %{"type" => "objectA_updated"}}
      ]

      for operation <- operations do
        case operation do
          {:add_ref, module} ->
            ReferenceStore.add_reference(store, module)

          {:add_def, module, schema} ->
            ReferenceStore.add_definition(store, module, schema)
        end
      end

      # Check final state
      references = ReferenceStore.get_references(store)
      definitions = ReferenceStore.get_definitions(store)

      # ModuleA, ModuleB, ModuleC
      assert length(references) == 3
      assert map_size(definitions) == 3

      assert ModuleA in references
      assert ModuleB in references
      assert ModuleC in references

      # ModuleA should have updated definition
      assert definitions["ModuleA"]["type"] == "objectA_updated"
      assert definitions["ModuleB"]["type"] == "objectB"
      assert definitions["ModuleC"]["type"] == "objectC"

      ReferenceStore.stop(store)
    end
  end
end
