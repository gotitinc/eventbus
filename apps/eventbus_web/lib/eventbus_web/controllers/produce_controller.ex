defmodule EventbusWeb.ProduceController do
  use EventbusWeb, :controller
  require Logger

  def ping(conn, _params) do
    conn
    |> put_status(200)
    |> text("pong")
  end

  def produce(conn, params) do
    Logger.info("#{conn.method} #{conn.request_path} #{inspect Map.delete(params, "payload")}")
    with :ok <- validate_produce_params(params),
         {:ok, valid_params} <- validate_max_retry_param(params),
         {:ok, valid_params} <- validate_timeout_param(valid_params),
         :ok <- call_produce(valid_params) do
      response(conn, 200, %{status: "ok"})
    else
      {:error, status, message} ->
        response(conn, status, %{status: "error", message: message})
    end
  end

  def produce_delayed(conn, params) do
    Logger.info("#{conn.method} #{conn.request_path} #{inspect Map.delete(params, "payload")}")
    with :ok <- validate_produce_delayed_params(params),
         {:ok, valid_params} <- validate_delay_param(params),
         {:ok, valid_params} <- validate_max_retry_param(valid_params),
         {:ok, valid_params} <- validate_timeout_param(valid_params),
         :ok <- call_produce_delayed(valid_params) do
      response(conn, 200, %{status: "ok"})
    else
      {:error, status, message} ->
        response(conn, status, %{status: "error", message: message})
    end
  end

  def reset(conn, _) do
    case Eventbus.reset_events() do
      :ok -> response(conn, 200, %{status: "ok"})
      {:error, status, message} ->
        response(conn, status, %{status: "error", message: message})
    end
  end

  def validate_produce_params(params) do
    message = for key <- ["topic", "key", "url", "payload"] do
      if Map.has_key?(params, key), do: nil, else: "missing \"#{key}\""
    end
    |> Enum.filter(&(&1))
    |> Enum.join(", ")
    if message == "" do
      :ok
    else
      {:error, 400, message}
    end
  end

  def validate_produce_delayed_params(params) do
    message = for key <- ["topic", "key", "url", "payload", "delay"] do
      if Map.has_key?(params, key), do: nil, else: "missing \"#{key}\""
    end
    |> Enum.filter(&(&1))
    |> Enum.join(", ")
    if message == "" do
      :ok
    else
      {:error, 400, message}
    end
  end

  def validate_delay_param(%{"delay" => delay} = params) when is_integer(delay) do
    {:ok, params}
  end
  def validate_delay_param(%{"delay" => delay} = params) do
    case Integer.parse(delay) do
      {delay, _} ->
        {:ok, %{params | "delay" => delay}}
      _ ->
        {:error, 400, "invalid delay: \"#{params["delay"]}\""}
    end
  end

  def validate_max_retry_param(%{"max_retry" => max_retry} = params) when is_integer(max_retry) do
    {:ok, params}
  end
  def validate_max_retry_param(%{"max_retry" => max_retry} = params) do
    case Integer.parse(max_retry) do
      {max_retry, _} ->
        {:ok, %{params | "max_retry" => max_retry}}
      _ ->
        {:error, 400, "invalid max_retry: \"#{params["max_retry"]}\""}
    end
  end
  def validate_max_retry_param(params), do: {:ok, params}

  def validate_timeout_param(%{"timeout" => timeout} = params) when is_integer(timeout) do
    {:ok, params}
  end
  def validate_timeout_param(%{"timeout" => timeout} = params) do
    case Integer.parse(timeout) do
      {timeout, _} ->
        {:ok, %{params | "timeout" => timeout}}
      _ ->
        {:error, 400, "invalid timeout: \"#{params["timeout"]}\""}
    end
  end
  def validate_timeout_param(params), do: {:ok, params}

  def call_produce(params) do
    Eventbus.produce(params["topic"], params["key"],
              url: params["url"], payload: params["payload"],
              max_retry: params["max_retry"], timeout: params["timeout"])
    |> eventbus_response()
  end

  def call_produce_delayed(params) do
    Eventbus.produce_delayed(params["topic"], params["key"], url: params["url"],
              payload: params["payload"], delay: params["delay"],
              max_retry: params["max_retry"], timeout: params["timeout"])
    |> eventbus_response()
  end

  def eventbus_response(resp) do
    case resp do
      {:ok, _} ->
        :ok
      {:bad_request, error} ->
        {:error, 400, inspect(error)}
      error ->
        {:error, 500, inspect(error)}
    end
  end

  def response(conn, status, res) do
    conn
    |> put_status(status)
    |> json(res)
  end
end
