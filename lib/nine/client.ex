defmodule Ex9P.Nine.Client do
  alias Ex9P.Nine
  alias Ex9P.Nine.DirEntry

  @opaque t() :: GenServer.server()

  defmodule File do
    use TypedStruct

    typedstruct enforce: true do
      field :client, Nine.Client.t()
      field :fid, Nine.fid()
      field :qid, Nine.QID.t()
    end
  end

  @doc false
  defdelegate child_spec(spec), to: __MODULE__.GenServer

  def start_link(opts) do
    {server_opts, opts} = Keyword.split(opts, [:name])
    GenServer.start_link(__MODULE__.GenServer, opts, server_opts)
  end

  defp request(client, msg) do
    GenServer.call(client, {:request, msg})
  end

  @spec attach(t(), String.t(), String.t(), File.t() | nil) ::
          {:ok, File.t()} | {:error, Exception.t()}
  def attach(client, aname, uname, afile \\ nil) do
    afid = if afile, do: afile.fid, else: :nofid
    fid = GenServer.call(client, :next_fid)
    rsp = request(client, %Nine.Tattach{uname: uname, aname: aname, fid: fid, afid: afid})

    with %Nine.Rattach{qid: qid} <- rsp do
      {:ok, %File{client: client, fid: fid, qid: qid}}
    else
      err when is_exception(err) -> {:error, err}
    end
  end

  @spec stat(File.t()) :: {:ok, DirEntry.t()} | {:error, String.t()}
  def stat(%File{client: client, fid: fid}) do
    rsp = request(client, %Nine.Tstat{fid: fid})

    with %Nine.Rstat{stat: stat} <- rsp do
      {:ok, stat}
    else
      err when is_exception(err) -> {:error, err}
    end
  end

  @spec walk(File.t(), String.t()) :: {:ok, File.t()} | {:error, String.t()}
  def walk(%File{client: client, fid: fid}, path) when is_binary(path) do
    wname = String.split(path, "/", trim: true)
    newfid = GenServer.call(client, :next_fid)
    rsp = request(client, %Nine.Twalk{fid: fid, newfid: newfid, wname: wname})

    with %Nine.Rwalk{wqid: wqid} <- rsp do
      {:ok, %File{client: client, fid: newfid, qid: List.last(wqid)}}
    else
      err when is_exception(err) -> {:error, err}
    end
  end
end
