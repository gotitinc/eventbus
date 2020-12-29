defmodule EventbusWeb.Router do
  use EventbusWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :api_with_logs do
    plug Plug.Logger
    plug :accepts, ["json"]
  end


  scope "/api", EventbusWeb do
    scope "/ping" do
      pipe_through :api

      get "/", ProduceController, :ping
    end

    scope "/" do
      pipe_through :api_with_logs

      post "/produce", ProduceController, :produce
      post "/produce_delayed", ProduceController, :produce_delayed
      post "/reset", ProduceController, :reset
    end
  end

  scope "/stats", EventbusWeb do
    pipe_through :api

    get "/counter/:counter/:topic", StatsController, :get_topic_counter
    get "/latency/:counter/:topic", StatsController, :get_topic_latency
    delete "/", StatsController, :delete_all
  end
end
