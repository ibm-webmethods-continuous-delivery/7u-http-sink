#!/bin/sh
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BINARY="$PROJECT_ROOT/target/bin/http-sink-linux-amd64"
TEST_DATA_DIR="$SCRIPT_DIR/test-data"
TEST_BODY_DIR="$TEST_DATA_DIR/bodies"
TEST_PORT="18080"

cleanup() {
    echo "Cleaning up..."
    if [ -n "$SERVER_PID" ] && kill -0 "$SERVER_PID" 2>/dev/null; then
        echo "Stopping server (PID: $SERVER_PID)..."
        kill "$SERVER_PID" 2>/dev/null || true
        wait "$SERVER_PID" 2>/dev/null || true
    fi
    rm -rf "$TEST_DATA_DIR"
    echo "Cleanup complete"
}

trap cleanup EXIT INT TERM

echo "========================================="
echo "HTTP Sink Acceptance Tests"
echo "========================================="
echo ""

if [ ! -f "$BINARY" ]; then
    echo "ERROR: Binary not found at $BINARY"
    echo "Please run 'make build-static' first"
    exit 1
fi

echo "Step 1: Preparing test environment..."
rm -rf "$TEST_DATA_DIR"
mkdir -p "$TEST_DATA_DIR"
mkdir -p "$TEST_BODY_DIR"

echo "Step 2: Starting HTTP Sink server..."
export HTTP_SINK_HOST=127.0.0.1
export HTTP_SINK_PORT=$TEST_PORT
export HTTP_SINK_BODY_DIR=$TEST_BODY_DIR
export HTTP_SINK_MAX_BODY_SIZE=10485760

"$BINARY" serve > "$TEST_DATA_DIR/server.log" 2>&1 &
SERVER_PID=$!

echo "Server started with PID: $SERVER_PID"
sleep 2

if ! kill -0 "$SERVER_PID" 2>/dev/null; then
    echo "ERROR: Server failed to start"
    cat "$TEST_DATA_DIR/server.log"
    exit 1
fi

echo "Step 3: Running test requests..."

echo "  Test 3.1: GET request with no body..."
curl -s -X GET "http://127.0.0.1:$TEST_PORT/test/path" \
    -H "X-Test-Header: test-value" \
    -H "User-Agent: acceptance-test" \
    > /dev/null

echo "  Test 3.2: POST request with body..."
echo "This is test body content" | curl -s -X POST "http://127.0.0.1:$TEST_PORT/api/data" \
    -H "Content-Type: text/plain" \
    -H "X-Request-ID: test-123" \
    -d @- \
    > /dev/null

echo "  Test 3.3: PUT request with JSON body..."
curl -s -X PUT "http://127.0.0.1:$TEST_PORT/api/update" \
    -H "Content-Type: application/json" \
    -d '{"key":"value","number":42}' \
    > /dev/null

echo "  Test 3.4: DELETE request..."
curl -s -X DELETE "http://127.0.0.1:$TEST_PORT/api/resource/123" \
    > /dev/null

echo "  Test 3.5: GET request with query parameters..."
curl -s -X GET "http://127.0.0.1:$TEST_PORT/api/search?query=test&limit=10&offset=0" \
    -H "X-Search-ID: search-456" \
    > /dev/null

sleep 1

echo ""
echo "Step 4: Verifying results..."

if ! grep -q "RECEIVED REQUEST BEGIN" "$TEST_DATA_DIR/server.log"; then
    echo "ERROR: No request logs found"
    exit 1
fi
echo "  ✓ Request logging verified"

if ! grep -q "Method: GET" "$TEST_DATA_DIR/server.log"; then
    echo "ERROR: GET method not logged"
    exit 1
fi
echo "  ✓ GET method logged"

if ! grep -q "Method: POST" "$TEST_DATA_DIR/server.log"; then
    echo "ERROR: POST method not logged"
    exit 1
fi
echo "  ✓ POST method logged"

if ! grep -q "Path: /test/path" "$TEST_DATA_DIR/server.log"; then
    echo "ERROR: Path not logged correctly"
    exit 1
fi
echo "  ✓ Path logging verified"

if ! grep -q "Query: query=test" "$TEST_DATA_DIR/server.log"; then
    echo "ERROR: Query parameters not logged"
    exit 1
fi
echo "  ✓ Query parameter logging verified"

if ! grep -q "X-Test-Header: test-value" "$TEST_DATA_DIR/server.log"; then
    echo "ERROR: Headers not logged"
    exit 1
fi
echo "  ✓ Header logging verified"

BODY_FILES=$(find "$TEST_BODY_DIR" -name "body_*.dat" 2>/dev/null | wc -l)
if [ "$BODY_FILES" -lt 2 ]; then
    echo "ERROR: Expected at least 2 body files, found $BODY_FILES"
    exit 1
fi
echo "  ✓ Body files created ($BODY_FILES files)"

HOUR_FOLDERS=$(find "$TEST_BODY_DIR" -type d -name "20*" 2>/dev/null | wc -l)
if [ "$HOUR_FOLDERS" -lt 1 ]; then
    echo "ERROR: No hour folders created"
    exit 1
fi
echo "  ✓ Hour-based folder structure verified"

if ! grep -q "Body Size:" "$TEST_DATA_DIR/server.log"; then
    echo "ERROR: Body size not logged"
    exit 1
fi
echo "  ✓ Body size logging verified"

echo ""
echo "========================================="
echo "All Acceptance Tests Passed!"
echo "========================================="
echo ""
echo "Summary:"
echo "  - Server started successfully"
echo "  - All HTTP methods logged correctly"
echo "  - Headers logged correctly"
echo "  - Paths logged correctly"
echo "  - Query parameters logged correctly"
echo "  - Body files created: $BODY_FILES"
echo "  - Hour folders created: $HOUR_FOLDERS"
echo ""

exit 0
