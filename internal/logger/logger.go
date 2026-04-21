package logger

import (
	"fmt"
	"io"
	"net/http"
	"os"
	"time"

	"github.com/google/uuid"
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
	requestID := uuid.New().String()
	timestamp := time.Now().UTC().Format(time.RFC3339)

	fmt.Fprintf(l.writer, "%s ===== RECEIVED REQUEST BEGIN =====\n", requestID)
	fmt.Fprintf(l.writer, "%s Timestamp: %s\n", requestID, timestamp)
	fmt.Fprintf(l.writer, "%s Method: %s\n", requestID, r.Method)
	fmt.Fprintf(l.writer, "%s Path: %s\n", requestID, r.URL.Path)
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
