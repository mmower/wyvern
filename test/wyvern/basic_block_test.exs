defmodule Wyvern.BasicBlockTest do
  use ExUnit.Case

  alias Wyvern.IR
  alias Wyvern.Type
  alias Wyvern.Label
  alias Wyvern.Value
  alias Wyvern.Instruction
  alias Wyvern.BasicBlock

  # The purpose of the dynamic helper is to defeat the type checker for tests
  # that would be type errors first.
  @spec dynamic(term()) :: dynamic()
  defp dynamic(value), do: value

  describe "BasicBlock" do
    test "builds a named block with its instructions" do
      instructions = [Instruction.ret(Value.i32(0))]
      block = BasicBlock.new(Label.new("entry"), instructions)

      assert block.label.name == "entry"
      assert block.instructions == instructions
    end

    test "builds an unnamed block" do
      instructions = [Instruction.ret(Value.i32(0))]
      block = BasicBlock.new(Label.new(), instructions)

      assert block.label.name == nil
      assert block.instructions == instructions
    end

    test "assigned a unique id" do
      instructions = [Instruction.ret(Value.i32(0))]

      assert %BasicBlock{id: id} = BasicBlock.new(Label.new(), instructions)
      assert is_reference(id)
    end

    test "two blocks get different ids" do
      instructions = [Instruction.ret(Value.i32(0))]

      {%BasicBlock{id: id_one}, %BasicBlock{id: id_two}} =
        {BasicBlock.new(Label.new(), instructions), BasicBlock.new(Label.new(), instructions)}

      refute id_one == id_two
    end

    test "raises on empty instruction list" do
      assert_raise RuntimeError, fn ->
        BasicBlock.new(Label.new("entry"), [])
      end
    end

    test "raises on non-label name" do
      assert_raise FunctionClauseError, fn ->
        instructions = [Instruction.ret(Value.i32(0))]
        BasicBlock.new(dynamic(42.0), instructions)
      end
    end

    test "raises if instructions are not a list" do
      assert_raise FunctionClauseError, fn ->
        BasicBlock.new(Label.new("entry"), dynamic(42.0))
      end
    end

    test "raises if instructions don't end in a terminator" do
      assert_raise RuntimeError, fn ->
        instructions = [Instruction.ptr_to_int(nil, Value.local_ref(Type.ptr(), "p"), Type.i32())]
        BasicBlock.new(Label.new("entry"), instructions)
      end
    end

    test "raises on more than one terminator" do
      assert_raise RuntimeError, fn ->
        instructions = [Instruction.br(Label.new("foo")), Instruction.ret(Value.i32(0))]
        BasicBlock.new(Label.new("entry"), instructions)
      end
    end
  end

  describe "to_ir" do
    setup do
      [ctx: IR.Context.new()]
    end

    test "named block, single terminator instruction", %{ctx: ctx} do
      block = BasicBlock.new(Label.new("entry"), [Instruction.ret(Value.i32(0))])

      ctx_1 = IR.resolve_names(block, ctx)

      {block, _} = IR.to_ir(block, ctx_1)

      assert block == "entry:\n  ret i32 0"
    end

    test "named block, multiple instructions", %{ctx: ctx} do
      block =
        BasicBlock.new(Label.new("entry"), [
          Instruction.add("x", Value.i32(1), Value.i32(2)),
          Instruction.ret(Value.local_ref(Type.i32(), "x"))
        ])

      ctx_1 = IR.resolve_names(block, ctx)

      {block, _} = IR.to_ir(block, ctx_1)

      assert block == "entry:\n  %x = add i32 1, 2\n  ret i32 %x"
    end

    test "unnamed block is numbered before instructions", %{ctx: ctx} do
      block =
        BasicBlock.new(Label.new(), [
          Instruction.add(nil, Value.i32(1), Value.i32(2)),
          Instruction.ret(Value.i32(0))
        ])

      ctx_1 = IR.resolve_names(block, ctx)
      {block, _} = IR.to_ir(block, ctx_1)

      assert block == "0:\n  %1 = add i32 1, 2\n  ret i32 0"
    end

    test "block ending in br instead of ret", %{ctx: ctx} do
      loop_label = Label.new("loop")
      #      ctx_2 = IR.Context.map_id_to_name(ctx, loop_label)
      block = BasicBlock.new(loop_label, [Instruction.br(loop_label)])

      ctx_1 = IR.resolve_names(block, ctx)
      {block, _} = IR.to_ir(block, ctx_1)

      assert block == "loop:\n  br label %loop"
    end
  end
end
