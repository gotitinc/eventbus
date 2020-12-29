defmodule Eventbus.ClusterManager do
  @moduledoc """
  Manages node registration and joining the cluster
  """
  use GenServer
  require Logger
  alias Eventbus.{Hash, Utils}

  @registry "nodes"
  @one_minute 60 * 1000

  def start_link(name, params) do
    GenServer.start_link(__MODULE__, params, name: name)
  end

  def init(_params) do
    register_node()
    connect_to_cluster()
    {:ok, %{}}
  end

  def register_node() do
    {:ok, hash} = Hash.init(@registry)
    :ok = Hash.set(hash, node(), Utils.now())
    Process.send_after(self(), :register_node, @one_minute)
  end

  def connect_to_cluster() do
    {:ok, hash} = Hash.init(@registry)
    with {:ok, nodes} <- Hash.get_all(hash) do
      nodes
      |> Enum.filter(fn {node, ts} ->
        node != to_string(node()) and ts > Utils.now() - 2 * @one_minute
      end)
      |> Enum.map(fn {node, _ts} ->
        String.to_atom(node)
      end)
      |> Enum.reduce([], fn node, acc ->
        [Task.async(fn ->
          try do
            res = Node.connect(node)
            Logger.info("ClusterManager connect to #{inspect node} -> #{inspect res}")
          rescue
            error ->
              Logger.error("ClusterManager error #{inspect error}")
          catch
            :exit, _ ->
              Logger.error("ClusterManager exit")
          end
        end) | acc]
      end)
      |> Enum.map(&Task.await/1)
    end
  end

  def handle_info(:register_node, state) do
    register_node()
    {:noreply, state}
  end

end
