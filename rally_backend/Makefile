# Rally Point Backend Makefile

# Load environment variables from .env file if it exists
-include .env
export

.PHONY: help build run test clean docker-build docker-run docker-stop migrate-up migrate-down

# Default target
help: ## Show this help message
	@echo "Rally Point Backend - Available Commands:"
	@echo ""
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

# Development
build: ## Build all services
	@echo "🔨 Building all services..."
	@cd user-service && go build -o bin/user-service cmd/main.go
	@cd location-service && go build -o bin/location-service cmd/main.go
	@cd territory-service && go build -o bin/territory-service cmd/main.go
	@cd survey-service && go build -o bin/survey-service cmd/main.go
	@cd delivery-service && go build -o bin/delivery-service cmd/main.go
	@cd walkie-service && go build -o bin/walkie-service cmd/main.go
	@cd ministry-service && go build -o bin/ministry-service cmd/main.go
	@cd api-gateway && go build -o bin/api-gateway cmd/main.go
	@echo "✅ All services built successfully"

run: ## Run all services locally
	@echo "🚀 Starting all services..."
	@docker-compose --env-file .env up -d postgres redis nats
	@sleep 5
	@cd user-service && go run cmd/main.go &
	@cd location-service && go run cmd/main.go &
	@cd territory-service && go run cmd/main.go &
	@cd survey-service && go run cmd/main.go &
	@cd delivery-service && go run cmd/main.go &
	@cd walkie-service && go run cmd/main.go &
	@cd ministry-service && go run cmd/main.go &
	@cd api-gateway && go run cmd/main.go &
	@echo "✅ All services started"

test: ## Run tests for all services
	@echo "🧪 Running tests..."
	@cd user-service && go test ./...
	@cd location-service && go test ./...
	@cd territory-service && go test ./...
	@cd survey-service && go test ./...
	@cd delivery-service && go test ./...
	@cd walkie-service && go test ./...
	@cd ministry-service && go test ./...
	@cd api-gateway && go test ./...
	@echo "✅ All tests passed"

clean: ## Clean build artifacts
	@echo "🧹 Cleaning build artifacts..."
	@find . -name "bin" -type d -exec rm -rf {} +
	@find . -name "*.log" -delete
	@echo "✅ Clean complete"

# Docker
docker-build: ## Build all Docker images
	@echo "🐳 Building Docker images..."
	@docker-compose --env-file .env build
	@echo "✅ Docker images built"

# Start infrastructure services first (postgres, redis, nats) with health checks
docker-run-infra: ## Start only infrastructure services
	@echo "🚀 Starting infrastructure services (Postgres, Redis, NATS)..."
	@docker-compose --env-file .env up -d postgres redis nats
	@echo "⏳ Waiting for services to be ready..."
	@until docker compose --env-file .env exec -T postgres pg_isready -U rally_user -d rally_point >/dev/null 2>&1; do \
		echo "  ⌛ Waiting for PostgreSQL to be ready..."; \
		sleep 5; \
	done
	@echo "✅ PostgreSQL is ready"
	@until docker compose --env-file .env exec -T redis redis-cli ping | grep -q PONG; do \
		echo "  ⌛ Waiting for Redis to be ready..."; \
		sleep 2; \
	done
	@echo "✅ Redis is ready"
	@echo "✅ All infrastructure services are ready"

# Start all services with proper dependency handling
docker-run: docker-run-infra ## Run all services with proper dependency handling
	@echo "🚀 Starting all application services..."
	@docker-compose --env-file .env up -d --no-deps --build \
		user-service location-service territory-service \
		survey-service delivery-service walkie-service ministry-service api-gateway
	@echo "✅ All application services started"

# Start all services with auto-restart on failure
docker-run-with-restart: docker-run-infra
	@echo "� Starting services with auto-restart..."
	@docker-compose --env-file .env up -d --no-deps --build \
		--exit-code-from=user-service user-service
	@docker-compose --env-file .env up -d --no-deps --build \
		--exit-code-from=location-service location-service
	@docker-compose --env-file .env up -d --no-deps --build \
		--exit-code-from=territory-service territory-service
	@docker-compose --env-file .env up -d --no-deps --build \
		--exit-code-from=survey-service survey-service
	@docker-compose --env-file .env up -d --no-deps --build \
		--exit-code-from=delivery-service delivery-service
	@docker-compose --env-file .env up -d --no-deps --build \
		--exit-code-from=walkie-service walkie-service
	@docker-compose --env-file .env up -d --no-deps --build \
		--exit-code-from=ministry-service ministry-service
	@docker-compose --env-file .env up -d --no-deps --build \
		--exit-code-from=api-gateway api-gateway
	@echo "✅ All services started with auto-restart"

