# Build stage
FROM golang:1.23-alpine AS builder

# Install build dependencies (including gcc for CGO/SQLite)
RUN apk add --no-cache git gcc musl-dev

# Set working directory
WORKDIR /app

# Copy shared module first
COPY shared/ ./shared/

# Copy service go mod files
COPY territory-service/go.mod territory-service/go.sum ./territory-service/
WORKDIR /app/territory-service

# Download dependencies
RUN go mod download

# Copy service source code
COPY territory-service/ .

# Build the application with CGO enabled for SQLite support
RUN CGO_ENABLED=1 GOOS=linux go build -a -installsuffix cgo -o main cmd/main.go

# Final stage
FROM alpine:latest

# Install ca-certificates for HTTPS requests
RUN apk --no-cache add ca-certificates wget

# Create app directory
WORKDIR /root/

# Copy binary from builder stage
COPY --from=builder /app/territory-service/main .

# Expose port
EXPOSE 8083

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:8083/health || exit 1

# Run the application
CMD ["./main"]
