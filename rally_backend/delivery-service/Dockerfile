# Build stage
FROM golang:1.23-alpine AS builder

# Install build dependencies
RUN apk add --no-cache git

# Set working directory
WORKDIR /app

# Copy shared module first
COPY shared/ ./shared/

# Copy service go mod files
COPY delivery-service/go.mod delivery-service/go.sum ./delivery-service/
WORKDIR /app/delivery-service

# Download dependencies
RUN go mod download

# Copy service source code
COPY delivery-service/ .

# Build the application
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o main cmd/main.go

# Final stage
FROM alpine:latest

# Install ca-certificates for HTTPS requests
RUN apk --no-cache add ca-certificates wget

# Create app directory
WORKDIR /root/

# Copy binary from builder stage
COPY --from=builder /app/delivery-service/main .

# Expose port
EXPOSE 8085

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:8085/health || exit 1

# Run the application
CMD ["./main"]
