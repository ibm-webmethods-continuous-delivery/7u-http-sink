package server

import (
	"context"
	"fmt"

	// "io"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/ibm-webmethods-aftermarket-tools/7u-http-sink/internal/logger"
	"github.com/ibm-webmethods-aftermarket-tools/7u-http-sink/internal/rotation"
)

type Server struct {
	host          string
	port          string
	logger        *logger.RequestLogger
	folderManager *rotation.FolderManager
	httpServer    *http.Server
}

func New(host, port, bodyDir string, maxBodySize int64) (*Server, error) {
	fm, err := rotation.NewFolderManager(bodyDir, maxBodySize)
	if err != nil {
		return nil, fmt.Errorf("failed to create folder manager: %w", err)
	}

	s := &Server{
		host:          host,
		port:          port,
		logger:        logger.New(os.Stdout),
		folderManager: fm,
	}

	mux := http.NewServeMux()
	mux.HandleFunc("/", s.handleRequest)
	mux.HandleFunc("/health", s.handleHealth)

	s.httpServer = &http.Server{
		Addr:    fmt.Sprintf("%s:%s", host, port),
		Handler: mux,
	}

	return s, nil
}

func (s *Server) handleHealth(w http.ResponseWriter, r *http.Request) {
	w.WriteHeader(http.StatusOK)
	w.Write([]byte("OK"))
}

func (s *Server) handleRequest(w http.ResponseWriter, r *http.Request) {
	var bodyFilePath string
	var bodySize int64

	// requestID := ""
	
	if r.Body != nil && r.ContentLength != 0 {
		tempID := fmt.Sprintf("temp-%d", time.Now().UnixNano())
		filePath, size, err := s.folderManager.SaveBody(tempID, r.Body)
		if err != nil {
			s.logger.LogError("Failed to save body: %v", err)
		} else {
			bodyFilePath = filePath
			bodySize = size
		}
	}

	// requestID = 
	s.logger.LogRequest(r, bodySize, bodyFilePath)

	w.WriteHeader(http.StatusOK)
}

func (s *Server) Start() error {
	s.logger.LogInfo("Starting HTTP Sink Server on %s:%s", s.host, s.port)
	s.logger.LogInfo("Body files directory: %s", s.folderManager.GetCurrentFolder())

	errChan := make(chan error, 1)
	go func() {
		if err := s.httpServer.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			errChan <- err
		}
	}()

	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, os.Interrupt, syscall.SIGTERM)

	select {
	case err := <-errChan:
		return fmt.Errorf("server error: %w", err)
	case sig := <-sigChan:
		s.logger.LogInfo("Received signal: %v, shutting down gracefully...", sig)
		return s.Shutdown()
	}
}

func (s *Server) Shutdown() error {
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	if err := s.httpServer.Shutdown(ctx); err != nil {
		return fmt.Errorf("server shutdown error: %w", err)
	}

	s.logger.LogInfo("Server stopped gracefully")
	return nil
}

func (s *Server) IsHealthy() bool {
	return true
}
