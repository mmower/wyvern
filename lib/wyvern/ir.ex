defprotocol Wyvern.IR do
  alias Wyvern.IR.Context

  @doc """
  Converts the term (expected to be an Wyvern struct) into a string representation of the IR
  ready to be passed to clang.
  """
  @spec to_ir(any(), Context.t()) :: {String.t(), Context.t()}
  def to_ir(term, ctx)

  @spec resolve_names(any(), Context.t()) :: Context.t()
  def resolve_names(term, ctx)
end
