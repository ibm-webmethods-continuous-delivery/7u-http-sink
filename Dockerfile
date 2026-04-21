# Multi-stage build for HTTP Sink
# Stage 1: Build the static binary
FROM golang:1.24.4-alpine3.22 AS builder

WORKDIR /build

# Copy go mod files
COPY go.mod go.sum ./
RUN go mod download

# Copy source code
COPY cmd/ ./cmd/
COPY internal/ ./internal/

# Build static binary
ARG VERSION=container
ARG BUILD_DATE
ARG GIT_COMMIT=unknown

RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build \
    -ldflags "-s -w -X main.Version=${VERSION} -X main.BuildDate=${BUILD_DATE} -X main.GitCommit=${GIT_COMMIT}" \
    -o http-sink \
    ./cmd/http-sink

# Verify the binary is static
RUN ldd http-sink 2>&1 | grep -qE "(statically linked|Not a valid dynamic program|not a dynamic executable)" || (echo "Binary is not static!" && exit 1)

# Stage 2: Runtime container from scratch
FROM scratch

# Copy the static binary
COPY --from=builder /build/http-sink /http-sink

# Set default environment variables
ENV HTTP_SINK_HOST=0.0.0.0
ENV HTTP_SINK_PORT=8080
ENV HTTP_SINK_BODY_DIR=/data/bodies
ENV HTTP_SINK_MAX_BODY_SIZE=104857600

# Expose the default port
EXPOSE 8080

# Run the server
ENTRYPOINT ["/http-sink"]
CMD ["serve"]
