# syntax=docker/dockerfile:1
FROM rust:1.98.1-bookworm AS builder

ARG GIT_COMMIT=unknown

WORKDIR /build
COPY Cargo.toml Cargo.lock ./
COPY src ./src
COPY migrations ./migrations
RUN cargo build --locked --release --bins

FROM debian:bookworm-slim

ARG GIT_COMMIT=unknown
LABEL org.opencontainers.image.title="JLU Dela API" \
      org.opencontainers.image.revision="${GIT_COMMIT}" \
      org.opencontainers.image.licenses="GPL-3.0-or-later"

RUN apt-get update \
    && apt-get install --yes --no-install-recommends ca-certificates curl \
    && rm -rf /var/lib/apt/lists/* \
    && groupadd --system --gid 10001 app \
    && useradd --system --uid 10001 --gid app --home-dir /nonexistent --shell /usr/sbin/nologin app \
    && mkdir -p /var/lib/jlu-dela/files \
    && chown 10001:10001 /var/lib/jlu-dela/files

COPY --from=builder /build/target/release/jlu-dela-api /usr/local/bin/jlu-dela-api
COPY --from=builder /build/target/release/migrate /usr/local/bin/migrate

USER 10001:10001
EXPOSE 8080
ENV HTTP_HOST=0.0.0.0 \
    HTTP_PORT=8080 \
    LOG_FORMAT=json

HEALTHCHECK --interval=10s --timeout=3s --start-period=5s --retries=3 \
    CMD ["curl", "--fail", "--silent", "--show-error", "http://127.0.0.1:8080/health/live"]

CMD ["/usr/local/bin/jlu-dela-api"]
