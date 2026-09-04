defprotocol Wyvern.ToHandle do
  alias Wyvern.Value.Handle
  alias Wyvern.Instruction

  @spec to_handle(Instruction.t()) :: Handle.t()
  def to_handle(instruction)
end
