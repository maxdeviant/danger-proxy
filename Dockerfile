FROM ghcr.io/gleam-lang/gleam:v1.0.0-erlang-alpine AS builder
WORKDIR /app
COPY . .
RUN gleam export erlang-shipment

FROM ghcr.io/gleam-lang/gleam:v1.0.0-erlang-alpine
WORKDIR /app
COPY --from=builder /app/build/erlang-shipment /app
ENTRYPOINT ["/app/entrypoint.sh"]
CMD ["run"]
