defmodule Ex9.Message do
  @moduledoc """
  A single 9P message and related functionality.
  """

  defmodule Type do
    @moduledoc """
    Functions for dealing with message type data.
    """

    def from_id(100), do: {:t, :version}
    def from_id(101), do: {:r, :version}
    def from_id(102), do: {:t, :auth}
    def from_id(103), do: {:r, :auth}
    def from_id(104), do: {:t, :attach}
    def from_id(105), do: {:r, :attach}
    def from_id(107), do: {:r, :error}
    def from_id(108), do: {:t, :flush}
    def from_id(109), do: {:r, :flush}
    def from_id(110), do: {:t, :walk}
    def from_id(111), do: {:r, :walk}
    def from_id(112), do: {:t, :open}
    def from_id(113), do: {:r, :open}
    def from_id(114), do: {:t, :create}
    def from_id(115), do: {:r, :create}
    def from_id(116), do: {:t, :read}
    def from_id(117), do: {:r, :read}
    def from_id(118), do: {:t, :write}
    def from_id(119), do: {:r, :write}
    def from_id(120), do: {:t, :clunk}
    def from_id(121), do: {:r, :clunk}
    def from_id(122), do: {:t, :remove}
    def from_id(123), do: {:r, :remove}
    def from_id(124), do: {:t, :stat}
    def from_id(125), do: {:r, :stat}
    def from_id(126), do: {:t, :wstat}
    def from_id(127), do: {:r, :wstat}

    def to_id({:t, :version}), do: 100
    def to_id({:r, :version}), do: 101
    def to_id({:t, :auth}), do: 102
    def to_id({:r, :auth}), do: 103
    def to_id({:t, :attach}), do: 104
    def to_id({:r, :attach}), do: 105
    def to_id({:r, :error}), do: 107
    def to_id({:t, :flush}), do: 108
    def to_id({:r, :flush}), do: 109
    def to_id({:t, :walk}), do: 110
    def to_id({:r, :walk}), do: 111
    def to_id({:t, :open}), do: 112
    def to_id({:r, :open}), do: 113
    def to_id({:t, :create}), do: 114
    def to_id({:r, :create}), do: 115
    def to_id({:t, :read}), do: 116
    def to_id({:r, :read}), do: 117
    def to_id({:t, :write}), do: 118
    def to_id({:r, :write}), do: 119
    def to_id({:t, :clunk}), do: 120
    def to_id({:r, :clunk}), do: 121
    def to_id({:t, :remove}), do: 122
    def to_id({:r, :remove}), do: 123
    def to_id({:t, :stat}), do: 124
    def to_id({:r, :stat}), do: 125
    def to_id({:t, :wstat}), do: 126
    def to_id({:r, :wstat}), do: 127
  end

  defstruct type: nil, tag: nil, data: nil

  def parse(<<size::4*8-little, type::8, tag::2*8-little, rest::binary>>) do
    type = Type.from_id(type)
    datasize = size - 4 - 1 - 2
    <<data::binary-(^datasize * 8), rest::binary>> = rest
    {%__MODULE__{type: type, tag: tag, data: parse_data(datasize, type, data)}, rest}
  end

  defp parse_data(size, {:t, :version}, <<msize::4*8-little, rest::binary>>)
       when byte_size(rest) == size - 4,
       do: %{msize: msize, version: rest}

  defp parse_data(size, {:r, :version}, <<msize::4*8-little, rest::binary>>)
       when byte_size(rest) == size - 4,
       do: %{msize: msize, version: rest}
end
