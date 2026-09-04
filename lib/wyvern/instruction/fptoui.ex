defmodule Wyvern.Instruction.Fptoui do
  @mnemonic "fptoui"
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
    if !Type.float?(src.type), do: raise("Unsupported: fptoui on non-float src!")
    if !Type.integer?(to_type), do: raise("Unsupported: fptoui to non-integer type!")

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

defimpl Wyvern.IR, for: Wyvern.Instruction.Fptoui do
  alias Wyvern.IR.Helpers

  def to_ir(instruction, ctx), do: Helpers.conversion_op(@for.mnemonic(), instruction, ctx)
  def resolve_names(instruction, ctx), do: Helpers.resolve_dest(instruction, ctx)
end

defimpl Wyvern.ToHandle, for: Wyvern.Instruction.Fptoui do
  def to_handle(instruction), do: Wyvern.ToHandle.Helpers.from_to_type(instruction)
end
