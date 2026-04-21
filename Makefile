BINARY_NAME=http-sink
BUILD_DIR=target/bin
CMD_DIR=cmd/http-sink
ACCEPTANCE_TEST_DIR=acceptance-test

GOCMD=go
GOBUILD=$(GOCMD) build
GOCLEAN=$(GOCMD) clean
GOTEST=$(GOCMD) test
GOMOD=$(GOCMD) mod

VERSION?=dev
BUILD_DATE=$(shell date -u '+%Y-%m-%d_%H:%M:%S')
GIT_COMMIT=$(shell git rev-parse --short HEAD 2>/dev/null || echo "unknown")

LDFLAGS=-ldflags "-s -w -X main.Version=$(VERSION) -X main.BuildDate=$(BUILD_DATE) -X main.GitCommit=$(GIT_COMMIT)"
BUILD_FLAGS=-v $(LDFLAGS)

.PHONY: all build clean test lint deps build-static build-all acceptance-test help

all: clean test build

build:
	@echo "Building $(BINARY_NAME)..."
	@mkdir -p $(BUILD_DIR)
	$(GOBUILD) $(BUILD_FLAGS) -o $(BUILD_DIR)/$(BINARY_NAME) ./$(CMD_DIR)
	@echo "Build complete: $(BUILD_DIR)/$(BINARY_NAME)"

build-static:
	@echo "Building static binary for Linux amd64..."
	@mkdir -p $(BUILD_DIR)
	CGO_ENABLED=0 GOOS=linux GOARCH=amd64 $(GOBUILD) $(BUILD_FLAGS) -o $(BUILD_DIR)/$(BINARY_NAME)-linux-amd64 ./$(CMD_DIR)
	@echo "Static build complete: $(BUILD_DIR)/$(BINARY_NAME)-linux-amd64"
	@echo "Binary size: $$(du -h $(BUILD_DIR)/$(BINARY_NAME)-linux-amd64 | cut -f1)"

build-windows:
	@echo "Building static binary for Windows amd64..."
	@mkdir -p $(BUILD_DIR)
	CGO_ENABLED=0 GOOS=windows GOARCH=amd64 $(GOBUILD) $(BUILD_FLAGS) -o $(BUILD_DIR)/$(BINARY_NAME)-windows-amd64.exe ./$(CMD_DIR)
	@echo "Windows build complete: $(BUILD_DIR)/$(BINARY_NAME)-windows-amd64.exe"
	@echo "Binary size: $$(du -h $(BUILD_DIR)/$(BINARY_NAME)-windows-amd64.exe | cut -f1)"

build-all: build-static build-windows
	@echo "Multi-platform build complete:"
	@ls -lh $(BUILD_DIR)/$(BINARY_NAME)-*

clean:
	@echo "Cleaning..."
	$(GOCLEAN)
	@rm -rf $(BUILD_DIR)
	@rm -rf target
	@echo "Clean complete"

test:
	@echo "Running tests..."
	$(GOTEST) -v ./...

test-verbose:
	@echo "Running tests with verbose output..."
	$(GOTEST) -v -race ./...

coverage:
	@echo "Generating coverage report..."
	$(GOTEST) -coverprofile=coverage.out ./...
	$(GOCMD) tool cover -html=coverage.out -o coverage.html
	@echo "Coverage report generated: coverage.html"

lint:
	@echo "Running linter..."
	golangci-lint run ./...

deps:
	@echo "Downloading dependencies..."
	$(GOMOD) download
	$(GOMOD) tidy

acceptance-test: build-static
	@echo "Running acceptance tests..."
	@cd $(ACCEPTANCE_TEST_DIR) && ./test_acceptance.sh

run-help: build
	./$(BUILD_DIR)/$(BINARY_NAME) --help

dev: build
	@echo "Development setup complete"
	@echo "Run './target/bin/$(BINARY_NAME) serve' to start the server"

help:
	@echo "Available targets:"
	@echo "  all              - Clean, test, and build"
	@echo "  build            - Build the application"
	@echo "  build-static     - Build static binary for Linux amd64"
	@echo "  build-windows    - Build static binary for Windows amd64"
	@echo "  build-all        - Build for Linux and Windows"
	@echo "  clean            - Clean build artifacts"
	@echo "  test             - Run unit tests"
	@echo "  test-verbose     - Run tests with verbose output"
	@echo "  coverage         - Generate test coverage report"
	@echo "  lint             - Run linter"
	@echo "  deps             - Download and tidy dependencies"
	@echo "  acceptance-test  - Run acceptance tests"
	@echo "  run-help         - Build and show application help"
	@echo "  dev              - Development setup"
	@echo "  help             - Show this help message"
