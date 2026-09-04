defmodule Wyvern.IR.Context do
  alias Wyvern.Label

  @moduledoc """
  A Context module is threaded through resolve_names()/to_ir() protocol to hold
  any state that is modified during the serialisation process.
  """
  @type t :: %__MODULE__{
          fn_auto_num: integer(),
          id_map: map()
        }
  defstruct fn_auto_num: 0, id_map: %{}

  @spec new() :: t()
  def new() do
    %__MODULE__{}
  end

  defp resolve_name(%__MODULE__{fn_auto_num: n} = ctx, nil) do
    {"#{n}", %{ctx | fn_auto_num: n + 1}}
  end

  defp resolve_name(%__MODULE__{} = ctx, name) when is_binary(name) do
    {name, ctx}
  end

  def map_id_to_name(%__MODULE__{id_map: id_map} = ctx, id, name)
      when is_reference(id) and (is_nil(name) or is_binary(name)) do
    if Map.has_key?(id_map, id) do
      ctx
    else
      {resolved_name, ctx_1} = resolve_name(ctx, name)
      %{ctx_1 | id_map: Map.put_new(id_map, id, resolved_name)}
    end
  end

  def map_id_to_name(%__MODULE__{} = ctx, %Label{id: id, name: name}) do
    map_id_to_name(ctx, id, name)
  end

  def lookup_id(%__MODULE__{id_map: id_map}, id) do
    Map.fetch!(id_map, id)
  end
end
