# Build stage
FROM hexpm/elixir:1.15-erlang-26.0.1-alpine-3.23.2 AS builder

# Install build dependencies
RUN apt-get update -qq && \
    apt-get install -y -qq git build-essential nodejs npm && \
    rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Install hex and rebar
RUN mix local.hex --force && \
    mix local.rebar --force

# Copy dependency files
COPY mix.exs mix.lock ./
COPY config config

# Install dependencies
RUN mix deps.get --only prod && \
    mix deps.compile

# Copy application code
COPY . .

# Build assets
RUN mix assets.deploy

# Compile application
RUN mix compile

# Build release
RUN mix release

# Runtime stage
FROM ubuntu:22.04

# Install runtime dependencies
RUN apt-get update -qq && \
    apt-get install -y -qq \
      curl \
      ca-certificates \
      openssl \
      libstdc++6 \
      libgcc1 \
      && \
    rm -rf /var/lib/apt/lists/*

# Create app user
RUN useradd -m -s /bin/bash app

# Set working directory
WORKDIR /app

# Copy release from builder
COPY --from=builder --chown=app:app /app/_build/prod/rel/afya_fit .

# Switch to app user
USER app

# Expose port
EXPOSE 4000

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=40s --retries=3 \
  CMD curl -f http://localhost:4000/ || exit 1

# Start the application
ENTRYPOINT ["/app/bin/afya_fit"]
CMD ["start"]

