defmodule Wyvern.FunctionTest do
  use ExUnit.Case

  alias Wyvern.IR
  alias Wyvern.Type
  alias Wyvern.Value
  alias Wyvern.Label
  alias Wyvern.Function
  alias Wyvern.BasicBlock
  alias Wyvern.Instruction
  alias Wyvern.Param

  describe "Function" do
    setup do
      [ctx: IR.Context.new()]
    end

    test "declares a function" do
      entry_label = Label.new("entry")
      param_a = Param.named("a", Type.i32())
      param_b = Param.named("b", Type.i32())
      params = [param_a, param_b]

      blocks = [
        BasicBlock.new(entry_label, [
          Instruction.add(
            "r",
            Param.ref(param_a),
            Param.ref(param_b)
          ),
          Instruction.ret(Value.local_ref(Type.i32(), "r"))
        ])
      ]

      f = Function.new("adder", Type.i32(), params, blocks)

      assert f.name == "adder"
      assert f.ret_type == Type.i32()
      assert f.params == params
      assert f.blocks == blocks
    end

    test "define i32 @adder(i32 %a, i32 %b) { ... }", %{ctx: ctx} do
      param_a = Param.named("a", Type.i32())
      param_b = Param.named("b", Type.i32())
      params = [param_a, param_b]

      blocks = [
        BasicBlock.new(Label.new("entry"), [
          Instruction.add(
            "r",
            Param.ref(param_a),
            Param.ref(param_b)
          ),
          Instruction.ret(Value.local_ref(Type.i32(), "r"))
        ])
      ]

      f = Function.new("adder", Type.i32(), params, blocks)
      ctx = IR.resolve_names(f, ctx)

      assert IR.to_ir(f, ctx) ==
               {"define i32 @adder(i32 %a, i32 %b) {\nentry:\n  %r = add i32 %a, %b\n  ret i32 %r\n}",
                ctx}
    end

    test "unnamed blocks: forward branch must agree with the block it's actually printed as", %{
      ctx: ctx
    } do
      target_label = Label.new()
      target_block = BasicBlock.new(target_label, [Instruction.ret(Value.i32(0))])

      entry_label = Label.new()
      entry_block = BasicBlock.new(entry_label, [Instruction.br(target_label)])

      f = Function.new("f", Type.i32(), [], [entry_block, target_block])
      ctx = IR.resolve_names(f, ctx)

      assert IR.to_ir(f, ctx) ==
               {"define i32 @f() {\n0:\n  br label %1\n1:\n  ret i32 0\n}", ctx}
    end
  end

  describe "Unnamed/positional params" do
    setup do
      [ctx: IR.Context.new()]
    end

    test "signature renders bare types; body references resolve to %0/%1", %{ctx: ctx} do
      param_0 = Param.unnamed(Type.i32())
      param_1 = Param.unnamed(Type.i32())

      blocks = [
        BasicBlock.new(Label.new("entry"), [
          Instruction.add("r", Param.ref(param_0), Param.ref(param_1)),
          Instruction.ret(Value.local_ref(Type.i32(), "r"))
        ])
      ]

      f = Function.new("f", Type.i32(), [param_0, param_1], blocks)
      ctx = IR.resolve_names(f, ctx)

      assert IR.to_ir(f, ctx) ==
               {"define i32 @f(i32, i32) {\nentry:\n  %r = add i32 %0, %1\n  ret i32 %r\n}", ctx}
    end
  end

  describe "Param attributes appear only in the signature" do
    setup do
      [ctx: IR.Context.new()]
    end

    test "zeroext renders once in the signature, not at the usage site", %{ctx: ctx} do
      param_a = Param.named("a", Type.i8(), zeroext: true)

      blocks = [
        BasicBlock.new(Label.new("entry"), [
          Instruction.ret(Param.ref(param_a))
        ])
      ]

      f = Function.new("f", Type.i8(), [param_a], blocks)
      ctx = IR.resolve_names(f, ctx)

      assert IR.to_ir(f, ctx) ==
               {"define i8 @f(i8 zeroext %a) {\nentry:\n  ret i8 %a\n}", ctx}
    end
  end

  describe "Duplicate params" do
    setup do
      [blocks: [BasicBlock.new(Label.new("entry"), [Instruction.ret(Value.void())])]]
    end

    test "raises when two params share the same name", %{blocks: blocks} do
      dup = [Param.named("x", Type.i32(), []), Param.named("x", Type.i32(), [])]

      assert_raise RuntimeError, fn ->
        Function.new("foo", Type.void(), dup, blocks)
      end
    end
  end

  describe "Linkage" do
    setup do
      [
        ctx: IR.Context.new(),
        blocks: [BasicBlock.new(Label.new("entry"), [Instruction.ret(Value.void())])]
      ]
    end

    test "private linkage renders", %{ctx: ctx, blocks: blocks} do
      f = Function.new("foo", Type.void(), [], blocks, linkage: :private)
      ctx = IR.resolve_names(f, ctx)
      assert IR.to_ir(f, ctx) == {"define private void @foo() {\nentry:\n  ret void\n}", ctx}
    end

    test "internal linkage renders", %{ctx: ctx, blocks: blocks} do
      f = Function.new("foo", Type.void(), [], blocks, linkage: :internal)
      ctx = IR.resolve_names(f, ctx)
      assert IR.to_ir(f, ctx) == {"define internal void @foo() {\nentry:\n  ret void\n}", ctx}
    end

    test "raises when :common linkage is used on a function", %{blocks: blocks} do
      assert_raise RuntimeError, fn ->
        Function.new("foo", Type.void(), [], blocks, linkage: :common)
      end
    end

    test "raises when :appending linkage is used on a function", %{blocks: blocks} do
      assert_raise RuntimeError, fn ->
        Function.new("foo", Type.void(), [], blocks, linkage: :appending)
      end
    end

    test "raises on unknown linkage atom", %{blocks: blocks} do
      assert_raise RuntimeError, fn ->
        Function.new("foo", Type.void(), [], blocks, linkage: :bogus)
      end
    end
  end

  describe "Visibility" do
    setup do
      [
        ctx: IR.Context.new(),
        blocks: [BasicBlock.new(Label.new("entry"), [Instruction.ret(Value.void())])]
      ]
    end

    test "hidden visibility renders", %{ctx: ctx, blocks: blocks} do
      f = Function.new("foo", Type.void(), [], blocks, visibility: :hidden)
      ctx = IR.resolve_names(f, ctx)
      assert IR.to_ir(f, ctx) == {"define hidden void @foo() {\nentry:\n  ret void\n}", ctx}
    end

    test "protected visibility renders", %{ctx: ctx, blocks: blocks} do
      f = Function.new("foo", Type.void(), [], blocks, visibility: :protected)
      ctx = IR.resolve_names(f, ctx)
      assert IR.to_ir(f, ctx) == {"define protected void @foo() {\nentry:\n  ret void\n}", ctx}
    end

    test "linkage renders before visibility", %{ctx: ctx, blocks: blocks} do
      f = Function.new("foo", Type.void(), [], blocks, linkage: :weak, visibility: :hidden)
      ctx = IR.resolve_names(f, ctx)

      assert IR.to_ir(f, ctx) ==
               {"define weak hidden void @foo() {\nentry:\n  ret void\n}", ctx}
    end

    test "raises when :private linkage is combined with non-default visibility", %{
      blocks: blocks
    } do
      assert_raise RuntimeError, fn ->
        Function.new("foo", Type.void(), [], blocks, linkage: :private, visibility: :hidden)
      end
    end

    test "raises when :internal linkage is combined with non-default visibility", %{
      blocks: blocks
    } do
      assert_raise RuntimeError, fn ->
        Function.new("foo", Type.void(), [], blocks, linkage: :internal, visibility: :protected)
      end
    end

    test "does not raise when :private linkage is combined with explicit :default visibility", %{
      ctx: ctx,
      blocks: blocks
    } do
      f = Function.new("foo", Type.void(), [], blocks, linkage: :private, visibility: :default)

      ctx = IR.resolve_names(f, ctx)

      assert IR.to_ir(f, ctx) ==
               {"define private default void @foo() {\nentry:\n  ret void\n}", ctx}
    end

    test "raises on unknown visibility atom", %{blocks: blocks} do
      assert_raise RuntimeError, fn ->
        Function.new("foo", Type.void(), [], blocks, visibility: :bogus)
      end
    end
  end

  describe "Calling Convention" do
    setup do
      [
        ctx: IR.Context.new(),
        blocks: [BasicBlock.new(Label.new("entry"), [Instruction.ret(Value.void())])]
      ]
    end

    test "fastcc renders", %{ctx: ctx, blocks: blocks} do
      f = Function.new("foo", Type.void(), [], blocks, cconv: :fastcc)
      ctx = IR.resolve_names(f, ctx)
      assert IR.to_ir(f, ctx) == {"define fastcc void @foo() {\nentry:\n  ret void\n}", ctx}
    end

    test "coldcc renders", %{ctx: ctx, blocks: blocks} do
      f = Function.new("foo", Type.void(), [], blocks, cconv: :coldcc)
      ctx = IR.resolve_names(f, ctx)
      assert IR.to_ir(f, ctx) == {"define coldcc void @foo() {\nentry:\n  ret void\n}", ctx}
    end

    test "calling convention renders after linkage and visibility", %{ctx: ctx, blocks: blocks} do
      f =
        Function.new("foo", Type.void(), [], blocks,
          linkage: :weak,
          visibility: :hidden,
          cconv: :fastcc
        )

      ctx = IR.resolve_names(f, ctx)

      assert IR.to_ir(f, ctx) ==
               {"define weak hidden fastcc void @foo() {\nentry:\n  ret void\n}", ctx}
    end

    test "raises on unknown calling convention atom", %{blocks: blocks} do
      assert_raise RuntimeError, fn ->
        Function.new("foo", Type.void(), [], blocks, cconv: :bogus)
      end
    end
  end

  describe "Address" do
    setup do
      [
        ctx: IR.Context.new(),
        blocks: [BasicBlock.new(Label.new("entry"), [Instruction.ret(Value.void())])]
      ]
    end

    test "unnamed_addr renders after the param list", %{ctx: ctx, blocks: blocks} do
      f = Function.new("foo", Type.void(), [], blocks, addr: :unnamed_addr)
      ctx = IR.resolve_names(f, ctx)

      assert IR.to_ir(f, ctx) ==
               {"define void @foo() unnamed_addr {\nentry:\n  ret void\n}", ctx}
    end

    test "local_unnamed_addr renders after the param list", %{ctx: ctx, blocks: blocks} do
      f = Function.new("foo", Type.void(), [], blocks, addr: :local_unnamed_addr)
      ctx = IR.resolve_names(f, ctx)

      assert IR.to_ir(f, ctx) ==
               {"define void @foo() local_unnamed_addr {\nentry:\n  ret void\n}", ctx}
    end

    # LangRef order is Linkage, Visibility, DLLStorageClass, cconv, ret type, @name(args),
    # then (unnamed_addr|local_unnamed_addr) — so address renders after the param list,
    # not clustered with linkage/visibility/cconv before the return type.
    test "address renders after linkage, visibility, and cconv", %{ctx: ctx, blocks: blocks} do
      f =
        Function.new("foo", Type.void(), [], blocks,
          linkage: :weak,
          visibility: :hidden,
          cconv: :fastcc,
          addr: :unnamed_addr
        )

      ctx = IR.resolve_names(f, ctx)

      assert IR.to_ir(f, ctx) ==
               {"define weak hidden fastcc void @foo() unnamed_addr {\nentry:\n  ret void\n}",
                ctx}
    end

    test "raises on unknown address atom", %{blocks: blocks} do
      assert_raise RuntimeError, fn ->
        Function.new("foo", Type.void(), [], blocks, addr: :bogus)
      end
    end
  end
end
