defmodule Ex9P.Conn do
  use GenServer

  import Ex9P.Proto

  def new(socket, opts \\ []) when is_port(socket) do
    with :ok <- :gen_tcp.controlling_process(socket, self()),
         {:ok, conn} <- GenServer.start_link(__MODULE__, {self(), socket, opts}) do
      :ok = :gen_tcp.controlling_process(socket, conn)
      {:ok, conn}
    end
  end

  def connect(address, port, opts \\ [])

  def connect(address, port, opts) when is_binary(address) do
    connect(String.to_charlist(address), port, opts)
  end

  def connect(address, port, opts) when is_list(address) do
    GenServer.start_link(__MODULE__, {self(), address, port, opts})
  end

  def send(client, msg) do
    GenServer.call(client, {:send, msg})
  end

  @impl true
  def init({control, address, port, opts}) do
    with {:ok, socket} <- :gen_tcp.connect(address, port, []) do
      init({control, socket, opts})
    end
  end

  @impl true
  def init({control, socket, opts}) when is_port(socket) do
    state = %{
      opts: opts,
      socket: socket,
      control: control
    }

    {:ok, state}
  end

  @impl true
  def handle_continue({:send, msg}, state) do
    data = encode_message(msg, state.opts)
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
    {msg, ""} = decode_message(data, state.opts)
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
