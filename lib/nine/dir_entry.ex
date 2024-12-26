defmodule Ex9P.Nine.DirEntry do
  use TypedStruct
  import Ex9P.Proto
  alias Ex9P.Nine.{QID, Perms}

  typedstruct do
    field :type, integer(), default: -1
    field :dev, integer(), default: -1
    field :qid, QID.t(), default: %QID{type: -1, version: -1, path: -1}
    field :mode, Perms.t(), default: -1
    field :atime, DateTime.t() | nil, default: nil
    field :mtime, DateTime.t() | nil, default: nil
    field :length, integer(), default: -1
    field :name, String.t(), default: ""
    field :uid, String.t(), default: ""
    field :gid, String.t(), default: ""
    field :muid, String.t(), default: ""
  end

  @spec decode(binary()) :: {t(), binary()}
  def decode(<<size::2*8-little, data::binary>>) do
    <<data::(^size)*8-binary, rest::binary>> = data

    <<type::2*8-little, dev::4*8-little, data::binary>> = data
    {qid, data} = QID.decode(data)
    {mode, data} = Perms.decode(data)

    <<
      atime::4*8-little-signed,
      mtime::4*8-little-signed,
      length::8*8-little-signed,
      data::binary
    >> = data

    {name, data} = decode_binary(data)
    {uid, data} = decode_binary(data)
    {gid, data} = decode_binary(data)
    {muid, ""} = decode_binary(data)

    atime = if atime < 0, do: nil, else: DateTime.from_unix!(atime, :second)
    mtime = if mtime < 0, do: nil, else: DateTime.from_unix!(mtime, :second)

    {%__MODULE__{
       type: type,
       dev: dev,
       qid: qid,
       mode: mode,
       atime: atime,
       mtime: mtime,
       length: length,
       name: name,
       uid: uid,
       gid: gid,
       muid: muid
     }, rest}
  end

  @spec encode(t()) :: iodata()
  def encode(%__MODULE__{
        type: type,
        dev: dev,
        qid: qid,
        mode: mode,
        atime: atime,
        mtime: mtime,
        length: length,
        name: name,
        uid: uid,
        gid: gid,
        muid: muid
      }) do
    atime = if atime, do: DateTime.to_unix(atime), else: -1
    mtime = if mtime, do: DateTime.to_unix(mtime), else: -1

    [
      <<type::2*8-little, dev::4*8-little>>,
      QID.encode(qid),
      Perms.encode(mode),
      <<atime::4*8-little, mtime::4*8-little, length::8*8-little>>,
      encode_binary(name),
      encode_binary(uid),
      encode_binary(gid),
      encode_binary(muid)
    ]
  end
end
