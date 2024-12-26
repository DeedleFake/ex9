defmodule Ex9P.Nine.Stream do
  @moduledoc false

  use TypedStruct

  alias Ex9P.Nine.Client
  alias Ex9P.Nine.Client.File

  typedstruct enforce: true do
    field :file, File.t()
    field :offset, non_neg_integer()
    field :count, non_neg_integer()
  end

  def new(%File{} = file, opts) do
    %__MODULE__{
      file: file,
      offset: opts[:starting_offset],
      count: opts[:chunk_size]
    }
  end

  defimpl Enumerable do
    alias Ex9P.Nine.Stream

    @impl true
    def count(%Stream{}) do
      {:error, __MODULE__}
    end

    @impl true
    def member?(%Stream{}, val) when is_binary(val) when is_list(val) do
      {:error, __MODULE__}
    end

    @impl true
    def member?(%Stream{}, _val) do
      {:ok, false}
    end

    @impl true
    def slice(%Stream{}) do
      {:error, __MODULE__}
    end

    @impl true
    def reduce(%Stream{}, {:halt, acc}, _reducer) do
      {:halted, acc}
    end

    @impl true
    def reduce(%Stream{} = stream, {:suspend, acc}, reducer) do
      {:suspended, acc, &reduce(stream, &1, reducer)}
    end

    @impl true
    def reduce(%Stream{file: file, offset: offset, count: count} = stream, {:cont, acc}, reducer) do
      case Client.read(file, offset, count) do
        {:ok, ""} ->
          {:done, acc}

        {:ok, data} ->
          count = IO.iodata_length(data)

          reduce(
            %Stream{stream | offset: offset + count},
            reducer.(data, acc),
            reducer
          )
      end
    end
  end

  defimpl Collectable do
    alias Ex9P.Nine.Stream

    @impl true
    def into(%Stream{file: file, offset: offset}) do
      collector = fn
        offset, {:cont, data} ->
          {:ok, count} = Client.write(file, offset, data)
          offset + count

        _offset, :done ->
          file

        _offset, :halt ->
          :ok
      end

      {offset, collector}
    end
  end
end
