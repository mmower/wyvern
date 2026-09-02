defmodule Wyvern.ModuleTest do
  use ExUnit.Case

  alias Wyvern.Type
  alias Wyvern.Value
  alias Wyvern.Label
  alias Wyvern.Param
  alias Wyvern.Function
  alias Wyvern.BasicBlock
  alias Wyvern.Instruction
  alias Wyvern.Declaration
  alias Wyvern.GlobalVariable
  alias Wyvern.Module

  describe "Module.to_ir" do
    test "declare + call, non-void, no var_args" do
      fn_type = Type.function(Type.i32(), [Type.i32(), Type.i32()], false)
      decl = Declaration.new("external_add", fn_type)

      call_ins =
        Instruction.call(nil, fn_type, Value.global_ref("external_add"), [
          Value.i32(3),
          Value.i32(4)
        ])

      ret_ins = Instruction.ret(Value.handle(call_ins))
      block = BasicBlock.new(Label.new(), [call_ins, ret_ins])
      f = Function.new("main", Type.i32(), [], [block])

      m = Module.new("test", "test.c", declarations: [decl], functions: [f])

      assert Module.to_ir(m, suppress_header: true) ==
               "declare i32 @external_add(i32, i32)\n\n" <>
                 "define i32 @main() {\n" <>
                 "0:\n" <>
                 "  %1 = call i32 @external_add(i32 3, i32 4)\n" <>
                 "  ret i32 %1\n" <>
                 "}"
    end

    test "declare + call, var_args" do
      fn_type = Type.function(Type.i32(), [Type.i32()], true)
      decl = Declaration.new("sum_all", fn_type)

      call_ins =
        Instruction.call(nil, fn_type, Value.global_ref("sum_all"), [
          Value.i32(3),
          Value.i32(1),
          Value.i32(2),
          Value.i32(3)
        ])

      ret_ins = Instruction.ret(Value.handle(call_ins))
      block = BasicBlock.new(Label.new(), [call_ins, ret_ins])
      f = Function.new("main", Type.i32(), [], [block])

      m = Module.new("test", "test.c", declarations: [decl], functions: [f])

      assert Module.to_ir(m, suppress_header: true) ==
               "declare i32 @sum_all(i32, ...)\n\n" <>
                 "define i32 @main() {\n" <>
                 "0:\n" <>
                 "  %1 = call i32 (i32, ...) @sum_all(i32 3, i32 1, i32 2, i32 3)\n" <>
                 "  ret i32 %1\n" <>
                 "}"
    end

    test "multiple declares and functions: fixed ordering, blank-line separation, per-function numbering reset" do
      decl_x = Declaration.new("get_x", Type.function(Type.i32(), [], false))
      decl_y = Declaration.new("get_y", Type.function(Type.i32(), [], false))
      decl_log = Declaration.new("log", Type.function(Type.void(), [Type.i32()], false))

      call_x =
        Instruction.call(nil, Type.function(Type.i32(), [], false), Value.global_ref("get_x"), [])

      call_y =
        Instruction.call(nil, Type.function(Type.i32(), [], false), Value.global_ref("get_y"), [])

      add_ins = Instruction.add(nil, Value.handle(call_x), Value.handle(call_y))

      log_call =
        Instruction.call(
          nil,
          Type.function(Type.void(), [Type.i32()], false),
          Value.global_ref("log"),
          [Value.handle(add_ins)]
        )

      ret_ins = Instruction.ret(Value.handle(add_ins))

      add_globals_block =
        BasicBlock.new(Label.new(), [call_x, call_y, add_ins, log_call, ret_ins])

      add_globals_fn = Function.new("add_globals", Type.i32(), [], [add_globals_block])

      n_ref = Param.named("n", Type.i32())
      add_ins2 = Instruction.add(nil, Param.ref(n_ref), Param.ref(n_ref))
      ret_ins2 = Instruction.ret(Value.handle(add_ins2))
      double_block = BasicBlock.new(Label.new(), [add_ins2, ret_ins2])
      double_fn = Function.new("double", Type.i32(), [n_ref], [double_block])

      m =
        Module.new("test", "test.c",
          declarations: [decl_x, decl_y, decl_log],
          functions: [add_globals_fn, double_fn]
        )

      assert Module.to_ir(m, suppress_header: true) ==
               "declare i32 @get_x()\n" <>
                 "declare i32 @get_y()\n" <>
                 "declare void @log(i32)\n\n" <>
                 "define i32 @add_globals() {\n" <>
                 "0:\n" <>
                 "  %1 = call i32 @get_x()\n" <>
                 "  %2 = call i32 @get_y()\n" <>
                 "  %3 = add i32 %1, %2\n" <>
                 "  call void @log(i32 %3)\n" <>
                 "  ret i32 %3\n" <>
                 "}\n\n" <>
                 "define i32 @double(i32 %n) {\n" <>
                 "0:\n" <>
                 "  %1 = add i32 %n, %n\n" <>
                 "  ret i32 %1\n" <>
                 "}"
    end

    test "no declarations: no leading blank line" do
      block = BasicBlock.new(Label.new(), [Instruction.ret(Value.void())])
      f = Function.new("f", Type.void(), [], [block])
      m = Module.new("test", "test.c", functions: [f])

      assert Module.to_ir(m, suppress_header: true) == "define void @f() {\n0:\n  ret void\n}"
    end

    test "no functions: no trailing blank line" do
      decl = Declaration.new("get_x", Type.function(Type.i32(), [], false))
      m = Module.new("test", "test.c", declarations: [decl])

      assert Module.to_ir(m, suppress_header: true) == "declare i32 @get_x()"
    end

    test "empty module" do
      m = Module.new("test", "test.c")
      assert Module.to_ir(m) == "; ModuleID=test\nsource_filename=test.c\n"
    end

    test "target triple renders after source_filename" do
      m = Module.new("test", "test.c", target_triple: "x86_64-unknown-linux-gnu")

      assert Module.to_ir(m) ==
               "; ModuleID=test\nsource_filename=test.c\ntarget triple = \"x86_64-unknown-linux-gnu\"\n"
    end

    test "target datalayout renders after source_filename" do
      m = Module.new("test", "test.c", target_datalayout: "e-m:e-i64:64-f80:128-n8:16:32:64-S128")

      assert Module.to_ir(m) ==
               "; ModuleID=test\nsource_filename=test.c\ntarget datalayout = \"e-m:e-i64:64-f80:128-n8:16:32:64-S128\"\n"
    end

    test "globals appear before declarations and before functions" do
      g = GlobalVariable.new("counter", Value.i32(0))
      decl = Declaration.new("get_x", Type.function(Type.i32(), [], false))
      block = BasicBlock.new(Label.new(), [Instruction.ret(Value.void())])
      f = Function.new("f", Type.void(), [], [block])

      m = Module.new("test", "test.c", globals: [g], declarations: [decl], functions: [f])

      assert Module.to_ir(m, suppress_header: true) ==
               "@counter = global i32 0\n\n" <>
                 "declare i32 @get_x()\n\n" <>
                 "define void @f() {\n0:\n  ret void\n}"
    end

    test "constant global uses the 'constant' keyword" do
      g = GlobalVariable.new("pi_ish", Value.i32(3), mutable: false)
      m = Module.new("test", "test.c", globals: [g])

      assert Module.to_ir(m, suppress_header: true) == "@pi_ish = constant i32 3"
    end

    test "outputs named struct IR" do
      ns1 = Type.named_struct("Point", [Type.i32(), Type.i32()])
      m = Module.new("test", "test.c", named_structs: [ns1])

      assert Module.to_ir(m, suppress_header: true) == "%Point = type {i32, i32}"
    end
  end

  describe "Module.new duplicate name rejection" do
    defp void_fn(name) do
      block = BasicBlock.new(Label.new(), [Instruction.ret(Value.void())])
      Function.new(name, Type.void(), [], [block])
    end

    test "raises when a declaration and a function share a name" do
      decl = Declaration.new("foo", Type.function(Type.void(), [], false))
      f = void_fn("foo")

      assert_raise RuntimeError, fn ->
        Module.new("test", "test.c", declarations: [decl], functions: [f])
      end
    end

    test "raises when two functions share a name" do
      f1 = void_fn("foo")
      f2 = void_fn("foo")

      assert_raise RuntimeError, fn ->
        Module.new("test", "test.c", functions: [f1, f2])
      end
    end

    test "raises when two declarations share a name" do
      decl1 = Declaration.new("foo", Type.function(Type.void(), [], false))
      decl2 = Declaration.new("foo", Type.function(Type.i32(), [], false))

      assert_raise RuntimeError, fn ->
        Module.new("test", "test.c", declarations: [decl1, decl2])
      end
    end

    test "raises when two globals share a name" do
      g1 = GlobalVariable.new("foo", Value.i32(1))
      g2 = GlobalVariable.new("foo", Value.i32(2))

      assert_raise RuntimeError, fn ->
        Module.new("test", "test.c", globals: [g1, g2])
      end
    end

    test "raises when a global and a function share a name" do
      g = GlobalVariable.new("foo", Value.i32(1))
      f = void_fn("foo")

      assert_raise RuntimeError, fn ->
        Module.new("test", "test.c", globals: [g], functions: [f])
      end
    end

    test "raised when two named structs share a name" do
      ns1 = Type.named_struct("Point", [Type.i32(), Type.i32()])
      ns2 = Type.named_struct("Point", [Type.array(Type.i32(), 2)])

      assert_raise RuntimeError, fn ->
        Module.new("test", "test.c", named_structs: [ns1, ns2])
      end
    end
  end
end
