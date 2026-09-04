defmodule Wyvern.Instruction.Store do
  @mnemonic "store"
  alias Wyvern.Type
  alias Wyvern.Value

  @type t :: %__MODULE__{
          id: reference(),
          value: Value.t(),
          dest: Value.t()
        }
  defstruct [:id, :value, :dest]

  @spec new(Value.t(), Value.t()) :: __MODULE__.t()
  def new(value, dest) do
    if dest.type != Type.ptr(),
      do: raise("Unsupported store to non-pointer destination!")

    %__MODULE__{
      id: make_ref(),
      value: value,
      dest: dest
    }
  end

  @doc """
  The LLVM mnemonic this instruction serialises to.
  """
  @spec mnemonic() :: String.t()
  def mnemonic, do: @mnemonic
end

defimpl Wyvern.IR, for: Wyvern.Instruction.Store do
  alias Wyvern.IR
  alias Wyvern.Instruction

  def to_ir(%Instruction.Store{value: value, dest: dest}, %IR.Context{} = ctx) do
    {value_str, ctx_1} = IR.to_ir(value, ctx)
    {dest_str, ctx_2} = IR.to_ir(dest, ctx_1)
    {"#{@for.mnemonic()} #{value_str}, #{dest_str}", ctx_2}
  end

  def resolve_names(_, ctx), do: ctx
end

defimpl Wyvern.ToHandle, for: Wyvern.Instruction.Store do
  def to_handle(_), do: raise("ToHandle not supported in store!")
end
