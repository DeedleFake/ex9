defmodule Ex9P.Proto do
  @moduledoc """
  Protocol definition of standard 9P messages.
  """

  use Ex9P.Message.Proto

  defmodule QID do
    defstruct type: nil, version: nil, path: nil

    def parse(<<type::8, version::8*4-little, path::8*8-little>>),
      do: %__MODULE__{type: type, version: version, path: path}

    def to_binary(%{type: type, version: version, path: path}),
      do: <<type::8, version::8*4-little, path::8*8-little>>
  end

  message 100, tversion do
    data(<<msize::4*8-little, rest::binary>>) ->
      {version, _} = parse_bytes(rest)
      %{msize: msize, version: version}

    binary(%{msize: msize, version: version}) ->
      <<msize::4*8-little, to_bytes(version)::binary>>
  end

  message 101, rversion do
    data(<<msize::4*8-little, rest::binary>>) ->
      {version, _} = parse_bytes(rest)
      %{msize: msize, version: version}

    binary(%{msize: msize, version: version}) ->
      <<msize::4*8-little, to_bytes(version)::binary>>
  end

  message 102, tauth do
    data(<<afid::8*4-little, rest::binary>>) ->
      {uname, rest} = parse_bytes(rest)
      {aname, _} = parse_bytes(rest)
      %{afid: afid, uname: uname, aname: aname}

    binary(%{afid: afid, uname: uname, aname: aname}) ->
      <<afid::8*4-little, to_bytes(uname)::binary, to_bytes(aname)::binary>>
  end

  message 103, rauth do
    data(<<data::binary-(13 * 8)>>) ->
      %{aqid: QID.parse(data)}

    binary(%{aqid: aqid}) ->
      QID.to_binary(aqid)
  end

  message(104, tattach)
  message(105, rattach)
  message(107, rerror)
  message(108, tflush)
  message(109, rflush)
  message(110, twalk)
  message(111, rwalk)
  message(112, topen)
  message(113, ropen)
  message(114, tcreate)
  message(115, rcreate)
  message(116, tread)
  message(117, rread)
  message(118, twrite)
  message(119, rwrite)
  message(120, tclunk)
  message(121, rclunk)
  message(122, tremove)
  message(123, rremove)
  message(124, tstat)
  message(125, rstat)
  message(126, twstat)
  message(127, rwstat)
end
