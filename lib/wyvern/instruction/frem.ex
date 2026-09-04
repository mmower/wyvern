defmodule Wyvern.Instruction.Frem do
  @mnemonic "frem"
  alias Wyvern.Instruction.Types
  alias Wyvern.Type
  alias Wyvern.Value

  @type t :: %__MODULE__{
          id: reference(),
          dest: Types.destination(),
          op1: Value.t(),
          op2: Value.t()
        }
  defstruct [:id, :dest, :op1, :op2]

  @spec new(Types.destination(), Value.t(), Value.t()) :: __MODULE__.t()
  def new(dest, op1, op2) do
    unless Type.float?(op1.type), do: raise("frem - only supports float types!")
    unless op1.type == op2.type, do: raise("frem - operands have different types!")

    %__MODULE__{
      id: make_ref(),
      dest: dest,
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

defimpl Wyvern.IR, for: Wyvern.Instruction.Frem do
  alias Wyvern.IR.Helpers

  def to_ir(instruction, ctx), do: Helpers.binary_op(@for.mnemonic(), instruction, ctx)
  def resolve_names(instruction, ctx), do: Helpers.resolve_dest(instruction, ctx)
end

defimpl Wyvern.ToHandle, for: Wyvern.Instruction.Frem do
  def to_handle(instruction), do: Wyvern.ToHandle.Helpers.from_op1(instruction)
end
