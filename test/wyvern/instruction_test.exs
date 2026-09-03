defmodule Wyvern.InstructionTest do
  use ExUnit.Case

  alias Wyvern.IR
  alias Wyvern.Instruction
  alias Wyvern.Type
  alias Wyvern.Label
  alias Wyvern.Value

  def gen_code(instruction, ctx) do
    ctx_1 = IR.resolve_names(instruction, ctx)
    {code, _} = IR.to_ir(instruction, ctx_1)
    code
  end

  describe "Add" do
    setup do
      [ctx: IR.Context.new()]
    end

    test "add i32, 41, 1", %{ctx: ctx} do
      code = gen_code(Instruction.add(nil, Value.i32(41), Value.i32(1)), ctx)
      assert code == "%0 = add i32 41, 1"
    end

    test "x = add i8, 21, 21", %{ctx: ctx} do
      code = gen_code(Instruction.add("x", Value.i8(21), Value.i8(21)), ctx)
      assert code == "%x = add i8 21, 21"
    end
  end

  describe "Alloca" do
    setup do
      [ctx: IR.Context.new()]
    end

    test "%ptr = alloca i32", %{ctx: ctx} do
      code = gen_code(Instruction.alloca("ptr", Type.i32()), ctx)
      assert code == "%ptr = alloca i32"
    end

    test "%ptr = alloca i32, i32 4", %{ctx: ctx} do
      code = gen_code(Instruction.alloca("ptr", Type.i32(), 4), ctx)
      assert code == "%ptr = alloca i32, i8 4"
    end

    test "count from previous instruction", %{ctx: ctx} do
      load_ins = Instruction.load("n", Type.i32(), Value.local_ref(Type.ptr(), "nptr"))
      count = Value.handle(load_ins)
      alloc_ins = Instruction.alloca("buf", Type.i8(), count)

      ctx_1 = IR.resolve_names(load_ins, ctx)
      ctx_2 = IR.resolve_names(alloc_ins, ctx_1)

      {code, _} = IR.to_ir(alloc_ins, ctx_2)

      assert code == "%buf = alloca i8, i32 %n"
    end
  end

  describe "And" do
    setup do
      [ctx: IR.Context.new()]
    end

    test "and i32 255, 15", %{ctx: ctx} do
      code = gen_code(Instruction.bit_and(nil, Value.i32(255), Value.i32(15)), ctx)
      assert code == "%0 = and i32 255, 15"
    end

    test "x = and i8 21, 21", %{ctx: ctx} do
      code = gen_code(Instruction.bit_and("x", Value.i8(21), Value.i8(21)), ctx)
      assert code == "%x = and i8 21, 21"
    end

    test "raise on type mismatch" do
      assert_raise RuntimeError, fn ->
        Instruction.bit_and("x", Value.i32(1), Value.i8(1))
      end
    end

    test "raise on non-integer operand" do
      assert_raise RuntimeError, fn ->
        Instruction.bit_and("x", Value.float(1.0), Value.float(2.0))
      end
    end
  end

  describe "Ashr" do
    setup do
      [ctx: IR.Context.new()]
    end

    test "ashr i32 -16, 2", %{ctx: ctx} do
      code = gen_code(Instruction.ashr(nil, Value.i32(-16), Value.i32(2)), ctx)
      assert code == "%0 = ashr i32 -16, 2"
    end

    test "x = ashr i8 21, 1", %{ctx: ctx} do
      code = gen_code(Instruction.ashr("x", Value.i8(21), Value.i8(1)), ctx)
      assert code == "%x = ashr i8 21, 1"
    end

    test "raise on type mismatch" do
      assert_raise RuntimeError, fn ->
        Instruction.ashr("x", Value.i32(1), Value.i8(1))
      end
    end

    test "raise on non-integer operand" do
      assert_raise RuntimeError, fn ->
        Instruction.ashr("x", Value.float(1.0), Value.float(2.0))
      end
    end
  end

  describe "BR" do
    setup do
      [ctx: IR.Context.new()]
    end

    test "br label", %{ctx: ctx} do
      code = gen_code(Instruction.br(Label.new("test")), ctx)
      assert code == "br label %test"
    end

    test "br %cond, %IfEqual, %IfUnequal", %{ctx: ctx} do
      code =
        gen_code(
          Instruction.br(
            Value.local_ref(Type.i1(), "cond"),
            Label.new("IfEqual"),
            Label.new("IfUnequal")
          ),
          ctx
        )

      assert code == "br i1 %cond, label %IfEqual, label %IfUnequal"
    end

    test "br %cond, %IfTrue (two-target conditional, no else)", %{ctx: ctx} do
      code =
        gen_code(
          Instruction.br(
            Value.local_ref(Type.i1(), "cond"),
            Label.new("IfTrue")
          ),
          ctx
        )

      assert code == "br i1 %cond, label %IfTrue"
    end
  end

  describe "Call" do
    setup do
      [ctx: IR.Context.new()]
    end

    test "Plain non-void call, explicit dest", %{ctx: ctx} do
      code =
        gen_code(
          Instruction.call(
            "sum",
            Type.function(Type.i32(), [Type.i32(), Type.i32()]),
            Value.global_ref("add"),
            [Value.i32(1), Value.i32(2)]
          ),
          ctx
        )

      assert code == "%sum = call i32 @add(i32 1, i32 2)"
    end

    test "Non-void call, auto-numbered dest", %{ctx: ctx} do
      code =
        gen_code(
          Instruction.call(
            nil,
            Type.function(Type.i32(), [Type.i32()]),
            Value.global_ref("square"),
            [Value.i32(5)]
          ),
          ctx
        )

      assert code == "%0 = call i32 @square(i32 5)"
    end

    test "Void call — no destination at all", %{ctx: ctx} do
      code =
        gen_code(
          Instruction.call(
            nil,
            Type.function(Type.void(), [Type.i32()]),
            Value.global_ref("exit"),
            [Value.i32(0)]
          ),
          ctx
        )

      assert code == "call void @exit(i32 0)"
    end

    test "No-argument call", %{ctx: ctx} do
      code =
        gen_code(
          Instruction.call(
            "x",
            Type.function(Type.i32(), []),
            Value.global_ref("get_value"),
            []
          ),
          ctx
        )

      assert code == "%x = call i32 @get_value()"
    end

    test "Varargs call", %{ctx: ctx} do
      code =
        gen_code(
          Instruction.call(
            "r",
            Type.function(Type.i32(), [Type.ptr()], true),
            Value.global_ref("printf"),
            [Value.global_ref("fmt"), Value.i32(42)]
          ),
          ctx
        )

      assert code == "%r = call i32 (ptr, ...) @printf(ptr @fmt, i32 42)"
    end

    test "Indirect call through a function pointer", %{ctx: ctx} do
      code =
        gen_code(
          Instruction.call(
            "r",
            Type.function(Type.i32(), [Type.i32()]),
            Value.local_ref(Type.ptr(), "fp"),
            [Value.i32(10)]
          ),
          ctx
        )

      assert code == "%r = call i32 %fp(i32 10)"
    end

    test "Raises on wrong arg count" do
      assert_raise RuntimeError, fn ->
        Instruction.call(
          "sum",
          Type.function(Type.i32(), [Type.i32(), Type.i32()]),
          Value.global_ref("add"),
          [Value.i32(1)]
        )
      end

      assert_raise RuntimeError, fn ->
        Instruction.call(
          "sum",
          Type.function(Type.i32(), [Type.i32(), Type.i32()]),
          Value.global_ref("add"),
          [Value.i32(1), Value.i32(2), Value.i32(3)]
        )
      end
    end

    test "Raises on too few args, varargs" do
      assert_raise RuntimeError, fn ->
        Instruction.call(
          "r",
          Type.function(Type.i32(), [Type.ptr()], true),
          Value.global_ref("printf"),
          []
        )
      end
    end

    test "Raises on mismatched argument types" do
      assert_raise RuntimeError, fn ->
        Instruction.call(
          "sum",
          Type.function(Type.i32(), [Type.i32(), Type.i32()]),
          Value.global_ref("add"),
          [Value.i8(1), Value.i32(2)]
        )
      end
    end
  end

  describe "CallASM" do
    setup do
      [ctx: IR.Context.new()]
    end

    test "Non-void asm call — os_write syscall shape", %{ctx: ctx} do
      code =
        gen_code(
          Instruction.call_asm(
            "ret",
            Type.function(Type.i64(), [Type.i64(), Type.i64(), Type.ptr(), Type.i64()]),
            "svc 0",
            "={x0},{x8},{x0},{x1},{x2},~{memory},~{cc}",
            [
              Value.i64(64),
              Value.local_ref(Type.i64(), "fd"),
              Value.local_ref(Type.ptr(), "buf"),
              Value.local_ref(Type.i64(), "len")
            ],
            sideeffect: true
          ),
          ctx
        )

      assert code ==
               ~s[%ret = call i64 asm sideeffect "svc 0", "={x0},{x8},{x0},{x1},{x2},~{memory},~{cc}"(i64 64, i64 %fd, ptr %buf, i64 %len)]
    end

    test "Void asm call — no destination at all", %{ctx: ctx} do
      code =
        gen_code(
          Instruction.call_asm(
            nil,
            Type.function(Type.void(), [Type.i64()]),
            "svc 0",
            "{x0}",
            [Value.i64(0)],
            sideeffect: true
          ),
          ctx
        )

      assert code == ~s[call void asm sideeffect "svc 0", "{x0}"(i64 0)]
    end

    test "Result flows into a following instruction, like os_mem_reserve_commit's inttoptr", %{
      ctx: ctx
    } do
      asm_ins =
        Instruction.call_asm(
          nil,
          Type.function(Type.i64(), [Type.i64()]),
          "svc 0",
          "={x0},{x0},~{memory},~{cc}",
          [Value.i64(9)],
          sideeffect: true
        )

      ptr_ins = Instruction.int_to_ptr("ptr", Value.handle(asm_ins))

      ctx_1 = IR.resolve_names(asm_ins, ctx)
      ctx_2 = IR.resolve_names(ptr_ins, ctx_1)

      {code, _} = IR.to_ir(ptr_ins, ctx_2)

      assert code == "%ptr = inttoptr i64 %0 to ptr"
    end

    test "Raises on an unknown option" do
      assert_raise RuntimeError, fn ->
        Instruction.call_asm(
          nil,
          Type.function(Type.i64(), []),
          "svc 0",
          "={x0}",
          [],
          garbage: true
        )
      end
    end

    test "Raises on wrong arg count" do
      assert_raise RuntimeError, fn ->
        Instruction.call_asm(
          nil,
          Type.function(Type.i64(), [Type.i64()]),
          "svc 0",
          "={x0},{x0}",
          [],
          sideeffect: true
        )
      end
    end
  end

  describe "Fadd" do
    setup do
      [ctx: IR.Context.new()]
    end

    test "fadd float 1.5, 2.5", %{ctx: ctx} do
      code = gen_code(Instruction.fadd(nil, Value.float(1.5), Value.float(2.5)), ctx)
      assert code == "%0 = fadd float 0x3ff8000000000000, 0x4004000000000000"
    end

    test "x = fadd double 1.0, 2.0", %{ctx: ctx} do
      code = gen_code(Instruction.fadd("x", Value.double(1.0), Value.double(2.0)), ctx)
      assert code == "%x = fadd double 0x3ff0000000000000, 0x4000000000000000"
    end

    test "raise on type mismatch" do
      assert_raise RuntimeError, fn ->
        Instruction.fadd("x", Value.float(1.0), Value.double(2.0))
      end
    end

    test "raise on non-float operand" do
      assert_raise RuntimeError, fn ->
        Instruction.fadd("x", Value.i32(1), Value.i32(2))
      end
    end
  end

  describe "Fsub" do
    setup do
      [ctx: IR.Context.new()]
    end

    test "fsub float 1.5, 2.5", %{ctx: ctx} do
      code = gen_code(Instruction.fsub(nil, Value.float(1.5), Value.float(2.5)), ctx)
      assert code == "%0 = fsub float 0x3ff8000000000000, 0x4004000000000000"
    end

    test "x = fsub double 1.0, 2.0", %{ctx: ctx} do
      code = gen_code(Instruction.fsub("x", Value.double(1.0), Value.double(2.0)), ctx)
      assert code == "%x = fsub double 0x3ff0000000000000, 0x4000000000000000"
    end

    test "raise on type mismatch" do
      assert_raise RuntimeError, fn ->
        Instruction.fsub("x", Value.float(1.0), Value.double(2.0))
      end
    end

    test "raise on non-float operand" do
      assert_raise RuntimeError, fn ->
        Instruction.fsub("x", Value.i32(1), Value.i32(2))
      end
    end
  end

  describe "Fneg" do
    setup do
      [ctx: IR.Context.new()]
    end

    test "fneg float 1.5", %{ctx: ctx} do
      code = gen_code(Instruction.fneg(nil, Value.float(1.5)), ctx)
      assert code == "%0 = fneg float 0x3ff8000000000000"
    end

    test "x = fneg double 1.0", %{ctx: ctx} do
      code = gen_code(Instruction.fneg("x", Value.double(1.0)), ctx)
      assert code == "%x = fneg double 0x3ff0000000000000"
    end

    test "raise on non-float operand" do
      assert_raise RuntimeError, fn ->
        Instruction.fneg("x", Value.i32(1))
      end
    end
  end

  describe "Fmul" do
    setup do
      [ctx: IR.Context.new()]
    end

    test "fmul float 1.5, 2.5", %{ctx: ctx} do
      code = gen_code(Instruction.fmul(nil, Value.float(1.5), Value.float(2.5)), ctx)
      assert code == "%0 = fmul float 0x3ff8000000000000, 0x4004000000000000"
    end

    test "x = fmul double 1.0, 2.0", %{ctx: ctx} do
      code = gen_code(Instruction.fmul("x", Value.double(1.0), Value.double(2.0)), ctx)
      assert code == "%x = fmul double 0x3ff0000000000000, 0x4000000000000000"
    end

    test "raise on type mismatch" do
      assert_raise RuntimeError, fn ->
        Instruction.fmul("x", Value.float(1.0), Value.double(2.0))
      end
    end

    test "raise on non-float operand" do
      assert_raise RuntimeError, fn ->
        Instruction.fmul("x", Value.i32(1), Value.i32(2))
      end
    end
  end

  describe "Fdiv" do
    setup do
      [ctx: IR.Context.new()]
    end

    test "fdiv float 1.5, 2.5", %{ctx: ctx} do
      code = gen_code(Instruction.fdiv(nil, Value.float(1.5), Value.float(2.5)), ctx)
      assert code == "%0 = fdiv float 0x3ff8000000000000, 0x4004000000000000"
    end

    test "x = fdiv double 1.0, 2.0", %{ctx: ctx} do
      code = gen_code(Instruction.fdiv("x", Value.double(1.0), Value.double(2.0)), ctx)
      assert code == "%x = fdiv double 0x3ff0000000000000, 0x4000000000000000"
    end

    test "raise on type mismatch" do
      assert_raise RuntimeError, fn ->
        Instruction.fdiv("x", Value.float(1.0), Value.double(2.0))
      end
    end

    test "raise on non-float operand" do
      assert_raise RuntimeError, fn ->
        Instruction.fdiv("x", Value.i32(1), Value.i32(2))
      end
    end
  end

  describe "Frem" do
    setup do
      [ctx: IR.Context.new()]
    end

    test "frem float 1.5, 2.5", %{ctx: ctx} do
      code = gen_code(Instruction.frem(nil, Value.float(1.5), Value.float(2.5)), ctx)
      assert code == "%0 = frem float 0x3ff8000000000000, 0x4004000000000000"
    end

    test "x = frem double 1.0, 2.0", %{ctx: ctx} do
      code = gen_code(Instruction.frem("x", Value.double(1.0), Value.double(2.0)), ctx)
      assert code == "%x = frem double 0x3ff0000000000000, 0x4000000000000000"
    end

    test "raise on type mismatch" do
      assert_raise RuntimeError, fn ->
        Instruction.frem("x", Value.float(1.0), Value.double(2.0))
      end
    end

    test "raise on non-float operand" do
      assert_raise RuntimeError, fn ->
        Instruction.frem("x", Value.i32(1), Value.i32(2))
      end
    end
  end

  describe "Fcmp" do
    setup do
      [ctx: IR.Context.new()]
    end

    test "fcmp oeq float 1.5, 2.5", %{ctx: ctx} do
      code = gen_code(Instruction.fcmp(nil, :oeq, Value.float(1.5), Value.float(2.5)), ctx)
      assert code == "%0 = fcmp oeq float 0x3ff8000000000000, 0x4004000000000000"
    end

    test "x = fcmp une double 1.0, 2.0", %{ctx: ctx} do
      code = gen_code(Instruction.fcmp("x", :une, Value.double(1.0), Value.double(2.0)), ctx)
      assert code == "%x = fcmp une double 0x3ff0000000000000, 0x4000000000000000"
    end

    test "raise on type mismatch" do
      assert_raise RuntimeError, fn ->
        Instruction.fcmp("x", :oeq, Value.float(1.0), Value.double(2.0))
      end
    end

    test "raise on non-float operand" do
      assert_raise RuntimeError, fn ->
        Instruction.fcmp("x", :oeq, Value.i32(1), Value.i32(2))
      end
    end
  end

  describe "Fptrunc" do
    setup do
      [ctx: IR.Context.new()]
    end

    test "narrow double to float, explicit dest", %{ctx: ctx} do
      code = gen_code(Instruction.fptrunc("y", Value.double(1.5), Type.float()), ctx)
      assert code == "%y = fptrunc double 0x3ff8000000000000 to float"
    end

    test "auto-numbered dest", %{ctx: ctx} do
      code = gen_code(Instruction.fptrunc(nil, Value.double(3.0), Type.float()), ctx)
      assert code == "%0 = fptrunc double 0x4008000000000000 to float"
    end

    test "raise on same width" do
      assert_raise RuntimeError, fn ->
        Instruction.fptrunc("x", Value.double(1.0), Type.double())
      end
    end

    test "raise on widening" do
      assert_raise RuntimeError, fn ->
        Instruction.fptrunc("x", Value.float(1.0), Type.double())
      end
    end

    test "raise on non-float source" do
      assert_raise RuntimeError, fn ->
        Instruction.fptrunc("x", Value.i32(1), Type.float())
      end
    end

    test "raise on non-float target" do
      assert_raise RuntimeError, fn ->
        Instruction.fptrunc("x", Value.double(1.0), Type.i32())
      end
    end
  end

  describe "Fpext" do
    setup do
      [ctx: IR.Context.new()]
    end

    test "widen float to double, explicit dest", %{ctx: ctx} do
      code = gen_code(Instruction.fpext("y", Value.float(1.5), Type.double()), ctx)
      assert code == "%y = fpext float 0x3ff8000000000000 to double"
    end

    test "auto-numbered dest", %{ctx: ctx} do
      code = gen_code(Instruction.fpext(nil, Value.half(2.0), Type.double()), ctx)
      assert code == "%0 = fpext half 0x4000000000000000 to double"
    end

    test "raise on same width" do
      assert_raise RuntimeError, fn ->
        Instruction.fpext("x", Value.float(1.0), Type.float())
      end
    end

    test "raise on narrowing" do
      assert_raise RuntimeError, fn ->
        Instruction.fpext("x", Value.double(1.0), Type.float())
      end
    end

    test "raise on non-float source" do
      assert_raise RuntimeError, fn ->
        Instruction.fpext("x", Value.i32(1), Type.double())
      end
    end

    test "raise on non-float target" do
      assert_raise RuntimeError, fn ->
        Instruction.fpext("x", Value.float(1.0), Type.i32())
      end
    end
  end

  describe "Fptosi" do
    setup do
      [ctx: IR.Context.new()]
    end

    test "fptosi double to i32, explicit dest", %{ctx: ctx} do
      code = gen_code(Instruction.fptosi("y", Value.double(3.9), Type.i32()), ctx)
      assert code == "%y = fptosi double 0x400f333333333333 to i32"
    end

    test "auto-numbered dest", %{ctx: ctx} do
      code = gen_code(Instruction.fptosi(nil, Value.float(1.5), Type.i8()), ctx)
      assert code == "%0 = fptosi float 0x3ff8000000000000 to i8"
    end

    test "raise on non-float source" do
      assert_raise RuntimeError, fn ->
        Instruction.fptosi("x", Value.i32(1), Type.i32())
      end
    end

    test "raise on non-integer target" do
      assert_raise RuntimeError, fn ->
        Instruction.fptosi("x", Value.double(1.0), Type.float())
      end
    end
  end

  describe "Fptoui" do
    setup do
      [ctx: IR.Context.new()]
    end

    test "fptoui float to i8, explicit dest", %{ctx: ctx} do
      code = gen_code(Instruction.fptoui("y", Value.float(4.0), Type.i8()), ctx)
      assert code == "%y = fptoui float 0x4010000000000000 to i8"
    end

    test "auto-numbered dest", %{ctx: ctx} do
      code = gen_code(Instruction.fptoui(nil, Value.double(2.0), Type.i32()), ctx)
      assert code == "%0 = fptoui double 0x4000000000000000 to i32"
    end

    test "raise on non-float source" do
      assert_raise RuntimeError, fn ->
        Instruction.fptoui("x", Value.i32(1), Type.i32())
      end
    end

    test "raise on non-integer target" do
      assert_raise RuntimeError, fn ->
        Instruction.fptoui("x", Value.double(1.0), Type.float())
      end
    end
  end

  describe "Freeze" do
    setup do
      [ctx: IR.Context.new()]
    end

    test "freeze i32 41, explicit dest", %{ctx: ctx} do
      code = gen_code(Instruction.freeze("x", Value.i32(41)), ctx)
      assert code == "%x = freeze i32 41"
    end

    test "auto-numbered dest", %{ctx: ctx} do
      code = gen_code(Instruction.freeze(nil, Value.float(1.5)), ctx)
      assert code == "%0 = freeze float 0x3ff8000000000000"
    end

    test "freeze a poison value", %{ctx: ctx} do
      code = gen_code(Instruction.freeze("x", Value.poison(Type.i32())), ctx)
      assert code == "%x = freeze i32 poison"
    end

    test "freeze an undef value", %{ctx: ctx} do
      code = gen_code(Instruction.freeze("x", Value.undef(Type.double())), ctx)
      assert code == "%x = freeze double undef"
    end

    test "freeze a pointer value", %{ctx: ctx} do
      code = gen_code(Instruction.freeze("p", Value.local_ref(Type.ptr(), "raw")), ctx)
      assert code == "%p = freeze ptr %raw"
    end

    test "freeze a handle from a previous instruction", %{ctx: ctx} do
      add_ins = Instruction.add(nil, Value.i32(1), Value.i32(2))
      ctx_1 = IR.resolve_names(add_ins, ctx)
      handle = Value.handle(add_ins)

      freeze_ins = Instruction.freeze("safe", handle)
      code = gen_code(freeze_ins, ctx_1)

      assert code == "%safe = freeze i32 %0"
    end
  end

  describe "GetElementPtr" do
    setup do
      [ctx: IR.Context.new()]
    end

    test "single index into a pointer", %{ctx: ctx} do
      code =
        gen_code(
          Instruction.get_element_ptr("next", Type.i32(), Value.local_ref(Type.ptr(), "p"), [
            Value.i32(5)
          ]),
          ctx
        )

      assert code == "%next = getelementptr i32, ptr %p, i32 5"
    end

    test "auto numbered dest", %{ctx: ctx} do
      code =
        gen_code(
          Instruction.get_element_ptr(nil, Type.i32(), Value.local_ref(Type.ptr(), "p"), [
            Value.i32(0)
          ]),
          ctx
        )

      assert code == "%0 = getelementptr i32, ptr %p, i32 0"
    end

    test "indexing into array", %{ctx: ctx} do
      code =
        gen_code(
          Instruction.get_element_ptr(
            "elem",
            Type.array(Type.i8(), 10),
            Value.local_ref(Type.ptr(), "s"),
            [Value.i32(0), Value.i32(3)]
          ),
          ctx
        )

      assert code == "%elem = getelementptr [10 x i8], ptr %s, i32 0, i32 3"
    end

    test "indexing into a struct field", %{ctx: ctx} do
      code =
        gen_code(
          Instruction.get_element_ptr(
            "field",
            Type.struct([Type.i32(), Type.i8()]),
            Value.local_ref(Type.ptr(), "s"),
            [Value.i32(0), Value.i32(1)]
          ),
          ctx
        )

      assert code == "%field = getelementptr {i32, i8}, ptr %s, i32 0, i32 1"
    end

    test "indexing into a named struct field", %{ctx: ctx} do
      point = Type.named_struct("Point", [Type.i32(), Type.i32()])

      code =
        gen_code(
          Instruction.get_element_ptr(
            "y",
            point,
            Value.local_ref(Type.ptr(), "p"),
            [Value.i32(0), Value.i32(1)]
          ),
          ctx
        )

      assert code == "%y = getelementptr %Point, ptr %p, i32 0, i32 1"
    end

    test "inbounds variant", %{ctx: ctx} do
      code =
        gen_code(
          Instruction.get_element_ptr(
            "next",
            Type.i32(),
            Value.local_ref(Type.ptr(), "p"),
            [
              Value.i32(5)
            ],
            inbounds: true
          ),
          ctx
        )

      assert code == "%next = getelementptr inbounds i32, ptr %p, i32 5"
    end

    test "raise when base pointer is not a pointer" do
      assert_raise RuntimeError, fn ->
        Instruction.get_element_ptr("x", Type.i32(), Value.i32(5), [Value.i32(0)])
      end
    end
  end

  describe "Icmp" do
    setup do
      [ctx: IR.Context.new()]
    end

    test "icmp eq 42, 42", %{ctx: ctx} do
      code = gen_code(Instruction.icmp(nil, :eq, Value.i32(42), Value.i32(42)), ctx)
      assert code == "%0 = icmp eq i32 42, 42"
    end

    test "icmp ne ptr %p, %q", %{ctx: ctx} do
      code =
        gen_code(
          Instruction.icmp(
            nil,
            :ne,
            Value.local_ref(Type.ptr(), "p"),
            Value.local_ref(Type.ptr(), "q")
          ),
          ctx
        )

      assert code == "%0 = icmp ne ptr %p, %q"
    end

    test "cannot icmp different types" do
      assert_raise RuntimeError, fn ->
        Instruction.icmp(nil, :eq, Value.i32(42), Value.i8(42))
      end
    end

    test "cannot icmp invalid types" do
      assert_raise RuntimeError, fn ->
        Instruction.icmp(nil, :eq, Value.double(42.0), Value.double(42.0))
      end
    end
  end

  describe "IndirectBr" do
    setup do
      [ctx: IR.Context.new()]
    end

    test "runtime address, two destinations", %{ctx: ctx} do
      code =
        gen_code(
          Instruction.indirect_br(
            Value.local_ref(Type.ptr(), "addr"),
            [Label.new("bb1"), Label.new("bb2")]
          ),
          ctx
        )

      assert code == "indirectbr ptr %addr, [label %bb1, label %bb2]"
    end

    test "blockaddress address, single destination", %{ctx: ctx} do
      function = Value.global_ref("f")
      label = Label.new("entry")

      code = gen_code(Instruction.indirect_br(Value.blockaddress(function, label), [label]), ctx)

      assert code == "indirectbr ptr blockaddress(@f, %entry), [label %entry]"
    end

    test "global_ref address does not raise", %{ctx: ctx} do
      code = gen_code(Instruction.indirect_br(Value.global_ref("table"), [Label.new("bb1")]), ctx)
      assert code == "indirectbr ptr @table, [label %bb1]"
    end

    test "handle (runtime-computed ptr) address does not raise", %{ctx: ctx} do
      load_ins = Instruction.load("addr", Type.ptr(), Value.local_ref(Type.ptr(), "slot"))
      indirect_br_ins = Instruction.indirect_br(Value.handle(load_ins), [Label.new("bb1")])

      ctx_1 = IR.resolve_names(load_ins, ctx)
      ctx_2 = IR.resolve_names(indirect_br_ins, ctx_1)
      {code, _} = IR.to_ir(indirect_br_ins, ctx_2)

      assert code == "indirectbr ptr %addr, [label %bb1]"
    end

    test "raise on non-pointer address type (i32)" do
      assert_raise RuntimeError, fn ->
        Instruction.indirect_br(Value.i32(0), [Label.new("bb1")])
      end
    end

    test "raise on non-pointer address type (float)" do
      assert_raise RuntimeError, fn ->
        Instruction.indirect_br(Value.float(0.0), [Label.new("bb1")])
      end
    end

    test "raise on non-pointer address type (array)" do
      assert_raise RuntimeError, fn ->
        Instruction.indirect_br(
          Value.array(Type.i8(), [Value.i8(1), Value.i8(2)]),
          [Label.new("bb1")]
        )
      end
    end

    test "raise on non-pointer address type (struct)" do
      assert_raise RuntimeError, fn ->
        Instruction.indirect_br(Value.struct([Value.i8(1)]), [Label.new("bb1")])
      end
    end

    test "raise when no destinations given" do
      assert_raise RuntimeError, fn ->
        Instruction.indirect_br(Value.local_ref(Type.ptr(), "addr"), [])
      end
    end

    test "raise when a destination is not a label" do
      assert_raise RuntimeError, fn ->
        Instruction.indirect_br(Value.local_ref(Type.ptr(), "addr"), [Value.i32(0)])
      end
    end
  end

  describe "InsertValue" do
    setup do
      [ctx: IR.Context.new()]
    end

    test "insert into struct field, explicit dest", %{ctx: ctx} do
      code =
        gen_code(
          Instruction.insert_value(
            "agg2",
            Value.undef(Type.struct([Type.i32(), Type.float()])),
            Value.i32(1),
            [0]
          ),
          ctx
        )

      assert code == "%agg2 = insertvalue {i32, float} undef, i32 1, 0"
    end

    test "auto-numbered dest", %{ctx: ctx} do
      code =
        gen_code(
          Instruction.insert_value(
            nil,
            Value.undef(Type.struct([Type.i32(), Type.i32()])),
            Value.i32(7),
            [1]
          ),
          ctx
        )

      assert code == "%0 = insertvalue {i32, i32} undef, i32 7, 1"
    end

    test "insert into array element", %{ctx: ctx} do
      code =
        gen_code(
          Instruction.insert_value(
            "arr2",
            Value.undef(Type.array(Type.i8(), 4)),
            Value.i8(9),
            [2]
          ),
          ctx
        )

      assert code == "%arr2 = insertvalue [4 x i8] undef, i8 9, 2"
    end

    test "nested indices into a struct-in-struct", %{ctx: ctx} do
      code =
        gen_code(
          Instruction.insert_value(
            "nested",
            Value.undef(Type.struct([Type.i32(), Type.struct([Type.float(), Type.double()])])),
            Value.double(1.0),
            [1, 1]
          ),
          ctx
        )

      assert code ==
               "%nested = insertvalue {i32, {float, double}} undef, double 0x3ff0000000000000, 1, 1"
    end

    test "replace a field in a constant struct literal", %{ctx: ctx} do
      literal = Value.struct([Value.i32(1), Value.float(2.0)])

      code = gen_code(Instruction.insert_value("agg", literal, Value.i32(99), [0]), ctx)

      assert code ==
               "%agg = insertvalue {i32, float} {i32 1, float 0x4000000000000000}, i32 99, 0"
    end

    test "replace an element in a constant array literal", %{ctx: ctx} do
      literal = Value.array(Type.i8(), [Value.i8(1), Value.i8(2), Value.i8(3)])

      code = gen_code(Instruction.insert_value("arr", literal, Value.i8(42), [1]), ctx)

      assert code == "%arr = insertvalue [3 x i8] [i8 1, i8 2, i8 3], i8 42, 1"
    end

    test "aggregate from a previous instruction's handle", %{ctx: ctx} do
      first_ins =
        Instruction.insert_value(
          nil,
          Value.undef(Type.struct([Type.i32(), Type.i32()])),
          Value.i32(1),
          [0]
        )

      ctx_1 = IR.resolve_names(first_ins, ctx)
      handle = Value.handle(first_ins)

      second_ins = Instruction.insert_value("agg", handle, Value.i32(2), [1])
      code = gen_code(second_ins, ctx_1)

      assert code == "%agg = insertvalue {i32, i32} %0, i32 2, 1"
    end

    test "raise on non-aggregate source" do
      assert_raise RuntimeError, fn ->
        Instruction.insert_value("x", Value.i32(5), Value.i32(1), [0])
      end
    end

    test "raise on empty indices" do
      assert_raise RuntimeError, fn ->
        Instruction.insert_value(
          "x",
          Value.undef(Type.struct([Type.i32()])),
          Value.i32(1),
          []
        )
      end
    end

    test "raise on index out of bounds" do
      assert_raise RuntimeError, fn ->
        Instruction.insert_value(
          "x",
          Value.undef(Type.struct([Type.i32(), Type.i32()])),
          Value.i32(1),
          [2]
        )
      end
    end

    test "raise on element type mismatch against a populated struct literal" do
      literal = Value.struct([Value.i32(1), Value.i32(2)])

      assert_raise RuntimeError, fn ->
        Instruction.insert_value("x", literal, Value.i64(1), [0])
      end
    end
  end

  describe "ExtractValue" do
    setup do
      [ctx: IR.Context.new()]
    end

    test "extract struct field, explicit dest", %{ctx: ctx} do
      code =
        gen_code(
          Instruction.extract_value(
            "field",
            Value.undef(Type.struct([Type.i32(), Type.float()])),
            [0]
          ),
          ctx
        )

      assert code == "%field = extractvalue {i32, float} undef, 0"
    end

    test "auto-numbered dest", %{ctx: ctx} do
      code =
        gen_code(
          Instruction.extract_value(
            nil,
            Value.undef(Type.struct([Type.i32(), Type.i32()])),
            [1]
          ),
          ctx
        )

      assert code == "%0 = extractvalue {i32, i32} undef, 1"
    end

    test "extract array element", %{ctx: ctx} do
      code =
        gen_code(
          Instruction.extract_value(
            "elem",
            Value.undef(Type.array(Type.i8(), 4)),
            [2]
          ),
          ctx
        )

      assert code == "%elem = extractvalue [4 x i8] undef, 2"
    end

    test "nested indices into a struct-in-struct", %{ctx: ctx} do
      code =
        gen_code(
          Instruction.extract_value(
            "nested",
            Value.undef(Type.struct([Type.i32(), Type.struct([Type.float(), Type.double()])])),
            [1, 1]
          ),
          ctx
        )

      assert code == "%nested = extractvalue {i32, {float, double}} undef, 1, 1"
    end

    test "extract from a constant struct literal", %{ctx: ctx} do
      literal = Value.struct([Value.i32(1), Value.float(2.0)])

      code = gen_code(Instruction.extract_value("field", literal, [1]), ctx)

      assert code ==
               "%field = extractvalue {i32, float} {i32 1, float 0x4000000000000000}, 1"
    end

    test "extract from a constant array literal", %{ctx: ctx} do
      literal = Value.array(Type.i8(), [Value.i8(1), Value.i8(2), Value.i8(3)])

      code = gen_code(Instruction.extract_value("elem", literal, [1]), ctx)

      assert code == "%elem = extractvalue [3 x i8] [i8 1, i8 2, i8 3], 1"
    end

    test "aggregate from a previous instruction's handle", %{ctx: ctx} do
      first_ins =
        Instruction.insert_value(
          nil,
          Value.undef(Type.struct([Type.i32(), Type.i32()])),
          Value.i32(1),
          [0]
        )

      ctx_1 = IR.resolve_names(first_ins, ctx)
      handle = Value.handle(first_ins)

      second_ins = Instruction.extract_value("field", handle, [1])
      code = gen_code(second_ins, ctx_1)

      assert code == "%field = extractvalue {i32, i32} %0, 1"
    end

    test "extracted handle carries the field type, not the aggregate type", %{ctx: ctx} do
      extract_ins =
        Instruction.extract_value(
          nil,
          Value.undef(Type.struct([Type.i32(), Type.float()])),
          [0]
        )

      ctx_1 = IR.resolve_names(extract_ins, ctx)
      field_handle = Value.handle(extract_ins)

      add_ins = Instruction.add("sum", field_handle, Value.i32(1))
      code = gen_code(add_ins, ctx_1)

      assert code == "%sum = add i32 %0, 1"
    end

    test "raise on non-aggregate source" do
      assert_raise RuntimeError, fn ->
        Instruction.extract_value("x", Value.i32(5), [0])
      end
    end

    test "raise on empty indices" do
      assert_raise RuntimeError, fn ->
        Instruction.extract_value(
          "x",
          Value.undef(Type.struct([Type.i32()])),
          []
        )
      end
    end

    test "raise on index out of bounds" do
      assert_raise RuntimeError, fn ->
        Instruction.extract_value(
          "x",
          Value.undef(Type.struct([Type.i32(), Type.i32()])),
          [2]
        )
      end
    end
  end

  describe "IntToPtr" do
    setup do
      [ctx: IR.Context.new()]
    end

    test "basic conversion, explicit dest", %{ctx: ctx} do
      code = gen_code(Instruction.int_to_ptr("p", Value.i64(4096)), ctx)
      assert code == "%p = inttoptr i64 4096 to ptr"
    end

    test "auto-numbered dest", %{ctx: ctx} do
      code = gen_code(Instruction.int_to_ptr(nil, Value.i32(8)), ctx)
      assert code == "%0 = inttoptr i32 8 to ptr"
    end

    test "raise — non-integer source" do
      assert_raise RuntimeError, fn ->
        Instruction.int_to_ptr(nil, Value.float(42.0))
      end
    end
  end

  describe "Load" do
    setup do
      [ctx: IR.Context.new()]
    end

    test "load i32, ptr %p", %{ctx: ctx} do
      code = gen_code(Instruction.load("x", Type.i32(), Value.local_ref(Type.ptr(), "p")), ctx)
      assert code == "%x = load i32, ptr %p"
    end

    test "load i32, i32 5 raises" do
      assert_raise RuntimeError, fn ->
        Instruction.load("x", Type.i32(), Value.i32(5))
      end
    end
  end

  describe "Lshr" do
    setup do
      [ctx: IR.Context.new()]
    end

    test "lshr i32 16, 2", %{ctx: ctx} do
      code = gen_code(Instruction.lshr(nil, Value.i32(16), Value.i32(2)), ctx)
      assert code == "%0 = lshr i32 16, 2"
    end

    test "x = lshr i8 21, 1", %{ctx: ctx} do
      code = gen_code(Instruction.lshr("x", Value.i8(21), Value.i8(1)), ctx)
      assert code == "%x = lshr i8 21, 1"
    end

    test "raise on type mismatch" do
      assert_raise RuntimeError, fn ->
        Instruction.lshr("x", Value.i32(1), Value.i8(1))
      end
    end

    test "raise on non-integer operand" do
      assert_raise RuntimeError, fn ->
        Instruction.lshr("x", Value.float(1.0), Value.float(2.0))
      end
    end
  end

  describe "Mul" do
    setup do
      [ctx: IR.Context.new()]
    end

    test "mul i32 4, 5", %{ctx: ctx} do
      code = gen_code(Instruction.mul(nil, Value.i32(4), Value.i32(5)), ctx)
      assert code == "%0 = mul i32 4, 5"
    end

    test "x = mul i8 6, 7", %{ctx: ctx} do
      code = gen_code(Instruction.mul("x", Value.i8(6), Value.i8(7)), ctx)
      assert code == "%x = mul i8 6, 7"
    end

    test "raise on type mismatch" do
      assert_raise RuntimeError, fn ->
        Instruction.mul("x", Value.i32(1), Value.i8(1))
      end
    end

    test "raise on non-integer operand" do
      assert_raise RuntimeError, fn ->
        Instruction.mul("x", Value.float(1.0), Value.float(2.0))
      end
    end
  end

  describe "Or" do
    setup do
      [ctx: IR.Context.new()]
    end

    test "or i32 240, 15", %{ctx: ctx} do
      code = gen_code(Instruction.bit_or(nil, Value.i32(240), Value.i32(15)), ctx)
      assert code == "%0 = or i32 240, 15"
    end

    test "x = or i8 21, 21", %{ctx: ctx} do
      code = gen_code(Instruction.bit_or("x", Value.i8(21), Value.i8(21)), ctx)
      assert code == "%x = or i8 21, 21"
    end

    test "raise on type mismatch" do
      assert_raise RuntimeError, fn ->
        Instruction.bit_or("x", Value.i32(1), Value.i8(1))
      end
    end

    test "raise on non-integer operand" do
      assert_raise RuntimeError, fn ->
        Instruction.bit_or("x", Value.float(1.0), Value.float(2.0))
      end
    end
  end

  describe "Phi" do
    setup do
      [ctx: IR.Context.new()]
    end

    test "two incoming values", %{ctx: ctx} do
      entry = Label.new("entry")
      loop = Label.new("loop")

      code =
        gen_code(
          Instruction.phi("x", Type.i32(), [{Value.i32(0), entry}, {Value.i32(1), loop}]),
          ctx
        )

      assert code == "%x = phi i32 [0, %entry], [1, %loop]"
    end

    test "raise on empty incoming" do
      assert_raise RuntimeError, fn ->
        Instruction.phi("x", Type.i32(), [])
      end
    end

    test "raise on type mismatch" do
      assert_raise RuntimeError, fn ->
        Instruction.phi("x", Type.i32(), [{Value.i8(1), Label.new("entry")}])
      end
    end
  end

  describe "PtrToInt" do
    setup do
      [ctx: IR.Context.new()]
    end

    test "basic conversion, explicit dest", %{ctx: ctx} do
      code =
        gen_code(Instruction.ptr_to_int("i", Value.local_ref(Type.ptr(), "p"), Type.i64()), ctx)

      assert code == "%i = ptrtoint ptr %p to i64"
    end

    test "auto-numbered dest", %{ctx: ctx} do
      code =
        gen_code(Instruction.ptr_to_int(nil, Value.local_ref(Type.ptr(), "p"), Type.i32()), ctx)

      assert code == "%0 = ptrtoint ptr %p to i32"
    end

    test "global ref as source", %{ctx: ctx} do
      code = gen_code(Instruction.ptr_to_int("addr", Value.global_ref("g"), Type.i64()), ctx)

      assert code == "%addr = ptrtoint ptr @g to i64"
    end

    test "raise — non-pointer source" do
      assert_raise RuntimeError, fn ->
        Instruction.ptr_to_int("x", Value.i64(42), Type.i8())
      end
    end

    test "raise — non-integer destination" do
      assert_raise RuntimeError, fn ->
        Instruction.ptr_to_int("x", Value.local_ref(Type.ptr(), "p"), Type.float())
      end
    end
  end

  describe "Ret" do
    setup do
      [ctx: IR.Context.new()]
    end

    test "ret void", %{ctx: ctx} do
      assert IR.to_ir(Instruction.ret(Value.void()), ctx) ==
               {"ret void", ctx}
    end

    test "ret i32 42", %{ctx: ctx} do
      assert IR.to_ir(Instruction.ret(Value.i32(42)), ctx) == {"ret i32 42", ctx}
    end
  end

  describe "Sdiv" do
    setup do
      [ctx: IR.Context.new()]
    end

    test "sdiv i32 10, 3", %{ctx: ctx} do
      code = gen_code(Instruction.sdiv(nil, Value.i32(10), Value.i32(3)), ctx)
      assert code == "%0 = sdiv i32 10, 3"
    end

    test "x = sdiv i8 21, 7", %{ctx: ctx} do
      code = gen_code(Instruction.sdiv("x", Value.i8(21), Value.i8(7)), ctx)
      assert code == "%x = sdiv i8 21, 7"
    end

    test "raise on type mismatch" do
      assert_raise RuntimeError, fn ->
        Instruction.sdiv("x", Value.i32(1), Value.i8(1))
      end
    end

    test "raise on non-integer operand" do
      assert_raise RuntimeError, fn ->
        Instruction.sdiv("x", Value.float(1.0), Value.float(2.0))
      end
    end
  end

  describe "Select" do
    setup do
      [ctx: IR.Context.new()]
    end

    test "select i1 1, i32 10, i32 20", %{ctx: ctx} do
      code = gen_code(Instruction.select(nil, Value.i1(1), Value.i32(10), Value.i32(20)), ctx)
      assert code == "%0 = select i1 1, i32 10, i32 20"
    end

    test "x = select i1 0, double 1.0, double 2.0", %{ctx: ctx} do
      code =
        gen_code(
          Instruction.select("x", Value.i1(0), Value.double(1.0), Value.double(2.0)),
          ctx
        )

      assert code == "%x = select i1 0, double 0x3ff0000000000000, double 0x4000000000000000"
    end

    test "raise on non-i1 cond" do
      assert_raise RuntimeError, fn ->
        Instruction.select("x", Value.i32(1), Value.i32(10), Value.i32(20))
      end
    end

    test "raise on if_true/if_false type mismatch" do
      assert_raise RuntimeError, fn ->
        Instruction.select("x", Value.i1(1), Value.i32(10), Value.double(2.0))
      end
    end
  end

  describe "Sext" do
    setup do
      [ctx: IR.Context.new()]
    end

    test "Basic widening, explicit dest", %{ctx: ctx} do
      code = gen_code(Instruction.sext("y", Value.i8(42), Type.i32()), ctx)
      assert code == "%y = sext i8 42 to i32"
    end

    test "Auto-numbered dest", %{ctx: ctx} do
      code = gen_code(Instruction.sext(nil, Value.i16(300), Type.i32()), ctx)
      assert code == "%0 = sext i16 300 to i32"
    end

    test "Widening from i1", %{ctx: ctx} do
      code = gen_code(Instruction.sext("b", Value.i1(1), Type.i8()), ctx)
      assert code == "%b = sext i1 1 to i8"
    end

    test "Widen using a handle src", %{ctx: ctx} do
      add_ins = Instruction.add(nil, Value.i8(1), Value.i8(2))
      ctx_1 = IR.resolve_names(add_ins, ctx)
      handle = Value.handle(add_ins)
      sext_ins = Instruction.sext("w", handle, Type.i32())
      code = gen_code(sext_ins, ctx_1)

      assert code == "%w = sext i8 %0 to i32"
    end

    test "raise same width" do
      assert_raise RuntimeError, fn ->
        Instruction.sext("x", Value.i32(42), Type.i32())
      end
    end

    test "raise narrows" do
      assert_raise RuntimeError, fn ->
        Instruction.sext("x", Value.i32(42), Type.i16())
      end
    end

    test "raise non-integer src" do
      assert_raise RuntimeError, fn ->
        Instruction.sext("x", Value.float(42.0), Type.i8())
      end
    end

    test "raise non-integer target" do
      assert_raise RuntimeError, fn ->
        Instruction.sext("x", Value.i8(42), Type.float())
      end
    end
  end

  describe "Shl" do
    setup do
      [ctx: IR.Context.new()]
    end

    test "shl i32 4, 2", %{ctx: ctx} do
      code = gen_code(Instruction.shl(nil, Value.i32(4), Value.i32(2)), ctx)
      assert code == "%0 = shl i32 4, 2"
    end

    test "x = shl i8 21, 1", %{ctx: ctx} do
      code = gen_code(Instruction.shl("x", Value.i8(21), Value.i8(1)), ctx)
      assert code == "%x = shl i8 21, 1"
    end

    test "raise on type mismatch" do
      assert_raise RuntimeError, fn ->
        Instruction.shl("x", Value.i32(1), Value.i8(1))
      end
    end

    test "raise on non-integer operand" do
      assert_raise RuntimeError, fn ->
        Instruction.shl("x", Value.float(1.0), Value.float(2.0))
      end
    end
  end

  describe "Sitofp" do
    setup do
      [ctx: IR.Context.new()]
    end

    test "sitofp i32 to double, explicit dest", %{ctx: ctx} do
      code = gen_code(Instruction.sitofp("y", Value.i32(-7), Type.double()), ctx)
      assert code == "%y = sitofp i32 -7 to double"
    end

    test "auto-numbered dest", %{ctx: ctx} do
      code = gen_code(Instruction.sitofp(nil, Value.i8(42), Type.float()), ctx)
      assert code == "%0 = sitofp i8 42 to float"
    end

    test "raise on non-integer source" do
      assert_raise RuntimeError, fn ->
        Instruction.sitofp("x", Value.float(1.0), Type.double())
      end
    end

    test "raise on non-float target" do
      assert_raise RuntimeError, fn ->
        Instruction.sitofp("x", Value.i32(1), Type.i32())
      end
    end
  end

  describe "Srem" do
    setup do
      [ctx: IR.Context.new()]
    end

    test "srem i32 10, 3", %{ctx: ctx} do
      code = gen_code(Instruction.srem(nil, Value.i32(10), Value.i32(3)), ctx)
      assert code == "%0 = srem i32 10, 3"
    end

    test "x = srem i8 21, 5", %{ctx: ctx} do
      code = gen_code(Instruction.srem("x", Value.i8(21), Value.i8(5)), ctx)
      assert code == "%x = srem i8 21, 5"
    end

    test "raise on type mismatch" do
      assert_raise RuntimeError, fn ->
        Instruction.srem("x", Value.i32(1), Value.i8(1))
      end
    end

    test "raise on non-integer operand" do
      assert_raise RuntimeError, fn ->
        Instruction.srem("x", Value.float(1.0), Value.float(2.0))
      end
    end
  end

  describe "Store" do
    setup do
      [ctx: IR.Context.new()]
    end

    test "store i32, ptr %p", %{ctx: ctx} do
      assert IR.to_ir(Instruction.store(Value.i32(42), Value.local_ref(Type.ptr(), "p")), ctx) ==
               {"store i32 42, ptr %p", ctx}
    end

    test "store i32 42, i32 1 raises" do
      assert_raise RuntimeError, fn ->
        Instruction.store(Value.i32(42), Value.i32(1))
      end
    end
  end

  describe "Sub" do
    setup do
      [ctx: IR.Context.new()]
    end

    test "sub i32 10, 3", %{ctx: ctx} do
      code = gen_code(Instruction.sub(nil, Value.i32(10), Value.i32(3)), ctx)
      assert code == "%0 = sub i32 10, 3"
    end

    test "x = sub i8 21, 21", %{ctx: ctx} do
      code = gen_code(Instruction.sub("x", Value.i8(21), Value.i8(21)), ctx)
      assert code == "%x = sub i8 21, 21"
    end

    test "raise on type mismatch" do
      assert_raise RuntimeError, fn ->
        Instruction.sub("x", Value.i32(1), Value.i8(1))
      end
    end

    test "raise on non-integer operand" do
      assert_raise RuntimeError, fn ->
        Instruction.sub("x", Value.float(1.0), Value.float(2.0))
      end
    end
  end

  describe "Switch" do
    setup do
      [ctx: IR.Context.new()]
    end

    test "two cases", %{ctx: ctx} do
      code =
        gen_code(
          Instruction.switch(
            Value.local_ref(Type.i32(), "val"),
            Label.new("otherwise"),
            [
              {Value.i32(0), Label.new("onzero")},
              {Value.i32(1), Label.new("onone")}
            ]
          ),
          ctx
        )

      assert code ==
               "switch i32 %val, label %otherwise [i32 0, label %onzero i32 1, label %onone]"
    end

    test "no cases, default only", %{ctx: ctx} do
      code =
        gen_code(
          Instruction.switch(Value.local_ref(Type.i32(), "val"), Label.new("otherwise"), []),
          ctx
        )

      assert code == "switch i32 %val, label %otherwise []"
    end

    test "raise on non-integer value" do
      assert_raise RuntimeError, fn ->
        Instruction.switch(Value.float(1.0), Label.new("otherwise"), [])
      end
    end

    test "raise on case value different type to switch value" do
      assert_raise RuntimeError, fn ->
        Instruction.switch(Value.local_ref(Type.i32(), "val"), Label.new("otherwise"), [
          {Value.i8(0), Label.new("onzero")}
        ])
      end
    end
  end

  describe "Trunc" do
    setup do
      [ctx: IR.Context.new()]
    end

    test "Basic narrowing, explicit dest", %{ctx: ctx} do
      code = gen_code(Instruction.trunc("y", Value.i32(257), Type.i8()), ctx)
      assert code == "%y = trunc i32 257 to i8"
    end

    test "Auto-numbered dest", %{ctx: ctx} do
      code = gen_code(Instruction.trunc(nil, Value.i64(300), Type.i32()), ctx)
      assert code == "%0 = trunc i64 300 to i32"
    end

    test "Narrowing all the way to i1", %{ctx: ctx} do
      code = gen_code(Instruction.trunc("b", Value.i32(1), Type.i1()), ctx)
      assert code == "%b = trunc i32 1 to i1"
    end

    test "Raise — same width" do
      assert_raise RuntimeError, fn ->
        Instruction.trunc("x", Value.i32(42), Type.i32())
      end
    end

    test "Raise — widening" do
      assert_raise RuntimeError, fn ->
        Instruction.trunc("x", Value.i8(42), Type.i16())
      end
    end

    test "Raise — non-integer source" do
      assert_raise RuntimeError, fn ->
        Instruction.trunc("x", Value.float(42.0), Type.i8())
      end
    end

    test "Raise — non-integer target" do
      assert_raise RuntimeError, fn ->
        Instruction.trunc("x", Value.i8(42), Type.float())
      end
    end
  end

  describe "Udiv" do
    setup do
      [ctx: IR.Context.new()]
    end

    test "udiv i32 10, 3", %{ctx: ctx} do
      code = gen_code(Instruction.udiv(nil, Value.i32(10), Value.i32(3)), ctx)
      assert code == "%0 = udiv i32 10, 3"
    end

    test "x = udiv i8 21, 7", %{ctx: ctx} do
      code = gen_code(Instruction.udiv("x", Value.i8(21), Value.i8(7)), ctx)
      assert code == "%x = udiv i8 21, 7"
    end

    test "raise on type mismatch" do
      assert_raise RuntimeError, fn ->
        Instruction.udiv("x", Value.i32(1), Value.i8(1))
      end
    end

    test "raise on non-integer operand" do
      assert_raise RuntimeError, fn ->
        Instruction.udiv("x", Value.float(1.0), Value.float(2.0))
      end
    end
  end

  describe "Uitofp" do
    setup do
      [ctx: IR.Context.new()]
    end

    test "uitofp i8 to float, explicit dest", %{ctx: ctx} do
      code = gen_code(Instruction.uitofp("y", Value.i8(200), Type.float()), ctx)
      assert code == "%y = uitofp i8 200 to float"
    end

    test "auto-numbered dest", %{ctx: ctx} do
      code = gen_code(Instruction.uitofp(nil, Value.i32(42), Type.double()), ctx)
      assert code == "%0 = uitofp i32 42 to double"
    end

    test "raise on non-integer source" do
      assert_raise RuntimeError, fn ->
        Instruction.uitofp("x", Value.float(1.0), Type.double())
      end
    end

    test "raise on non-float target" do
      assert_raise RuntimeError, fn ->
        Instruction.uitofp("x", Value.i32(1), Type.i32())
      end
    end
  end

  describe "Unreachable" do
    setup do
      [ctx: IR.Context.new()]
    end

    test "unreachable", %{ctx: ctx} do
      assert IR.to_ir(Instruction.unreachable(), ctx) == {"unreachable", ctx}
    end

    test "resolve_names is a no-op", %{ctx: ctx} do
      assert IR.resolve_names(Instruction.unreachable(), ctx) == ctx
    end
  end

  describe "Urem" do
    setup do
      [ctx: IR.Context.new()]
    end

    test "urem i32 10, 3", %{ctx: ctx} do
      code = gen_code(Instruction.urem(nil, Value.i32(10), Value.i32(3)), ctx)
      assert code == "%0 = urem i32 10, 3"
    end

    test "x = urem i8 21, 5", %{ctx: ctx} do
      code = gen_code(Instruction.urem("x", Value.i8(21), Value.i8(5)), ctx)
      assert code == "%x = urem i8 21, 5"
    end

    test "raise on type mismatch" do
      assert_raise RuntimeError, fn ->
        Instruction.urem("x", Value.i32(1), Value.i8(1))
      end
    end

    test "raise on non-integer operand" do
      assert_raise RuntimeError, fn ->
        Instruction.urem("x", Value.float(1.0), Value.float(2.0))
      end
    end
  end

  describe "Xor" do
    setup do
      [ctx: IR.Context.new()]
    end

    test "xor i32 255, 15", %{ctx: ctx} do
      code = gen_code(Instruction.bit_xor(nil, Value.i32(255), Value.i32(15)), ctx)
      assert code == "%0 = xor i32 255, 15"
    end

    test "x = xor i8 21, 21", %{ctx: ctx} do
      code = gen_code(Instruction.bit_xor("x", Value.i8(21), Value.i8(21)), ctx)
      assert code == "%x = xor i8 21, 21"
    end

    test "raise on type mismatch" do
      assert_raise RuntimeError, fn ->
        Instruction.bit_xor("x", Value.i32(1), Value.i8(1))
      end
    end

    test "raise on non-integer operand" do
      assert_raise RuntimeError, fn ->
        Instruction.bit_xor("x", Value.float(1.0), Value.float(2.0))
      end
    end
  end

  describe "Zext" do
    setup do
      [ctx: IR.Context.new()]
    end

    test "Basic widening, explicit dest", %{ctx: ctx} do
      code = gen_code(Instruction.zext("y", Value.i8(42), Type.i32()), ctx)
      assert code == "%y = zext i8 42 to i32"
    end

    test "Auto-numbered dest", %{ctx: ctx} do
      code = gen_code(Instruction.zext(nil, Value.i16(300), Type.i32()), ctx)
      assert code == "%0 = zext i16 300 to i32"
    end

    test "Widening from i1", %{ctx: ctx} do
      code = gen_code(Instruction.zext("b", Value.i1(1), Type.i8()), ctx)
      assert code == "%b = zext i1 1 to i8"
    end

    test "Widen using a handle src", %{ctx: ctx} do
      add_ins = Instruction.add(nil, Value.i8(1), Value.i8(2))
      ctx_1 = IR.resolve_names(add_ins, ctx)
      handle = Value.handle(add_ins)
      zext_ins = Instruction.zext("w", handle, Type.i32())
      code = gen_code(zext_ins, ctx_1)

      assert code == "%w = zext i8 %0 to i32"
    end

    test "raise same width" do
      assert_raise RuntimeError, fn ->
        Instruction.zext("x", Value.i32(42), Type.i32())
      end
    end

    test "raise narrows" do
      assert_raise RuntimeError, fn ->
        Instruction.zext("x", Value.i32(42), Type.i16())
      end
    end

    test "raise non-integer src" do
      assert_raise RuntimeError, fn ->
        Instruction.zext("x", Value.float(42.0), Type.i8())
      end
    end

    test "raise non-integer target" do
      assert_raise RuntimeError, fn ->
        Instruction.zext("x", Value.i8(42), Type.float())
      end
    end
  end
end
