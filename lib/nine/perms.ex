defmodule Ex9P.Nine.Perms do
  use TypedStruct
  import Bitwise

  @type perm() :: non_neg_integer()
  @read 0x4
  @write 0x2
  @exec 0x1

  @type type() :: non_neg_integer()

  typedstruct do
    field :type, type(), default: 0
    field :owner, perm(), default: 0
    field :group, perm(), default: 0
    field :other, perm(), default: 0
  end

  defguard is_read(perm) when (perm &&& @read) != 0
  defguard is_write(perm) when (perm &&& @write) != 0
  defguard is_exec(perm) when (perm &&& @exec) != 0

  defguard is_dir(type) when (type &&& 0x80) != 0
  defguard is_append(type) when (type &&& 0x40) != 0
  defguard is_execlusive(type) when (type &&& 0x20) != 0
  defguard is_mounted_chan(type) when (type &&& 0x10) != 0
  defguard is_auth(type) when (type &&& 0x8) != 0
  defguard is_tmp(type) when (type &&& 0x4) != 0
  defguard is_symlink(type) when (type &&& 0x2) != 0
  defguard is_plain(type) when type === 0

  @spec decode(binary()) :: {t(), binary()}
  def decode(<<data::4*8-little, rest::binary>>) do
    <<type::8, _::15, owner::3, group::3, other::3>> = <<data::32>>

    {%__MODULE__{
       type: type,
       owner: owner,
       group: group,
       other: other
     }, rest}
  end

  @spec encode(t()) :: iodata()
  def encode(%__MODULE__{type: type, owner: owner, group: group, other: other}) do
    <<type::8, 0::15, owner::3, group::3, other::3>>
  end
end

defimpl String.Chars, for: Ex9P.Nine.Perms do
  import Ex9P.Nine.Perms

  @impl true
  def to_string(perms) do
    <<
      type_string(perms.type)::binary,
      perm_string(perms.owner)::binary,
      perm_string(perms.group)::binary,
      perm_string(perms.other)::binary
    >>
  end

  defp type_string(type) when is_dir(type), do: "d-"
  defp type_string(type) when is_plain(type), do: "--"
  defp type_string(_type), do: "??"

  defp perm_string(perm) do
    <<
      if(is_read(perm), do: "r", else: "-")::binary,
      if(is_write(perm), do: "w", else: "-")::binary,
      if(is_exec(perm), do: "x", else: "-")::binary
    >>
  end
end
