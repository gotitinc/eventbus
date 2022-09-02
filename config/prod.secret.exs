# In this file, we load production configuration and secrets
# from environment variables. You can also hardcode secrets,
# although such is generally not recommended and you have to
# remember to add this file to your .gitignore.
use Mix.Config

secret_key_base =
  System.get_env("SECRET_KEY_BASE") ||
   (:crypto.strong_rand_bytes(64) |> Base.encode64 |> binary_part(0, 64))

config :eventbus_web, EventbusWeb.Endpoint,
  http: [
    port: String.to_integer(System.get_env("PORT") || "4000"),
    protocol_options: [idle_timeout: 70_000],
    transport_options: [socket_opts: [:inet6]]
  ],
  secret_key_base: secret_key_base

# ## Using releases (Elixir v1.9+)
#
# If you are doing OTP releases, you need to instruct Phoenix
# to start each relevant endpoint:
#
#     config :eventbus_web, EventbusWeb.Endpoint, server: true
#
# Then you can assemble a release by calling `mix release`.
# See `mix help release` for more information.
