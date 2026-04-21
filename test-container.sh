#!/bin/sh
# Build and test the HTTP Sink container
# This script builds the container and runs acceptance tests

set -e

echo "Building HTTP Sink container..."
export VERSION="${VERSION:-dev}"
export BUILD_DATE="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
export GIT_COMMIT="$(git rev-parse --short HEAD 2>/dev/null || echo unknown)"

echo "Version: $VERSION"
echo "Build Date: $BUILD_DATE"
echo "Git Commit: $GIT_COMMIT"
echo ""

# Build the container
docker-compose build

echo ""
echo "Running acceptance tests..."
echo ""

# Run acceptance tests
docker-compose up --abort-on-container-exit --exit-code-from acceptance-test

# Capture exit code
TEST_EXIT_CODE=$?

# Cleanup
echo ""
echo "Cleaning up..."
docker-compose down -v

if [ $TEST_EXIT_CODE -eq 0 ]; then
    echo ""
    echo "✓ All tests passed!"
    exit 0
else
    echo ""
    echo "✗ Tests failed!"
    exit 1
fi
