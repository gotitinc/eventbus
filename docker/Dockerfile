# Builder Stage
FROM hexpm/elixir:1.11.4-erlang-24.2-alpine-3.16.0 as builder
WORKDIR /opt/local/eventbus
COPY ./ /opt/local/eventbus
RUN mix do local.hex --force, local.rebar --force
RUN MIX_ENV=prod mix deps.get --only prod
RUN MIX_ENV=prod mix release --force --overwrite

# Runner Stage
FROM hexpm/elixir:1.11.4-erlang-24.2-alpine-3.16.0 as runner
ENV PORT 4000

COPY --from=builder /opt/local/eventbus/_build/prod/rel/eventbus_service /opt/local/eventbus/_build/prod/rel/eventbus_service

# create running user
RUN adduser --system --no-create-home --home /nonexistent --shell /usr/sbin/nologin -G root docker-runner
# update permissions & change user to not run as root
RUN chgrp -R 0 /opt/local/eventbus/_build/prod/rel/eventbus_service && chmod -R g=u /opt/local/eventbus/_build/prod/rel/eventbus_service
# switch to non-root user
USER docker-runner

ENTRYPOINT []
CMD ["/opt/local/eventbus/_build/prod/rel/eventbus_service/bin/eventbus_service", "start"]
