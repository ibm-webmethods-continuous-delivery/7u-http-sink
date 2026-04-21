# HTTP Sink

A lightweight HTTP server that accepts all requests and logs them to stdout. Request bodies are saved to files in hourly rotating folders.

## Features

- Accepts all HTTP methods (GET, POST, PUT, DELETE, etc.)
- Logs all request details to stdout with unique GUIDs
- Saves request bodies to files with hourly rotation
- Automatic folder compression (zip) when hour changes
- Configurable via environment variables
- Graceful shutdown support
- Static binary builds for Linux and Windows
- No external dependencies at runtime

## Quick Start

### Using the devcontainer

1. Open the project in VS Code
2. Click "Reopen in Container" when prompted
3. Build the project:
   ```bash
   make build
   ```
4. Run the server:
   ```bash
   ./target/bin/http-sink serve
   ```

### Manual Build

Requirements:
- Go 1.24 or later
- Make

```bash
# Build for current platform
make build

# Build static binaries for Linux and Windows
make build-all

# Run acceptance tests
make acceptance-test
```

## Configuration

Configure the server using environment variables:

| Variable | Default | Description |
|----------|---------|-------------|
| `HTTP_SINK_HOST` | `0.0.0.0` | Host to bind to |
| `HTTP_SINK_PORT` | `8080` | Port to listen on |
| `HTTP_SINK_BODY_DIR` | `/tmp/http-sink-body` | Directory for body files |
| `HTTP_SINK_MAX_BODY_SIZE` | `104857600` (100MB) | Maximum body size in bytes |

## Usage

### Start the server

```bash
http-sink serve
```

### With custom configuration

```bash
export HTTP_SINK_HOST=127.0.0.1
export HTTP_SINK_PORT=9000
export HTTP_SINK_BODY_DIR=/var/log/http-sink
http-sink serve
```

### Check version

```bash
http-sink --version
```

### Health check

```bash
http-sink health
```

## Log Format

Each request is logged with a unique GUID prefix:

```
<GUID> ===== RECEIVED REQUEST BEGIN =====
<GUID> Timestamp: 2026-04-21T08:30:00Z
<GUID> Method: POST
<GUID> Path: /api/data
<GUID> Remote Address: 192.168.1.100:54321
<GUID> Headers:
<GUID>   Content-Type: application/json
<GUID>   User-Agent: curl/7.68.0
<GUID> Body Size: 1234 bytes
<GUID> Body File: /tmp/http-sink-body/2026-04-21-08/body_<guid>.dat
<GUID> ===== RECEIVED REQUEST END   =====
```

## Body File Management

- Body files are saved in hour-based folders: `YYYY-MM-DD-HH`
- When a new hour starts, the previous hour's folder is automatically zipped
- Empty bodies do not create files
- Zipped folders are preserved indefinitely (manual cleanup required)

Example structure:
```
/tmp/http-sink-body/
├── 2026-04-21-08.zip
├── 2026-04-21-09.zip
└── 2026-04-21-10/
    ├── body_abc123.dat
    └── body_def456.dat
```

## Development

### Project Structure

```
.
├── cmd/http-sink/          # Main application entry point
├── internal/
│   ├── logger/             # Request logging
│   ├── rotation/           # Folder rotation and zipping
│   └── server/             # HTTP server implementation
├── acceptance-test/        # Acceptance tests
├── .devcontainer/          # VS Code devcontainer configuration
├── Makefile                # Build automation
└── README.md               # This file
```

### Running Tests

```bash
# Unit tests
make test

# Acceptance tests
make acceptance-test

# Test coverage
make coverage
```

### Building

```bash
# Build for current platform
make build

# Build static binary for Linux
make build-static

# Build static binary for Windows
make build-windows

# Build all platforms
make build-all
```

## Deployment

### Docker/Container

The static Linux binary can be used in minimal containers:

```dockerfile
FROM scratch
COPY http-sink-linux-amd64 /http-sink
ENTRYPOINT ["/http-sink", "serve"]
```

### Systemd Service

Example systemd service file:

