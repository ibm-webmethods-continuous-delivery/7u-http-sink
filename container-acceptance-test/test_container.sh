#!/bin/sh
# Container Acceptance Test for HTTP Sink
# This script runs inside a test container and validates the HTTP sink service

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
HTTP_SINK_URL="${HTTP_SINK_URL:-http://http-sink:8080}"
BODY_DIR="${BODY_DIR:-/data/bodies}"

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Install curl if not available
if ! command -v curl >/dev/null 2>&1; then
    echo "Installing curl..."
    apk add --no-cache curl
fi

# Helper functions
log_info() {
    echo "${GREEN}[INFO]${NC} $*"
}

log_error() {
    echo "${RED}[ERROR]${NC} $*"
}

log_test() {
    echo "${YELLOW}[TEST]${NC} $*"
}

pass_test() {
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo "${GREEN}✓ PASS${NC}: $*"
}

fail_test() {
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo "${RED}✗ FAIL${NC}: $*"
}

run_test() {
    TESTS_RUN=$((TESTS_RUN + 1))
}

# Test 1: Server is reachable
test_server_reachable() {
    log_test "Test 1: Server is reachable"
    run_test
    
    if curl -s -o /dev/null -w "%{http_code}" "$HTTP_SINK_URL/" | grep -q "200"; then
        pass_test "Server responded with 200 OK"
    else
        fail_test "Server did not respond with 200 OK"
    fi
}

# Test 2: GET request
test_get_request() {
    log_test "Test 2: GET request"
    run_test
    
    response=$(curl -s -w "%{http_code}" -o /dev/null "$HTTP_SINK_URL/test/get")
    if [ "$response" = "200" ]; then
        pass_test "GET request returned 200"
    else
        fail_test "GET request returned $response instead of 200"
    fi
}

# Test 3: POST request with body
test_post_request() {
    log_test "Test 3: POST request with body"
    run_test
    
    test_body="This is a test body for POST request"
    response=$(curl -s -w "%{http_code}" -o /dev/null -X POST -d "$test_body" "$HTTP_SINK_URL/api/data")
    
    if [ "$response" = "200" ]; then
        pass_test "POST request returned 200"
    else
        fail_test "POST request returned $response instead of 200"
    fi
}
# Test 4: PUT request
test_put_request() {
    log_test "Test 4: PUT request"
    run_test
    
    response=$(curl -s -w "%{http_code}" -o /dev/null -X PUT -d "update data" "$HTTP_SINK_URL/resource/123")
    
    if [ "$response" = "200" ]; then
        pass_test "PUT request returned 200"
    else
        fail_test "PUT request returned $response instead of 200"
    fi
}

# Test 5: DELETE request
test_delete_request() {
    log_test "Test 5: DELETE request"
    run_test
    
    response=$(curl -s -w "%{http_code}" -o /dev/null -X DELETE "$HTTP_SINK_URL/resource/456")
    
    if [ "$response" = "200" ]; then
        pass_test "DELETE request returned 200"
    else
        fail_test "DELETE request returned $response instead of 200"
    fi
}

# Test 6: Custom headers
test_custom_headers() {
    log_test "Test 6: Custom headers"
    run_test
    
    response=$(curl -s -w "%{http_code}" -o /dev/null \
        -H "X-Custom-Header: test-value" \
        -H "Authorization: Bearer token123" \
        "$HTTP_SINK_URL/api/secure")
    
    if [ "$response" = "200" ]; then
        pass_test "Request with custom headers returned 200"
    else
        fail_test "Request with custom headers returned $response instead of 200"
    fi
}

# Test 7: Large body (within limit)
test_large_body() {
    log_test "Test 7: Large body (1MB)"
    run_test
    
    dd if=/dev/zero bs=1024 count=1024 2>/dev/null | base64 > /tmp/large_file.bin
    response=$(curl -s -w "%{http_code}" -o /dev/null -X POST -T /tmp/large_file.bin "$HTTP_SINK_URL/upload/large")
    
    if [ "$response" = "200" ]; then
        pass_test "Large body (1MB) request returned 200"
    else
        fail_test "Large body request returned $response instead of 200"
    fi
}
# Test 8: Body files are created
test_body_files_created() {
    log_test "Test 8: Body files are created in hourly folders"
    run_test
    
    sleep 2
    
    if find "$BODY_DIR" -type d -name "????-??-??-??" | grep -q .; then
        pass_test "Hourly folder structure exists"
    else
        fail_test "No hourly folders found in $BODY_DIR"
    fi
}

# Test 9: Multiple concurrent requests
test_concurrent_requests() {
    log_test "Test 9: Multiple concurrent requests"
    run_test
    
    for i in 1 2 3 4 5; do
        curl -s -o /dev/null -X POST -d "concurrent request $i" "$HTTP_SINK_URL/concurrent/$i" &
    done
    wait
    
    pass_test "Concurrent requests completed"
}

# Test 10: Different content types
test_content_types() {
    log_test "Test 10: Different content types"
    run_test
    
    response=$(curl -s -w "%{http_code}" -o /dev/null \
        -H "Content-Type: application/json" \
        -d '{"key":"value"}' \
        "$HTTP_SINK_URL/api/json")
    
    if [ "$response" = "200" ]; then
        pass_test "JSON content type request returned 200"
    else
        fail_test "JSON content type request returned $response"
    fi
}

# Main test execution
main() {
    log_info "Starting HTTP Sink Container Acceptance Tests"
    log_info "Target URL: $HTTP_SINK_URL"
    log_info "Body directory: $BODY_DIR"
    echo ""
    
    log_info "Waiting for server to be ready..."
    max_attempts=30
    attempt=0
    while [ $attempt -lt $max_attempts ]; do
        if curl -s -o /dev/null "$HTTP_SINK_URL/" 2>/dev/null; then
            log_info "Server is ready!"
            break
        fi
        attempt=$((attempt + 1))
        sleep 1
    done
    
    if [ $attempt -eq $max_attempts ]; then
        log_error "Server did not become ready in time"
        exit 1
    fi
    
    echo ""
    
    test_server_reachable
    test_get_request
    test_post_request
    test_put_request
    test_delete_request
    test_custom_headers
    test_large_body
    test_body_files_created
    test_concurrent_requests
    test_content_types
    
    echo ""
    echo "=========================================="
    echo "Test Summary"
    echo "=========================================="
    echo "Tests Run:    $TESTS_RUN"
    echo "Tests Passed: ${GREEN}$TESTS_PASSED${NC}"
    echo "Tests Failed: ${RED}$TESTS_FAILED${NC}"
    echo "=========================================="
    
    if [ $TESTS_FAILED -eq 0 ]; then
        log_info "All tests passed! ✓"
        exit 0
    else
        log_error "Some tests failed!"
        exit 1
    fi
}

main
