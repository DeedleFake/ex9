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

  @type tag() :: non_neg_integer()
  @type message_type() :: non_neg_integer()

  @callback decode(type_id, data) :: message
            when type_id: message_type(), data: binary(), message: struct()
  @callback encode(message) :: {type_id, data}
            when message: struct(), type_id: message_type(), data: iodata()

  @notag (1 <<< 16) - 1

  @spec decode_message(message_data, options) :: {message, rest}
        when message_data: iodata(), options: keyword(), message: struct(), rest: binary()
  def decode_message(data, opts \\ []) do
    %{proto: proto} = Keyword.validate!(opts, proto: Ex9P.Nine) |> Map.new()

    <<size::4*8-little, type::8, tag::2*8-little, rest::binary>> = IO.iodata_to_binary(data)
    datasize = size - 4 - 1 - 2
    <<data::binary-(^datasize * 8), rest::binary>> = rest
    msg = {tag, proto.decode(type, data)}
    msg = with {@notag, msg} <- msg, do: msg
    {msg, rest}
  end

  @spec encode_message(message, options) :: message_data
        when message: struct() | {tag(), struct()},
             options: keyword(),
             message_data: iodata()
  def encode_message(msg, opts \\ [])

  def encode_message({tag, msg}, opts) do
    %{proto: proto} = Keyword.validate!(opts, proto: Ex9P.Nine) |> Map.new()

    {type, data} = proto.encode(msg)
    size = 4 + 1 + 2 + IO.iodata_length(data)
    [<<size::4*8-little, type::8, tag::2*8-little>>, data]
  end

  def encode_message(msg, opts) do
    encode_message({@notag, msg}, opts)
  end

  @spec decode_binary(data) :: {decoded_data, rest}
        when data: iodata(), decoded_data: binary(), rest: binary()
  def decode_binary(<<size::2*8-little, data::binary>>) do
    <<data::(^size)*8-binary, rest::binary>> = IO.iodata_to_binary(data)
    {data, rest}
  end

  @spec encode_binary(data) :: encoded_data when data: iodata(), encoded_data: iodata()
  def encode_binary(data) do
    [<<IO.iodata_length(data)::2*8-little>>, data]
  end

  @spec decode_list(data, decode_element) :: {list, rest}
        when data: iodata(),
             decode_element: (binary() -> {element, binary()}),
             list: [element],
             rest: binary(),
             element: term()
  def decode_list(data, decode_element)
      when is_binary(data) and is_function(decode_element, 1) do
    {data, rest} = decode_binary(data)
    {decode_list_loop(data, decode_element, []), rest}
  end

  defp decode_list_loop("", _decode_element, result), do: Enum.reverse(result)

  defp decode_list_loop(data, decode_element, result) do
    {element, rest} = decode_element.(data)
    decode_list_loop(rest, decode_element, [element | result])
  end

  @spec encode_list(list, encode_element) :: encoded_list
        when list: [element],
             encode_element: (element -> iodata()),
             encoded_list: iodata(),
             element: term()
  def encode_list(list, encode_element) when is_function(encode_element, 1) do
    data =
      for element <- list, reduce: [] do
        data -> [data, encode_element.(element)]
      end

    [<<IO.iodata_length(data)::2*8-little>> | data]
  end
end
