defmodule Ex9.Proto do
  @moduledoc """
  Protocol definition of standard 9P messages.
  """

  use Ex9.Message.Proto

  type 100, tversion(<<msize::4*8-little, version_s::2*8-little, version::binary>>) do
    %{msize: msize, version: binary_part(version, 0, version_s)}
  end

  type 101, rversion(<<msize::4*8-little, version_s::2*8-little, version::binary>>) do
    %{msize: msize, version: binary_part(version, 0, version_s)}
  end

  type(102, tauth)
  type(103, rauth)
  type(104, tattach)
  type(105, rattach)
  type(107, rerror)
  type(108, tflush)
  type(109, rflush)
  type(110, twalk)
  type(111, rwalk)
  type(112, topen)
  type(113, ropen)
  type(114, tcreate)
  type(115, rcreate)
  type(116, tread)
  type(117, rread)
  type(118, twrite)
  type(119, rwrite)
  type(120, tclunk)
  type(121, rclunk)
  type(122, tremove)
  type(123, rremove)
  type(124, tstat)
  type(125, rstat)
  type(126, twstat)
  type(127, rwstat)

  defmodule QID do
    defstruct type: nil, version: nil, path: nil

    def parse(<<type::8, version::8*4-little, path::8*8-little>>),
      do: %__MODULE__{type: type, version: version, path: path}

    def to_binary(%{type: type, version: version, path: path}),
      do: <<type::8, version::8*4-little, path::8*8-little>>
  end
end
