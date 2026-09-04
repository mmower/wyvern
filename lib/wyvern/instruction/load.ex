defmodule Wyvern.Instruction.Load do
  @mnemonic "load"
  alias Wyvern.Instruction.Types
  alias Wyvern.Type
  alias Wyvern.Value

  @type t :: %__MODULE__{
          id: reference(),
          dest: Types.destination(),
          type: Type.t(),
          src: Value.t()
        }
  defstruct [:id, :dest, :type, :src]

  @spec new(Types.destination(), Type.t(), Value.t()) :: __MODULE__.t()
  def new(dest, type, src) do
    if src.type != Type.ptr(), do: raise("Unsupported attempt to load from non-pointer!")
    %__MODULE__{id: make_ref(), dest: dest, type: type, src: src}
  end

  @doc """
  The LLVM mnemonic this instruction serialises to.
  """
  @spec mnemonic() :: String.t()
  def mnemonic, do: @mnemonic
end

defimpl Wyvern.IR, for: Wyvern.Instruction.Load do
  alias Wyvern.IR
  alias Wyvern.Instruction

  def to_ir(%Instruction.Load{id: id, type: type, src: src}, %IR.Context{} = ctx) do
    dest_str = IR.Context.lookup_id(ctx, id)
    {type_str, ctx_1} = IR.to_ir(type, ctx)
    {src_str, ctx_2} = IR.to_ir(src, ctx_1)
    {"%#{dest_str} = #{@for.mnemonic()} #{type_str}, #{src_str}", ctx_2}
  end

  def resolve_names(%Instruction.Load{id: id, dest: dest}, %IR.Context{} = ctx) do
    IR.Context.map_id_to_name(ctx, id, dest)
  end
end

defimpl Wyvern.ToHandle, for: Wyvern.Instruction.Load do
  alias Wyvern.Value.Handle

  def to_handle(%Wyvern.Instruction.Load{id: id, type: type}) do
    Handle.new(id, type)
  end
end
