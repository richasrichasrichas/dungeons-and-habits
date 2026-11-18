# Build the API with a Go toolchain compatible with Fiber v3.
FROM golang:1.26-alpine AS builder

WORKDIR /src
RUN apk add --no-cache ca-certificates

COPY go.mod go.sum ./
RUN go mod download
COPY . .

RUN CGO_ENABLED=0 GOOS=linux go build \
    -trimpath \
    -ldflags="-s -w" \
    -o /out/dah-api ./cmd/api

# Static binary in a minimal runtime image.
FROM scratch
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/
COPY --from=builder /out/dah-api /dah-api
USER 65532:65532
EXPOSE 8080
ENTRYPOINT ["/dah-api"]
