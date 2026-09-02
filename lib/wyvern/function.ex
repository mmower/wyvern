defmodule Wyvern.Function do
  @moduledoc """
  The %Function{} represents a function defintion in the LLVM IR.

  A function does not require an id because it has a global name.
  """
  alias Wyvern.Type
  alias Wyvern.Param
  alias Wyvern.BasicBlock

  @valid_options [
    :linkage,
    :visibility,
    :cconv,
    :addr
  ]

  @definition_linkages [
    :private,
    :internal,
    :available_externally,
    :linkonce,
    :weak,
    :linkonce_odr,
    :weak_odr
  ]

  @type definition_linkage ::
          nil
          | :private
          | :internal
          | :available_externally
          | :linkonce
          | :weak
          | :linkonce_odr
          | :weak_odr

  @visibility [:default, :hidden, :protected]

  @type visibility :: nil | :default | :hidden | :protected

  @addr [:unnamed_addr, :local_unnamed_addr]

  @type addr :: nil | :unnamed_addr | :local_unnamed_addr

  @cconv [:fastcc, :coldcc, :tailcc, :swiftcc, :swifttailcc]

  @type cconv :: [nil | :fastcc | :coldcc | :tailcc | :swiftcc | :swifttailcc]

  @type param_list :: [Param.t()]
  @type block_list :: [BasicBlock.t()]

  @type t :: %__MODULE__{
          name: String.t(),
          ret_type: Type.t(),
          params: param_list(),
          blocks: block_list(),
          linkage: definition_linkage(),
          visibility: visibility(),
          addr: addr(),
          cconv: cconv()
        }
  defstruct [:name, :ret_type, :params, :blocks, :linkage, :visibility, :addr, :cconv]

  @spec new(String.t(), Type.t(), param_list(), block_list(), keyword()) :: __MODULE__.t()
  def new(name, ret_type, params, blocks, opts \\ [])
      when is_binary(name) and is_list(params) and is_list(blocks) do
    validate_opts!(opts)

    validate_params!(params)
    linkage = Keyword.get(opts, :linkage)
    validate_linkage!(linkage)
    visibility = Keyword.get(opts, :visibility)
    validate_visibility!(visibility, linkage)
    cconv = Keyword.get(opts, :cconv)
    validate_cconv!(cconv)
    addr = Keyword.get(opts, :addr)
    validate_addr!(addr)

    %__MODULE__{
      name: name,
      ret_type: ret_type,
      params: params,
      blocks: blocks,
      linkage: linkage,
      visibility: visibility,
      addr: addr,
      cconv: cconv
    }
  end

  defp validate_opts!(opts) do
    unless Enum.all?(Keyword.keys(opts), fn opt -> opt in @valid_options end),
      do: raise("Invalid option specified!")
  end

  defp validate_params!([]), do: nil

  defp validate_params!(params) do
    if Enum.any?(params, fn param -> !match?(%Param{}, param) end),
      do: raise("unsupported: function params must be of type Param!")

    param_names = Enum.map(params, & &1.name)
    param_names = Enum.reject(param_names, &is_nil/1)

    if length(param_names) != length(Enum.uniq(param_names)) do
      raise "unsupported: function cannot use duplicate param names!"
    end
  end

  defp validate_linkage!(linkage) do
    if linkage && linkage not in @definition_linkages,
      do: raise("unsupported linkage #{inspect(linkage)}!")
  end

  defp validate_visibility!(visibility, linkage) do
    if linkage in [:internal, :private] && visibility && visibility != :default,
      do: raise("#{inspect(linkage)} linkage is not compatible with non-default visibility!")

    if visibility && visibility not in @visibility,
      do: raise("unsupported visibility #{inspect(visibility)}!")
  end

  defp validate_addr!(nil), do: nil
  defp validate_addr!(addr) when addr in @addr, do: nil
  defp validate_addr!(addr), do: raise("Unknown address mode: #{addr}!")

  defp validate_cconv!(cconv) do
    if cconv && cconv not in @cconv, do: raise("unsupported calling convention #{cconv}!")
  end
end
