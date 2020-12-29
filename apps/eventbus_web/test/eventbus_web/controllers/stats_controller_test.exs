defmodule EventbusWeb.StatsControllerTest do
  use EventbusWeb.ConnCase

  test "GET /stats/counter fails with invalid counter", %{conn: conn} do
    conn = get conn, "/stats/counter/foo/router"
    assert json_response(conn, 400) == %{"error" => "unknown counter"}
  end

  test "GET /stats/counter invalid topic", %{conn: conn} do
    conn = get conn, "/stats/counter/produce_in/foo"
    assert json_response(conn, 400) == %{"error" => "invalid topic"}
  end

  # test "GET /stats/counter gets stats", %{conn: conn} do
  #   conn = get conn, "/stats/counter/produce_in/default"
  #   assert json_response(conn, 200) == %{"value" => 0, "status" => "ok"}
  # end

end
