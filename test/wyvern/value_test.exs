defmodule Wyvern.ValueTest do
  use ExUnit.Case

  alias Wyvern.IR
  alias Wyvern.IROperand
  alias Wyvern.Value
  alias Wyvern.Type

  describe "Value" do
    setup do
      [ctx: IR.Context.new()]
    end

    test "i8 42", %{ctx: ctx} do
      assert IR.to_ir(Value.i8(42), ctx) == {"i8 42", ctx}
    end

    test "half 1.0", %{ctx: ctx} do
      assert IR.to_ir(Value.half(1.0), ctx) == {"half 0x3ff0000000000000", ctx}
    end

    test "bfloat pi", %{ctx: ctx} do
      assert IR.to_ir(Value.bfloat(:math.pi()), ctx) == {"bfloat 0x4009200000000000", ctx}
    end

    test "bfloat 1.0", %{ctx: ctx} do
      assert IR.to_ir(Value.bfloat(1.0), ctx) == {"bfloat 0x3ff0000000000000", ctx}
    end

    test "float 2.0", %{ctx: ctx} do
      assert IR.to_ir(Value.float(2.0), ctx) == {"float 0x4000000000000000", ctx}
    end

    test "double 2.0", %{ctx: ctx} do
      assert IR.to_ir(Value.double(2.0), ctx) == {"double 0x4000000000000000", ctx}
    end

    test "local_ref", %{ctx: ctx} do
      assert IR.to_ir(Value.local_ref(Type.i8(), "foo.bar"), ctx) == {"i8 %foo.bar", ctx}
    end

    test "quoted local_ref", %{ctx: ctx} do
      assert IR.to_ir(Value.local_ref(Type.float(), "0demon"), ctx) == {"float %\"0demon\"", ctx}
    end

    test "global_ref", %{ctx: ctx} do
      assert IR.to_ir(Value.global_ref("bar$baz"), ctx) == {"ptr @bar$baz", ctx}
    end

    test "quoted global_ref", %{ctx: ctx} do
      assert IR.to_ir(Value.global_ref("0fex"), ctx) == {"ptr @\"0fex\"", ctx}
    end

    test "handle", %{ctx: ctx} do
      id = make_ref()
      ctx_1 = IR.Context.map_id_to_name(ctx, id, "x")

      {value, _} = IR.to_ir(Value.handle(id, Type.i32()), ctx_1)
      assert value == "i32 %x"
    end

    test "blockaddress with named label", %{ctx: ctx} do
      function = Value.global_ref("my_func")
      label = Wyvern.Label.new("entry")
      blockaddress = Value.blockaddress(function, label)

      ctx_1 = IR.resolve_names(blockaddress, ctx)

      assert IR.to_ir(blockaddress, ctx_1) == {"ptr blockaddress(@my_func, %entry)", ctx_1}
    end

    test "blockaddress with unnamed label", %{ctx: ctx} do
      function = Value.global_ref("my_func")
      label = Wyvern.Label.new()
      blockaddress = Value.blockaddress(function, label)

      ctx_1 = IR.resolve_names(blockaddress, ctx)

      assert IR.to_ir(blockaddress, ctx_1) == {"ptr blockaddress(@my_func, %0)", ctx_1}
    end
  end

  describe "Poison" do
    setup do
      [ctx: IR.Context.new()]
    end

    test "poisoned i8", %{ctx: ctx} do
      {code, _} = IR.to_ir(Value.poison(Type.i8()), ctx)
      assert code == "i8 poison"
    end
  end

  describe "Undef" do
    setup do
      [ctx: IR.Context.new()]
    end

    test "undef i8", %{ctx: ctx} do
      {code, _} = IR.to_ir(Value.undef(Type.i8()), ctx)
      assert code == "i8 undef"
    end
  end

  describe "Operand" do
    setup do
      [ctx: IR.Context.new()]
    end

    test "int operand", %{ctx: ctx} do
      assert IROperand.to_operand(Value.i8(42), ctx) == {"42", ctx}
    end

    test "float operand", %{ctx: ctx} do
      assert IROperand.to_operand(Value.bfloat(:math.pi()), ctx) == {"0x4009200000000000", ctx}
    end

    test "local_ref operand", %{ctx: ctx} do
      assert IROperand.to_operand(Value.local_ref(Type.i8(), "foo.bar"), ctx) == {"%foo.bar", ctx}
    end

    test "global_ref operand", %{ctx: ctx} do
      assert IROperand.to_operand(Value.global_ref("bar$baz"), ctx) == {"@bar$baz", ctx}
    end

    test "handle", %{ctx: ctx} do
      id = make_ref()
      ctx_1 = IR.Context.map_id_to_name(ctx, id, "x")

      {value, _} = IROperand.to_operand(Value.handle(id, Type.i8()), ctx_1)
      assert value == "%x"
    end
  end
end
