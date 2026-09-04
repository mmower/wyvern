defmodule Wyvern.Instruction.Icmp do
  @mnemonic "icmp"
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

  @legal_ops [:eq, :ne, :ugt, :uge, :ult, :ule, :sgt, :sge, :slt, :sle]

  @spec new(Types.destination(), operation(), operand(), operand()) :: __MODULE__.t()
  def new(dest, operation, op1, op2) when operation in @legal_ops do
    if op1.type != Type.ptr() && !Type.integer?(op1.type),
      do: raise("Unsupported operand-1 type #{inspect(op1.type)}!")

    if op2.type != Type.ptr() && !Type.integer?(op2.type),
      do: raise("Unsupported operand-2 type #{inspect(op2.type)}!")

    if op1.type != op2.type, do: raise("Unsupported attempt to mix types in icmp!")

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

defimpl Wyvern.IR, for: Wyvern.Instruction.Icmp do
  alias Wyvern.IR
  alias Wyvern.IROperand
  alias Wyvern.Instruction

  @doc """
  Implemented: <result> = icmp <cond> <ty> <op1>, <op2>   ; yields i1 or <N x i1>:result
  Not implemented: <result> = icmp samesign <cond> <ty> <op1>, <op2>   ; yields i1 or <N x i1>:result
  """

  def to_ir(
        %Instruction.Icmp{id: id, operation: operation, op1: op1, op2: op2},
        %IR.Context{} = ctx
      ) do
    dest_str = IR.Context.lookup_id(ctx, id)
    op_str = Atom.to_string(operation)
    {op1_str, ctx_1} = IR.to_ir(op1, ctx)
    {op2_str, ctx_2} = IROperand.to_operand(op2, ctx_1)
    {"%#{dest_str} = #{@for.mnemonic()} #{op_str} #{op1_str}, #{op2_str}", ctx_2}
  end

  def resolve_names(%Instruction.Icmp{id: id, dest: dest}, %IR.Context{} = ctx) do
    IR.Context.map_id_to_name(ctx, id, dest)
  end
end

defimpl Wyvern.ToHandle, for: Wyvern.Instruction.Icmp do
  alias Wyvern.Type
  alias Wyvern.Value.Handle

  def to_handle(%Wyvern.Instruction.Icmp{id: id}) do
    Handle.new(id, Type.i1())
  end
end
