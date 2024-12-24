defmodule Ex9P.Message do
  @moduledoc """
  A single 9P message and related functionality.
  """

  import Bitwise

  @notag (1 <<< 16) - 1

  def deserialize(size, <<type::8, tag::2*8-little, rest::binary>>, opts \\ []) do
    %{proto: proto} = Keyword.validate!(opts, proto: Ex9P.Proto) |> Map.new()

    datasize = size - 4 - 1 - 2
    <<data::binary-(^datasize * 8), rest::binary>> = rest
    msg = proto.deserialize(type, data)
    {{tag, msg}, rest}
  end

  def serialize(msg, opts \\ [])

  def serialize({tag, msg}, opts) do
    %{proto: proto} = Keyword.validate!(opts, proto: Ex9P.Proto) |> Map.new()

    {type, data} = proto.serialize(msg)
    size = 4 + 1 + 2 + byte_size(data)
    <<size::4*8-little, type::8, tag::2*8-little, data::binary>>
  end

  def serialize(msg, opts), do: serialize({@notag, msg}, opts)

  def deserialize_binary(<<size::2*8-little, data::binary>>) do
    <<data::(^size)*8-binary, rest::binary>> = data
    {data, rest}
  end

  def serialize_binary(data) when is_binary(data) do
    <<byte_size(data)::2*8-little, data::binary>>
  end

  defmodule Proto do
    @type serialized_type() :: pos_integer()
    @type serialized_data() :: binary()
    @type message() :: struct()

    @callback deserialize(serialized_type(), serialized_data()) :: message()
    @callback serialize(message()) :: {serialized_type(), serialized_data()}
  end
end
