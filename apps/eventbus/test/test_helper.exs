Application.ensure_all_started(:httpoison)
Application.ensure_all_started(Eventbus.Application)
ExUnit.start()
