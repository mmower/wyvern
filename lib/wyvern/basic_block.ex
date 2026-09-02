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
