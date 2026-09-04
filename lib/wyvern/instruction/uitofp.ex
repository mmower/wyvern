defmodule Wyvern.Instruction.Uitofp do
  @mnemonic "uitofp"
  alias Wyvern.Instruction.Types
  alias Wyvern.Type
  alias Wyvern.Value

  @type t :: %__MODULE__{
          id: reference(),
          dest: Types.destination(),
          src: Value.t(),
          to_type: Type.Float.t()
        }
  defstruct [:id, :dest, :src, :to_type]

  @spec new(Types.destination(), Value.t(), Type.Float.t()) :: __MODULE__.t()
  def new(dest, src, to_type) do
    if !Type.integer?(src.type), do: raise("Unsupported: uitofp on non-integer src!")
    if !Type.float?(to_type), do: raise("Unsupported: uitofp to non-float type!")

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

defimpl Wyvern.IR, for: Wyvern.Instruction.Uitofp do
  alias Wyvern.IR.Helpers

  def to_ir(instruction, ctx), do: Helpers.conversion_op(@for.mnemonic(), instruction, ctx)
  def resolve_names(instruction, ctx), do: Helpers.resolve_dest(instruction, ctx)
end

defimpl Wyvern.ToHandle, for: Wyvern.Instruction.Uitofp do
  def to_handle(instruction), do: Wyvern.ToHandle.Helpers.from_to_type(instruction)
end
