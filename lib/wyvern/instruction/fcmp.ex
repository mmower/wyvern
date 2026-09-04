defmodule Wyvern.Instruction.Fcmp do
  @mnemonic "fcmp"
  alias Wyvern.Instruction.Types
  alias Wyvern.Type
  alias Wyvern.Value

  @type operation :: atom()
  @type operand :: Value.t()
  @type t :: %__MODULE__{
          id: reference(),
          dest: Types.destination(),
          operation: operation(),
          op1: operand(),
          op2: operand()
        }
  defstruct [:id, :dest, :operation, :op1, :op2]

  @legal_ops [
    false,
    :oeq,
    :ogt,
    :oge,
    :olt,
    :ole,
    :one,
    :ord,
    :ueq,
    :ugt,
    :uge,
    :ult,
    :ule,
    :une,
    :uno,
    true
  ]

  @spec new(Types.destination(), operation(), operand(), operand()) :: __MODULE__.t()
  def new(dest, operation, op1, op2) when operation in @legal_ops do
    unless Type.float?(op1.type),
      do: raise("fcmp - operand-1 must be float typed, got #{inspect(op1.type)}!")

    unless Type.float?(op2.type),
      do: raise("fcmp - operand-2 must be float typed, got #{inspect(op2.type)}!")

    if op1.type != op2.type, do: raise("Unsupported attempt to mix types in fcmp!")

    %__MODULE__{
      id: make_ref(),
      dest: dest,
      operation: operation,
      op1: op1,
      op2: op2
    }
  end

  @doc """
  The LLVM mnemonic this instruction serialises to.
  """
  @spec mnemonic() :: String.t()
  def mnemonic, do: @mnemonic
end

defimpl Wyvern.IR, for: Wyvern.Instruction.Fcmp do
  alias Wyvern.IR
  alias Wyvern.IROperand
  alias Wyvern.Instruction

  def to_ir(
        %Instruction.Fcmp{id: id, operation: operation, op1: op1, op2: op2},
        %IR.Context{} = ctx
      ) do
    dest_str = IR.Context.lookup_id(ctx, id)
    op_str = Atom.to_string(operation)
    {op1_str, ctx_1} = IR.to_ir(op1, ctx)
    {op2_str, ctx_2} = IROperand.to_operand(op2, ctx_1)
    {"%#{dest_str} = #{@for.mnemonic()} #{op_str} #{op1_str}, #{op2_str}", ctx_2}
  end

  def resolve_names(%Instruction.Fcmp{id: id, dest: dest}, %IR.Context{} = ctx) do
    IR.Context.map_id_to_name(ctx, id, dest)
  end
end

defimpl Wyvern.ToHandle, for: Wyvern.Instruction.Fcmp do
  alias Wyvern.Type
  alias Wyvern.Value.Handle

  def to_handle(%Wyvern.Instruction.Fcmp{id: id}) do
    Handle.new(id, Type.i1())
  end
end
