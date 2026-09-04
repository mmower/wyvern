defmodule Wyvern.InstructionProtocolTest do
  use ExUnit.Case, async: true

  @moduledoc """
  Guards the invariants that no single file states any more.

  Instruction modules, their protocol implementations and the `Wyvern.Instruction.t`
  union are spread across separate files, so nothing but these tests notices when
  an instruction is added without being wired up everywhere it needs to be.
  """

  defp instruction_modules do
    {:ok, modules} = :application.get_key(:wyvern, :modules)

    modules
    |> Enum.filter(fn module ->
      case Module.split(module) do
        ["Wyvern", "Instruction", _name] ->
          Code.ensure_loaded?(module) and function_exported?(module, :__struct__, 0)

        _ ->
          false
      end
    end)
    |> Enum.sort()
  end

  test "there are instruction modules to check" do
    assert length(instruction_modules()) > 40
  end

  test "every instruction implements Wyvern.IR" do
    missing =
      instruction_modules()
      |> Enum.reject(&Wyvern.IR.impl_for(struct(&1)))

    assert missing == [], "instructions without a Wyvern.IR impl: #{inspect(missing)}"
  end

  test "every instruction implements Wyvern.ToHandle" do
    missing =
      instruction_modules()
      |> Enum.reject(&Wyvern.ToHandle.impl_for(struct(&1)))

    assert missing == [], "instructions without a Wyvern.ToHandle impl: #{inspect(missing)}"
  end

  test "every instruction declares an LLVM mnemonic" do
    bad =
      for module <- instruction_modules(),
          not (function_exported?(module, :mnemonic, 0) and
                 is_binary(module.mnemonic()) and
                 module.mnemonic() =~ ~r/^[a-z]+$/),
          do: module

    assert bad == [], "instructions without a usable mnemonic/0: #{inspect(bad)}"
  end

  test "every instruction appears in the Wyvern.Instruction.t union" do
    {:ok, types} = Code.Typespec.fetch_types(Wyvern.Instruction)
    {:type, {:t, union, _}} = Enum.find(types, &match?({:type, {:t, _, _}}, &1))
    {:type, _, :union, members} = union

    in_union =
      for {:remote_type, _, [{:atom, _, module}, {:atom, _, :t}, _]} <- members,
          into: MapSet.new(),
          do: module

    missing = Enum.reject(instruction_modules(), &MapSet.member?(in_union, &1))

    assert missing == [], "instructions missing from @type t: #{inspect(missing)}"
  end
end
