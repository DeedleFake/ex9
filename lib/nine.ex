defmodule Ex9P.Nine do
  @moduledoc """
  Protocol definition of standard 9P messages.
  """

  use Ex9P.Proto

  import Bitwise

  @nofid (1 <<< 32) - 1

  defmodule QID do
    @enforce_keys [:type, :version, :path]
    defstruct @enforce_keys

    def decode(<<type::8, version::8*4-little, path::8*8-little, rest::binary>>) do
      {%__MODULE__{type: type, version: version, path: path}, rest}
    end

    def encode(%{type: type, version: version, path: path}) do
      <<type::8, version::8*4-little, path::8*8-little>>
    end
  end

  defmodule Tversion do
    @enforce_keys [:msize, :version]
    defstruct @enforce_keys
  end

  defmodule Rversion do
    @enforce_keys [:msize, :version]
    defstruct @enforce_keys
  end

  defmodule Tauth do
    @enforce_keys [:afid, :uname, :aname]
    defstruct @enforce_keys
  end

  defmodule Rauth do
    @enforce_keys [:aqid]
    defstruct @enforce_keys
  end

  defmodule Rerror do
    @enforce_keys [:ename]
    defstruct @enforce_keys
  end

  defmodule Tattach do
    @enforce_keys [:fid, :afid, :uname, :aname]
    defstruct @enforce_keys
  end

  defmodule Rattach do
    @enforce_keys [:qid]
    defstruct @enforce_keys
  end

  defmodule Tflush do
    @enforce_keys [:oldtag]
    defstruct @enforce_keys
  end

  defmodule Rflush do
    defstruct []
  end

  defmodule Twalk do
    @enforce_keys [:fid, :newfid, :wname]
    defstruct @enforce_keys
  end

  defmodule Rwalk do
    @enforce_keys [:wqid]
    defstruct @enforce_keys
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

  @impl true
  def decode(100, <<msize::4*8-little, rest::binary>>) do
    {version, ""} = decode_binary(rest)
    %Tversion{msize: msize, version: version}
  end

  @impl true
  def decode(101, <<msize::4*8-little, rest::binary>>) do
    {version, ""} = decode_binary(rest)
    %Rversion{msize: msize, version: version}
  end

  @impl true
  def decode(102, <<afid::8*4-little, rest::binary>>) do
    {uname, rest} = decode_binary(rest)
    {aname, ""} = decode_binary(rest)
    %Tauth{afid: afid, uname: uname, aname: aname}
  end

  @impl true
  def decode(103, <<data::13*8-binary>>) do
    {aqid, ""} = QID.decode(data)
    %Rauth{aqid: aqid}
  end

  @impl true
  def decode(107, <<ename::binary>>) do
    {ename, ""} = decode_binary(ename)
    %Rerror{ename: ename}
  end

  @impl true
  def decode(104, <<fid::4*8-little, afid::4*8-little, rest::binary>>) do
    afid = with @nofid <- afid, do: :nofid
    {uname, rest} = decode_binary(rest)
    {aname, ""} = decode_binary(rest)
    %Tattach{fid: fid, afid: afid, uname: uname, aname: aname}
  end

  @impl true
  def decode(105, data) when is_binary(data) do
    {qid, ""} = QID.decode(data)
    %Rattach{qid: qid}
  end

  @impl true
  def decode(108, <<oldtag::2*8-little>>) do
    %Tflush{oldtag: oldtag}
  end

  @impl true
  def decode(109, "") do
    %Rflush{}
  end

  @impl true
  def decode(110, <<fid::4*8-little, newfid::4*8-little, rest::binary>>) do
    {wname, ""} = decode_list(rest, &decode_binary/1)
    %Twalk{fid: fid, newfid: newfid, wname: wname}
  end

  @impl true
  def decode(111, data) when is_binary(data) do
    {wqid, ""} = decode_list(data, &QID.decode/1)
    %Rwalk{wqid: wqid}
  end

  @impl true
  def encode(%Tversion{msize: msize, version: version}) do
    data = [<<msize::4*8-little>>, encode_binary(version)]
    {100, data}
  end

  @impl true
  def encode(%Rversion{msize: msize, version: version}) do
    data = [<<msize::4*8-little>>, encode_binary(version)]
    {101, data}
  end

  @impl true
  def encode(%Tauth{afid: afid, uname: uname, aname: aname}) do
    data = [<<afid::8*4-little>>, encode_binary(uname), encode_binary(aname)]
    {102, data}
  end

  @impl true
  def encode(%Rauth{aqid: aqid}) do
    data = QID.encode(aqid)
    {103, data}
  end

  @impl true
  def encode(%Rerror{ename: ename}) do
    data = encode_binary(ename)
    {107, data}
  end

  @impl true
  def encode(%Tattach{fid: fid, afid: afid, uname: uname, aname: aname}) do
    afid = with :nofid <- afid, do: @nofid

    data =
      [
        <<fid::4*8-little, afid::4*8-little>>,
        encode_binary(uname),
        encode_binary(aname)
      ]

    {104, data}
  end

  @impl true
  def encode(%Rattach{qid: qid}) do
    data = QID.encode(qid)
    {105, data}
  end

  @impl true
  def encode(%Tflush{oldtag: oldtag}) do
    data = <<oldtag::2*8-little>>
    {108, data}
  end

  @impl true
  def encode(%Rflush{}) do
    {109, ""}
  end

  @impl true
  def encode(%Twalk{fid: fid, newfid: newfid, wname: wname}) do
    data =
      [
        <<fid::4*8-little, newfid::4*8-little>>,
        encode_list(wname, &encode_binary/1)
      ]

    {110, data}
  end

  @impl true
  def encode(%Rwalk{wqid: wqid}) do
    data = encode_list(wqid, &QID.encode/1)
    {111, data}
  end
end
