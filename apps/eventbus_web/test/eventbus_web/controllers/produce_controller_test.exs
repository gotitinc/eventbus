defmodule EventbusWeb.ProduceControllerTest do
  use EventbusWeb.ConnCase

  test "GET /api/ping", %{conn: conn} do
    conn = get conn, "/api/ping"
    assert text_response(conn, 200) =~ "pong"
  end

  test "POST /api/produce without params", %{conn: conn} do
    conn = post conn, "/api/produce", %{}
    assert json_response(conn, 400) == %{"status" => "error", "message" => "missing \"topic\", missing \"key\", missing \"url\", missing \"payload\""}
  end

  test "POST /api/produce with invalid max_retry", %{conn: conn} do
    conn = post conn, "/api/produce", %{topic: "router", key: "key", url: "http://example.com", payload: "hello", max_retry: "invalid"}
    assert json_response(conn, 400) == %{"status" => "error", "message" => "invalid max_retry: \"invalid\""}
  end

  test "POST /api/produce with invalid timeout", %{conn: conn} do
    conn = post conn, "/api/produce", %{topic: "router", key: "key", url: "http://example.com", payload: "hello", max_retry: "2", timeout: "invalid"}
    assert json_response(conn, 400) == %{"status" => "error", "message" => "invalid timeout: \"invalid\""}
  end

  test "POST /api/produce_delayed without params", %{conn: conn} do
    conn = post conn, "/api/produce_delayed", %{}
    assert json_response(conn, 400) == %{"status" => "error", "message" => "missing \"topic\", missing \"key\", missing \"url\", missing \"payload\", missing \"delay\""}
  end

  test "POST /api/produce_delayed with invalid delay", %{conn: conn} do
    conn = post conn, "/api/produce_delayed", %{topic: "router", key: "key", url: "http://example.com", payload: "hello", delay: "invalid"}
    assert json_response(conn, 400) == %{"status" => "error", "message" => "invalid delay: \"invalid\""}
  end

  test "POST /api/produce_delayed with invalid max_retry", %{conn: conn} do
    conn = post conn, "/api/produce_delayed", %{topic: "router", key: "key", url: "http://example.com", payload: "hello", delay: "20", max_retry: "invalid"}
    assert json_response(conn, 400) == %{"status" => "error", "message" => "invalid max_retry: \"invalid\""}
  end

  test "POST /api/produce_delayed with invalid timeout", %{conn: conn} do
    conn = post conn, "/api/produce_delayed", %{topic: "router", key: "key", url: "http://example.com", payload: "hello", delay: "20", max_retry: "0", timeout: "invalid"}
    assert json_response(conn, 400) == %{"status" => "error", "message" => "invalid timeout: \"invalid\""}
  end

  test "eventbus_response succeeds" do
    assert EventbusWeb.ProduceController.eventbus_response({:ok, "ignored"}) == :ok
  end

  test "eventbus_response fails" do
    assert EventbusWeb.ProduceController.eventbus_response("an error") == {:error, 500, "\"an error\""}
  end
end
