defmodule Wyvern.Instruction.Add do
  @mnemonic "add"
  alias Wyvern.Instruction.Types
  alias Wyvern.Value

  @type operand :: Value.t()

  @type t :: %__MODULE__{
          id: reference(),
          dest: Types.destination(),
          op1: Value.t(),
          op2: Value.t()
        }
  defstruct [:id, :dest, :op1, :op2]

  @spec new(Types.destination(), Value.t(), Value.t()) :: __MODULE__.t()
  def new(dest, %{type: op1_type} = op1, %{type: op2_type} = op2) do
    if op1_type != op2_type, do: raise("Unsupported attempt to mix types!")

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

defimpl Wyvern.IR, for: Wyvern.Instruction.Add do
  alias Wyvern.IR.Helpers

  def to_ir(instruction, ctx), do: Helpers.binary_op(@for.mnemonic(), instruction, ctx)
  def resolve_names(instruction, ctx), do: Helpers.resolve_dest(instruction, ctx)
end

defimpl Wyvern.ToHandle, for: Wyvern.Instruction.Add do
  def to_handle(instruction), do: Wyvern.ToHandle.Helpers.from_op1(instruction)
end
