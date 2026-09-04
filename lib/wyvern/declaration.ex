defmodule Wyvern.Declaration do
  alias Wyvern.Type

  @type t :: %__MODULE__{
          name: String.t(),
          type: Type.Function.t()
        }
  defstruct [:name, :type]

  @spec new(String.t(), Type.Function.t()) :: __MODULE__.t()
  def new(name, type) do
    %__MODULE__{
      name: name,
      type: type
    }
  end
end

defimpl Wyvern.IR, for: Wyvern.Declaration do
  alias Wyvern.IR
  alias Wyvern.Type
  alias Wyvern.Identifier
  alias Wyvern.Declaration

  def to_ir(
        %Declaration{
          name: name,
          type: %Type.Function{ret_type: ret_type, params: params, var_args: false}
        },
        %IR.Context{} = ctx
      ) do
    {ret_type_str, ctx_1} = IR.to_ir(ret_type, ctx)
    {param_strs, ctx_2} = Enum.map_reduce(params, ctx_1, &IR.to_ir/2)
    params_joined = Enum.join(param_strs, ", ")
    {"declare #{ret_type_str} @#{Identifier.legal_identifier(name)}(#{params_joined})", ctx_2}
  end

  def to_ir(
        %Declaration{
          name: name,
          type: %Type.Function{ret_type: ret_type, params: [], var_args: true}
        },
        %IR.Context{} = ctx
      ) do
    {ret_type_str, ctx_1} = IR.to_ir(ret_type, ctx)
    {"declare #{ret_type_str} @#{Identifier.legal_identifier(name)}(...)", ctx_1}
  end

  def to_ir(
        %Declaration{
          name: name,
          type: %Type.Function{ret_type: ret_type, params: params, var_args: true}
        },
        %IR.Context{} = ctx
      ) do
    {ret_type_str, ctx_1} = IR.to_ir(ret_type, ctx)
    {param_strs, ctx_2} = Enum.map_reduce(params, ctx_1, &IR.to_ir/2)
    params_joined = Enum.join(param_strs, ", ")

    {"declare #{ret_type_str} @#{Identifier.legal_identifier(name)}(#{params_joined}, ...)",
     ctx_2}
  end

  def resolve_names(_, %IR.Context{} = ctx), do: ctx
end
