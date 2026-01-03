# Stage 1: Build the Burrito binary

ARG ELIXIR_VERSION=1.18.4
ARG OTP_VERSION=27.3.4.6
ARG DEBIAN_VERSION=trixie-20251229-slim

ARG BUILDER_IMAGE="hexpm/elixir:${ELIXIR_VERSION}-erlang-${OTP_VERSION}-debian-${DEBIAN_VERSION}"

FROM ${BUILDER_IMAGE} AS builder

ARG TARGETARCH

WORKDIR /app

# Install build dependencies
RUN apt-get update && apt-get install -y \
    git \
    curl \
    build-essential \
    xz-utils \
    && rm -rf /var/lib/apt/lists/*

# Install Zig from official tarball based on architecture
# Using Zig 0.15.2 which is compatible with Burrito 1.5.0
RUN ZIG_VERSION="0.15.2" && \
    if [ "$TARGETARCH" = "amd64" ]; then \
      ZIG_ARCH="x86_64"; \
    elif [ "$TARGETARCH" = "arm64" ]; then \
      ZIG_ARCH="aarch64"; \
    else \
      echo "Unsupported architecture: $TARGETARCH" && exit 1; \
    fi && \
    curl -sSL "https://ziglang.org/download/${ZIG_VERSION}/zig-${ZIG_ARCH}-linux-${ZIG_VERSION}.tar.xz" | tar -xJ -C /usr/local && \
    ln -s /usr/local/zig-${ZIG_ARCH}-linux-${ZIG_VERSION}/zig /usr/local/bin/zig

# Install hex and rebar
# ERL_FLAGS=-noinput prevents TTY initialization issues with OTP 28 in Distroless images
ENV ERL_FLAGS="-noinput"
RUN mix local.hex --force && mix local.rebar --force

# Copy dependency files first for better caching
COPY mix.exs mix.lock ./
COPY config config

# workaround for an issue with typed_struct when cross compiling
# for two architectures concurrently
ENV ERL_FLAGS="+JPperf true"

# Get and compile dependencies
ENV MIX_ENV=prod
RUN mix deps.get --only prod
RUN mix deps.compile

# Copy application code
COPY lib lib
COPY priv priv

# Determine the Burrito target based on TARGETARCH
# TARGETARCH is automatically set by buildx (amd64 or arm64)
# Burrito outputs binaries with target suffix (e.g., kpd_server_linux_amd64)
# so we rename to a consistent name for the COPY stage
RUN BURRITO_TARGET=$(if [ "$TARGETARCH" = "amd64" ]; then echo "linux_amd64"; else echo "linux_arm64"; fi) && \
    MIX_ENV=prod BURRITO_TARGET=$BURRITO_TARGET mix release && \
    mv /app/burrito_out/kpd_server_${BURRITO_TARGET} /app/burrito_out/kpd_server

# Stage 2: Runtime image (no SSL - use behind TLS-terminating proxy)
FROM gcr.io/distroless/base-nossl-debian13:nonroot

WORKDIR /app

# Copy the Burrito binary from builder
COPY --from=builder /app/burrito_out/kpd_server /app/kpd_server

# Expose the port the app listens on
EXPOSE 4000

# Run as nonroot user (UID 65532 in distroless)
USER nonroot

# Use vector form for ENTRYPOINT (required for distroless - no shell)
ENTRYPOINT ["/app/kpd_server"]
