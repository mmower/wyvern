defmodule Wyvern.Instruction.Freeze do
  @mnemonic "freeze"
  alias Wyvern.Instruction.Types
  alias Wyvern.Value

  @type t :: %__MODULE__{
          id: reference(),
          dest: Types.destination(),
          src: Value.t()
        }
  defstruct [:id, :dest, :src]

  def new(dest, src) do
    %__MODULE__{
      id: make_ref(),
      dest: dest,
      src: src
    }
  end

  @doc """
  The LLVM mnemonic this instruction serialises to.
  """
  @spec mnemonic() :: String.t()
  def mnemonic, do: @mnemonic
end

defimpl Wyvern.IR, for: Wyvern.Instruction.Freeze do
  alias Wyvern.IR
  alias Wyvern.Instruction

  def to_ir(%Instruction.Freeze{id: id, src: src}, %IR.Context{} = ctx) do
    dest_str = IR.Context.lookup_id(ctx, id)
    {src_str, ctx} = IR.to_ir(src, ctx)
    {"%#{dest_str} = #{@for.mnemonic()} #{src_str}", ctx}
  end

  def resolve_names(%Instruction.Freeze{id: id, dest: dest}, %IR.Context{} = ctx) do
    IR.Context.map_id_to_name(ctx, id, dest)
  end
end

defimpl Wyvern.ToHandle, for: Wyvern.Instruction.Freeze do
  alias Wyvern.Value.Handle

  def to_handle(%Wyvern.Instruction.Freeze{id: id, src: src}) do
    Handle.new(id, src.type)
  end
end
