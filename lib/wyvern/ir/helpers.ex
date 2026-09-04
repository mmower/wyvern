defmodule Wyvern.IR.Helpers do
  @moduledoc """
  Shared `Wyvern.IR` implementation bodies.

  Several families of term serialise the same way apart from one detail — a
  mnemonic, a conversion target — and values render either typed or bare
  depending on syntactic position. These helpers hold those shared bodies so
  each `defimpl Wyvern.IR` states only what is particular to it.

  They pattern match on the fields they need rather than on a specific struct,
  since protocol dispatch has already established the type by the time a helper
  is called.
  """

  alias Wyvern.IR
  alias Wyvern.IROperand

  @doc """
  Renders `%dest = <mnemonic> <type> <op1>, <op2>`.

  This is the shape shared by the integer, float and bitwise binary operations,
  where both operands are of the same type and that type is written once.
  """
  @spec binary_op(String.t(), struct(), IR.Context.t()) :: {String.t(), IR.Context.t()}
  def binary_op(mnemonic, %{id: id, op1: op1, op2: op2}, %IR.Context{} = ctx)
      when is_binary(mnemonic) do
    dest_str = IR.Context.lookup_id(ctx, id)
    {type_str, ctx_1} = IR.to_ir(op1.type, ctx)
    {op1_str, ctx_2} = IROperand.to_operand(op1, ctx_1)
    {op2_str, ctx_3} = IROperand.to_operand(op2, ctx_2)
    {"%#{dest_str} = #{mnemonic} #{type_str} #{op1_str}, #{op2_str}", ctx_3}
  end

  @doc """
  Renders `%dest = <mnemonic> <src> to <to_type>`, taking the target type from the
  instruction's own `:to_type` field.

  This is the shape shared by the conversion operations.
  """
  @spec conversion_op(String.t(), struct(), IR.Context.t()) :: {String.t(), IR.Context.t()}
  def conversion_op(mnemonic, %{to_type: to_type} = instruction, %IR.Context{} = ctx) do
    conversion_op(mnemonic, instruction, to_type, ctx)
  end

  @doc """
  Renders `%dest = <mnemonic> <src> to <to_type>` against an explicitly supplied
  target type.

  Used by conversions whose target is fixed by the instruction rather than carried
  on the struct, such as `inttoptr`, which always converts to `ptr`.
  """
  @spec conversion_op(String.t(), struct(), Wyvern.Type.t(), IR.Context.t()) ::
          {String.t(), IR.Context.t()}
  def conversion_op(mnemonic, %{id: id, src: src}, to_type, %IR.Context{} = ctx)
      when is_binary(mnemonic) do
    dest_str = IR.Context.lookup_id(ctx, id)
    {src_str, ctx_1} = IR.to_ir(src, ctx)
    {type_str, ctx_2} = IR.to_ir(to_type, ctx_1)
    {"%#{dest_str} = #{mnemonic} #{src_str} to #{type_str}", ctx_2}
  end

  @doc """
  The typed form of a value: its type, followed by its bare operand form.

  LLVM writes a value either with its type (`i32 5`) or bare (`5`), depending on
  where it appears. `Wyvern.IROperand` renders the bare form; this derives the
  typed form from it, so the two renderings of a value cannot drift apart.
  """
  @spec typed_operand(struct(), IR.Context.t()) :: {String.t(), IR.Context.t()}
  def typed_operand(%{type: type} = value, %IR.Context{} = ctx) do
    {type_str, ctx_1} = IR.to_ir(type, ctx)
    {operand_str, ctx_2} = IROperand.to_operand(value, ctx_1)
    {"#{type_str} #{operand_str}", ctx_2}
  end

  @doc """
  The `resolve_names/2` body shared by every instruction that binds a destination.
  """
  @spec resolve_dest(struct(), IR.Context.t()) :: IR.Context.t()
  def resolve_dest(%{id: id, dest: dest}, %IR.Context{} = ctx) do
    IR.Context.map_id_to_name(ctx, id, dest)
  end
end
