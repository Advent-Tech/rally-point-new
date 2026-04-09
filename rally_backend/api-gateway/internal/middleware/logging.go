package middleware

import (
	"bytes"
	"io"
	"time"

	"github.com/gin-gonic/gin"
)

// LoggingMiddleware provides structured logging for requests
func LoggingMiddleware() gin.HandlerFunc {
	return gin.LoggerWithFormatter(func(param gin.LogFormatterParams) string {
		return ""
	})
}

// RequestResponseLogger logs request and response details
func RequestResponseLogger() gin.HandlerFunc {
	return func(c *gin.Context) {
		// Start timer
		start := time.Now()
		
		// Log request
		var requestBody []byte
		if c.Request.Body != nil {
			requestBody, _ = io.ReadAll(c.Request.Body)
			c.Request.Body = io.NopCloser(bytes.NewBuffer(requestBody))
		}
		
		// Create a response writer wrapper to capture response
		blw := &bodyLogWriter{body: bytes.NewBufferString(""), ResponseWriter: c.Writer}
		c.Writer = blw
		
		// Process request
		c.Next()
		
		// Calculate latency
		latency := time.Since(start)
		
		// Get user info if available
		userID, _ := c.Get("user_id")
		teamID, _ := c.Get("team_id")
		
		// Log the request/response
		logData := map[string]interface{}{
			"timestamp":    start.Format(time.RFC3339),
			"method":       c.Request.Method,
			"path":         c.Request.URL.Path,
			"query":        c.Request.URL.RawQuery,
			"status":       c.Writer.Status(),
			"latency":      latency.String(),
			"client_ip":    c.ClientIP(),
			"user_agent":   c.Request.UserAgent(),
			"user_id":      userID,
			"team_id":      teamID,
			"request_size": len(requestBody),
			"response_size": blw.body.Len(),
		}
		
		// Add error if status >= 400
		if c.Writer.Status() >= 400 {
			logData["error"] = true
			if len(c.Errors) > 0 {
				logData["errors"] = c.Errors.String()
			}
		}
		
		// In debug mode, include request/response bodies for non-sensitive endpoints
		if gin.Mode() == gin.DebugMode && !isSensitiveEndpoint(c.Request.URL.Path) {
			if len(requestBody) > 0 && len(requestBody) < 1024 {
				logData["request_body"] = string(requestBody)
			}
			if blw.body.Len() > 0 && blw.body.Len() < 1024 {
				logData["response_body"] = blw.body.String()
			}
		}
		
		// Log based on status code
		if c.Writer.Status() >= 500 {
			gin.DefaultWriter.Write([]byte("ERROR: " + formatLogData(logData) + "\n"))
		} else if c.Writer.Status() >= 400 {
			gin.DefaultWriter.Write([]byte("WARN: " + formatLogData(logData) + "\n"))
		} else {
			gin.DefaultWriter.Write([]byte("INFO: " + formatLogData(logData) + "\n"))
		}
	}
}

// bodyLogWriter wraps gin.ResponseWriter to capture response body
type bodyLogWriter struct {
	gin.ResponseWriter
	body *bytes.Buffer
}

func (w bodyLogWriter) Write(b []byte) (int, error) {
	w.body.Write(b)
	return w.ResponseWriter.Write(b)
}

// isSensitiveEndpoint checks if an endpoint contains sensitive data
func isSensitiveEndpoint(path string) bool {
	sensitivePatterns := []string{
		"/auth/login",
		"/auth/register",
		"/auth/refresh",
		"/users/password",
		"/users/profile",
	}
	
	for _, pattern := range sensitivePatterns {
		if len(path) >= len(pattern) && path[:len(pattern)] == pattern {
			return true
		}
	}
	
	return false
}

// formatLogData converts log data to a readable string format
func formatLogData(data map[string]interface{}) string {
	result := ""
	for key, value := range data {
		if result != "" {
			result += " "
		}
		result += key + "=" + toString(value)
	}
	return result
}

// toString converts interface{} to string
func toString(v interface{}) string {
	if v == nil {
		return "nil"
	}
	
	switch val := v.(type) {
	case string:
		return val
	case int:
		return string(rune(val))
	case bool:
		if val {
			return "true"
		}
		return "false"
	default:
		return "unknown"
	}
}
