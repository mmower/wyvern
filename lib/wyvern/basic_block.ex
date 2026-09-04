defmodule Wyvern.BasicBlock do
  alias Wyvern.Label
  alias Wyvern.Instruction

  @type instruction_list :: [Wyvern.Instruction.t()]

  @type t :: %__MODULE__{
          id: reference(),
          label: Label.t(),
          instructions: instruction_list()
        }
  defstruct [:id, :label, :instructions]

  @spec new(Label.t(), instruction_list()) :: __MODULE__.t()
  def new(%Label{} = label, instructions) when is_list(instructions) do
    if Enum.empty?(instructions), do: raise("Cannot create an empty block!")

    if !Instruction.terminator?(List.last(instructions)),
      do: raise("Block must end with a terminator!")

    if Enum.filter(instructions, &Instruction.terminator?/1) |> Enum.count() > 1,
      do: raise("Only one terminator allowed per block!")

    %__MODULE__{
      id: label.id,
      label: label,
      instructions: instructions
    }
  end
end

defimpl Wyvern.IR, for: Wyvern.BasicBlock do
  alias Wyvern.IR
  alias Wyvern.Label
  alias Wyvern.BasicBlock

  def to_ir(%BasicBlock{label: %Label{id: id}, instructions: instructions}, %IR.Context{} = ctx) do
    name_str = IR.Context.lookup_id(ctx, id)
    {ins_ir, ctx} = Enum.map_reduce(instructions, ctx, &IR.to_ir/2)
    ins_str = ins_ir |> Enum.map(fn ins -> "  #{ins}" end) |> Enum.join("\n")
    {"#{name_str}:\n#{ins_str}", ctx}
  end

  def resolve_names(
        %BasicBlock{label: %Label{} = label, instructions: instructions},
        %IR.Context{} = ctx
      ) do
    ctx = IR.Context.map_id_to_name(ctx, label)
    Enum.reduce(instructions, ctx, &IR.resolve_names/2)
  end
end
