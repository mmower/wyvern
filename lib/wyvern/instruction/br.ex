defmodule Wyvern.Instruction.BR do
  @mnemonic "br"
  alias Wyvern.Type
  alias Wyvern.Label
  alias Wyvern.Value

  @type t :: %__MODULE__{
          id: reference(),
          cond: Value.t(),
          if_true: Label.t(),
          if_false: Label.t() | nil
        }
  defstruct [:id, :cond, :if_true, :if_false]

  @spec unconditional(Label.t()) :: __MODULE__.t()
  def unconditional(%Label{} = if_true) do
    %__MODULE__{id: make_ref(), cond: nil, if_true: if_true, if_false: nil}
  end

  @spec conditional(Value.t(), Label.t()) :: __MODULE__.t()
  def conditional(cond, %Label{} = if_true) do
    if cond.type != Type.i1(), do: raise("cond must be type i1!")
    %__MODULE__{id: make_ref(), cond: cond, if_true: if_true, if_false: nil}
  end

  @spec conditional(Value.t(), Label.t(), Label.t()) :: __MODULE__.t()
  def conditional(cond, %Label{} = if_true, %Label{} = if_false) do
    if cond.type != Type.i1(), do: raise("cond must be i1!")
    %__MODULE__{id: make_ref(), cond: cond, if_true: if_true, if_false: if_false}
  end

  @doc """
  The LLVM mnemonic this instruction serialises to.
  """
  @spec mnemonic() :: String.t()
  def mnemonic, do: @mnemonic
end

defimpl Wyvern.IR, for: Wyvern.Instruction.BR do
  alias Wyvern.IR
  alias Wyvern.Label
  alias Wyvern.Identifier
  alias Wyvern.Instruction

  def to_ir(%Instruction.BR{cond: nil, if_true: if_true}, %IR.Context{} = ctx) do
    label = IR.Context.lookup_id(ctx, if_true.id) |> Identifier.legal_identifier()
    {"#{@for.mnemonic()} label %#{label}", ctx}
  end

  def to_ir(
        %Instruction.BR{
          cond: cond,
          if_true: if_true,
          if_false: nil
        },
        ctx
      ) do
    {cond_str, ctx_1} = IR.to_ir(cond, ctx)
    true_label = IR.Context.lookup_id(ctx, if_true.id) |> Identifier.legal_identifier()
    {"#{@for.mnemonic()} #{cond_str}, label %#{true_label}", ctx_1}
  end

  def to_ir(
        %Instruction.BR{
          cond: cond,
          if_true: if_true,
          if_false: if_false
        },
        %IR.Context{} = ctx
      ) do
    {cond_str, ctx_1} = IR.to_ir(cond, ctx)

    true_label = IR.Context.lookup_id(ctx, if_true.id) |> Identifier.legal_identifier()
    false_label = IR.Context.lookup_id(ctx, if_false.id) |> Identifier.legal_identifier()

    {"#{@for.mnemonic()} #{cond_str}, label %#{true_label}, label %#{false_label}", ctx_1}
  end

  def resolve_names(%Instruction.BR{if_true: if_true, if_false: if_false}, %IR.Context{} = ctx) do
    ctx
    |> then(&IR.resolve_names(if_true, &1))
    |> then(fn ctx ->
      if is_nil(if_false), do: ctx, else: IR.resolve_names(if_false, ctx)
    end)
  end
end

defimpl Wyvern.ToHandle, for: Wyvern.Instruction.BR do
  def to_handle(_), do: raise("ToHandle not supported in br!")
end
