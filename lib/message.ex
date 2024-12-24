defmodule Ex9P.Message do
  @moduledoc """
  A single 9P message and related functionality.
  """

  @enforce_keys [:type, :tag, :data]
  defstruct @enforce_keys

  def deserialize(size, <<id::8, tag::2*8-little, rest::binary>>, opts \\ []) do
    %{proto: proto} = Keyword.validate!(opts, proto: Ex9P.Proto) |> Map.new()

    datasize = size - 4 - 1 - 2
    <<data::binary-(^datasize * 8), rest::binary>> = rest
    {type, data} = proto.deserialize(id, data)
    {%__MODULE__{type: type, tag: tag, data: data}, rest}
  end

  def serialize(%{type: type, tag: tag, data: data}, opts \\ []) do
    %{proto: proto} = Keyword.validate!(opts, proto: Ex9P.Proto) |> Map.new()

    {id, data} = proto.serialize(type, data)
    size = 4 + 1 + 2 + byte_size(data)
    <<size::4*8-little, id::8, tag::2*8-little, data::binary>>
  end

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
    @type type() :: atom()
    @type data() :: term()

    @callback deserialize(serialized_type(), serialized_data()) :: {type(), data()}
    @callback serialize(type(), data()) :: {serialized_type(), serialized_data()}
  end
end
