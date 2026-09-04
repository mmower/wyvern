defmodule Wyvern.Instruction.GetElementPtr do
  @mnemonic "getelementptr"
  alias Wyvern.Instruction.Types
  alias Wyvern.Type
  alias Wyvern.Value

  @type t :: %__MODULE__{
          id: reference(),
          dest: Types.destination(),
          type: Type.t(),
          source: Value.t(),
          indices: [Value.t()],
          inbounds: boolean()
        }
  defstruct [:id, :dest, :type, :source, :indices, :inbounds]

  @spec new(Types.destination(), Type.t(), Value.t(), [Value.t()], keyword(atom())) ::
          __MODULE__.t()
  def new(dest, type, source, indices, opts \\ []) do
    inbounds = Keyword.get(opts, :inbounds, false)

    unless Enum.all?(indices, &integer_index?/1),
      do: raise("Unsupported non-integer index value!")

    unless Type.ptr?(source.type), do: raise("Source #{inspect(source)} must be pointer typed!")

    %__MODULE__{
      id: make_ref(),
      dest: dest,
      type: type,
      source: source,
      indices: indices,
      inbounds: inbounds
    }
  end

  defp integer_index?(%Value.Integer{}), do: true
  defp integer_index?(%Value.LocalRef{type: %Type.Integer{}}), do: true
  defp integer_index?(%Value.Handle{type: %Type.Integer{}}), do: true
  defp integer_index?(_), do: false

  @doc """
  The LLVM mnemonic this instruction serialises to.
  """
  @spec mnemonic() :: String.t()
  def mnemonic, do: @mnemonic
end

defimpl Wyvern.IR, for: Wyvern.Instruction.GetElementPtr do
  alias Wyvern.IR
  alias Wyvern.Instruction

  def to_ir(
        %Instruction.GetElementPtr{
          id: id,
          type: type,
          source: source,
          indices: indices,
          inbounds: inbounds
        },
        ctx
      ) do
    dest_str = IR.Context.lookup_id(ctx, id)
    inbounds_str = if inbounds, do: "inbounds ", else: ""
    {type_str, ctx_1} = IR.to_ir(type, ctx)
    {source_name, ctx_2} = IR.to_ir(source, ctx_1)
    {index_names, ctx_3} = Enum.map_reduce(indices, ctx_2, &IR.to_ir/2)
    index_str = Enum.join(index_names, ", ")

    {"%#{dest_str} = #{@for.mnemonic()} #{inbounds_str}#{type_str}, #{source_name}, #{index_str}",
     ctx_3}
  end

  def resolve_names(%Instruction.GetElementPtr{id: id, dest: dest}, %IR.Context{} = ctx) do
    IR.Context.map_id_to_name(ctx, id, dest)
  end
end

defimpl Wyvern.ToHandle, for: Wyvern.Instruction.GetElementPtr do
  def to_handle(instruction), do: Wyvern.ToHandle.Helpers.as_ptr(instruction)
end
