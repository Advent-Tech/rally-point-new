# Rally Point Backend - Go Microservices Architecture

## 🏗️ Architecture Overview

This backend implements a scalable microservices architecture using Go, designed for lowest latency and high performance. Each service is containerized with its own Dockerfile and can be scaled independently.

### 🎯 Key Features
- **Clean Architecture** with Domain-Driven Design
- **Microservices** with independent scaling
- **PostgreSQL** for persistent data
- **Redis** for caching and real-time features
- **WebSocket** for real-time communication
- **gRPC** for inter-service communication
- **Docker Compose** for local development
- **Kubernetes** ready deployment

## 📊 Services Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    API Gateway (Port 8080)                  │
│                   Authentication & Routing                   │
└─────────────────────┬───────────────────────────────────────┘
                      │
        ┌─────────────┼─────────────┐
        │             │             │
┌───────▼──────┐ ┌────▼────┐ ┌─────▼──────┐
│ User Service │ │Location │ │Territory   │
│  (Port 8081) │ │Service  │ │Service     │
│              │ │(8082)   │ │(Port 8083) │
└──────────────┘ └─────────┘ └────────────┘
        │             │             │
┌───────▼──────┐ ┌────▼────┐ ┌─────▼──────┐
│Survey Service│ │Delivery │ │Walkie      │
│(Port 8084)   │ │Service  │ │Talkie      │
│              │ │(8085)   │ │(Port 8086) │
└──────────────┘ └─────────┘ └────────────┘
        │             │             │
        └─────────────┼─────────────┘
                      │
        ┌─────────────▼─────────────┐
        │     Shared Infrastructure │
        │ PostgreSQL + Redis + NATS │
        └───────────────────────────┘
```

## 🚀 Services

### 1. **API Gateway** (Port 8080)
- JWT Authentication
- Rate Limiting
- Request Routing
- Load Balancing
- CORS Handling

### 2. **User Service** (Port 8081)
- User Authentication & Authorization
- Profile Management
- Team Management
- Role-based Access Control

### 3. **Location Service** (Port 8082)
- Real-time Location Tracking
- GPS Coordinate Processing
- Location History
- Geofencing

### 4. **Territory Service** (Port 8083)
- Territory Management
- Boundary Definitions
- Territory Assignment
- Entry/Exit Tracking

### 5. **Survey Service** (Port 8084)
- Survey Creation & Management
- Response Collection
- Analytics & Reporting
- Assignment Tracking

### 6. **Delivery Service** (Port 8085)
- Delivery Tracking
- Status Management
- Route Optimization
- Performance Analytics

### 7. **Walkie Talkie Service** (Port 8086)
- Real-time Voice Communication
- WebSocket Connections
- Audio File Management
- Session Management

## 🔧 Technology Stack

- **Language**: Go 1.21+
- **Database**: PostgreSQL 15
- **Cache**: Redis 7
- **Message Queue**: NATS
- **API**: REST + gRPC + WebSocket
- **Authentication**: JWT
- **Containerization**: Docker
- **Orchestration**: Docker Compose / Kubernetes

## 📁 Project Structure

```
rally_backend/
├── api-gateway/          # API Gateway service
├── user-service/         # User management
├── location-service/     # Real-time location tracking
├── territory-service/    # Territory management
├── survey-service/       # Survey management
├── delivery-service/     # Delivery tracking
├── walkie-service/       # Walkie talkie communication
├── shared/              # Shared libraries and utilities
│   ├── auth/           # JWT authentication
│   ├── database/       # Database connections
│   ├── redis/          # Redis client
│   ├── grpc/           # gRPC clients
│   └── utils/          # Common utilities
├── docker-compose.yml   # Local development setup
├── docker-compose.prod.yml # Production setup
└── k8s/                # Kubernetes manifests
```

## 🚀 Quick Start

### Prerequisites
- Docker & Docker Compose
- Go 1.21+ (for development)
- PostgreSQL (for production)

### 1. Clone and Setup
```bash
cd /Users/winnie/Downloads/Rally-Point-App-master/rally_backend
```

### 2. Start Infrastructure
```bash
docker-compose up -d postgres redis nats
```

### 3. Run Services
```bash
# Start all services
docker-compose up

# Or start individual services
docker-compose up api-gateway user-service location-service
```

### 4. API Endpoints
- **API Gateway**: http://localhost:8080
- **User Service**: http://localhost:8081
- **Location Service**: http://localhost:8082
- **Territory Service**: http://localhost:8083
- **Survey Service**: http://localhost:8084
- **Delivery Service**: http://localhost:8085
- **Walkie Service**: http://localhost:8086

## 🔐 Authentication Flow

1. **Login**: POST `/api/auth/login`
2. **Get JWT Token**: Response includes access token
3. **Use Token**: Include in `Authorization: Bearer <token>` header
4. **Refresh**: POST `/api/auth/refresh`

## 📡 Real-time Features

### WebSocket Endpoints
- **Location Updates**: `ws://localhost:8082/ws/location`
- **Walkie Talkie**: `ws://localhost:8086/ws/walkie`
- **Territory Alerts**: `ws://localhost:8083/ws/alerts`

### Real-time Events
- Live location tracking (1-second updates)
- Territory entry/exit notifications
- Voice communication
- Delivery status updates

## 🎯 Performance Optimizations

1. **Database Indexing**: Optimized for location queries
2. **Redis Caching**: Frequently accessed data
3. **Connection Pooling**: Efficient database connections
4. **Horizontal Scaling**: Independent service scaling
5. **Load Balancing**: Request distribution
6. **Compression**: gRPC and HTTP compression

## 📊 Monitoring & Observability

- **Health Checks**: `/health` endpoint on each service
- **Metrics**: Prometheus metrics
- **Logging**: Structured JSON logging
- **Tracing**: Distributed tracing support

## 🔧 Development

### Running Locally
```bash
# Start infrastructure
docker-compose up -d postgres redis nats

# Run a service locally
cd user-service
go run cmd/main.go
```

### Testing
```bash
# Run tests for all services
make test

# Run tests for specific service
cd user-service && go test ./...
```

### Database Migrations
```bash
# Run migrations
make migrate-up

# Rollback migrations
make migrate-down
```

## 🚀 Deployment

### Docker Compose (Production)
```bash
docker-compose -f docker-compose.prod.yml up -d
```

### Kubernetes
```bash
kubectl apply -f k8s/
```

## 📈 Scaling

Each service can be scaled independently:

```bash
# Scale location service to 3 replicas
docker-compose up -d --scale location-service=3

# Kubernetes scaling
kubectl scale deployment location-service --replicas=3
```

## 🔒 Security Features

- JWT Authentication with refresh tokens
- Role-based access control (RBAC)
- API rate limiting
- Input validation and sanitization
- HTTPS/TLS encryption
- Database connection encryption

## 📝 API Documentation

API documentation is available at:
- **Swagger UI**: http://localhost:8080/swagger/
- **Postman Collection**: `docs/postman/`

## 🤝 Contributing

1. Follow Go coding standards
2. Write tests for new features
3. Update documentation
4. Use conventional commits
5. Ensure all services pass health checks

## 📞 Support

For issues and questions:
- Create GitHub issues
- Check documentation
- Review service logs: `docker-compose logs <service-name>`
