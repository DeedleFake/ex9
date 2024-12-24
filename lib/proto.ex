defmodule Ex9P.Proto do
  @moduledoc """
  Protocol definition of standard 9P messages.
  """

  import Bitwise

  @behaviour Ex9P.Message.Proto
  import Ex9P.Message, only: [serialize_binary: 1, deserialize_binary: 1]

  @nofid (1 <<< 32) - 1
  def nofid(), do: @nofid
  defguard is_nofid(fid) when fid === @nofid

  defmodule QID do
    @enforce_keys [:type, :version, :path]
    defstruct @enforce_keys

    def deserialize(<<type::8, version::8*4-little, path::8*8-little, rest::binary>>) do
      {%__MODULE__{type: type, version: version, path: path}, rest}
    end

    def serialize(%{type: type, version: version, path: path}) do
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

  # Tflush  108
  # Rflush  109
  # Twalk   110
  # Rwalk   111
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
  def deserialize(100, <<msize::4*8-little, rest::binary>>) do
    {version, ""} = deserialize_binary(rest)
    %Tversion{msize: msize, version: version}
  end

  @impl true
  def deserialize(101, <<msize::4*8-little, rest::binary>>) do
    {version, ""} = deserialize_binary(rest)
    %Rversion{msize: msize, version: version}
  end

  @impl true
  def deserialize(102, <<afid::8*4-little, rest::binary>>) do
    {uname, rest} = deserialize_binary(rest)
    {aname, ""} = deserialize_binary(rest)
    %Tauth{afid: afid, uname: uname, aname: aname}
  end

  @impl true
  def deserialize(103, <<data::13*8-binary>>) do
    {aqid, ""} = QID.deserialize(data)
    %Rauth{aqid: aqid}
  end

  @impl true
  def deserialize(107, <<ename::binary>>) do
    {ename, ""} = deserialize_binary(ename)
    %Rerror{ename: ename}
  end

  @impl true
  def deserialize(104, <<fid::4*8-little, afid::4*8-little, rest::binary>>) do
    {uname, rest} = deserialize_binary(rest)
    {aname, ""} = deserialize_binary(rest)
    %Tattach{fid: fid, afid: afid, uname: uname, aname: aname}
  end

  @impl true
  def deserialize(105, data) when is_binary(data) do
    {qid, ""} = QID.deserialize(data)
    %Rattach{qid: qid}
  end

  @impl true
  def serialize(%Tversion{msize: msize, version: version}) do
    data = <<msize::4*8-little, serialize_binary(version)::binary>>
    {100, data}
  end

  @impl true
  def serialize(%Rversion{msize: msize, version: version}) do
    data = <<msize::4*8-little, serialize_binary(version)::binary>>
    {101, data}
  end

  @impl true
  def serialize(%Tauth{afid: afid, uname: uname, aname: aname}) do
    data = <<afid::8*4-little, serialize_binary(uname)::binary, serialize_binary(aname)::binary>>
    {102, data}
  end

  @impl true
  def serialize(%Rauth{aqid: aqid}) do
    data = QID.serialize(aqid)
    {103, data}
  end

  @impl true
  def serialize(%Rerror{ename: ename}) do
    data = serialize_binary(ename)
    {107, data}
  end

  @impl true
  def serialize(%Tattach{fid: fid, afid: afid, uname: uname, aname: aname}) do
    data =
      <<
        fid::4*8-little,
        afid::4*8-little,
        serialize_binary(uname)::binary,
        serialize_binary(aname)::binary
      >>

    {104, data}
  end

  @impl true
  def serialize(%Rattach{qid: qid}) do
    data = QID.serialize(qid)
    {105, data}
  end
end
