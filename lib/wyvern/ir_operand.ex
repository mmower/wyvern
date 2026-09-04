defprotocol Wyvern.IROperand do
  alias Wyvern.IR.Context

  @spec to_operand(any(), Context.t()) :: {String.t(), Context.t()}
  def to_operand(term, ctx)
end
