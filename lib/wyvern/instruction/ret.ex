defmodule Wyvern.Instruction.Ret do
  @mnemonic "ret"
  alias Wyvern.Value

  @type val_type :: Value.t() | nil
  @type t :: %__MODULE__{
          id: reference(),
          value: val_type()
        }
  defstruct [:id, :value]

  @spec new(val_type()) :: __MODULE__.t()
  def new(value) do
    %__MODULE__{id: make_ref(), value: value}
  end

  @doc """
  The LLVM mnemonic this instruction serialises to.
  """
  @spec mnemonic() :: String.t()
  def mnemonic, do: @mnemonic
end

defimpl Wyvern.IR, for: Wyvern.Instruction.Ret do
  alias Wyvern.IR
  alias Wyvern.Instruction

  def to_ir(%Instruction.Ret{value: value}, %IR.Context{} = ctx) do
    {value_str, ctx_1} = IR.to_ir(value, ctx)
    {"#{@for.mnemonic()} #{value_str}", ctx_1}
  end

  def resolve_names(_, ctx), do: ctx
end

defimpl Wyvern.ToHandle, for: Wyvern.Instruction.Ret do
  def to_handle(_), do: raise("ToHandle not supported in ret!")
end
