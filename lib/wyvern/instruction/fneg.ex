defmodule Wyvern.Instruction.Fneg do
  @mnemonic "fneg"
  alias Wyvern.Instruction.Types
  alias Wyvern.Type
  alias Wyvern.Value

  @type t :: %__MODULE__{
          id: reference(),
          dest: Types.destination(),
          src: Value.t()
        }
  defstruct [:id, :dest, :src]

  @spec new(Types.destination(), Value.t()) :: __MODULE__.t()
  def new(dest, src) do
    unless Type.float?(src.type), do: raise("fneg - requires floating point source!")

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

defimpl Wyvern.IR, for: Wyvern.Instruction.Fneg do
  alias Wyvern.IR

  def to_ir(%Wyvern.Instruction.Fneg{id: id, src: src}, %IR.Context{} = ctx) do
    dest_str = IR.Context.lookup_id(ctx, id)
    {src_str, ctx_1} = IR.to_ir(src, ctx)
    {"%#{dest_str} = #{@for.mnemonic()} #{src_str}", ctx_1}
  end

  def resolve_names(%Wyvern.Instruction.Fneg{id: id, dest: dest}, %IR.Context{} = ctx) do
    IR.Context.map_id_to_name(ctx, id, dest)
  end
end

defimpl Wyvern.ToHandle, for: Wyvern.Instruction.Fneg do
  alias Wyvern.Value.Handle

  def to_handle(%Wyvern.Instruction.Fneg{id: id, src: src}) do
    Handle.new(id, src.type)
  end
end
