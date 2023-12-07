defmodule Ex9.Proto do
  @moduledoc """
  Protocol definition of standard 9P messages.
  """

  use Ex9.Message.Proto

  type :t, :version, 100, <<msize::4*8-little, rest_s::2*8-little, rest::binary>> do
    %{msize: msize, version: binary_part(rest, 0, rest_s)}
  end

  type :r, :version, 101, <<msize::4*8-little, rest_s::2*8-little, rest::binary>> do
    %{msize: msize, version: binary_part(rest, 0, rest_s)}
  end

  type(:t, :auth, 102)
  type(:r, :auth, 103)
  type(:t, :attach, 104)
  type(:r, :attach, 105)
  type(:r, :error, 107)
  type(:t, :flush, 108)
  type(:r, :flush, 109)
  type(:t, :walk, 110)
  type(:r, :walk, 111)
  type(:t, :open, 112)
  type(:r, :open, 113)
  type(:t, :create, 114)
  type(:r, :create, 115)
  type(:t, :read, 116)
  type(:r, :read, 117)
  type(:t, :write, 118)
  type(:r, :write, 119)
  type(:t, :clunk, 120)
  type(:r, :clunk, 121)
  type(:t, :remove, 122)
  type(:r, :remove, 123)
  type(:t, :stat, 124)
  type(:r, :stat, 125)
  type(:t, :wstat, 126)
  type(:r, :wstat, 127)
end