# View logs for a specific service (e.g., make logs-service service=user-service)
logs-service: ## View logs for a specific service
	@if [ -z "$(service)" ]; then \
		echo "Error: Please specify a service name (e.g., make logs-service service=user-service)"; \
		echo "Available services: user-service location-service territory-service survey-service delivery-service walkie-service ministry-service api-gateway"; \
		exit 1; \
	fi
	@docker-compose --env-file .env logs -f $(service)

docker-logs: ## View logs from all services
	@docker-compose --env-file .env logs -f

docker-stop: ## Stop all Docker services
	@echo "🛑 Stopping Docker services..."
	@docker-compose --env-file .env down
	@echo "✅ All services stopped"

docker-restart: docker-stop docker-run ## Restart all services
	@echo "🔄 All services restarted"

# Check service status
docker-ps: ## Show running containers
	@docker-compose --env-file .env ps

# View logs for all services
docker-logs-all: ## View logs for all services
	@docker-compose --env-file .env logs -f

# View logs for a specific service
docker-logs-service: ## View logs for a specific service (e.g., make docker-logs-service service=user-service)
	@if [ -z "$(service)" ]; then \
		echo "Error: Please specify a service name (e.g., make docker-logs-service service=user-service)"; \
		echo "Available services: user-service location-service territory-service survey-service delivery-service walkie-service api-gateway"; \
		exit 1; \
	fi
	@docker-compose --env-file .env logs -f $(service)

# Database
migrate-up: ## Run database migrations
	@echo "📊 Running database migrations..."
	@docker-compose --env-file .env exec postgres psql -U $(DB_USER) -d $(DB_NAME) -f /docker-entrypoint-initdb.d/001_initial_schema.sql
	@docker-compose --env-file .env exec postgres psql -U $(DB_USER) -d $(DB_NAME) -f /docker-entrypoint-initdb.d/002_add_indexes.sql || true
	@docker-compose --env-file .env exec postgres psql -U $(DB_USER) -d $(DB_NAME) -f /docker-entrypoint-initdb.d/002_schema_updates.sql || true
	@docker-compose --env-file .env exec postgres psql -U $(DB_USER) -d $(DB_NAME) -f /docker-entrypoint-initdb.d/003_territories_table.sql || true
	@docker-compose --env-file .env exec postgres psql -U $(DB_USER) -d $(DB_NAME) -f /docker-entrypoint-initdb.d/004_territory_assignments.sql || true
	@docker-compose --env-file .env exec postgres psql -U $(DB_USER) -d $(DB_NAME) -f /docker-entrypoint-initdb.d/005_custom_territories.sql || true
	@docker-compose --env-file .env exec postgres psql -U $(DB_USER) -d $(DB_NAME) -f /docker-entrypoint-initdb.d/006_territory_work_sessions.sql || true
	@docker-compose --env-file .env exec postgres psql -U $(DB_USER) -d $(DB_NAME) -f /docker-entrypoint-initdb.d/007_visit_records.sql || true
	@docker-compose --env-file .env exec postgres psql -U $(DB_USER) -d $(DB_NAME) -f /docker-entrypoint-initdb.d/008_receipts_donations.sql || true
	@docker-compose --env-file .env exec postgres psql -U $(DB_USER) -d $(DB_NAME) -f /docker-entrypoint-initdb.d/009_delivery_territory_context.sql || true
	@docker-compose --env-file .env exec postgres psql -U $(DB_USER) -d $(DB_NAME) -f /docker-entrypoint-initdb.d/010_work_schedules.sql || true
	@docker-compose --env-file .env exec postgres psql -U $(DB_USER) -d $(DB_NAME) -f /docker-entrypoint-initdb.d/011_delivery_schema_update.sql || true
	@docker-compose --env-file .env exec postgres psql -U $(DB_USER) -d $(DB_NAME) -f /docker-entrypoint-initdb.d/012_chat_tables.sql || true
	@docker-compose --env-file .env exec postgres psql -U $(DB_USER) -d $(DB_NAME) -f /docker-entrypoint-initdb.d/016_multi_role_system.sql || true
	@docker-compose --env-file .env exec postgres psql -U $(DB_USER) -d $(DB_NAME) -f /docker-entrypoint-initdb.d/017_legacy_data_reconciliation.sql || true
	@docker-compose --env-file .env exec postgres psql -U $(DB_USER) -d $(DB_NAME) -f /docker-entrypoint-initdb.d/018_survey_optional_team.sql || true
	@docker-compose --env-file .env exec postgres psql -U $(DB_USER) -d $(DB_NAME) -f /docker-entrypoint-initdb.d/019_blogs_table.sql || true
	@docker-compose --env-file .env exec postgres psql -U $(DB_USER) -d $(DB_NAME) -f /docker-entrypoint-initdb.d/020_prayer_requests.sql || true
	@docker-compose --env-file .env exec postgres psql -U $(DB_USER) -d $(DB_NAME) -f /docker-entrypoint-initdb.d/021_survey_multi_team.sql || true
	@echo "✅ Migrations completed"

