use Mix.Config

config :eventbus,
  max_retry: 5,
  start_delay: 0,
  topics: [
           [topic: "router", partition_count: 1],
           [topic: "default", partition_count: 2],
           [topic: "pusher", partition_count: 3],
           [topic: "analytics", partition_count: 4],
           [topic: "_other", partition_count: 1]
         ]

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :eventbus_web, EventbusWeb.Endpoint,
  http: [port: 4002],
  server: false

# Print only warnings and errors during test
config :logger, level: :warn
