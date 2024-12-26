defmodule Ex9P.Nine.DSL do
  @moduledoc false

  defmacro defmessage(name, type_id, do: block) do
    quote do
      defmodule unquote(name) do
        @behaviour __MODULE__
        @callback decode(binary()) :: %__MODULE__{}
        @callback encode(%__MODULE__{}) :: iodata()

        @nofid Bitwise.bsl(1, 32) - 1

        def type_id(), do: unquote(type_id)
        unquote(block)
      end

      @impl true
      def decode(unquote(type_id), data), do: unquote(name).decode(data)

      @impl true
      def encode(%unquote(name){} = message),
        do: {unquote(type_id), unquote(name).encode(message)}
    end
  end
end

defmodule Ex9P.Nine do
  @moduledoc """
  Protocol definition of standard 9P messages.
  """

  use Ex9P.Proto

  import __MODULE__.DSL

  @opaque fid() :: non_neg_integer()

  defmodule QID do
    use TypedStruct

    typedstruct enforce: true do
      field :type, non_neg_integer()
      field :version, non_neg_integer()
      field :path, non_neg_integer()
    end

    @spec decode(binary()) :: {t(), binary()}
    def decode(<<type::8, version::8*4-little, path::8*8-little, rest::binary>>) do
      {%__MODULE__{type: type, version: version, path: path}, rest}
    end

    @spec encode(t()) :: iodata()
    def encode(%__MODULE__{type: type, version: version, path: path}) do
      <<type::8, version::8*4-little, path::8*8-little>>
    end
  end

  defmodule DirEntry do
    use TypedStruct

    typedstruct enforce: true do
      field :type, integer()
      field :dev, integer()
      field :qid, QID.t()
      field :mode, non_neg_integer()
      field :atime, DateTime.t()
      field :mtime, DateTime.t()
      field :length, non_neg_integer()
      field :name, String.t()
      field :uid, String.t()
      field :gid, String.t()
      field :muid, String.t()
    end

    @spec decode(binary()) :: {t(), binary()}
    def decode(<<type::2*8-little, dev::4*8-little, data::binary>>) do
      {qid, data} = QID.decode(data)

      <<
        mode::4*8-little,
        atime::4*8-little,
        mtime::4*8-little,
        length::8*8-little,
        data::binary
      >> = data

      {name, data} = decode_binary(data)
      {uid, data} = decode_binary(data)
      {gid, data} = decode_binary(data)
      {muid, data} = decode_binary(data)

      atime = DateTime.from_unix!(atime, :second)
      mtime = DateTime.from_unix!(mtime, :second)

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
       }, data}
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
      atime = DateTime.to_unix(atime)
      mtime = DateTime.to_unix(mtime)

      [
        <<type::2*8-little, dev::4*8-little>>,
        QID.encode(qid),
        <<mode::4*8-little, atime::4*8-little, mtime::4*8-little, length::8*8-little>>,
        encode_binary(name),
        encode_binary(uid),
        encode_binary(gid),
        encode_binary(muid)
      ]
    end
  end

  defmessage Tversion, 100 do
    use TypedStruct

    typedstruct enforce: true do
      field :msize, pos_integer()
      field :version, String.t()
    end

    @impl true
    def decode(<<msize::4*8-little, rest::binary>>) do
      {version, ""} = decode_binary(rest)
      %__MODULE__{msize: msize, version: version}
    end

    @impl true
    def encode(%__MODULE__{msize: msize, version: version}) do
      [<<msize::4*8-little>>, encode_binary(version)]
    end
  end

  defmessage Rversion, 101 do
    use TypedStruct

    typedstruct enforce: true do
      field :msize, pos_integer()
      field :version, String.t()
    end

    @impl true
    def decode(<<msize::4*8-little, rest::binary>>) do
      {version, ""} = decode_binary(rest)
      %__MODULE__{msize: msize, version: version}
    end

    @impl true
    def encode(%__MODULE__{msize: msize, version: version}) do
      [<<msize::4*8-little>>, encode_binary(version)]
    end
  end

  defmessage Tauth, 102 do
    use TypedStruct

    typedstruct enforce: true do
      field :afid, Ex9P.Nine.fid()
      field :uname, String.t()
      field :aname, String.t()
    end

    @impl true
    def decode(<<afid::8*4-little, rest::binary>>) do
      {uname, rest} = decode_binary(rest)
      {aname, ""} = decode_binary(rest)
      %__MODULE__{afid: afid, uname: uname, aname: aname}
    end

    @impl true
    def encode(%__MODULE__{afid: afid, uname: uname, aname: aname}) do
      [<<afid::8*4-little>>, encode_binary(uname), encode_binary(aname)]
    end
  end

  defmessage Rauth, 103 do
    use TypedStruct

    typedstruct enforce: true do
      field :aqid, QID.t()
    end

    @impl true
    def decode(<<data::13*8-binary>>) do
      {aqid, ""} = QID.decode(data)
      %__MODULE__{aqid: aqid}
    end

    @impl true
    def encode(%__MODULE__{aqid: aqid}) do
      QID.encode(aqid)
    end
  end

  defmessage Rerror, 107 do
    use TypedStruct

    typedstruct enforce: true do
      field :ename, String.t()
    end

    @impl true
    def decode(<<ename::binary>>) do
      {ename, ""} = decode_binary(ename)
      %__MODULE__{ename: ename}
    end

    @impl true
    def encode(%__MODULE__{ename: ename}) do
      encode_binary(ename)
    end
  end

  defmessage Tattach, 104 do
    use TypedStruct

    typedstruct enforce: true do
      field :fid, Ex9P.Nine.fid()
      field :afid, Ex9P.Nine.fid()
      field :uname, String.t()
      field :aname, String.t()
    end

    @impl true
    def decode(<<fid::4*8-little, afid::4*8-little, rest::binary>>) do
      afid = with @nofid <- afid, do: :nofid
      {uname, rest} = decode_binary(rest)
      {aname, ""} = decode_binary(rest)
      %__MODULE__{fid: fid, afid: afid, uname: uname, aname: aname}
    end

    @impl true
    def encode(%__MODULE__{fid: fid, afid: afid, uname: uname, aname: aname}) do
      afid = with :nofid <- afid, do: @nofid

      [
        <<fid::4*8-little, afid::4*8-little>>,
        encode_binary(uname),
        encode_binary(aname)
      ]
    end
  end

  defmessage Rattach, 105 do
    use TypedStruct

    typedstruct enforce: true do
      field :qid, QID.t()
    end

    @impl true
    def decode(data) do
      {qid, ""} = QID.decode(data)
      %__MODULE__{qid: qid}
    end

    @impl true
    def encode(%__MODULE__{qid: qid}) do
      QID.encode(qid)
    end
  end

  defmessage Tflush, 108 do
    use TypedStruct

    typedstruct enforce: true do
      field :oldtag, Ex9P.Proto.tag()
    end

    @impl true
    def decode(<<oldtag::2*8-little>>) do
      %__MODULE__{oldtag: oldtag}
    end

    @impl true
    def encode(%__MODULE__{oldtag: oldtag}) do
      <<oldtag::2*8-little>>
    end
  end

  defmessage Rflush, 109 do
    defstruct []
    @type t() :: %__MODULE__{}

    @impl true
    def decode("") do
      %__MODULE__{}
    end

    @impl true
    def encode(%__MODULE__{}) do
      ""
    end
  end

  defmessage Twalk, 110 do
    use TypedStruct

    typedstruct enforce: true do
      field :fid, Ex9P.Nine.fid()
      field :newfid, Ex9P.Nine.fid()
      field :wname, [String.t()]
    end

    @impl true
    def decode(<<fid::4*8-little, newfid::4*8-little, rest::binary>>) do
      {wname, ""} = decode_list(rest, &decode_binary/1)
      %__MODULE__{fid: fid, newfid: newfid, wname: wname}
    end

    @impl true
    def encode(%__MODULE__{fid: fid, newfid: newfid, wname: wname}) do
      [
        <<fid::4*8-little, newfid::4*8-little>>,
        encode_list(wname, &encode_binary/1)
      ]
    end
  end

  defmessage Rwalk, 111 do
    use TypedStruct

    typedstruct enforce: true do
      field :wqid, [QID.t()]
    end

    @impl true
    def decode(data) when is_binary(data) do
      {wqid, ""} = decode_list(data, &QID.decode/1)
      %__MODULE__{wqid: wqid}
    end

    @impl true
    def encode(%__MODULE__{wqid: wqid}) do
      encode_list(wqid, &QID.encode/1)
    end
  end

  defmessage Topen, 112 do
    use TypedStruct

    typedstruct do
      field :fid, non_neg_integer()
      field :mode, pos_integer()
    end

    @impl true
    def decode(<<fid::4*8-little, mode::1*8-little>>) do
      %__MODULE__{fid: fid, mode: mode}
    end

    @impl true
    def encode(%__MODULE__{fid: fid, mode: mode}) do
      <<fid::4*8-little, mode::1*8-little>>
    end
  end

  defmessage Ropen, 113 do
    use TypedStruct

    typedstruct enforce: true do
      field :qid, QID.t()
      field :iounit, integer()
    end

    @impl true
    def decode(data) do
      {qid, data} = QID.decode(data)
      <<iounit::4*8-little>> = data
      %__MODULE__{qid: qid, iounit: iounit}
    end

    @impl true
    def encode(%__MODULE__{qid: qid, iounit: iounit}) do
      [QID.encode(qid), <<iounit::4*8-little>>]
    end
  end

  defmessage Tcreate, 114 do
    use TypedStruct

    typedstruct enforce: true do
      field :fid, Ex9P.Nine.fid()
      field :name, String.t()
      field :perm, pos_integer()
      field :mode, pos_integer()
    end

    @impl true
    def decode(<<fid::4*8-little, data::binary>>) do
      {name, data} = decode_binary(data)
      <<perm::4*8-little, mode::1*8-little>> = data
      %__MODULE__{fid: fid, name: name, perm: perm, mode: mode}
    end

    @impl true
    def encode(%__MODULE__{fid: fid, name: name, perm: perm, mode: mode}) do
      [
        <<fid::4*8-little>>,
        encode_binary(name),
        <<perm::4*8-little, mode::1*8-little>>
      ]
    end
  end

  defmessage Rcreate, 115 do
    use TypedStruct

    typedstruct enforce: true do
      field :qid, QID.t()
      field :iounit, integer()
    end

    @impl true
    def decode(data) do
      {qid, data} = QID.decode(data)
      <<iounit::4*8-little>> = data
      %__MODULE__{qid: qid, iounit: iounit}
    end

    @impl true
    def encode(%__MODULE__{qid: qid, iounit: iounit}) do
      [QID.encode(qid), <<iounit::4*8-little>>]
    end
  end

  defmessage Tread, 116 do
    use TypedStruct

    typedstruct enforce: true do
      field :fid, Ex9P.Nine.fid()
      field :offset, non_neg_integer()
      field :count, non_neg_integer()
    end

    @impl true
    def decode(<<fid::4*8-little, offset::8*8-little, count::4*8-little>>) do
      %__MODULE__{fid: fid, offset: offset, count: count}
    end

    @impl true
    def encode(%__MODULE__{fid: fid, offset: offset, count: count}) do
      <<fid::4*8-little, offset::8*8-little, count::4*8-little>>
    end
  end

  defmessage Rread, 117 do
    use TypedStruct

    typedstruct enforce: true do
      field :data, iodata()
    end

    @impl true
    def decode(data) do
      {data, ""} = decode_binary(4, data)
      %__MODULE__{data: data}
    end

    @impl true
    def encode(%__MODULE__{data: data}) do
      encode_binary(4, data)
    end
  end

  defmessage Twrite, 118 do
    use TypedStruct

    typedstruct enforce: true do
      field :fid, Ex9P.Nine.fid()
      field :offset, non_neg_integer()
      field :data, iodata()
    end

    @impl true
    def decode(<<fid::4*8-little, offset::8*8-little, data::binary>>) do
      {data, ""} = decode_binary(4, data)
      %__MODULE__{fid: fid, offset: offset, data: data}
    end

    @impl true
    def encode(%__MODULE__{fid: fid, offset: offset, data: data}) do
      [
        <<fid::4*8-little, offset::8*8-little>>,
        encode_binary(4, data)
      ]
    end
  end

  defmessage Rwrite, 119 do
    use TypedStruct

    typedstruct enforce: true do
      field :count, non_neg_integer()
    end

    @impl true
    def decode(<<count::4*8-little>>) do
      %__MODULE__{count: count}
    end

    @impl true
    def encode(%__MODULE__{count: count}) do
      <<count::4*8-little>>
    end
  end

  defmessage Tclunk, 120 do
    use TypedStruct

    typedstruct enforce: true do
      field :fid, Ex9P.Nine.fid()
    end

    @impl true
    def decode(<<fid::4*8-little>>) do
      %__MODULE__{fid: fid}
    end

    @impl true
    def encode(%__MODULE__{fid: fid}) do
      <<fid::4*8-little>>
    end
  end

  defmessage Rclunk, 121 do
    defstruct []
    @type t() :: %__MODULE__{}

    @impl true
    def decode("") do
      %__MODULE__{}
    end

    @impl true
    def encode(%__MODULE__{}) do
      ""
    end
  end

  defmessage Tremove, 122 do
    use TypedStruct

    typedstruct enforce: true do
      field :fid, Ex9P.Nine.fid()
    end

    @impl true
    def decode(<<fid::4*8-little>>) do
      %__MODULE__{fid: fid}
    end

    @impl true
    def encode(%__MODULE__{fid: fid}) do
      <<fid::4*8-little>>
    end
  end

  defmessage Rremove, 123 do
    defstruct []
    @type t() :: %__MODULE__{}

    @impl true
    def decode("") do
      %__MODULE__{}
    end

    @impl true
    def encode(%__MODULE__{}) do
      ""
    end
  end

  defmessage Tstat, 124 do
    use TypedStruct

    typedstruct enforce: true do
      field :fid, Ex9P.Nine.fid()
    end

    @impl true
    def decode(<<fid::4*8-little>>) do
      %__MODULE__{fid: fid}
    end

    @impl true
    def encode(%__MODULE__{fid: fid}) do
      <<fid::4*8-little>>
    end
  end

  defmessage Rstat, 125 do
    use TypedStruct

    typedstruct enforce: true do
      field :stat, DirEntry.t()
    end

    @impl true
    def decode(data) do
      {stat, ""} = DirEntry.decode(data)
      %__MODULE__{stat: stat}
    end

    @impl true
    def encode(%__MODULE__{stat: stat}) do
      DirEntry.encode(stat)
    end
  end

  # Twstat, 126
  # Rwstat, 127
  # Topenfd, 98
  # Ropenfd, 99
end
