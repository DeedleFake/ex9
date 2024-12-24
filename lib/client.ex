defmodule Ex9P.Client do
  use GenServer

  alias Ex9P.Message

  def connect(address, port, opts \\ []) do
    GenServer.start_link(__MODULE__, {self(), address, port, opts})
  end

  def send(client, %Message{} = msg) do
    GenServer.call(client, {:send, msg})
  end

  @impl true
  def init({control, address, port, opts}) do
    with {:ok, socket} <- :gen_tcp.connect(address, port, []) do
      state = %{
        opts: opts,
        socket: socket,
        control: control
      }

      {:ok, state}
    end
  end

  @impl true
  def handle_continue({:send, msg}, state) do
    data = Message.serialize(msg)
    :ok = :gen_tcp.send(state.socket, data)
    {:noreply, state}
  end

  @impl true
  def handle_call({:send, msg}, _from, state) do
    # TODO: Handle things like having been disconnected.
    {:reply, :ok, state, {:continue, {:send, msg}}}
  end

  @impl true
  def handle_info({:tcp, socket, data}, %{socket: socket} = state) do
    <<size::4*8-little, data::binary>> = IO.iodata_to_binary(data)
    {msg, ""} = Message.deserialize(size, data, state.opts)
    Kernel.send(state.control, {Ex9P, self(), msg})
    {:noreply, state}
  end

  @impl true
  def handle_info({:tcp_closed, socket}, %{socket: socket} = state) do
    # TODO: Handle disconnections.
    {:ok, state}
  end

  @impl true
  def handle_info({:tcp_error, socket, reason}, %{socket: socket} = state) do
    # TODO: Handle errors.
    dbg(reason)
    {:ok, state}
  end
end
