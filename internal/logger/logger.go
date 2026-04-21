package logger

import (
	"crypto/rand"
	"encoding/base64"
	"fmt"
	"io"
	"net/http"
	"os"
	"time"
)

type RequestLogger struct {
	writer io.Writer
}

func New(writer io.Writer) *RequestLogger {
	return &RequestLogger{
		writer: writer,
	}
}

func (l *RequestLogger) LogRequest(r *http.Request, bodySize int64, bodyFilePath string) string {
	requestID := generateShortID()
	timestamp := time.Now().UTC().Format(time.RFC3339)

	fmt.Fprintf(l.writer, "%s ===== RECEIVED REQUEST BEGIN =====\n", requestID)
	fmt.Fprintf(l.writer, "%s Timestamp: %s\n", requestID, timestamp)
	fmt.Fprintf(l.writer, "%s Method: %s\n", requestID, r.Method)
	fmt.Fprintf(l.writer, "%s Path: %s\n", requestID, r.URL.Path)
	if r.URL.RawQuery != "" {
		fmt.Fprintf(l.writer, "%s Query: %s\n", requestID, r.URL.RawQuery)
	}
	fmt.Fprintf(l.writer, "%s Remote Address: %s\n", requestID, r.RemoteAddr)
	
	fmt.Fprintf(l.writer, "%s Headers:\n", requestID)
	for name, values := range r.Header {
		for _, value := range values {
			fmt.Fprintf(l.writer, "%s   %s: %s\n", requestID, name, value)
		}
	}
	
	fmt.Fprintf(l.writer, "%s Body Size: %d bytes\n", requestID, bodySize)
	if bodyFilePath != "" {
		fmt.Fprintf(l.writer, "%s Body File: %s\n", requestID, bodyFilePath)
	} else {
		fmt.Fprintf(l.writer, "%s Body File: (empty body, no file created)\n", requestID)
	}
	
	fmt.Fprintf(l.writer, "%s ===== RECEIVED REQUEST END   =====\n", requestID)

	return requestID
}

func (l *RequestLogger) LogError(format string, args ...interface{}) {
	fmt.Fprintf(os.Stderr, "ERROR: "+format+"\n", args...)
}

func (l *RequestLogger) LogInfo(format string, args ...interface{}) {
	fmt.Fprintf(l.writer, "INFO: "+format+"\n", args...)
}

// generateShortID creates a short, base64-encoded random ID (12 bytes = 16 chars base64)
func generateShortID() string {
	b := make([]byte, 12)
	if _, err := rand.Read(b); err != nil {
		// Fallback to timestamp-based ID if random fails
		return fmt.Sprintf("%d", time.Now().UnixNano())
	}
	// Use URL-safe base64 encoding without padding
	return base64.RawURLEncoding.EncodeToString(b)
}
