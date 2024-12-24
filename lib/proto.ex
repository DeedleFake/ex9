defmodule Ex9P.Proto do
  @moduledoc """
  Protocol definition of standard 9P messages.
  """

  @behaviour Ex9P.Message.Proto
  import Ex9P.Message, only: [serialize_binary: 1, deserialize_binary: 1]

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

  @impl true
  def deserialize(100, <<msize::4*8-little, rest::binary>>) do
    {version, ""} = deserialize_binary(rest)
    data = %{msize: msize, version: version}
    {:tversion, data}
  end

  @impl true
  def deserialize(101, <<msize::4*8-little, rest::binary>>) do
    {version, ""} = deserialize_binary(rest)
    data = %{msize: msize, version: version}
    {:rversion, data}
  end

  @impl true
  def deserialize(102, <<afid::8*4-little, rest::binary>>) do
    {uname, rest} = deserialize_binary(rest)
    {aname, ""} = deserialize_binary(rest)
    data = %{afid: afid, uname: uname, aname: aname}
    {:tauth, data}
  end

  @impl true
  def deserialize(103, <<data::13*8-binary>>) do
    {aqid, ""} = QID.deserialize(data)
    data = %{aqid: aqid}
    {:rauth, data}
  end

  @impl true
  def serialize(:tversion, %{msize: msize, version: version}) do
    data = <<msize::4*8-little, serialize_binary(version)::binary>>
    {100, data}
  end

  @impl true
  def serialize(:rversion, %{msize: msize, version: version}) do
    data = <<msize::4*8-little, serialize_binary(version)::binary>>
    {101, data}
  end

  @impl true
  def serialize(:tauth, %{afid: afid, uname: uname, aname: aname}) do
    data = <<afid::8*4-little, serialize_binary(uname)::binary, serialize_binary(aname)::binary>>
    {102, data}
  end

  @impl true
  def serialize(:rauth, %{aqid: aqid}) do
    data = QID.serialize(aqid)
    {103, data}
  end
end
