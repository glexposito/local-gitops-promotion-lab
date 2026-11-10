FROM rust:1.95-slim AS builder

WORKDIR /app

RUN apt-get update \
    && apt-get install --yes --no-install-recommends musl-tools \
    && rm -rf /var/lib/apt/lists/* \
    && rustup target add x86_64-unknown-linux-musl

COPY Cargo.toml Cargo.lock ./
COPY src ./src

RUN cargo build --locked --release --target x86_64-unknown-linux-musl

FROM gcr.io/distroless/static-debian12:nonroot AS runtime

WORKDIR /app

COPY --from=builder /app/target/x86_64-unknown-linux-musl/release/pulse-api /app/pulse-api
# Keep a documentation-only commit observable as a new image digest in this
# promotion lab. It has no effect on the executable.
COPY README.md /app/README.md

EXPOSE 8080
ENV PORT=8080
CMD ["/app/pulse-api"]
