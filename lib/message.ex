defmodule Ex9.Message do
  @moduledoc """
  A single 9P message and related functionality.
  """

  defstruct type: nil, tag: nil, data: nil

  def parse(<<size::4*8-little, type::8, tag::2*8-little, rest::binary>>, opts \\ []) do
    proto = opts |> Keyword.get(:proto, Ex9.Proto)

    type = proto.type_from_id(type)
    datasize = size - 4 - 1 - 2
    <<data::binary-(^datasize * 8), rest::binary>> = rest
    {%__MODULE__{type: type, tag: tag, data: proto.parse_data(datasize, type, data)}, rest}
  end

  def to_binary(%{type: type, tag: tag, data: data}, tag, opts \\ []) do
    proto = opts |> Keyword.get(:proto, Ex9.Proto)

    type = proto.id_from_type(type)
    data = proto.data_to_binary(data)
    size = 4 + 1 + 2 + byte_size(data)
    <<size::4*8-little, type::8, tag::2*8-little, data>>
  end

  defmodule Proto do
    @moduledoc """
    Module with helper macros for defining protocols.

    ## Example

    This example defines a protocol module with one type. The type is
    a `:t`, meaning that it is a client-to-server message, has a type
    of `:example`, and a wire ID of 100. The data of the type is
    parsed with a pattern match of `<<data::4*8>>`, and that info is
    then available in the `do` block. The return from the `do` block
    will be inserted into the resulting `Ex9.Message`'s `data` field.

        defmodule ExampleProto do
            use Ex9.Message.Proto

            type 100, texample(<<data::8*4>>) do
              %{data: data}
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
    Defines a message type with the given dir, type, and wire ID. For
    more info, see the module documentation.
    """
    defmacro type(id, {name, _, [data]}, do: block)
             when is_integer(id) do
      dt = split_name(name)

      quote do
        def type_from_id(unquote(id)), do: unquote(dt)
        def type_to_id(unquote(dt)), do: unquote(id)
        def parse_data(size, unquote(dt), unquote(data)), do: unquote(block)
      end
    end

    defmacro to_binary({name, _, [data]}, do: block) do
      dt = split_name(name)

      quote do
        def data_to_binary(unquote(dt), unquote(data)), do: unquote(block)
      end
    end

    @doc """
    A shortcut to define a type with no body. A type defined like this
    will always ignore its data and return `nil`. It also defines an
    equivalently nil `to_binary` definition.
    """
    defmacro type(id, {type, _, _}) do
      quote do
        type(unquote(id), unquote(type)(_), do: nil)
        to_binary(unquote(type)(_), do: nil)
      end
    end

    @doc """
    A convenience function to parse a 9P string. It returns a
    `{parsed_string, rest}` tuple.
    """
    def parse_string(<<size::2*8-little, rest::binary>>) when byte_size(rest) >= size do
      <<str::binary-(^size * 8), rest::binary>> = rest
      {str, rest}
    end

    def string_to_binary(str) when is_binary(str) do
      <<byte_size(str)::8*2-little, str::binary>>
    end

    defp split_name(name) do
      <<dir::binary-1, type::binary>> = Atom.to_string(name)
      unless dir in ["t", "r"], do: raise(ArgumentError, "direction not :t or :r")
      {dir |> String.to_atom(), type |> String.to_atom()}
    end
  end
end
