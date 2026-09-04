defmodule Wyvern.Instruction.Trunc do
  @mnemonic "trunc"
  alias Wyvern.Instruction.Types
  alias Wyvern.Type
  alias Wyvern.Value

  alias Wyvern.Value

  @type t :: %__MODULE__{
          id: reference(),
          dest: Types.destination(),
          src: Value.t(),
          to_type: Type.Integer.t()
        }
  defstruct [:id, :dest, :src, :to_type]

  def new(dest, src, to_type) do
    if !Type.integer?(src.type), do: raise("Unsupported: trunc on non-integer src!")
    if !Type.integer?(to_type), do: raise("Unsupported: trunc to non-integer type!")

    if to_type.width >= src.type.width,
      do: raise("Unsupported: trunc #{src.type.width} -> #{to_type.width} does not narrow!")

    %__MODULE__{
      id: make_ref(),
      dest: dest,
      src: src,
      to_type: to_type
    }
  end

  @doc """
  The LLVM mnemonic this instruction serialises to.
  """
  @spec mnemonic() :: String.t()
  def mnemonic, do: @mnemonic
end

defimpl Wyvern.IR, for: Wyvern.Instruction.Trunc do
  alias Wyvern.IR.Helpers

  def to_ir(instruction, ctx), do: Helpers.conversion_op(@for.mnemonic(), instruction, ctx)
  def resolve_names(instruction, ctx), do: Helpers.resolve_dest(instruction, ctx)
end

defimpl Wyvern.ToHandle, for: Wyvern.Instruction.Trunc do
  def to_handle(instruction), do: Wyvern.ToHandle.Helpers.from_to_type(instruction)
end
