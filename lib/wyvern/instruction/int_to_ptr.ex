defmodule Wyvern.Instruction.IntToPtr do
  @mnemonic "inttoptr"
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
    if !Type.integer?(src.type), do: raise("Attempt to convert a non-integer to pointer!")

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

defimpl Wyvern.IR, for: Wyvern.Instruction.IntToPtr do
  alias Wyvern.IR.Helpers
  alias Wyvern.Type

  def to_ir(instruction, ctx),
    do: Helpers.conversion_op(@for.mnemonic(), instruction, Type.ptr(), ctx)

  def resolve_names(instruction, ctx), do: Helpers.resolve_dest(instruction, ctx)
end

defimpl Wyvern.ToHandle, for: Wyvern.Instruction.IntToPtr do
  def to_handle(instruction), do: Wyvern.ToHandle.Helpers.as_ptr(instruction)
end
