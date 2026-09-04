defmodule Wyvern.Type.Function do
  @type param_list :: [Wyvern.Param.t()]

  @type t :: %__MODULE__{
          ret_type: Wyvern.Type.t(),
          params: param_list(),
          var_args: boolean()
        }
  defstruct ret_type: nil, params: [], var_args: false

  @spec new(Wyvern.Type.t(), param_list(), boolean()) :: __MODULE__.t()
  def new(ret_type, params, var_args) do
    %__MODULE__{ret_type: ret_type, params: params, var_args: var_args}
  end
end

defimpl Wyvern.IR, for: Wyvern.Type.Function do
  alias Wyvern.IR
  alias Wyvern.Type

  def to_ir(
        %Type.Function{ret_type: ret_type, params: params, var_args: false},
        %IR.Context{} = ctx
      ) do
    {ret_type_str, ctx_1} = IR.to_ir(ret_type, ctx)
    {param_strs, ctx_2} = Enum.map_reduce(params, ctx_1, &IR.to_ir/2)
    params_joined = Enum.join(param_strs, ", ")
    {"#{ret_type_str} (#{params_joined})", ctx_2}
  end

  def to_ir(
        %Type.Function{ret_type: ret_type, params: [], var_args: true},
        %IR.Context{} = ctx
      ) do
    {ret_type_str, ctx_1} = IR.to_ir(ret_type, ctx)
    {"#{ret_type_str} (...)", ctx_1}
  end

  def to_ir(
        %Type.Function{ret_type: ret_type, params: params, var_args: true},
        %IR.Context{} = ctx
      ) do
    {ret_type_str, ctx_1} = IR.to_ir(ret_type, ctx)
    {param_strs, ctx_2} = Enum.map_reduce(params, ctx_1, &IR.to_ir/2)
    params_joined = Enum.join(param_strs, ", ")
    {"#{ret_type_str} (#{params_joined}, ...)", ctx_2}
  end

  def resolve_names(_, ctx), do: ctx
end
