defmodule EventbusWeb.StatsController do
  use EventbusWeb, :controller

  @counters [
      "produce_in",
      "produce_delay_in",
      "queue_in",
      "queue_out",
      "queue_error",
      "delayed_in",
      "delayed_out",
      "delayed_error",
      "delayed_canceled",
      "http_start",
      "http_succeded",
      "http_error",
      "http_retry",
      "consumer_start",
      "consumer_stop",
      "queue",
      "delayed",
      "timer"
  ]

  @latencies [
      "queue",
      "http"
  ]

  def get_topic_counter(conn, params) do
    with {:ok, counter} <- Map.fetch(params, "counter"),
        {:ok, topic} <- Map.fetch(params, "topic") do

      if Enum.member?(@counters, counter) do
        case Eventbus.get_counter(String.to_atom(counter), topic) do
          %{error: error_code} ->
            response(conn, 400, %{error: error_code})
          value ->
            response(conn, 200, %{status: "ok", value: value})
        end
      else
        response(conn, 400, %{error: "unknown counter"})
      end

    else
      :error ->
        response(conn, 400, %{error: "invalid request"})
      {:error, status, message} ->
        response(conn, status, message)
    end
  end

  def validate_get_counter_params(params) do
    message = for key <- ["topic", "partition", "counter"] do
      if Map.has_key?(params, key), do: nil, else: "missing \"#{key}\""
    end
    |> Enum.filter(&(&1))
    |> Enum.join(", ")
    if message == "" do
      :ok
    else
      {:error, 400, %{error: message}}
    end
  end

  def get_topic_latency(conn, params) do
    with {:ok, counter} <- Map.fetch(params, "counter"),
        {:ok, topic} <- Map.fetch(params, "topic") do

      if Enum.member?(@latencies, counter) do
        case Eventbus.get_latency(String.to_atom(counter), topic) do
          %{error: error_code} ->
            response(conn, 400, %{error: error_code})
          value ->
            response(conn, 200, %{status: "ok", value: value})
        end
      else
        response(conn, 400, %{error: "unknown counter"})
      end

    else
      :error ->
        response(conn, 400, %{error: "invalid request"})
      {:error, status, message} ->
        response(conn, status, message)
    end
  end

  def delete_all(conn, _params) do
    case Eventbus.reset_counters() do
      val when is_map(val) ->
        response(conn, 200, %{status: "ok"})
      error ->
        response(conn, 500, error)
    end
  end

  def response(conn, status, res) do
    conn
    |> put_status(status)
    |> json(res)
  end
end
