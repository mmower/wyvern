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
