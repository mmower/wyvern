defmodule Wyvern.ParamTest do
  use ExUnit.Case

  alias Wyvern.IR
  alias Wyvern.Type
  alias Wyvern.Param

  describe "to_ir/2 - unnamed, no attributes" do
    setup do
      [ctx: IR.Context.new()]
    end

    test "renders just the type, with no stray whitespace", %{ctx: ctx} do
      assert IR.to_ir(Param.unnamed(Type.i32(), []), ctx) == {"i32", ctx}
    end
  end

  describe "to_ir/2 - named" do
    setup do
      [ctx: IR.Context.new()]
    end

    test "renders type followed by %name", %{ctx: ctx} do
      assert IR.to_ir(Param.named("x", Type.i32(), []), ctx) == {"i32 %x", ctx}
    end
  end

  describe "to_ir/2 - bare attributes" do
    setup do
      [ctx: IR.Context.new()]
    end

    test "signext renders on an unnamed (declaration-style) param", %{ctx: ctx} do
      assert IR.to_ir(Param.unnamed(Type.i8(), signext: true), ctx) == {"i8 signext", ctx}
    end

    test "signext renders between type and %name", %{ctx: ctx} do
      assert IR.to_ir(Param.named("x", Type.i8(), signext: true), ctx) == {"i8 signext %x", ctx}
    end
  end

  describe "to_ir/2 - payload attributes" do
    setup do
      [ctx: IR.Context.new()]
    end

    test "sret carries its pointee type", %{ctx: ctx} do
      point = Type.named_struct("Point", [Type.i32(), Type.i32()])

      assert IR.to_ir(Param.unnamed(Type.ptr(), sret: point), ctx) ==
               {"ptr sret(%Point)", ctx}
    end
  end

  describe "attribute validation - integer-only attributes" do
    test "signext on a non-integer type raises" do
      assert_raise RuntimeError, ~r/signext/, fn ->
        Param.named("x", Type.ptr(), signext: true)
      end
    end

    test "zeroext on a non-integer type raises" do
      assert_raise RuntimeError, ~r/zeroext/, fn ->
        Param.unnamed(Type.ptr(), zeroext: true)
      end
    end
  end

  describe "resolve_names/2 - unnamed params" do
    test "registers the param's id in the context, like every other unnamed value" do
      ctx = IR.resolve_names(Param.unnamed(Type.i32(), []), IR.Context.new())

      assert ctx.id_map != %{}
    end

    test "consumes an auto-numbered slot" do
      p = Param.unnamed(Type.i32(), [])
      ctx = IR.resolve_names(p, IR.Context.new())

      assert IR.Context.lookup_id(ctx, p.id) == "0"
    end
  end

  describe "ref/1" do
    test "returns a Value handle carrying the param's id and type" do
      p = Param.named("x", Type.i32(), [])

      assert Param.ref(p) == Wyvern.Value.handle(p.id, Type.i32())
    end

    test "works the same for an unnamed param" do
      p = Param.unnamed(Type.i32(), [])

      assert Param.ref(p) == Wyvern.Value.handle(p.id, Type.i32())
    end
  end
end
