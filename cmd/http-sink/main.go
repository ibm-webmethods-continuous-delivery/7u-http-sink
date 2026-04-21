package main

import (
	"net/http"
	"time"
	"fmt"
	"os"
	"strconv"

	"github.com/ibm-webmethods-aftermarket-tools/7u-http-sink/internal/server"
	"github.com/spf13/cobra"
)

var (
	Version   = "dev"
	BuildDate = "unknown"
	GitCommit = "unknown"
)

func main() {
	if err := rootCmd.Execute(); err != nil {
		fmt.Fprintf(os.Stderr, "Error: %v\n", err)
		os.Exit(1)
	}
}

var rootCmd = &cobra.Command{
	Use:   "http-sink",
	Short: "HTTP Sink - A simple HTTP server that logs all requests",
	Long: `HTTP Sink is an HTTP server that accepts all requests and logs them to stdout.
Request bodies are saved to files in hourly rotating folders.`,
	Version: fmt.Sprintf("%s (built: %s, commit: %s)", Version, BuildDate, GitCommit),
}

var serveCmd = &cobra.Command{
	Use:   "serve",
	Short: "Start the HTTP sink server",
	Long:  "Start the HTTP sink server that accepts and logs all HTTP requests",
	RunE: func(cmd *cobra.Command, args []string) error {
		host := getEnv("HTTP_SINK_HOST", "0.0.0.0")
		port := getEnv("HTTP_SINK_PORT", "8080")
		bodyDir := getEnv("HTTP_SINK_BODY_DIR", "/tmp/http-sink-body")
		maxBodySizeStr := getEnv("HTTP_SINK_MAX_BODY_SIZE", "104857600")
		
		maxBodySize, err := strconv.ParseInt(maxBodySizeStr, 10, 64)
		if err != nil {
			return fmt.Errorf("invalid HTTP_SINK_MAX_BODY_SIZE: %w", err)
		}

		srv, err := server.New(host, port, bodyDir, maxBodySize)
		if err != nil {
			return fmt.Errorf("failed to create server: %w", err)
		}

		return srv.Start()
	},
}

var healthCmd = &cobra.Command{
	Use:   "health",
	Short: "Check server health status",
	Long:  "Check if the HTTP sink server is running and healthy by making an HTTP request",
	RunE: func(cmd *cobra.Command, args []string) error {
		port := getEnv("HTTP_SINK_PORT", "8080")
		
		// Use localhost for health check since we're checking from inside the container
		url := fmt.Sprintf("http://127.0.0.1:%s/health", port)
		
		client := &http.Client{
			Timeout: 2 * time.Second,
		}
		
		resp, err := client.Get(url)
		if err != nil {
			return fmt.Errorf("health check failed: %w", err)
		}
		defer resp.Body.Close()
		
		if resp.StatusCode != http.StatusOK {
			return fmt.Errorf("health check failed: unexpected status code %d", resp.StatusCode)
		}
		
		return nil
	},
}

func init() {
	rootCmd.AddCommand(serveCmd)
	rootCmd.AddCommand(healthCmd)
}

func getEnv(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}
