# ============================================================
# Stage 1: Build the Rust service
# ============================================================
FROM rust:1.86-slim-bookworm AS builder

RUN apt-get update && apt-get install -y \
    protobuf-compiler \
    libprotobuf-dev \
    pkg-config \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY Cargo.toml Cargo.lock* ./
COPY build.rs .
COPY proto ./proto
COPY src ./src

RUN cargo build --release --locked

# ============================================================
# Stage 2: Minimal runtime image
# ============================================================
FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y \
    libprotobuf-dev \
    ca-certificates \
    curl \
    osmium-tool \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /app/target/release/runit-maps /usr/local/bin/runit-maps
COPY config /app/config

EXPOSE 50051

ENTRYPOINT ["runit-maps"]
