defmodule Ex9P.Proto do
  @moduledoc """
  This module defines a behaviour for serializing and deserializing
  messages as well as functions to perform those operations.
  """

  import Bitwise

  defmacro __using__([]) do
    quote do
      @behaviour unquote(__MODULE__)
      import unquote(__MODULE__)
    end
  end

  @callback deserialize(type_id, data) :: message
            when type_id: pos_integer(), data: binary(), message: struct()
  @callback serialize(message) :: {type_id, data}
            when message: struct(), type_id: pos_integer(), data: iodata()

  @notag (1 <<< 16) - 1

  @spec deserialize_message(message_data, options) :: {message, rest}
        when message_data: iodata(), options: keyword(), message: struct(), rest: binary()
  def deserialize_message(data, opts \\ []) do
    %{proto: proto} = Keyword.validate!(opts, proto: Ex9P.Nine) |> Map.new()

    <<size::4*8-little, type::8, tag::2*8-little, rest::binary>> = IO.iodata_to_binary(data)
    datasize = size - 4 - 1 - 2
    <<data::binary-(^datasize * 8), rest::binary>> = rest
    msg = {tag, proto.deserialize(type, data)}
    msg = with {@notag, msg} <- msg, do: msg
    {msg, rest}
  end

  @spec serialize_message(message, options) :: message_data
        when message: struct(), options: keyword(), message_data: iodata()
  def serialize_message(msg, opts \\ [])

  def serialize_message({tag, msg}, opts) do
    %{proto: proto} = Keyword.validate!(opts, proto: Ex9P.Nine) |> Map.new()

    {type, data} = proto.serialize(msg)
    size = 4 + 1 + 2 + IO.iodata_length(data)
    [<<size::4*8-little, type::8, tag::2*8-little>>, data]
  end

  def serialize_message(msg, opts) do
    serialize_message({@notag, msg}, opts)
  end

  @spec deserialize_binary(data) :: {deserialized_data, rest}
        when data: iodata(), deserialized_data: binary(), rest: binary()
  def deserialize_binary(<<size::2*8-little, data::binary>>) do
    <<data::(^size)*8-binary, rest::binary>> = IO.iodata_to_binary(data)
    {data, rest}
  end

  @spec serialize_binary(data) :: serialized_data when data: iodata(), serialized_data: iodata()
  def serialize_binary(data) do
    [<<IO.iodata_length(data)::2*8-little>>, data]
  end

  @spec deserialize_list(data, deserialize_element) :: {list, rest}
        when data: iodata(),
             deserialize_element: (binary() -> {element, binary()}),
             list: [element],
             rest: binary(),
             element: term()
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

  @spec serialize_list(list, serialize_element) :: serialized_list
        when list: [element],
             serialize_element: (element -> iodata()),
             serialized_list: iodata(),
             element: term()
  def serialize_list(list, serialize_element) when is_function(serialize_element, 1) do
    data =
      for element <- list, reduce: [] do
        data -> [data, serialize_element.(element)]
      end

    [<<IO.iodata_length(data)::2*8-little>> | data]
  end
end
