defmodule Wyvern.Instruction do
  @moduledoc """
  The modules in this namespace represent the LLVM instruction set.
  """

  alias Wyvern.Instruction.{
    Add,
    Alloca,
    And,
    Ashr,
    BR,
    Call,
    CallASM,
    ExtractValue,
    Fadd,
    Fcmp,
    Fdiv,
    Fmul,
    Fneg,
    Fpext,
    Fptosi,
    Fptoui,
    Fptrunc,
    Freeze,
    Frem,
    Fsub,
    GetElementPtr,
    Icmp,
    IndirectBr,
    InsertValue,
    IntToPtr,
    Load,
    Lshr,
    Mul,
    Or,
    Phi,
    PtrToInt,
    Ret,
    Sdiv,
    Select,
    Sext,
    Shl,
    Sitofp,
    Srem,
    Store,
    Sub,
    Switch,
    Trunc,
    Udiv,
    Uitofp,
    Unreachable,
    Urem,
    Xor,
    Zext
  }

  def add(dest, op1, op2), do: Add.new(dest, op1, op2)

  def alloca(dest, type, count \\ 1), do: Alloca.new(dest, type, count)

  def bit_and(dest, op1, op2), do: And.new(dest, op1, op2)

  def ashr(dest, op1, op2), do: Ashr.new(dest, op1, op2)

  def br(label), do: BR.unconditional(label)
  def br(cond, if_true), do: BR.conditional(cond, if_true)
  def br(cond, if_true, if_false), do: BR.conditional(cond, if_true, if_false)

  def call(dest, fn_type, fn_ref, args), do: Call.new(dest, fn_type, fn_ref, args)

  def call_asm(dest, fn_type, asm, constraints, args, opts),
    do: CallASM.new(dest, fn_type, asm, constraints, args, opts)

  def extract_value(dest, aggregate, index_list),
    do: ExtractValue.new(dest, aggregate, index_list)

  def fadd(dest, op1, op2), do: Fadd.new(dest, op1, op2)

  def fsub(dest, op1, op2), do: Fsub.new(dest, op1, op2)

  def fmul(dest, op1, op2), do: Fmul.new(dest, op1, op2)

  def fneg(dest, src), do: Fneg.new(dest, src)

  def fdiv(dest, op1, op2), do: Fdiv.new(dest, op1, op2)

  def frem(dest, op1, op2), do: Frem.new(dest, op1, op2)

  def fcmp(dest, operation, op1, op2), do: Fcmp.new(dest, operation, op1, op2)

  def fptrunc(dest, src, to_type), do: Fptrunc.new(dest, src, to_type)

  def fpext(dest, src, to_type), do: Fpext.new(dest, src, to_type)

  def fptosi(dest, src, to_type), do: Fptosi.new(dest, src, to_type)

  def fptoui(dest, src, to_type), do: Fptoui.new(dest, src, to_type)

  def freeze(dest, src), do: Freeze.new(dest, src)

  def get_element_ptr(dest, type, source, indices, opts \\ []) when is_list(indices),
    do: GetElementPtr.new(dest, type, source, indices, opts)

  def icmp(dest, operation, op1, op2), do: Icmp.new(dest, operation, op1, op2)

  def indirect_br(address, destinations), do: IndirectBr.new(address, destinations)

  def insert_value(dest, aggregate, value, index_list),
    do: InsertValue.new(dest, aggregate, value, index_list)

  def int_to_ptr(dest, src), do: IntToPtr.new(dest, src)

  def load(dest, type, src), do: Load.new(dest, type, src)

  def lshr(dest, op1, op2), do: Lshr.new(dest, op1, op2)

  def mul(dest, op1, op2), do: Mul.new(dest, op1, op2)

  def bit_or(dest, op1, op2), do: Or.new(dest, op1, op2)

  def phi(dest, type, incoming) when is_list(incoming), do: Phi.new(dest, type, incoming)

  def ptr_to_int(dest, src, to_type), do: PtrToInt.new(dest, src, to_type)

  def ret(value), do: Ret.new(value)

  def sdiv(dest, op1, op2), do: Sdiv.new(dest, op1, op2)

  def select(dest, cond, if_true, if_false), do: Select.new(dest, cond, if_true, if_false)

  def sext(dest, src, to_type), do: Sext.new(dest, src, to_type)

  def shl(dest, op1, op2), do: Shl.new(dest, op1, op2)

  def sitofp(dest, src, to_type), do: Sitofp.new(dest, src, to_type)

  def srem(dest, op1, op2), do: Srem.new(dest, op1, op2)

  def store(value, dest), do: Store.new(value, dest)

  def sub(dest, op1, op2), do: Sub.new(dest, op1, op2)

  def switch(value, default_label, cases), do: Switch.new(value, default_label, cases)

  def trunc(dest, src, to_type), do: Trunc.new(dest, src, to_type)

  def udiv(dest, op1, op2), do: Udiv.new(dest, op1, op2)

  def uitofp(dest, src, to_type), do: Uitofp.new(dest, src, to_type)

  def urem(dest, op1, op2), do: Urem.new(dest, op1, op2)

  def unreachable(), do: Unreachable.new()

  def bit_xor(dest, op1, op2), do: Xor.new(dest, op1, op2)

  def zext(dest, src, to_type), do: Zext.new(dest, src, to_type)

  @doc """
  Returns true if this instruction is a "terminator" that legally ends an LLVM block.
  """
  def terminator?(%BR{}), do: true
  def terminator?(%IndirectBr{}), do: true
  def terminator?(%Ret{}), do: true
  def terminator?(%Switch{}), do: true
  def terminator?(%Unreachable{}), do: true
  def terminator?(_), do: false

  @type t ::
          Add.t()
          | Alloca.t()
          | And.t()
          | Ashr.t()
          | BR.t()
          | Call.t()
          | CallASM.t()
          | Fadd.t()
          | Fcmp.t()
          | Fdiv.t()
          | Fmul.t()
          | Fneg.t()
          | Fpext.t()
          | Fptosi.t()
          | Fptoui.t()
          | Fptrunc.t()
          | Frem.t()
          | Fsub.t()
          | ExtractValue.t()
          | Freeze.t()
          | GetElementPtr.t()
          | Icmp.t()
          | IndirectBr.t()
          | InsertValue.t()
          | IntToPtr.t()
          | Load.t()
          | Lshr.t()
          | Mul.t()
          | Or.t()
          | Phi.t()
          | PtrToInt.t()
          | Ret.t()
          | Sdiv.t()
          | Select.t()
          | Sext.t()
          | Shl.t()
          | Sitofp.t()
          | Srem.t()
          | Store.t()
          | Sub.t()
          | Switch.t()
          | Trunc.t()
          | Udiv.t()
          | Uitofp.t()
          | Unreachable.t()
          | Urem.t()
          | Xor.t()
          | Zext.t()
end
