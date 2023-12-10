defmodule Ex9P.Message do
  @moduledoc """
  A single 9P message and related functionality.
  """

  defstruct type: nil, tag: nil, data: nil

  def parse(size, <<id::8, tag::2*8-little, rest::binary>>, opts \\ []) do
    [proto: proto] = Keyword.validate!(opts, proto: Ex9P.Proto)

    datasize = size - 4 - 1 - 2
    <<data::binary-(^datasize * 8), rest::binary>> = rest
    type = proto.id_to_type(id)
    msgdata = proto.binary_to_data(type, data)
    {%__MODULE__{type: type, tag: tag, data: msgdata}, rest}
  end

  def to_binary(%{type: type, tag: tag, data: data}, opts \\ []) do
    [proto: proto] = Keyword.validate!(opts, proto: Ex9P.Proto)

    id = proto.type_to_id(type)
    msgdata = proto.data_to_binary(type, data)
    size = 4 + 1 + 2 + byte_size(msgdata)
    <<size::4*8-little, id::8, tag::2*8-little, msgdata::binary>>
  end

  defmodule Proto do
    @moduledoc """
    Module with helper macros for defining protocols.

    ## Example

    This example defines a protocol module with one type. The type is
    a `:t`, meaning that it is a client-to-server message, has a type
    of `:example`, and a wire ID of 100. The block defines the
    mechanisms for converting from the binary wire format to the
    resulting Message's data field and vice versa.

        defmodule ExampleProto do
            use Ex9P.Message.Proto

            type 100, texample do
              data(<<data::8*4>>) ->
                %{data: data}
              binary(%{data: data}) ->
                <<data::8*4>>
            end
        end

    The message's direction, :t, or :r, is the first letter of the
    name. It must be either "t" or "r".
    """

    defmacro __using__(_opts) do
      quote do
        import unquote(__MODULE__)
      end
    end

    @doc """
    Defines a message type with the given ID and type. For more info,
    see the module documentation.
    """
    defmacro message(id, {type, _, _}, do: block) do
      type = extract_dir(type)

      f =
        unless block == nil,
          do:
            {:__block__, [],
             block
             |> Enum.map(fn
               {:->, _, [[{:data, _, [binary]} | _], block]} ->
                 quote do
                   def binary_to_data(unquote(type), unquote(binary)), do: unquote(block)
                 end

               {:->, _, [[{:binary, _, [data]} | _], block]} ->
                 quote do
                   def data_to_binary(unquote(type), unquote(data)), do: unquote(block)
                 end
             end)}

      quote do
        unquote(f)
        def id_to_type(unquote(id)), do: unquote(type)
        def type_to_id(unquote(type)), do: unquote(id)
      end
    end

    @doc """
    A shortcut to define a type with no body. A type defined like this
    will always ignore its data and return `nil`.
    """
    defmacro message(id, type) do
      quote do
        message(unquote(id), unquote(type), do: nil)
      end
    end

    @doc """
    A convenience function to parse a variable-sized 9P field. It
    returns a `{bytes, rest}` tuple.
    """
    def parse_bytes(<<size::2*8-little, rest::binary>>) when byte_size(rest) >= size do
      <<str::binary-(^size * 8), rest::binary>> = rest
      {str, rest}
    end

    @doc """
    The opposite of parse_string/1. Converts a binary into 9P-encoded
    variable-length field.
    """
    def to_bytes(str) when is_binary(str) do
      <<byte_size(str)::8*2-little, str::binary>>
    end

    defp extract_dir(type) do
      <<dir::binary-1, type::binary>> = Atom.to_string(type)
      unless dir in ["t", "r"], do: raise(ArgumentError, "direction in :t or :r")
      {String.to_atom(dir), String.to_atom(type)}
    end
  end
end
