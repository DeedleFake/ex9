defmodule Ex9P.Nine.Client do
  use GenServer

  alias Ex9P.Conn
  alias Ex9P.Nine

  @version "9P2000"

  def start_link(opts) do
    {server_opts, opts} = Keyword.split(opts, [:name])
    GenServer.start_link(__MODULE__, opts, server_opts)
  end

  defp request(client, msg, opts \\ []) do
    GenServer.call(client, {:request, msg, opts})
  end

  def handshake(client, msize) do
    rsp = request(client, %Nine.Tversion{msize: msize, version: @version}, notag: true)

    with %Nine.Rversion{msize: msize, version: version} <- rsp,
         ^version <- @version do
      {:ok, msize}
    else
      %Nine.Rerror{ename: ename} -> {:error, ename}
      @version -> {:error, :unsupported_version}
    end
  end

  def attach(client, aname, uname, afile \\ nil) do
    afid = if afile, do: afile.fid, else: :nofid
    fid = GenServer.call(client, :next_fid)
    rsp = request(client, %Nine.Tattach{uname: uname, aname: aname, fid: fid, afid: afid})

    with %Nine.Rattach{qid: qid} <- rsp do
      {:ok, qid}
    else
      %Nine.Rerror{ename: ename} -> {:error, ename}
    end
  end

  @impl true
  def init(opts) do
    opts = Keyword.validate!(opts, [:address, :port, :conn, connect_opts: []])

    conn =
      with nil <- opts[:conn] do
        {:ok, conn} = Conn.connect(opts[:address], opts[:port], opts[:connect_opts])
        conn
      end

    state = %{
      conn: conn,
      tags: %{},
      next_tag: 1,
      next_fid: 1
    }

    {:ok, state}
  end

  @impl true
  def handle_call({:request, msg, opts}, from, state) do
    {msg, state} =
      if opts[:notag] do
        state = put_in(state.tags[:notag], from)
        {msg, state}
      else
        {tag, state} = get_and_update_in(state.next_tag, &{&1, &1 + 1})
        state = put_in(state.tags[tag], from)
        {{tag, msg}, state}
      end

    :ok = Conn.send(state.conn, msg)
    {:noreply, state}
  end

  @impl true
  def handle_call(:next_fid, _from, state) do
    {fid, state} = get_and_update_in(state.next_fid, &{&1, &1 + 1})
    {:reply, fid, state}
  end

  @impl true
  def handle_info({Ex9P, conn, {tag, msg}}, %{conn: conn} = state) do
    {from, state} = pop_in(state.tags[tag])
    GenServer.reply(from, msg)

    {:noreply, state}
  end

  @impl true
  def handle_info({Ex9P, conn, msg}, %{conn: conn} = state) do
    from = state.tags[:notag]
    GenServer.reply(from, msg)

    state = %{state | tags: %{}}
    {:noreply, state}
  end
end
