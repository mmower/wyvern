defmodule Wyvern.GlobalVariableTest do
  use ExUnit.Case

  alias Wyvern.IR
  alias Wyvern.Type
  alias Wyvern.Label
  alias Wyvern.Value
  alias Wyvern.GlobalVariable

  describe "GlobalVariable" do
    test "create extern global" do
      gv = GlobalVariable.new("foo", Type.i32())

      {code, _} = IR.to_ir(gv, IR.Context.new())

      assert code == "@foo = external global i32"
    end

    test "create extern const" do
      gv = GlobalVariable.new("foo", Type.i32(), mutable: false)

      {code, _} = IR.to_ir(gv, IR.Context.new())

      assert code == "@foo = external constant i32"
    end

    test "create global" do
      gv = GlobalVariable.new("foo", Value.struct([Value.i32(0), Value.i32(1)]))

      {code, _} = IR.to_ir(gv, IR.Context.new())

      assert code == "@foo = global {i32, i32} {i32 0, i32 1}"
    end

    test "create const" do
      gv = GlobalVariable.new("foo", Value.i32(42), mutable: false)

      {code, _} = IR.to_ir(gv, IR.Context.new())

      assert code == "@foo = constant i32 42"
    end

    test "create global to other global" do
      gv = GlobalVariable.new("foo", Value.global_ref("bar"))

      {code, _} = IR.to_ir(gv, IR.Context.new())

      assert code == "@foo = global ptr @bar"
    end

    test "create const to a block" do
      ctx = IR.Context.new()

      main = Value.global_ref("main")
      block_lbl = Label.new("block_1")

      gv =
        GlobalVariable.new(
          "bar",
          Value.blockaddress(main, block_lbl),
          mutable: false
        )

      ctx = IR.resolve_names(gv, ctx)

      {code, _} = IR.to_ir(gv, ctx)

      assert code == "@bar = constant ptr blockaddress(@main, %block_1)"
    end

    test "raises on dynamic initializer" do
      assert_raise RuntimeError, fn ->
        GlobalVariable.new("foo", Value.local_ref(Type.i32(), "x"))
      end

      assert_raise RuntimeError, fn ->
        GlobalVariable.new("foo", Value.handle(make_ref(), Type.i32()))
      end
    end
  end

  describe "Linkage" do
    test "extern global with explicit :external linkage matches the default" do
      gv = GlobalVariable.new("foo", Type.i32(), linkage: :external)
      {code, _} = IR.to_ir(gv, IR.Context.new())
      assert code == "@foo = external global i32"
    end

    test "extern_weak declaration" do
      gv = GlobalVariable.new("foo", Type.i32(), linkage: :extern_weak)
      {code, _} = IR.to_ir(gv, IR.Context.new())
      assert code == "@foo = extern_weak global i32"
    end

    test "private definition" do
      gv = GlobalVariable.new("foo", Value.i32(1), linkage: :private)
      {code, _} = IR.to_ir(gv, IR.Context.new())
      assert code == "@foo = private global i32 1"
    end

    test "internal constant" do
      gv = GlobalVariable.new("foo", Value.i32(1), mutable: false, linkage: :internal)
      {code, _} = IR.to_ir(gv, IR.Context.new())
      assert code == "@foo = internal constant i32 1"
    end

    test "raises when a definition-only linkage is used without an initializer" do
      assert_raise RuntimeError, fn ->
        GlobalVariable.new("foo", Type.i32(), linkage: :private)
      end
    end

    test "raises when a declaration-only linkage is combined with an initializer" do
      assert_raise RuntimeError, fn ->
        GlobalVariable.new("foo", Value.i32(1), linkage: :external)
      end
    end

    # :common and :appending carry extra semantic rules beyond "needs an initializer"
    # that validate_linkage!/2 does not check yet - see LLVM's verifier:
    #   'common' global must have a zero initializer!
    #   'common' global may not be marked constant!
    #   Only global arrays can have appending linkage!
    test "raises when :common is combined with a non-zero initializer" do
      assert_raise RuntimeError, fn ->
        GlobalVariable.new("foo", Value.i32(5), linkage: :common)
      end
    end

    test "raises when :common is marked constant" do
      assert_raise RuntimeError, fn ->
        GlobalVariable.new("foo", Value.i32(0), mutable: false, linkage: :common)
      end
    end

    test "raises when :appending is used with a non-array type" do
      assert_raise RuntimeError, fn ->
        GlobalVariable.new("foo", Value.i32(0), linkage: :appending)
      end
    end
  end

  describe "Visibility" do
    test "hidden definition" do
      gv = GlobalVariable.new("foo", Value.i32(1), visibility: :hidden)
      {code, _} = IR.to_ir(gv, IR.Context.new())
      assert code == "@foo = hidden global i32 1"
    end

    test "protected definition" do
      gv = GlobalVariable.new("foo", Value.i32(1), visibility: :protected)
      {code, _} = IR.to_ir(gv, IR.Context.new())
      assert code == "@foo = protected global i32 1"
    end

    test "explicit :default visibility renders the keyword" do
      gv = GlobalVariable.new("foo", Value.i32(1), visibility: :default)
      {code, _} = IR.to_ir(gv, IR.Context.new())
      assert code == "@foo = default global i32 1"
    end

    test "hidden declaration" do
      gv = GlobalVariable.new("foo", Type.i32(), visibility: :hidden)
      {code, _} = IR.to_ir(gv, IR.Context.new())
      assert code == "@foo = external hidden global i32"
    end

    test "extern_weak declaration with hidden visibility" do
      gv = GlobalVariable.new("foo", Type.i32(), linkage: :extern_weak, visibility: :hidden)
      {code, _} = IR.to_ir(gv, IR.Context.new())
      assert code == "@foo = extern_weak hidden global i32"
    end

    test "protected declaration" do
      gv = GlobalVariable.new("foo", Type.i32(), visibility: :protected)
      {code, _} = IR.to_ir(gv, IR.Context.new())
      assert code == "@foo = external protected global i32"
    end

    test "extern_weak declaration with protected visibility" do
      gv = GlobalVariable.new("foo", Type.i32(), linkage: :extern_weak, visibility: :protected)
      {code, _} = IR.to_ir(gv, IR.Context.new())
      assert code == "@foo = extern_weak protected global i32"
    end

    # Only :private/:internal ("local linkage") are restricted to default visibility -
    # every other linkage should combine freely with hidden/protected.
    test "common linkage with hidden visibility does not raise" do
      gv =
        GlobalVariable.new("foo", Value.i32(0),
          linkage: :common,
          visibility: :hidden
        )

      {code, _} = IR.to_ir(gv, IR.Context.new())
      assert code == "@foo = common hidden global i32 0"
    end

    test "appending linkage with protected visibility does not raise" do
      array = Value.array(Type.i32(), [Value.i32(1)])

      gv =
        GlobalVariable.new("foo", array,
          linkage: :appending,
          visibility: :protected
        )

      {code, _} = IR.to_ir(gv, IR.Context.new())
      assert code == "@foo = appending protected global [1 x i32] [i32 1]"
    end

    test "linkage renders before visibility" do
      gv = GlobalVariable.new("foo", Value.i32(1), linkage: :weak, visibility: :hidden)
      {code, _} = IR.to_ir(gv, IR.Context.new())
      assert code == "@foo = weak hidden global i32 1"
    end

    # LLVM: "symbol with local linkage must have default visibility" - :private and
    # :internal are the two "local linkage" kinds and can't be hidden/protected.
    test "raises when :private linkage is combined with non-default visibility" do
      assert_raise RuntimeError, fn ->
        GlobalVariable.new("foo", Value.i32(1), linkage: :private, visibility: :hidden)
      end
    end

    test "raises when :internal linkage is combined with non-default visibility" do
      assert_raise RuntimeError, fn ->
        GlobalVariable.new("foo", Value.i32(1), linkage: :internal, visibility: :protected)
      end
    end

    test "does not raise when :private linkage is combined with explicit :default visibility" do
      gv = GlobalVariable.new("foo", Value.i32(1), linkage: :private, visibility: :default)
      {code, _} = IR.to_ir(gv, IR.Context.new())
      assert code == "@foo = private default global i32 1"
    end

    test "does not raise when :internal linkage is combined with explicit :default visibility" do
      gv = GlobalVariable.new("foo", Value.i32(1), linkage: :internal, visibility: :default)
      {code, _} = IR.to_ir(gv, IR.Context.new())
      assert code == "@foo = internal default global i32 1"
    end

    test "raises on unknown visibility atom" do
      assert_raise RuntimeError, fn ->
        GlobalVariable.new("foo", Value.i32(1), visibility: :bogus)
      end
    end
  end

  describe "Address" do
    test "unnamed_addr on a definition" do
      gv = GlobalVariable.new("foo", Value.i32(1), addr: :unnamed_addr)
      {code, _} = IR.to_ir(gv, IR.Context.new())
      assert code == "@foo = unnamed_addr global i32 1"
    end

    test "local_unnamed_addr on a definition" do
      gv = GlobalVariable.new("foo", Value.i32(1), addr: :local_unnamed_addr)
      {code, _} = IR.to_ir(gv, IR.Context.new())
      assert code == "@foo = local_unnamed_addr global i32 1"
    end

    test "unnamed_addr on a declaration" do
      gv = GlobalVariable.new("foo", Type.i32(), addr: :unnamed_addr)
      {code, _} = IR.to_ir(gv, IR.Context.new())
      assert code == "@foo = external unnamed_addr global i32"
    end

    # LangRef order is Linkage, Visibility, ..., (unnamed_addr|local_unnamed_addr) - so
    # address must render last, after both linkage and visibility.
    test "address renders after linkage and visibility" do
      gv =
        GlobalVariable.new("foo", Value.i32(1),
          linkage: :weak,
          visibility: :hidden,
          addr: :unnamed_addr
        )

      {code, _} = IR.to_ir(gv, IR.Context.new())
      assert code == "@foo = weak hidden unnamed_addr global i32 1"
    end

    test "raises on unknown address atom" do
      assert_raise RuntimeError, fn ->
        GlobalVariable.new("foo", Value.i32(1), addr: :bogus)
      end
    end
  end
end
