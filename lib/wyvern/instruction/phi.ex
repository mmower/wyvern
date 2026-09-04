defmodule Wyvern.Instruction.Phi do
  @mnemonic "phi"
  alias Wyvern.Instruction.Types
  alias Wyvern.Type
  alias Wyvern.Label
  alias Wyvern.Value

  @type incoming :: {Value.t(), Label.t()}
  @type t :: %__MODULE__{
          id: reference(),
          dest: Types.destination(),
          type: Type.t(),
          incoming: [incoming()]
        }
  defstruct [:id, :dest, :type, :incoming]

  @doc """
  Phi.new/3 validates that all incoming values share type, but does not validate that incoming's labels are actually the predecessor blocks of the block the Phi sits in (nor that every predecessor is covered exactly once).

  Doing that requires knowing the block's actual predecessors, which means walking the whole Function's blocks list to find which blocks end in a terminator targeting this block's label. We don't have that CFG-level analysis yet so it isn't checked here. Malformed phis (wrong/missing/duplicate predecessors) will produce syntactically valid but semantically broken LLVM IR (e.g. verifier will reject it) rather than raising during construction. We'll revisit this later.
  """
  @spec new(Types.destination(), Type.t(), [incoming()]) :: __MODULE__.t()
  def new(dest, type, incoming) when is_list(incoming) do
    if Enum.empty?(incoming), do: raise("Phi requires at least one incoming value!")

    if Enum.any?(incoming, fn {value, _label} -> value.type != type end),
      do: raise("Phi incoming value different to phi type!")

    %__MODULE__{
      id: make_ref(),
      dest: dest,
      type: type,
      incoming: incoming
    }
  end

  @doc """
  The LLVM mnemonic this instruction serialises to.
  """
  @spec mnemonic() :: String.t()
  def mnemonic, do: @mnemonic
end

defimpl Wyvern.IR, for: Wyvern.Instruction.Phi do
  alias Wyvern.IR
  alias Wyvern.Identifier
  alias Wyvern.IROperand
  alias Wyvern.Instruction

  def to_ir(%Instruction.Phi{id: id, type: type, incoming: incoming}, %IR.Context{} = ctx) do
    dest_str = IR.Context.lookup_id(ctx, id)
    {type_str, ctx_1} = IR.to_ir(type, ctx)

    {pairs, ctx_2} =
      Enum.map_reduce(incoming, ctx_1, fn {value, label}, acc_ctx ->
        {value_str, acc_ctx_1} = IROperand.to_operand(value, acc_ctx)
        label_str = IR.Context.lookup_id(acc_ctx_1, label.id) |> Identifier.legal_identifier()
        {"[#{value_str}, %#{label_str}]", acc_ctx_1}
      end)

    {"%#{dest_str} = #{@for.mnemonic()} #{type_str} #{Enum.join(pairs, ", ")}", ctx_2}
  end

  def resolve_names(%Instruction.Phi{id: id, dest: dest, incoming: incoming}, ctx) do
    ctx_1 = IR.Context.map_id_to_name(ctx, id, dest)

    Enum.reduce(incoming, ctx_1, fn {_value, label}, acc_ctx ->
      IR.resolve_names(label, acc_ctx)
    end)
  end
end

defimpl Wyvern.ToHandle, for: Wyvern.Instruction.Phi do
  alias Wyvern.Value.Handle

  def to_handle(%Wyvern.Instruction.Phi{id: id, type: type}) do
    Handle.new(id, type)
  end
end
