defmodule Ex9P.Nine.DSL do
  @moduledoc false

  defmacro defmessage(name, type_id, do: block) do
    quote do
      defmodule unquote(name) do
        @behaviour __MODULE__
        @callback decode(binary()) :: %__MODULE__{}
        @callback encode(%__MODULE__{}) :: iodata()

        @nofid (1 <<< 32) - 1

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

  import Bitwise
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
    def encode(%{type: type, version: version, path: path}) do
      <<type::8, version::8*4-little, path::8*8-little>>
    end
  end

  defmessage Tversion, 100 do
    use TypedStruct

    typedstruct enforce: true do
      field :msize, pos_integer()
      field :version, binary()
    end

    @impl true
    def decode(<<msize::4*8-little, rest::binary>>) do
      {version, ""} = decode_binary(rest)
      %Tversion{msize: msize, version: version}
    end

    @impl true
    def encode(%Tversion{msize: msize, version: version}) do
      [<<msize::4*8-little>>, encode_binary(version)]
    end
  end

  defmessage Rversion, 101 do
    use TypedStruct

    typedstruct enforce: true do
      field :msize, pos_integer()
      field :version, binary()
    end

    @impl true
    def decode(<<msize::4*8-little, rest::binary>>) do
      {version, ""} = decode_binary(rest)
      %Rversion{msize: msize, version: version}
    end

    @impl true
    def encode(%Rversion{msize: msize, version: version}) do
      [<<msize::4*8-little>>, encode_binary(version)]
    end
  end

  defmessage Tauth, 102 do
    use TypedStruct

    typedstruct enforce: true do
      field :afid, Ex9P.Nine.fid()
      field :uname, binary()
      field :aname, binary()
    end

    @impl true
    def decode(<<afid::8*4-little, rest::binary>>) do
      {uname, rest} = decode_binary(rest)
      {aname, ""} = decode_binary(rest)
      %Tauth{afid: afid, uname: uname, aname: aname}
    end

    @impl true
    def encode(%Tauth{afid: afid, uname: uname, aname: aname}) do
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
      %Rauth{aqid: aqid}
    end

    @impl true
    def encode(%Rauth{aqid: aqid}) do
      QID.encode(aqid)
    end
  end

  defmessage Rerror, 107 do
    use TypedStruct

    typedstruct enforce: true do
      field :ename, binary()
    end

    @impl true
    def decode(<<ename::binary>>) do
      {ename, ""} = decode_binary(ename)
      %Rerror{ename: ename}
    end

    @impl true
    def encode(%Rerror{ename: ename}) do
      encode_binary(ename)
    end
  end

  defmessage Tattach, 104 do
    use TypedStruct

    typedstruct enforce: true do
      field :fid, Ex9P.Nine.fid()
      field :afid, Ex9P.Nine.fid()
      field :uname, binary()
      field :aname, binary()
    end

    @impl true
    def decode(<<fid::4*8-little, afid::4*8-little, rest::binary>>) do
      afid = with @nofid <- afid, do: :nofid
      {uname, rest} = decode_binary(rest)
      {aname, ""} = decode_binary(rest)
      %Tattach{fid: fid, afid: afid, uname: uname, aname: aname}
    end

    @impl true
    def encode(%Tattach{fid: fid, afid: afid, uname: uname, aname: aname}) do
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
      %Rattach{qid: qid}
    end

    @impl true
    def encode(%Rattach{qid: qid}) do
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
      %Tflush{oldtag: oldtag}
    end

    @impl true
    def encode(%Tflush{oldtag: oldtag}) do
      <<oldtag::2*8-little>>
    end
  end

  defmessage Rflush, 109 do
    defstruct []
    @type t() :: %__MODULE__{}

    @impl true
    def decode("") do
      %Rflush{}
    end

    @impl true
    def encode(%Rflush{}) do
      ""
    end
  end

  defmessage Twalk, 110 do
    use TypedStruct

    typedstruct enforce: true do
      field :fid, Ex9P.Nine.fid()
      field :newfid, Ex9P.Nine.fid()
      field :wname, [binary()]
    end

    @impl true
    def decode(<<fid::4*8-little, newfid::4*8-little, rest::binary>>) do
      {wname, ""} = decode_list(rest, &decode_binary/1)
      %Twalk{fid: fid, newfid: newfid, wname: wname}
    end

    @impl true
    def encode(%Twalk{fid: fid, newfid: newfid, wname: wname}) do
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
      %Rwalk{wqid: wqid}
    end

    @impl true
    def encode(%Rwalk{wqid: wqid}) do
      encode_list(wqid, &QID.encode/1)
    end
  end

  # Topen   112
  # Ropen   113
  # Tcreate 114
  # Rcreate 115
  # Tread   116
  # Rread   117
  # Twrite  118
  # Rwrite  119
  # Tclunk  120
  # Rclunk  121
  # Tremove 122
  # Rremove 123
  # Tstat   124
  # Rstat   125
  # Twstat  126
  # Rwstat  127
  # Topenfd 98
  # Ropenfd 99
end
