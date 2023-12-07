defmodule Ex9.Message do
  @moduledoc """
  A single 9P message and related functionality.
  """

  defstruct type: nil, tag: nil, data: nil

  def parse(<<size::4*8-little, type::8, tag::2*8-little, rest::binary>>, proto \\ Ex9.Proto) do
    type = proto.type_from_id(type)
    datasize = size - 4 - 1 - 2
    <<data::binary-(^datasize * 8), rest::binary>> = rest
    {%__MODULE__{type: type, tag: tag, data: proto.parse_data(datasize, type, data)}, rest}
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

            type :t, :example, 100, <<data::4*8>> do
              %{data: data}
            end
        end
    """

    defmacro __using__(_opts) do
      quote do
        import unquote(__MODULE__)
      end
    end

    @doc """
    A shortcut to define a type with no body. A type defined like this
    will always ignore its data and return `nil`.
    """
    defmacro type(dir, type, id) do
      quote do
        type(unquote(dir), unquote(type), unquote(id), _, do: nil)
      end
    end

    @doc """
    Defines a message type with the given dir, type, and wire ID. For
    more info, see the module documentation.
    """
    defmacro type(dir, type, id, data, do: block)
             when dir in [:t, :r]
             when is_atom(type)
             when is_integer(id) do
      dt = {dir, type}

      quote do
        def type_from_id(unquote(id)), do: unquote(dt)
        def type_to_id(unquote(dt)), do: unquote(id)
        def parse_data(size, unquote(dt), unquote(data)), do: unquote(block)
      end
    end
  end
end
