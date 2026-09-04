defmodule Wyvern.Value.BlockAddress do
  alias Wyvern.Value.{GlobalRef}
  alias Wyvern.Type

  @type t :: %__MODULE__{
          type: Type.t(),
          function: GlobalRef.t(),
          label: Label.t()
        }
  defstruct [:type, :function, :label]

  def new(function, label) do
    %__MODULE__{
      type: Type.ptr(),
      function: function,
      label: label
    }
  end
end

defimpl Wyvern.IR, for: Wyvern.Value.BlockAddress do
  alias Wyvern.IR
  alias Wyvern.Identifier
  alias Wyvern.Value

  def to_ir(
        %Value.BlockAddress{function: %Value.GlobalRef{name: fn_name}, label: label},
        %IR.Context{} = ctx
      ) do
    label_str = IR.Context.lookup_id(ctx, label.id) |> Identifier.legal_identifier()
    {"ptr blockaddress(@#{fn_name}, %#{label_str})", ctx}
  end

  def resolve_names(%Value.BlockAddress{label: label}, %IR.Context{} = ctx) do
    IR.resolve_names(label, ctx)
  end
end
