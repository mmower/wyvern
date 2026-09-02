defmodule Wyvern.TypeTest do
  use ExUnit.Case

  alias Wyvern.IR
  alias Wyvern.Type

  describe "Test Integer" do
    setup do
      [ctx: IR.Context.new()]
    end

    test "i8", %{ctx: ctx} do
      assert IR.to_ir(Type.i8(), ctx) == {"i8", ctx}
    end

    test "i16", %{ctx: ctx} do
      assert IR.to_ir(Type.i16(), ctx) == {"i16", ctx}
    end

    test "i32", %{ctx: ctx} do
      assert IR.to_ir(Type.i32(), ctx) == {"i32", ctx}
    end

    test "i64", %{ctx: ctx} do
      assert IR.to_ir(Type.i64(), ctx) == {"i64", ctx}
    end

    test "char", %{ctx: ctx} do
      assert IR.to_ir(Type.char(), ctx) == {"i8", ctx}
    end
  end

  describe "Test Float" do
    setup do
      [ctx: IR.Context.new()]
    end

    test "half", %{ctx: ctx} do
      assert IR.to_ir(Type.half(), ctx) == {"half", ctx}
    end

    test "bfloat", %{ctx: ctx} do
      assert IR.to_ir(Type.bfloat(), ctx) == {"bfloat", ctx}
    end

    test "float", %{ctx: ctx} do
      assert IR.to_ir(Type.float(), ctx) == {"float", ctx}
    end

    test "double", %{ctx: ctx} do
      assert IR.to_ir(Type.double(), ctx) == {"double", ctx}
    end

    test "x86_fp80", %{ctx: ctx} do
      assert IR.to_ir(Type.x86_fp80(), ctx) == {"x86_fp80", ctx}
    end

    test "fp128", %{ctx: ctx} do
      assert IR.to_ir(Type.fp128(), ctx) == {"fp128", ctx}
    end

    test "ppc_fp128", %{ctx: ctx} do
      assert IR.to_ir(Type.ppc_fp128(), ctx) == {"ppc_fp128", ctx}
    end
  end

  describe "Pointer" do
    setup do
      [ctx: IR.Context.new()]
    end

    test "ptr", %{ctx: ctx} do
      assert IR.to_ir(Type.ptr(), ctx) == {"ptr", ctx}
    end
  end

  describe "Void" do
    setup do
      [ctx: IR.Context.new()]
    end

    test "void", %{ctx: ctx} do
      assert IR.to_ir(Type.void(), ctx) == {"void", ctx}
    end
  end

  describe "Array" do
    setup do
      [ctx: Wyvern.IR.Context.new()]
    end

    test "array of 16 x i8", %{ctx: ctx} do
      assert IR.to_ir(Type.array(Type.i8(), 16), ctx) == {"[16 x i8]", ctx}
    end

    test "array of 8 x char", %{ctx: ctx} do
      assert IR.to_ir(Type.array(Type.char(), 8), ctx) == {"[8 x i8]", ctx}
    end
  end

  describe "Literal Struct" do
    setup do
      [ctx: IR.Context.new()]
    end

    test "{i8, i64}", %{ctx: ctx} do
      assert IR.to_ir(Type.struct([Type.i8(), Type.i64()]), ctx) == {"{i8, i64}", ctx}
    end

    test "{i8, i64} packed", %{ctx: ctx} do
      assert IR.to_ir(Type.struct([Type.i8(), Type.i64()], packed: true), ctx) ==
               {"<{i8, i64}>", ctx}
    end

    test "{[16 x i8], i8}", %{ctx: ctx} do
      assert IR.to_ir(Type.struct([Type.array(Type.i8(), 16), Type.i8()]), ctx) ==
               {"{[16 x i8], i8}", ctx}
    end
  end

  describe "Function" do
    setup do
      [ctx: IR.Context.new()]
    end

    test "i32 no params", %{ctx: ctx} do
      assert IR.to_ir(Type.function(Type.i32(), []), ctx) == {"i32 ()", ctx}
    end

    test "i32 params", %{ctx: ctx} do
      assert IR.to_ir(Type.function(Type.i32(), [Type.i8(), Type.i8()]), ctx) ==
               {"i32 (i8, i8)", ctx}
    end

    test "i32 params varags", %{ctx: ctx} do
      assert IR.to_ir(Type.function(Type.i32(), [Type.i8(), Type.i8()], true), ctx) ==
               {"i32 (i8, i8, ...)", ctx}
    end

    test "i64 no params, vargs", %{ctx: ctx} do
      assert IR.to_ir(Type.function(Type.i64(), [], true), ctx) == {"i64 (...)", ctx}
    end
  end

  describe "field_type/2 with NamedStruct" do
    test "looks up each field of a named struct" do
      point = Type.named_struct("Point", [Type.i32(), Type.i8()])

      assert Type.field_type(point, [0]) == Type.i32()
      assert Type.field_type(point, [1]) == Type.i8()
    end

    test "recurses through a nested field" do
      vec = Type.named_struct("Vec", [Type.array(Type.i32(), 3), Type.i8()])

      assert Type.field_type(vec, [0, 1]) == Type.i32()
    end

    test "raises on an out-of-range index" do
      point = Type.named_struct("Point", [Type.i32(), Type.i8()])

      assert_raise RuntimeError, fn ->
        Type.field_type(point, [2])
      end
    end
  end
end
