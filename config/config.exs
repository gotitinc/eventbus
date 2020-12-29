# This file is responsible for configuring your umbrella
# and **all applications** and their dependencies with the
# help of Mix.Config.
#
# Note that all applications in your umbrella share the
# same configuration and dependencies, which is why they
# all use the same configuration file. If you want different
# configurations or dependencies per app, it is best to
# move said applications out of the umbrella.
use Mix.Config

config :eventbus,
  max_retry: 5,
  start_delay: 5_000,
  topics: [
           [topic: "router", partition_count: 500],
           [topic: "default", partition_count: 300],
           [topic: "pusher", partition_count: 100],
           [topic: "analytics", partition_count: 100],
           [topic: "_other", partition_count: 100]
         ],
  redis_url: [
    default: "redis://localhost"
  ]

config :eventbus_web,
  generators: [context_app: :eventbus]

# Configures the endpoint
config :eventbus_web, EventbusWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "yL/auLtjwxJg2K2xkjqAZev5wZTmXOKNEZdlN8fNIg9cBrCd1hUkAJkZsrs45IpV",
  render_errors: [view: EventbusWeb.ErrorView, accepts: ~w(json), layout: false],
  pubsub_server: Eventbus.PubSub,
  live_view: [signing_salt: "/88TVjP7"]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
