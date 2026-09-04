defmodule Wyvern do
  @moduledoc """
  Wyvern is an LLVM IR builder API.

  ```
  use Wyvern
  ```

  Includes most of the basic functionality of the library.
  """

  defmacro __using__(_opts) do
    quote do
      alias Wyvern.Module
      alias Wyvern.Function
      alias Wyvern.BasicBlock
      alias Wyvern.Instruction
      alias Wyvern.Declaration
      alias Wyvern.GlobalVariable
      alias Wyvern.Label
      alias Wyvern.Type
      alias Wyvern.Value
    end
  end
end
