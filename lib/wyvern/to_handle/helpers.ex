defmodule Wyvern.ToHandle.Helpers do
  @moduledoc """
  Shared `Wyvern.ToHandle` implementation bodies.

  Most instructions derive the type of their result handle in one of a few ways.
  These helpers name those ways so that each `defimpl` states only which one it
  uses. Instructions with a bespoke rule implement `to_handle/1` directly.
  """

  alias Wyvern.Type
  alias Wyvern.Value.Handle

  @doc """
  A handle typed from the first operand — used by the binary operations, whose
  result takes the same type as their (identically typed) operands.
  """
  @spec from_op1(struct()) :: Handle.t()
  def from_op1(%{id: id, op1: op1}), do: Handle.new(id, op1.type)

  @doc """
  A handle typed from the instruction's conversion target.
  """
  @spec from_to_type(struct()) :: Handle.t()
  def from_to_type(%{id: id, to_type: to_type}), do: Handle.new(id, to_type)

  @doc """
  A handle typed as a pointer — used by instructions that always yield an address.
  """
  @spec as_ptr(struct()) :: Handle.t()
  def as_ptr(%{id: id}), do: Handle.new(id, Type.ptr())
end
