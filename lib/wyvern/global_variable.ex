defmodule Wyvern.GlobalVariable do
  alias Wyvern.Type
  alias Wyvern.Value
  import Wyvern.Value.Guards
  import Wyvern.Type.Guards

  @valid_options [
    :mutable,
    :linkage,
    :visibility,
    :addr
  ]

  @declaration_linkages [:external, :extern_weak]
  @definition_linkages [
    :private,
    :internal,
    :available_externally,
    :linkonce,
    :weak,
    :common,
    :appending,
    :linkonce_odr,
    :weak_odr
  ]
  @linkages @declaration_linkages ++ @definition_linkages

  @type linkage ::
          nil
          | :private
          | :internal
          | :available_externally
          | :linkonce
          | :weak
          | :common
          | :appending
          | :extern_weak
          | :linkonce_odr
          | :weak_odr
          | :external

  @visibility [:default, :hidden, :protected]

  @type visibility :: nil | :default | :hidden | :protected

  @addr [:unnamed_addr, :local_unnamed_addr]

  @type addr :: nil | :unnamed_addr | :local_unnamed_addr

  @type t :: %__MODULE__{
          name: String.t(),
          type: Type.t(),
          # nil means an extern global
          initializer: Value.t() | nil,
          # true -> global var, false -> constant
          mutable: boolean(),
          linkage: linkage(),
          visibility: visibility(),
          addr: addr()
        }
  defstruct [:name, :type, :initializer, :mutable, :linkage, :visibility, :addr]

  @spec new(String.t(), Type.t() | Value.t(), keyword()) :: __MODULE__.t()
  def new(name, type_or_initializer, opts \\ [])

  def new(name, type, opts) when is_llvm_type(type) and is_list(opts) do
    validate_opts!(opts)

    mutable = Keyword.get(opts, :mutable, true)
    linkage = Keyword.get(opts, :linkage)
    validate_linkage!(linkage, false)
    visibility = Keyword.get(opts, :visibility)
    validate_visibility!(visibility, linkage)
    addr = Keyword.get(opts, :addr)
    validate_addr!(addr)

    %__MODULE__{
      name: name,
      type: type,
      initializer: nil,
      mutable: mutable,
      linkage: linkage,
      visibility: visibility,
      addr: addr
    }
  end

  def new(name, initializer, opts) when is_llvm_value(initializer) and is_list(opts) do
    validate_opts!(opts)

    mutable = Keyword.get(opts, :mutable, true)
    linkage = Keyword.get(opts, :linkage)
    validate_linkage!(linkage, true)
    if linkage == :appending, do: validate_appending_initializer!(initializer)
    if linkage == :common, do: validate_common_initializer!(initializer, mutable)
    visibility = Keyword.get(opts, :visibility)
    validate_visibility!(visibility, linkage)
    addr = Keyword.get(opts, :addr)
    validate_addr!(addr)

    if Value.dynamic_value?(initializer),
      do: raise("unsupported: cannot initialize global with dynamic value!")

    %__MODULE__{
      name: name,
      type: initializer.type,
      initializer: initializer,
      mutable: mutable,
      linkage: linkage,
      visibility: visibility,
      addr: addr
    }
  end

  defp validate_opts!(opts) do
    unless Enum.all?(Keyword.keys(opts), fn opt -> opt in @valid_options end),
      do: raise("Invalid option specified!")
  end

  defp validate_linkage!(nil, _has_initializer), do: :ok

  defp validate_linkage!(linkage, has_initializer) do
    cond do
      linkage not in @linkages ->
        raise "unknown linkage #{inspect(linkage)}!"

      has_initializer and linkage in @declaration_linkages ->
        raise "linkage #{inspect(linkage)} cannot be combined with an initializer!"

      not has_initializer and linkage in @definition_linkages ->
        raise "linkage #{inspect(linkage)} requires an initializer!"

      true ->
        :ok
    end
  end

  defp validate_appending_initializer!(initializer) do
    if !Value.array_value?(initializer),
      do: raise("Only global arrays can have appending linkage!")
  end

  defp validate_common_initializer!(initializer, mutable) do
    unless mutable, do: raise("'common' global may not be marked constant!")
    unless Value.zero?(initializer), do: raise("'common' global must have zero initializer!")
  end

  defp validate_visibility!(visibility, linkage) do
    if visibility != nil && visibility not in @visibility,
      do: raise("Invalid visibility class #{inspect(visibility)}!")

    if linkage in [:internal, :private] && (visibility != nil && visibility != :default),
      do: raise("Cannot combine :internal linkage with non-default visibility!")
  end

  defp validate_addr!(nil), do: nil
  defp validate_addr!(addr) when addr in @addr, do: nil
  defp validate_addr!(addr), do: raise("Unknown address mode: #{addr}!")
end
