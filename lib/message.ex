defmodule Ex9P.Message do
  @moduledoc """
  A single 9P message and related functionality.
  """

  import Bitwise

  defmacro __using__([]) do
    quote do
      @behaviour Ex9P.Message.Proto
      import Ex9P.Message,
        only: [
          serialize_binary: 1,
          deserialize_binary: 1,
          serialize_list: 2,
          deserialize_list: 2
        ]
    end
  end

  @notag (1 <<< 16) - 1

  def deserialize(data, opts \\ [])

  def deserialize(<<size::4*8-little, type::8, tag::2*8-little, rest::binary>>, opts) do
    %{proto: proto} = Keyword.validate!(opts, proto: Ex9P.Proto) |> Map.new()

    datasize = size - 4 - 1 - 2
    <<data::binary-(^datasize * 8), rest::binary>> = rest
    msg = {tag, proto.deserialize(type, data)}
    msg = with {@notag, msg} <- msg, do: msg
    {msg, rest}
  end

  def deserialize(data, opts) when is_list(data) do
    deserialize(IO.iodata_to_binary(data), opts)
  end

  def serialize(msg, opts \\ [])

  def serialize({tag, msg}, opts) do
    %{proto: proto} = Keyword.validate!(opts, proto: Ex9P.Proto) |> Map.new()

    {type, data} = proto.serialize(msg)
    size = 4 + 1 + 2 + IO.iodata_length(data)
    [<<size::4*8-little, type::8, tag::2*8-little>>, data]
  end

  def serialize(msg, opts) do
    serialize({@notag, msg}, opts)
  end

  def deserialize_binary(<<size::2*8-little, data::binary>>) do
    <<data::(^size)*8-binary, rest::binary>> = data
    {data, rest}
  end

  def deserialize_binary(data) when is_list(data) do
    deserialize_binary(IO.iodata_to_binary(data))
  end

  def serialize_binary(data) do
    [<<IO.iodata_length(data)::2*8-little>>, data]
  end

  def deserialize_list(data, deserialize_element)
      when is_binary(data) and is_function(deserialize_element, 1) do
    {data, rest} = deserialize_binary(data)
    {deserialize_list_loop(data, deserialize_element, []), rest}
  end

  defp deserialize_list_loop("", _deserialize_element, result), do: Enum.reverse(result)

  defp deserialize_list_loop(data, deserialize_element, result) do
    {element, rest} = deserialize_element.(data)
    deserialize_list_loop(rest, deserialize_element, [element | result])
  end

  def serialize_list(list, serialize_element) when is_function(serialize_element, 1) do
    data =
      for element <- list, reduce: [] do
        data -> [data, serialize_element.(element)]
      end

    [<<IO.iodata_length(data)::2*8-little>> | data]
  end

  defmodule Proto do
    @type serialized_type() :: pos_integer()
    @type serialized_data() :: binary()
    @type message() :: struct()

    @callback deserialize(serialized_type(), serialized_data()) :: message()
    @callback serialize(message()) :: {serialized_type(), serialized_data()}
  end
end