```ini
[Unit]
Description=HTTP Sink Server
After=network.target

[Service]
Type=simple
User=http-sink
Environment="HTTP_SINK_PORT=8080"
Environment="HTTP_SINK_BODY_DIR=/var/lib/http-sink/bodies"
ExecStart=/usr/local/bin/http-sink serve
Restart=on-failure

[Install]
WantedBy=multi-user.target
```

## License

Apache 2.0 License
Copyright IBM Corporation. All rights reserved.

## Contributing

This is a development and exploration tool, not intended for production use. For questions or issues, open issues on this repository.

## Container Deployment

### Building the Container

The project includes a multi-stage Dockerfile that builds a minimal container from scratch containing only the static binary.

#### Prerequisites

- Docker or Docker Desktop installed
- Docker Compose (or `docker compose` plugin)

#### Build and Test

**Linux/macOS:**
```bash
./test-container.sh
```

**Windows:**
```cmd
test-container.bat
```

These scripts will:
1. Build the container image with proper version information
2. Start the HTTP sink service
3. Run comprehensive acceptance tests
4. Clean up all resources

#### Manual Container Build

```bash
# Set version information (optional)
export VERSION=1.0.0
export BUILD_DATE=$(date -u +%Y-%m-%dT%H:%M:%SZ)
export GIT_COMMIT=$(git rev-parse --short HEAD)

# Build the container
docker compose build

# Or build directly with docker
docker build \
  --build-arg VERSION=${VERSION} \
  --build-arg BUILD_DATE=${BUILD_DATE} \
  --build-arg GIT_COMMIT=${GIT_COMMIT} \
  -t http-sink:${VERSION} .
```

### Running the Container

#### Using Docker Compose

```bash
# Start the service
docker compose up -d http-sink

# View logs
docker compose logs -f http-sink

# Stop the service
docker compose down
```

#### Using Docker Run

```bash
# Run with default configuration
docker run -d \
  --name http-sink \
  -p 8080:8080 \
  -v http-sink-data:/data/bodies \
  http-sink:dev

# Run with custom configuration
docker run -d \
  --name http-sink \
  -p 9000:9000 \
  -e HTTP_SINK_PORT=9000 \
  -e HTTP_SINK_MAX_BODY_SIZE=52428800 \
  -v /path/to/bodies:/data/bodies \
  http-sink:dev

# View logs
docker logs -f http-sink

# Stop and remove
docker stop http-sink
docker rm http-sink
```

### Container Acceptance Tests

The project includes a comprehensive container acceptance test suite that validates:

- Server reachability and health
- All HTTP methods (GET, POST, PUT, DELETE)
- Custom headers handling
- Large body handling (up to 1MB)
- Body file creation in hourly folders
- Concurrent request handling
- Different content types (JSON, etc.)

#### Test Structure

```
container-acceptance-test/
└── test_container.sh    # Test script (runs inside Alpine container)
```

#### Running Tests Manually

```bash
# Build and run tests
docker compose up --abort-on-container-exit --exit-code-from acceptance-test

# Cleanup
docker compose down -v
```

### Container Image Details

- **Base Image**: `FROM scratch` (minimal, no OS)
- **Size**: ~8MB (static binary only)
- **Architecture**: linux/amd64
- **Exposed Port**: 8080
- **Volume**: `/data/bodies` (for request body files)
- **Entrypoint**: `/http-sink serve`

### Security Considerations

- The container runs from scratch with no shell or utilities
- No root user or privilege escalation possible
- Static binary with no dynamic dependencies
- Minimal attack surface
- All request data is logged to stdout (ensure proper log management)
- Body files are stored in a dedicated volume (ensure proper access controls)

### Troubleshooting

#### Container won't start

```bash
# Check container logs
docker logs http-sink

# Verify port is not in use
netstat -an | grep 8080  # Linux/macOS
netstat -an | findstr 8080  # Windows
```

#### Tests fail

```bash
# Run tests with verbose output
docker compose up acceptance-test

# Check if server is healthy
docker compose ps
docker compose logs http-sink
```

#### Body files not persisted

```bash
# Verify volume is mounted
docker inspect http-sink | grep -A 10 Mounts

# Check volume contents
docker run --rm -v http-sink-data:/data alpine ls -la /data/bodies
```
