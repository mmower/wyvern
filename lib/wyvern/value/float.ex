defmodule Wyvern.Value.Float do
  alias Wyvern.Type

  import Bitwise

  @type t :: %__MODULE__{
          type: Type.Float.t(),
          value: float()
        }
  defstruct [:type, :value]

  @spec new(Type.Float.t(), float()) :: __MODULE__.t()
  def new(%Type.Float{variant: :half} = type, value) do
    %__MODULE__{type: type, value: half_to_bits(value)}
  end

  def new(%Type.Float{variant: :bfloat} = type, value) do
    %__MODULE__{type: type, value: bfloat_to_bits(value)}
  end

  def new(%Type.Float{variant: :float} = type, value) do
    %__MODULE__{type: type, value: float_to_bits(value)}
  end

  def new(%Type.Float{variant: :double} = type, value) do
    %__MODULE__{type: type, value: double_to_bits(value)}
  end

  defp half_to_bits(v) do
    <<half_rounded::float-size(16)>> = <<v::float-size(16)>>
    <<bits::unsigned-integer-size(64)>> = <<half_rounded::float-size(64)>>
    bits
  end

  defp bfloat_to_bits(v) do
    <<float_bits::unsigned-integer-size(32)>> = <<v::float-size(32)>>
    bfloat_bits = float_bits >>> 16
    widened_bits = bfloat_bits <<< 16
    <<widened::float-size(32)>> = <<widened_bits::unsigned-integer-size(32)>>
    <<bits::unsigned-integer-size(64)>> = <<widened::float-size(64)>>
    bits
  end

  defp float_to_bits(v) do
    <<float_rounded::float-size(32)>> = <<v::float-size(32)>>
    <<bits::unsigned-integer-size(64)>> = <<float_rounded::float-size(64)>>
    bits
  end

  defp double_to_bits(v) when is_float(v) do
    <<bits::unsigned-integer-size(64)>> = <<v::float-size(64)>>
    bits
  end
end

defimpl Wyvern.IR, for: Wyvern.Value.Float do
  alias Wyvern.IR.Helpers

  def to_ir(value, ctx), do: Helpers.typed_operand(value, ctx)
  def resolve_names(_, ctx), do: ctx
end

defimpl Wyvern.IROperand, for: Wyvern.Value.Float do
  alias Wyvern.IR
  alias Wyvern.Value

  def to_operand(%Value.Float{value: value}, %IR.Context{} = ctx) do
    value_str =
      value
      |> Integer.to_string(16)
      |> String.pad_leading(16, "0")
      |> String.downcase()

    {"0x#{value_str}", ctx}
  end
end