migrate-assignments: ## Run territory assignments migration only
	@echo "📊 Running territory assignments migration..."
	@docker-compose --env-file .env exec postgres psql -U $(DB_USER) -d $(DB_NAME) -f /docker-entrypoint-initdb.d/004_territory_assignments.sql
	@docker-compose --env-file .env exec postgres psql -U $(DB_USER) -d $(DB_NAME) -f /docker-entrypoint-initdb.d/005_custom_territories.sql
	@echo "✅ Territory migrations completed"

migrate-down: ## Rollback database migrations (WARNING: This will drop all tables)
	@echo "⚠️  Rolling back database migrations..."
	@read -p "Are you sure you want to drop all tables? [y/N] " -n 1 -r; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		docker-compose --env-file .env exec postgres psql -U $(DB_USER) -d $(DB_NAME) -c "DROP SCHEMA public CASCADE; CREATE SCHEMA public;"; \
		echo "✅ Database reset completed"; \
	else \
		echo "❌ Migration rollback cancelled"; \
	fi

db-shell: ## Connect to database shell
	@docker-compose --env-file .env exec postgres psql -U $(DB_USER) -d $(DB_NAME)

# Geo Data Management
geo-check: ## Check if geo territories data exists
	@echo "🗺️  Checking geo territories data..."
	@docker-compose --env-file .env exec postgres psql -U $(DB_USER) -d $(DB_NAME) -c \
		"SELECT COUNT(*) as territory_count, COUNT(DISTINCT union_name) as unions FROM territories WHERE geom IS NOT NULL;" \
		2>/dev/null || echo "No geo data found"

