defmodule Wyvern.Instruction.Switch do
  @mnemonic "switch"
  alias Wyvern.Type
  alias Wyvern.Label
  alias Wyvern.Value

  @type t :: %__MODULE__{
          id: reference(),
          value: Value.t(),
          default_label: Label.t(),
          cases: [{Value.t(), Label.t()}]
        }
  defstruct [:id, :value, :default_label, :cases]

  @spec new(Value.t(), Label.t(), [{Value.t(), Label.t()}]) :: __MODULE__.t()
  def new(value, %Label{} = default_label, cases) when is_list(cases) do
    if !Type.integer?(value.type), do: raise("switch - unsupported on non-integer value!")

    if Enum.any?(cases, fn {case_value, _} ->
         !match?(%Value.Integer{}, case_value) || value.type != case_value.type
       end),
       do: raise("switch - invalid or non-integer types!")

    case_values = Enum.map(cases, fn {case_value, _} -> case_value.value end) |> Enum.uniq()
    if length(case_values) < length(cases), do: raise("switch - non-unique value!")

    unless Enum.all?(cases, fn
             {_, %Label{}} -> true
             _ -> false
           end),
           do: raise("switch - case label missing!")

    %__MODULE__{
      id: make_ref(),
      value: value,
      default_label: default_label,
      cases: cases
    }
  end

  @doc """
  The LLVM mnemonic this instruction serialises to.
  """
  @spec mnemonic() :: String.t()
  def mnemonic, do: @mnemonic
end

defimpl Wyvern.IR, for: Wyvern.Instruction.Switch do
  alias Wyvern.IR
  alias Wyvern.Identifier
  alias Wyvern.Instruction

  def to_ir(
        %Instruction.Switch{value: value, default_label: default_label, cases: cases},
        %IR.Context{} = ctx
      )
      when is_list(cases) do
    {value_str, ctx_1} = IR.to_ir(value, ctx)

    default_label_str =
      IR.Context.lookup_id(ctx, default_label.id) |> Identifier.legal_identifier()

    {case_strs, ctx_2} =
      Enum.map_reduce(cases, ctx_1, fn {value, label}, acc_ctx ->
        {value_str, acc_ctx_1} = IR.to_ir(value, acc_ctx)
        label_str = IR.Context.lookup_id(acc_ctx_1, label.id) |> Identifier.legal_identifier()
        {"#{value_str}, label %#{label_str}", acc_ctx_1}
      end)

    case_str = Enum.join(case_strs, " ")
    {"#{@for.mnemonic()} #{value_str}, label %#{default_label_str} [#{case_str}]", ctx_2}
  end

  def resolve_names(
        %Instruction.Switch{default_label: default_label, cases: cases},
        %IR.Context{} = ctx
      ) do
    case_labels = Enum.map(cases, fn {_value, label} -> label end)

    Enum.reduce([default_label | case_labels], ctx, fn label, ctx ->
      IR.resolve_names(label, ctx)
    end)
  end
end

defimpl Wyvern.ToHandle, for: Wyvern.Instruction.Switch do
  def to_handle(%Wyvern.Instruction.Switch{}) do
    raise "Unsupported - cannot take a handle on a switch!"
  end
end
