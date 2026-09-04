defmodule Wyvern.Instruction.PtrToInt do
  @mnemonic "ptrtoint"
  alias Wyvern.Instruction.Types
  alias Wyvern.Type
  alias Wyvern.Value

  @type t :: %__MODULE__{
          id: reference(),
          dest: Types.destination(),
          src: Value.t(),
          to_type: Type.Integer.t()
        }
  defstruct [:id, :dest, :src, :to_type]

  @spec new(Types.destination(), Value.t(), Type.Integer.t()) :: __MODULE__.t()
  def new(dest, src, to_type) do
    if !Type.ptr?(src.type), do: raise("Cannot convert non-pointer value!")
    if !Type.integer?(to_type), do: raise("Cannot convert non-integer value!")

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

defimpl Wyvern.IR, for: Wyvern.Instruction.PtrToInt do
  alias Wyvern.IR.Helpers

  def to_ir(instruction, ctx), do: Helpers.conversion_op(@for.mnemonic(), instruction, ctx)
  def resolve_names(instruction, ctx), do: Helpers.resolve_dest(instruction, ctx)
end

defimpl Wyvern.ToHandle, for: Wyvern.Instruction.PtrToInt do
  def to_handle(instruction), do: Wyvern.ToHandle.Helpers.from_to_type(instruction)
end