geo-import: ## Import all GeoPackage files from ../Geopackage folder
	@echo "🗺️  Importing GeoPackage files..."
	@echo "⚠️  Note: This requires the territory-service to be running"
	@echo "   GeoPackage folder is mounted at /geopackage in containers"
	@for file in ../Geopackage/*.gpkg; do \
		if [ -f "$$file" ]; then \
			filename=$$(basename "$$file"); \
			echo "  📦 Importing $$filename..."; \
			curl -s -X POST http://localhost:8083/api/geo/import \
				-H "Content-Type: application/json" \
				-d "{\"file_path\": \"/geopackage/$$filename\"}" || echo "  ❌ Failed to import $$filename"; \
		fi; \
	done
	@echo "✅ GeoPackage import triggered"
	@echo "   Check progress at: GET http://localhost:8083/api/geo/import/{filename}"

geo-import-check: ## Check import progress
	@echo "📊 Checking import progress..."
	@for file in ../Geopackage/*.gpkg; do \
		if [ -f "$$file" ]; then \
			filename=$$(basename "$$file"); \
			echo "  📦 $$filename:"; \
			curl -s http://localhost:8083/api/geo/import/$$filename 2>/dev/null | head -1 || echo "  No progress info"; \
		fi; \
	done

geo-stats: ## Show geo territory statistics
	@echo "📊 Geo Territory Statistics:"
	@docker-compose --env-file .env exec postgres psql -U $(DB_USER) -d $(DB_NAME) -c \
		"SELECT union_name, COUNT(*) as territories, SUM(COALESCE(housing_units, 0)) as total_households FROM territories WHERE geom IS NOT NULL GROUP BY union_name ORDER BY union_name;"

# Development helpers
dev-setup: ## Setup development environment
	@echo "🛠️  Setting up development environment..."
	@docker-compose --env-file .env up -d postgres redis nats
	@sleep 10
	@make migrate-up
	@echo "✅ Development environment ready"

dev-reset: ## Reset development environment
	@echo "🔄 Resetting development environment..."
	@docker-compose --env-file .env down -v
	@docker-compose --env-file .env up -d postgres redis nats
	@sleep 10
	@make migrate-up
	@echo "✅ Development environment reset"

# Fresh Deployment (for new environments)
fresh-deploy: ## Complete setup for fresh deployment (new database)
	@echo "🚀 Starting fresh deployment..."
	@echo ""
	@echo "Step 1: Starting infrastructure..."
	@docker-compose --env-file .env up -d postgres redis nats
	@echo ""
	@echo "Step 2: Waiting for PostgreSQL to initialize (runs migrations automatically)..."
	@echo "   This may take a minute on first boot as migrations are applied..."
	@sleep 10
	@until docker-compose --env-file .env exec -T postgres pg_isready -U $(DB_USER) -d $(DB_NAME) >/dev/null 2>&1; do \
		echo "  ⌛ Waiting for PostgreSQL to be ready..."; \
		sleep 5; \
	done
	@echo "  ✅ PostgreSQL is ready"
	@echo ""
	@echo "Step 3: Verifying database tables..."
	@until docker-compose --env-file .env exec -T postgres psql -U $(DB_USER) -d $(DB_NAME) -c "SELECT 1 FROM users LIMIT 1;" >/dev/null 2>&1; do \
		echo "  ⌛ Waiting for migrations to complete..."; \
		sleep 5; \
	done
	@echo "  ✅ Database tables ready"
	@echo ""
	@echo "Step 4: Starting application services..."
	@docker-compose --env-file .env up -d --no-deps --build \
		user-service location-service territory-service \
		survey-service delivery-service walkie-service ministry-service api-gateway
	@echo ""
	@echo "Step 5: Waiting for services to start..."
	@sleep 15
	@echo ""
	@echo "Step 6: Checking geo data..."
	@GEO_COUNT=$$(docker-compose --env-file .env exec -T postgres psql -U $(DB_USER) -d $(DB_NAME) -t -c \
		"SELECT COUNT(*) FROM territories WHERE geom IS NOT NULL;" 2>/dev/null | tr -d ' '); \
	if [ "$$GEO_COUNT" = "0" ] || [ -z "$$GEO_COUNT" ]; then \
		echo "  ⚠️  No geo data found. Importing GeoPackage files..."; \
		make geo-import; \
	else \
		echo "  ✅ Geo data already exists ($$GEO_COUNT territories)"; \
	fi
	@echo ""
	@echo "✅ Fresh deployment complete!"
	@echo ""
	@echo "📋 Summary:"
	@echo "   - API Gateway: http://localhost:8080"
	@echo "   - Migrations: Applied automatically by PostgreSQL"
	@echo "   - Geo Data: Imported (if GeoPackage files exist)"
	@echo ""
	@echo "🔍 Useful commands:"
	@echo "   make health-check  - Check service health"
	@echo "   make geo-stats     - View geo territory stats"
	@echo "   make docker-logs   - View service logs"

fresh-deploy-no-geo: ## Fresh deployment without geo data import
	@echo "🚀 Starting fresh deployment (no geo import)..."
	@docker-compose --env-file .env up -d postgres redis nats
	@sleep 10
	@until docker-compose --env-file .env exec -T postgres pg_isready -U $(DB_USER) -d $(DB_NAME) >/dev/null 2>&1; do \
		echo "  ⌛ Waiting for PostgreSQL..."; \
		sleep 5; \
	done
	@until docker-compose --env-file .env exec -T postgres psql -U $(DB_USER) -d $(DB_NAME) -c "SELECT 1 FROM users LIMIT 1;" >/dev/null 2>&1; do \
		echo "  ⌛ Waiting for migrations..."; \
		sleep 5; \
	done
	@docker-compose --env-file .env up -d --no-deps --build \
		user-service location-service territory-service \
		survey-service delivery-service walkie-service ministry-service api-gateway
	@echo "✅ Fresh deployment complete (without geo data)"

# Database Status
db-status: ## Show database table counts and status
	@echo "📊 Database Status:"
	@docker-compose --env-file .env exec postgres psql -U $(DB_USER) -d $(DB_NAME) -c \
		"SELECT 'users' as table_name, COUNT(*) as count FROM users UNION ALL \
		 SELECT 'teams', COUNT(*) FROM teams UNION ALL \
		 SELECT 'territories (geo)', COUNT(*) FROM territories WHERE geom IS NOT NULL UNION ALL \
		 SELECT 'territory_assignments', COUNT(*) FROM territory_assignments UNION ALL \
		 SELECT 'deliveries', COUNT(*) FROM deliveries UNION ALL \
		 SELECT 'surveys', COUNT(*) FROM surveys UNION ALL \
		 SELECT 'households', COUNT(*) FROM households ORDER BY table_name;" 2>/dev/null || echo "Some tables may not exist yet"

# Monitoring
health-check: ## Check health of all services
	@echo "🏥 Checking service health..."
	@curl -s http://localhost:8080/health || echo "❌ API Gateway down"
	@curl -s http://localhost:8081/health || echo "❌ User Service down"
	@curl -s http://localhost:8082/health || echo "❌ Location Service down"
	@curl -s http://localhost:8083/health || echo "❌ Territory Service down"
	@curl -s http://localhost:8084/health || echo "❌ Survey Service down"
	@curl -s http://localhost:8085/health || echo "❌ Delivery Service down"
	@curl -s http://localhost:8086/health || echo "❌ Walkie Service down"
	@curl -s http://localhost:8087/health || echo "❌ Ministry Service down"
	@echo "✅ Health check completed"

logs: ## View logs from all services
	@echo "📋 Viewing service logs..."
	@docker-compose logs -f --tail=100

# Production
prod-build: ## Build production Docker images
	@echo "🏭 Building production images..."
	@docker-compose -f docker-compose.prod.yml build
	@echo "✅ Production images built"

prod-deploy: ## Deploy to production
	@echo "🚀 Deploying to production..."
	@docker-compose -f docker-compose.prod.yml up -d
	@echo "✅ Production deployment completed"

# Utilities
format: ## Format Go code
	@echo "💅 Formatting Go code..."
	@find . -name "*.go" -not -path "./vendor/*" | xargs gofmt -w
	@echo "✅ Code formatted"

lint: ## Run linters
	@echo "🔍 Running linters..."
	@golangci-lint run ./...
	@echo "✅ Linting completed"

deps: ## Download dependencies
	@echo "📦 Downloading dependencies..."
	@cd user-service && go mod download
	@cd location-service && go mod download
	@cd territory-service && go mod download
	@cd survey-service && go mod download
	@cd delivery-service && go mod download
	@cd walkie-service && go mod download
	@cd ministry-service && go mod download
	@cd api-gateway && go mod download
	@echo "✅ Dependencies downloaded"

# API Testing
test-api: ## Test API endpoints
	@echo "🧪 Testing API endpoints..."
	@curl -X POST http://localhost:8080/api/auth/register \
		-H "Content-Type: application/json" \
		-d '{"email":"test@example.com","password":"password123","display_name":"Test User"}' || true
	@curl -X POST http://localhost:8080/api/auth/login \
		-H "Content-Type: application/json" \
		-d '{"email":"test@example.com","password":"password123"}' || true
	@echo "✅ API testing completed"

# Documentation
docs: ## Generate API documentation
	@echo "📚 Generating API documentation..."
	@swag init -g api-gateway/cmd/main.go -o api-gateway/docs
	@echo "✅ Documentation generated"

# Environment

# Environment
env-example: ## Create example environment file
	@echo "📝 Creating .env.example..."
	@echo "# Database Configuration" > .env.example
	@echo "DB_HOST=localhost" >> .env.example
	@echo "DB_PORT=5432" >> .env.example
	@echo "DB_USER=rally_user" >> .env.example
	@echo "DB_PASSWORD=rally_password" >> .env.example
	@echo "DB_NAME=rally_point" >> .env.example
	@echo "DB_SSL_MODE=disable" >> .env.example
	@echo "" >> .env.example
	@echo "# JWT Configuration" >> .env.example
	@echo "JWT_SECRET=your-super-secret-jwt-key-change-in-production" >> .env.example
	@echo "" >> .env.example
	@echo "# Redis Configuration" >> .env.example
	@echo "REDIS_URL=localhost:6379" >> .env.example
	@echo "" >> .env.example
	@echo "# NATS Configuration" >> .env.example
	@echo "NATS_URL=localhost:4222" >> .env.example
	@echo "" >> .env.example
	@echo "# Service Ports" >> .env.example
	@echo "API_GATEWAY_PORT=8080" >> .env.example
	@echo "USER_SERVICE_PORT=8081" >> .env.example
	@echo "LOCATION_SERVICE_PORT=8082" >> .env.example
	@echo "TERRITORY_SERVICE_PORT=8083" >> .env.example
	@echo "SURVEY_SERVICE_PORT=8084" >> .env.example
	@echo "DELIVERY_SERVICE_PORT=8085" >> .env.example
	@echo "WALKIE_SERVICE_PORT=8086" >> .env.example
	@echo "MINISTRY_SERVICE_PORT=8087" >> .env.example
	@echo "" >> .env.example
	@echo "# Environment" >> .env.example
	@echo "GIN_MODE=debug" >> .env.example
	@echo "✅ .env.example created"
