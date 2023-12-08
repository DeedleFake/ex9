defmodule Ex9.Client do
  use GenServer

  defmodule Listener do
    use GenServer

    def start_link(opts) do
      GenServer.start_link(__MODULE__, opts)
    end

    def await(listener, from, tag) do
      listener |> GenServer.cast({:await, from, tag})
    end

    @impl true
    def init(proto: proto) do
      {:ok, %{proto: proto, msgs: %{}, waiting: %{}}}
    end

    @impl true
    def handle_cast({:await, from, tag}, opts) when is_map_key(opts.msgs, tag) do
      {msg, msgs} = opts.msgs |> Map.pop(tag)
      GenServer.reply(from, msg)
      {:noreply, %{opts | msgs: msgs}}
    end

    @impl true
    def handle_cast({:await, from, tag}, opts) do
      {:noreply, %{opts | waiting: %{opts.waiting | tag => from}}}
    end

    @impl true
    def handle_cast({:msg, msg}, opts) do
      # TODO
    end
  end

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(socket: socket, proto: proto) do
    {:ok, lis} = Listener.start_link(socket: socket, proto: proto)
    {:ok, %{socket: socket, proto: proto, listener: lis}}
  end

  @impl true
  def handle_call({:request, msg}, from, state) do
    state.socket |> :gen_tcp.send(state.proto.to_binary(msg))
    state.listener |> Listener.await(from, msg.tag)

    {:noreply, state}
  end
end
