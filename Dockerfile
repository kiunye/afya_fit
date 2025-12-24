# ----------  build stage  ----------
  FROM hexpm/elixir:1.15-erlang-26.0.1-alpine-3.23.2 AS builder

  RUN apk add --no-cache git build-base nodejs npm
  
  WORKDIR /app
  
  # elixir tools
  RUN mix local.hex --force && mix local.rebar --force
  
  # copy dependency files first (layer caching)
  COPY mix.exs mix.lock ./
  COPY config config
  RUN mix deps.get --only prod && mix deps.compile
  
  # copy source **including assets/**
  COPY . .
  
  # install npm packages (required before mix can call tailwind/esbuild)
  RUN cd assets && npm ci
  
  # now build assets & compile
  RUN mix assets.deploy
  RUN mix compile
  RUN mix release
  
  # ----------  runtime stage  ----------
  FROM ubuntu:22.04
  
  # ubuntu packages (glibc runtime)
  RUN apt-get update -qq && \
      apt-get install -y -qq curl ca-certificates openssl libstdc++6 libgcc1 && \
      rm -rf /var/lib/apt/lists/*
  
  RUN useradd -m -s /bin/bash app
  WORKDIR /app
  
  COPY --from=builder --chown=app:app /app/_build/prod/rel/afya_fit .
  USER app
  
  EXPOSE 4000
  
  HEALTHCHECK --interval=30s --timeout=3s --start-period=40s --retries=3 \
    CMD curl -f http://localhost:4000/ || exit 1
  
  ENTRYPOINT ["/app/bin/afya_fit"]
  CMD ["start"]