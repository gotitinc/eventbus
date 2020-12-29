FROM elixir:1.11
ENV PORT 80
ENV MIX_ENV prod
WORKDIR /opt/local/eventbus
COPY ./ /opt/local/eventbus
RUN mix do local.hex --force, local.rebar --force
RUN MIX_ENV=prod mix deps.get --only prod
RUN MIX_ENV=prod mix release --force --overwrite
CMD /opt/local/eventbus/_build/prod/rel/eventbus_service/bin/eventbus_service start
