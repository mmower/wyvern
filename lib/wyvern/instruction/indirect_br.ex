defmodule Wyvern.Instruction.IndirectBr do
  @mnemonic "indirectbr"
  alias Wyvern.Type
  alias Wyvern.Label
  alias Wyvern.Value

  @type t :: %__MODULE__{
          id: reference(),
          address: Value.t(),
          destinations: [Label.t()]
        }
  defstruct [:id, :address, :destinations]

  @spec new(Value.t(), destinations: [Label.t()]) :: __MODULE__.t()
  def new(address, destinations) do
    if !Type.ptr?(address.type), do: raise("indirectbr - address must be a pointer type!")
    if length(destinations) == 0, do: raise("indirectbr - requires at least one destination!")

    unless Enum.all?(destinations, &match?(%Label{}, &1)),
      do: raise("indirectbr - destinations must be labels!")

    %__MODULE__{
      id: make_ref(),
      address: address,
      destinations: destinations
    }
  end

  @doc """
  The LLVM mnemonic this instruction serialises to.
  """
  @spec mnemonic() :: String.t()
  def mnemonic, do: @mnemonic
end

defimpl Wyvern.IR, for: Wyvern.Instruction.IndirectBr do
  alias Wyvern.IR
  alias Wyvern.Identifier
  alias Wyvern.Instruction

  def to_ir(
        %Instruction.IndirectBr{address: address, destinations: destinations},
        %IR.Context{} = ctx
      ) do
    {addr_str, ctx} = IR.to_ir(address, ctx)

    labels =
      Enum.map_join(
        destinations,
        ", ",
        &(IR.Context.lookup_id(ctx, &1.id)
          |> Identifier.legal_identifier()
          |> String.replace_prefix("", "label %"))
      )

    {"#{@for.mnemonic()} #{addr_str}, [#{labels}]", ctx}
  end

  def resolve_names(
        %Instruction.IndirectBr{destinations: destinations},
        %IR.Context{} = ctx
      ) do
    Enum.reduce(destinations, ctx, fn destination, ctx ->
      IR.Context.map_id_to_name(ctx, destination.id, destination.name)
    end)
  end
end

defimpl Wyvern.ToHandle, for: Wyvern.Instruction.IndirectBr do
  def to_handle(_), do: raise("ToHandle not supported in indirectbr!")
end
