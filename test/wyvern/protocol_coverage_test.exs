defmodule Wyvern.ProtocolCoverageTest do
  use ExUnit.Case, async: true

  import Wyvern.Value.Guards
  import Wyvern.Type.Guards

  @moduledoc """
  Structs, their protocol implementations and the namespace `t` unions live in
  separate files, so nothing but these tests notices when one is added without
  being wired up everywhere it needs to be.
  """

  # Values with no bare-operand form at all.
  @not_operands %{
    Wyvern.Value.Void => "void is not a value that can appear as an operand"
  }

  # Values with no `Wyvern.IROperand` implementation that arguably should have one:
  # LLVM accepts each of these as a bare operand. Recorded here so the omission is a
  # visible decision rather than an invisible gap. These are NOT settled - remove an
  # entry when its implementation lands, or move it to @not_operands with a reason.
  @operand_gaps [
    Wyvern.Value.Array,
    Wyvern.Value.BlockAddress,
    Wyvern.Value.Struct
  ]

  defp structs_under(prefix) do
    {:ok, modules} = :application.get_key(:wyvern, :modules)
    depth = length(prefix) + 1

    modules
    |> Enum.filter(fn module ->
      parts = Module.split(module)

      length(parts) == depth and Enum.take(parts, length(prefix)) == prefix and
        Code.ensure_loaded?(module) and function_exported?(module, :__struct__, 0)
    end)
    |> Enum.sort()
  end

  defp without_impl(protocol, modules) do
    Enum.reject(modules, &protocol.impl_for(struct(&1)))
  end

  defp union_members(module) do
    {:ok, types} = Code.Typespec.fetch_types(module)
    {:type, {:t, union, _}} = Enum.find(types, &match?({:type, {:t, _, _}}, &1))
    {:type, _, :union, members} = union

    for {:remote_type, _, [{:atom, _, m}, {:atom, _, :t}, _]} <- members,
        into: MapSet.new(),
        do: m
  end

  defp missing_from_union(namespace, modules) do
    in_union = union_members(namespace)
    Enum.reject(modules, &MapSet.member?(in_union, &1))
  end

  describe "instructions" do
    defp instructions, do: structs_under(["Wyvern", "Instruction"])

    test "there are instruction modules to check" do
      assert length(instructions()) > 40
    end

    test "every instruction implements Wyvern.IR" do
      missing = without_impl(Wyvern.IR, instructions())
      assert missing == [], "instructions without a Wyvern.IR impl: #{inspect(missing)}"
    end

    test "every instruction implements Wyvern.ToHandle" do
      missing = without_impl(Wyvern.ToHandle, instructions())
      assert missing == [], "instructions without a Wyvern.ToHandle impl: #{inspect(missing)}"
    end

    test "every instruction declares an LLVM mnemonic" do
      bad =
        for module <- instructions(),
            not (function_exported?(module, :mnemonic, 0) and
                   is_binary(module.mnemonic()) and
                   module.mnemonic() =~ ~r/^[a-z]+$/),
            do: module

      assert bad == [], "instructions without a usable mnemonic/0: #{inspect(bad)}"
    end

    test "every instruction appears in the Wyvern.Instruction.t union" do
      missing = missing_from_union(Wyvern.Instruction, instructions())
      assert missing == [], "instructions missing from @type t: #{inspect(missing)}"
    end
  end

  describe "values" do
    defp values, do: structs_under(["Wyvern", "Value"])

    test "there are value modules to check" do
      assert length(values()) > 8
    end

    test "every value implements Wyvern.IR" do
      missing = without_impl(Wyvern.IR, values())
      assert missing == [], "values without a Wyvern.IR impl: #{inspect(missing)}"
    end

    test "every value implements Wyvern.IROperand or is recorded as not doing so" do
      recorded = Map.keys(@not_operands) ++ @operand_gaps

      unaccounted = without_impl(Wyvern.IROperand, values()) -- recorded

      assert unaccounted == [],
             """
             These values implement neither Wyvern.IROperand nor appear in \
             @not_operands / @operand_gaps: #{inspect(unaccounted)}.
             Either implement the protocol, or record the omission with a reason.\
             """
    end

    test "the recorded IROperand gaps are still gaps" do
      fixed = Enum.filter(@operand_gaps, &Wyvern.IROperand.impl_for(struct(&1)))

      assert fixed == [],
             "these now implement Wyvern.IROperand - remove from @operand_gaps: #{inspect(fixed)}"
    end

    test "is_llvm_value/1 accepts every value struct" do
      rejected = Enum.reject(values(), fn m -> is_llvm_value(struct(m)) end)

      assert rejected == [],
             "values not accepted by Wyvern.Value.Guards.is_llvm_value/1: #{inspect(rejected)}"
    end

    test "every value appears in the Wyvern.Value.t union" do
      missing = missing_from_union(Wyvern.Value, values())
      assert missing == [], "values missing from @type t: #{inspect(missing)}"
    end
  end

  describe "types" do
    defp types, do: structs_under(["Wyvern", "Type"])

    test "there are type modules to check" do
      assert length(types()) > 6
    end

    test "every type implements Wyvern.IR" do
      missing = without_impl(Wyvern.IR, types())
      assert missing == [], "types without a Wyvern.IR impl: #{inspect(missing)}"
    end

    test "is_llvm_type/1 accepts every type struct" do
      rejected = Enum.reject(types(), fn m -> is_llvm_type(struct(m)) end)

      assert rejected == [],
             "types not accepted by Wyvern.Type.Guards.is_llvm_type/1: #{inspect(rejected)}"
    end

    test "every type appears in the Wyvern.Type.t union" do
      missing = missing_from_union(Wyvern.Type, types())
      assert missing == [], "types missing from @type t: #{inspect(missing)}"
    end
  end
end
