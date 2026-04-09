package utils

import (
	"fmt"
	"log"
	"os"
	"runtime"
	"strings"
	"time"
)

// LogLevel represents the severity level of a log message
type LogLevel int

const (
	DEBUG LogLevel = iota
	INFO
	WARN
	ERROR
	FATAL
)

// String returns the string representation of LogLevel
func (l LogLevel) String() string {
	switch l {
	case DEBUG:
		return "DEBUG"
	case INFO:
		return "INFO"
	case WARN:
		return "WARN"
	case ERROR:
		return "ERROR"
	case FATAL:
		return "FATAL"
	default:
		return "UNKNOWN"
	}
}

// Logger represents a custom logger
type Logger struct {
	level  LogLevel
	logger *log.Logger
}

// NewLogger creates a new logger instance
func NewLogger(level LogLevel) *Logger {
	return &Logger{
		level:  level,
		logger: log.New(os.Stdout, "", 0),
	}
}

// SetLevel sets the minimum log level
func (l *Logger) SetLevel(level LogLevel) {
	l.level = level
}

// log writes a log message with the specified level
func (l *Logger) log(level LogLevel, message string, args ...interface{}) {
	if level < l.level {
		return
	}

	timestamp := time.Now().Format("2006-01-02 15:04:05")
	
	// Get caller information
	_, file, line, ok := runtime.Caller(2)
	caller := "unknown"
	if ok {
		// Extract just the filename from the full path
		parts := strings.Split(file, "/")
		if len(parts) > 0 {
			caller = fmt.Sprintf("%s:%d", parts[len(parts)-1], line)
		}
	}

	// Format message
	formattedMessage := fmt.Sprintf(message, args...)
	
	// Create log entry
	logEntry := fmt.Sprintf("[%s] %s %s - %s", 
		timestamp, level.String(), caller, formattedMessage)
	
	l.logger.Println(logEntry)
	
	// Exit on fatal errors
	if level == FATAL {
		os.Exit(1)
	}
}

// Debug logs a debug message
func (l *Logger) Debug(message string, args ...interface{}) {
	l.log(DEBUG, message, args...)
}

// Info logs an info message
func (l *Logger) Info(message string, args ...interface{}) {
	l.log(INFO, message, args...)
}

// Warn logs a warning message
func (l *Logger) Warn(message string, args ...interface{}) {
	l.log(WARN, message, args...)
}

// Error logs an error message
func (l *Logger) Error(message string, args ...interface{}) {
	l.log(ERROR, message, args...)
}

// Fatal logs a fatal message and exits
func (l *Logger) Fatal(message string, args ...interface{}) {
	l.log(FATAL, message, args...)
}

// Global logger instance
var defaultLogger = NewLogger(INFO)

// SetGlobalLogLevel sets the global log level
func SetGlobalLogLevel(level LogLevel) {
	defaultLogger.SetLevel(level)
}

// Debug logs a debug message using the global logger
func Debug(message string, args ...interface{}) {
	defaultLogger.Debug(message, args...)
}

// Info logs an info message using the global logger
func Info(message string, args ...interface{}) {
	defaultLogger.Info(message, args...)
}

// Warn logs a warning message using the global logger
func Warn(message string, args ...interface{}) {
	defaultLogger.Warn(message, args...)
}

// Error logs an error message using the global logger
func Error(message string, args ...interface{}) {
	defaultLogger.Error(message, args...)
}

// Fatal logs a fatal message and exits using the global logger
func Fatal(message string, args ...interface{}) {
	defaultLogger.Fatal(message, args...)
}

// LogRequest logs HTTP request information
func LogRequest(method, path, userID string, duration time.Duration, statusCode int) {
	Info("HTTP %s %s - User: %s - Status: %d - Duration: %v", 
		method, path, MaskSensitiveData(userID), statusCode, duration)
}

// LogError logs error with context
func LogError(err error, context string, args ...interface{}) {
	if err != nil {
		contextMessage := fmt.Sprintf(context, args...)
		Error("%s: %v", contextMessage, err)
	}
}

// LogPanic logs panic recovery
func LogPanic(recovered interface{}) {
	Error("Panic recovered: %v", recovered)
	
	// Print stack trace
	buf := make([]byte, 1024)
	for {
		n := runtime.Stack(buf, false)
		if n < len(buf) {
			Error("Stack trace:\n%s", string(buf[:n]))
			break
		}
		buf = make([]byte, 2*len(buf))
	}
}

// InitializeLogger initializes logger based on environment
func InitializeLogger() {
	env := os.Getenv("GO_ENV")
	
	switch env {
	case "development", "dev":
		SetGlobalLogLevel(DEBUG)
		Info("Logger initialized in development mode")
	case "production", "prod":
		SetGlobalLogLevel(INFO)
		Info("Logger initialized in production mode")
	case "test":
		SetGlobalLogLevel(WARN)
	default:
		SetGlobalLogLevel(INFO)
		Info("Logger initialized with default settings")
	}
}
