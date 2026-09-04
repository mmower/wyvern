defmodule Wyvern.Instruction.Unreachable do
  @mnemonic "unreachable"
  @type t :: %__MODULE__{
          id: reference()
        }
  defstruct [:id]

  def new() do
    %__MODULE__{id: make_ref()}
  end

  @doc """
  The LLVM mnemonic this instruction serialises to.
  """
  @spec mnemonic() :: String.t()
  def mnemonic, do: @mnemonic
end

defimpl Wyvern.IR, for: Wyvern.Instruction.Unreachable do
  alias Wyvern.IR
  alias Wyvern.Instruction

  def to_ir(%Instruction.Unreachable{}, %IR.Context{} = ctx) do
    {"#{@for.mnemonic()}", ctx}
  end

  def resolve_names(%Instruction.Unreachable{}, %IR.Context{} = ctx) do
    ctx
  end
end

defimpl Wyvern.ToHandle, for: Wyvern.Instruction.Unreachable do
  def to_handle(%Wyvern.Instruction.Unreachable{}) do
    raise "Unsupported - cannot get a handle for unreachable!"
  end
end
