defmodule Ex9P.Nine.QID do
  use TypedStruct
  alias Ex9P.Nine.Perms

  typedstruct do
    field :type, Perms.type(), default: -1
    field :version, integer(), default: -1
    field :path, integer(), default: -1
  end

  @spec decode(binary()) :: {t(), binary()}
  def decode(<<
        type::1*8-little-signed,
        version::4*8-little-signed,
        path::8*8-little-signed,
        rest::binary
      >>) do
    {%__MODULE__{type: type, version: version, path: path}, rest}
  end

  @spec encode(t()) :: iodata()
  def encode(%__MODULE__{type: type, version: version, path: path}) do
    <<type::1*8-signed, version::4*8-little, path::8*8-little>>
  end
end
