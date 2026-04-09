# Scalability Implementation Plan — Rally Point

## Context

Rally Point currently runs all 8 microservices + PostgreSQL + Redis + NATS on a single EC2 instance via Docker Compose. Analysis shows this handles ~200-500 concurrent users. The goal is to scale toward 10,000 concurrent users. This plan lists every task in priority order — each task is independent and can be deployed on its own. We go one by one so nothing gets confusing.

**Current bottlenecks identified:**
1. Location writes: Every 30s sync from every user → single-row INSERT + full session re-read (N+1)
2. Synchronous geofence HTTP call blocks every location update (5s timeout)
3. Connection pool hardcoded at 25/service, no PostgreSQL server tuning
4. In-memory WebSocket hub can't scale beyond one gateway instance
5. All users sync at exactly 30-second intervals (thundering herd)
6. `UpdateWorkerLocation()` is a NO-OP — no Redis caching for real-time data

---

## Task 1: PostgreSQL Server Tuning

**Why:** PostgreSQL runs with default Alpine config — designed for a laptop, not a server. Tuning shared_buffers, work_mem, and checkpoint settings alone can 2-3x throughput on the same hardware.

**File:** `rally_backend/docker-compose.yml`

**How to do it:**

Add a `command` section to the postgres service that passes tuning flags. These override postgresql.conf defaults without needing a custom config file.

```yaml
postgres:
  image: postgis/postgis:15-3.4-alpine
  container_name: rally_postgres
  command:
    - "postgres"
    - "-c"
    - "shared_buffers=512MB"          # Default is 128MB. Use ~25% of container RAM
    - "-c"
    - "effective_cache_size=1536MB"    # ~75% of container RAM (helps query planner)
    - "-c"
    - "work_mem=8MB"                   # Default 4MB. Per-sort/hash memory
    - "-c"
    - "maintenance_work_mem=128MB"     # For VACUUM, CREATE INDEX
    - "-c"
    - "wal_buffers=16MB"              # Write-ahead log buffer
    - "-c"
    - "max_connections=300"            # Default 100. We have 8 services × 25 = 200 potential
    - "-c"
    - "checkpoint_completion_target=0.9"  # Spread checkpoint writes (default 0.5)
    - "-c"
    - "random_page_cost=1.1"          # SSD storage (default 4.0 assumes spinning disk)
    - "-c"
    - "effective_io_concurrency=200"   # SSD can handle parallel reads
    - "-c"
    - "max_wal_size=1GB"              # Reduce checkpoint frequency
    - "-c"
    - "log_min_duration_statement=1000"  # Log queries taking >1 second
  environment:
    POSTGRES_DB: rally_point
    POSTGRES_USER: rally_user
    POSTGRES_PASSWORD: rally_password
  # ... rest stays the same
```

**What each setting does:**
| Setting | Default | New Value | Effect |
|---------|---------|-----------|--------|
| `shared_buffers` | 128MB | 512MB | More data cached in PostgreSQL memory |
| `effective_cache_size` | 4GB | 1536MB | Tells planner how much OS cache to expect |
| `work_mem` | 4MB | 8MB | Larger in-memory sorts/hashes before spilling to disk |
| `max_connections` | 100 | 300 | Room for 8 services × 25 connections + admin tools |
| `random_page_cost` | 4.0 | 1.1 | Planner prefers index scans (correct for SSD) |
| `checkpoint_completion_target` | 0.5 | 0.9 | Smoother write performance, fewer I/O spikes |
| `log_min_duration_statement` | off | 1000ms | Identify slow queries for future optimization |

**Verify:** `docker compose down && docker compose up -d`, then connect with `psql` and run `SHOW shared_buffers;` — should show `512MB`.

---

## Task 2: Configurable Connection Pool via Environment Variables

**Why:** The connection pool is hardcoded to 25 max / 5 idle across all 8 services. Different services have different load profiles — location-service needs more connections than walkie-service. Also, if we later upgrade EC2 or add DB replicas, we need to tune this without rebuilding images.

**File:** `rally_backend/shared/database/postgres.go`

**How to do it:**

Replace the hardcoded values with environment variable reads. Add a `PoolConfig` to the existing `Config` struct:

```go
// Add to Config struct:
type Config struct {
    Host         string
    Port         int
    User         string
    Password     string
    DBName       string
    SSLMode      string
    MaxOpenConns int  // NEW — default 25
    MaxIdleConns int  // NEW — default 10
    ConnMaxLifetimeSeconds int  // NEW — default 300
}
```

In `NewConnection()`, change lines 41-43 from:
```go
db.SetMaxOpenConns(25)
db.SetMaxIdleConns(5)
db.SetConnMaxLifetime(5 * time.Minute)
```
To:
```go
maxOpen := config.MaxOpenConns
if maxOpen <= 0 {
    maxOpen = 25
}
maxIdle := config.MaxIdleConns
if maxIdle <= 0 {
    maxIdle = 10  // Raise default from 5 to 10
}
connLifetime := config.ConnMaxLifetimeSeconds
if connLifetime <= 0 {
    connLifetime = 300
}
db.SetMaxOpenConns(maxOpen)
db.SetMaxIdleConns(maxIdle)
db.SetConnMaxLifetime(time.Duration(connLifetime) * time.Second)
```

Then in each service's `main.go` (or wherever `database.Config` is constructed), read from env:
```go
maxOpen, _ := strconv.Atoi(os.Getenv("DB_MAX_OPEN_CONNS"))
maxIdle, _ := strconv.Atoi(os.Getenv("DB_MAX_IDLE_CONNS"))
```

And in `docker-compose.yml`, set per-service:
```yaml
location-service:
  environment:
    - DB_MAX_OPEN_CONNS=40   # Highest traffic service
    - DB_MAX_IDLE_CONNS=15

territory-service:
  environment:
    - DB_MAX_OPEN_CONNS=30   # Geofence queries are heavy
    - DB_MAX_IDLE_CONNS=10

user-service:
  environment:
    - DB_MAX_OPEN_CONNS=20
    - DB_MAX_IDLE_CONNS=8
```

**Files to modify:**
- `rally_backend/shared/database/postgres.go` — add pool fields to Config, use them in NewConnection
- Each service's `main.go` or config loading — read `DB_MAX_OPEN_CONNS`, `DB_MAX_IDLE_CONNS` from env
- `rally_backend/docker-compose.yml` — add env vars per service

**Verify:** After restart, check PostgreSQL active connections: `SELECT count(*) FROM pg_stat_activity;` — should stay within limits.

---

## Task 3: Fix Session Update N+1 Problem (Incremental Distance)

**Why:** This is the single biggest performance bug. On every location update, `updateSessionWithNewLocation()` calls `GetTracksBySessionID()` which fetches ALL tracks for that session from the database, then recalculates the total distance from scratch. A worker active for 4 hours at 30s intervals = 480 tracks fetched on every single update. With 1,000 users, that's 480,000 rows read per sync cycle.

**File:** `rally_backend/location-service/internal/service/location_service.go`

**How to do it:**

Replace the "fetch all tracks, recalculate everything" approach with **incremental distance calculation**. We only need the previous track point to calculate the new segment distance, then add it to the running total.

**Step 1:** Add a method to the repository to get the last track before the current one:

**File:** `rally_backend/location-service/internal/repository/postgres/location_repository.go`

Add new method:
```go
// GetLastTrackForSession gets the most recent track for a session (before the given track)
func (r *locationRepository) GetLastTrackForSession(sessionID uuid.UUID, beforeTrackID uuid.UUID) (*domain.LocationTrack, error) {
    query := `
        SELECT id, user_id, latitude, longitude, accuracy, speed, heading, session_id, tracked_at, created_at
        FROM location_tracks
        WHERE session_id = $1 AND id != $2
        ORDER BY tracked_at DESC
        LIMIT 1
    `
    track := &domain.LocationTrack{}
    err := r.db.QueryRow(query, sessionID, beforeTrackID).Scan(
        &track.ID, &track.UserID, &track.Latitude, &track.Longitude,
        &track.Accuracy, &track.Speed, &track.Heading,
        &track.SessionID, &track.TrackedAt, &track.CreatedAt,
    )
    if err != nil {
        if err == sql.ErrNoRows {
            return nil, nil // First track in session
        }
        return nil, err
    }
    return track, nil
}
```

Add to `domain.LocationRepository` interface:
```go
GetLastTrackForSession(sessionID uuid.UUID, beforeTrackID uuid.UUID) (*domain.LocationTrack, error)
```

**Step 2:** Add an incremental session update method to the repository:

```go
// IncrementSessionDistance atomically adds distance and increments count
func (r *locationRepository) IncrementSessionDistance(sessionID uuid.UUID, addDistance float64) error {
    query := `
        UPDATE location_sessions
        SET total_distance = total_distance + $2,
            location_count = location_count + 1,
            updated_at = NOW()
        WHERE id = $1 AND is_active = true
    `
    _, err := r.db.Exec(query, sessionID, addDistance)
    return err
}
```

Add to `domain.LocationRepository` interface:
```go
IncrementSessionDistance(sessionID uuid.UUID, addDistance float64) error
```

**Step 3:** Replace `updateSessionWithNewLocation` in `location_service.go`:

Replace the entire method (lines 138-165) with:
```go
func (s *locationService) updateSessionWithNewLocation(sessionID uuid.UUID, newTrack *domain.LocationTrack) error {
    // Get only the previous track (1 row) instead of ALL tracks
    prevTrack, err := s.locationRepo.GetLastTrackForSession(sessionID, newTrack.ID)
    if err != nil {
        return fmt.Errorf("failed to get previous track: %w", err)
    }

    var segmentDistance float64
    if prevTrack != nil {
        segmentDistance = s.distanceCalc.CalculateDistance(
            prevTrack.Latitude, prevTrack.Longitude,
            newTrack.Latitude, newTrack.Longitude,
        )
        // Same sanity check: ignore jumps > 1km between 30s updates
        if segmentDistance > 1000 {
            segmentDistance = 0
        }
    }

    // Atomic increment — no race conditions, no full re-read
    return s.locationRepo.IncrementSessionDistance(sessionID, segmentDistance)
}
```

**Performance improvement:** From `SELECT * FROM location_tracks WHERE session_id = X` (480+ rows) to `SELECT ... LIMIT 1` (1 row) + `UPDATE ... SET total_distance = total_distance + $2` (atomic). That's a **~500x reduction** in data read per location update.

**Files to modify:**
- `rally_backend/location-service/internal/domain/location.go` — add 2 methods to LocationRepository interface
- `rally_backend/location-service/internal/repository/postgres/location_repository.go` — add `GetLastTrackForSession` and `IncrementSessionDistance`
- `rally_backend/location-service/internal/service/location_service.go` — replace `updateSessionWithNewLocation`

**Verify:** Start a session, send 5 location updates. Check `location_sessions` table — `total_distance` should increase incrementally, `location_count` should match number of tracks.

---

## Task 4: Add Jitter to Flutter 30-Second Sync Timer

**Why:** Every worker's location bloc starts a `Timer.periodic(Duration(seconds: 30))`. When 1,000 users are online, all 1,000 fire their sync at second 0, 30, 60, etc. This creates "thundering herd" — massive spike every 30 seconds, idle in between. Adding random jitter (25-35 seconds) spreads the load evenly.

**File:** `ui_flutter/lib/presentation/blocs/location/location_bloc.dart`

**How to do it:**

Replace the fixed timer (lines 177-181):
```dart
// Start periodic upload timer (every 30 seconds)
_uploadTimer = Timer.periodic(
  const Duration(seconds: 30),
  (_) => add(const LocationSyncPending()),
);
```

With a jittered timer that varies between 25-35 seconds:
```dart
// Start upload timer with jitter to prevent thundering herd
_startJitteredUploadTimer();
```

Add a new method:
```dart
void _startJitteredUploadTimer() {
  // Random interval between 25-35 seconds
  final jitter = 25 + Random().nextInt(11); // 25 to 35
  _uploadTimer = Timer(
    Duration(seconds: jitter),
    () {
      add(const LocationSyncPending());
      _startJitteredUploadTimer(); // Schedule next with new random interval
    },
  );
}
```

Add `import 'dart:math';` at the top of the file.

**Effect:** Instead of 1,000 requests hitting at exactly second 0, they spread across a 10-second window. Peak load drops from 1,000/s to ~100/s.

**Verify:** Check server logs — location update requests should arrive spread out instead of in bursts.

---

## Task 5: Make Geofence Checks Asynchronous via NATS

**Why:** Currently, every location update makes a synchronous HTTP call to territory-service (`geofence_client.go`, 5s timeout). This means: (a) location update response is blocked waiting for geofence, (b) territory-service gets overwhelmed with HTTP requests, (c) if territory-service is slow, location-service connections pile up. Making this async via NATS decouples the two services completely.

**Files to modify:**
- `rally_backend/location-service/internal/service/location_service.go` — publish to NATS instead of HTTP call
- `rally_backend/location-service/cmd/main.go` — connect to NATS on startup
- `rally_backend/territory-service/cmd/main.go` — subscribe to NATS location events
- `rally_backend/territory-service/internal/service/geofence_service.go` — add NATS handler

**How to do it:**

**Step 1:** Create a NATS publisher in location-service.

Create file: `rally_backend/location-service/internal/events/nats_publisher.go`
```go
package events

import (
    "encoding/json"
    "fmt"
    "github.com/google/uuid"
    "github.com/nats-io/nats.go"
)

type LocationEvent struct {
    WorkerID  uuid.UUID  `json:"worker_id"`
    TeamID    *uuid.UUID `json:"team_id,omitempty"`
    Latitude  float64    `json:"latitude"`
    Longitude float64    `json:"longitude"`
    SessionID *uuid.UUID `json:"session_id,omitempty"`
}

type NATSPublisher struct {
    nc *nats.Conn
}

func NewNATSPublisher(natsURL string) (*NATSPublisher, error) {
    nc, err := nats.Connect(natsURL)
    if err != nil {
        return nil, fmt.Errorf("failed to connect to NATS: %w", err)
    }
    return &NATSPublisher{nc: nc}, nil
}

func (p *NATSPublisher) PublishLocationUpdate(event *LocationEvent) error {
    data, err := json.Marshal(event)
    if err != nil {
        return err
    }
    return p.nc.Publish("location.update", data)
}

func (p *NATSPublisher) Close() {
    p.nc.Drain()
}
```

**Step 2:** In location-service's `UpdateLocation()` (location_service.go), replace the synchronous geofence call (lines 97-105):

FROM:
```go
// Check geofencing if client is configured
if s.geofenceClient != nil {
    geofenceEvent, err := s.geofenceClient.ProcessLocationUpdate(...)
    ...
}
```

TO:
```go
// Publish location event for async geofence processing
if s.natsPublisher != nil {
    go func() {
        evt := &events.LocationEvent{
            WorkerID:  userID,
            Latitude:  update.Latitude,
            Longitude: update.Longitude,
            SessionID: update.SessionID,
        }
        if err := s.natsPublisher.PublishLocationUpdate(evt); err != nil {
            fmt.Printf("Warning: failed to publish location event: %v\n", err)
        }
    }()
}
```

**Step 3:** In territory-service, subscribe to NATS and process geofence checks:

In `territory-service/cmd/main.go`, after existing setup:
```go
// Subscribe to location events for geofence processing
natsConn, err := nats.Connect(os.Getenv("NATS_URL"))
if err == nil {
    natsConn.Subscribe("location.update", func(msg *nats.Msg) {
        var event LocationEvent
        if err := json.Unmarshal(msg.Data, &event); err != nil {
            return
        }
        // Process geofence check asynchronously
        geofenceService.ProcessLocationUpdate(event.WorkerID, event.TeamID, event.Latitude, event.Longitude)
    })
}
```

**Effect:** Location update response time drops from ~200ms (with HTTP geofence call) to ~5ms. Geofence checks still happen, just asynchronously. Territory-service processes them at its own pace.

**Verify:** Send a location update, verify response is fast (<50ms). Check territory-service logs to confirm it still processes geofence events via NATS.

---

## Task 6: Implement Redis Caching for Real-Time Worker Locations

**Why:** `UpdateWorkerLocation()` in `location_repository.go` (line 448-452) is currently a NO-OP (returns nil). The `GetActiveWorkers()` method queries PostgreSQL with a JOIN across `users` and `location_tracks` tables. With Redis, real-time worker locations are served from memory (~0.1ms) instead of PostgreSQL (~50ms).

**Files to modify:**
- `rally_backend/location-service/internal/repository/postgres/location_repository.go` — implement Redis-backed UpdateWorkerLocation and GetActiveWorkers
- `rally_backend/location-service/cmd/main.go` — initialize Redis client

**How to do it:**

**Step 1:** Create a Redis-backed location cache.

Create file: `rally_backend/location-service/internal/cache/redis_location_cache.go`
```go
package cache

import (
    "context"
    "encoding/json"
    "fmt"
    "time"

    "github.com/go-redis/redis/v8"
    "github.com/google/uuid"
    "rally-point/location-service/internal/domain"
)

type RedisLocationCache struct {
    client *redis.Client
}

func NewRedisLocationCache(redisURL string) (*RedisLocationCache, error) {
    opts, err := redis.ParseURL("redis://" + redisURL)
    if err != nil {
        return nil, err
    }
    client := redis.NewClient(opts)
    if err := client.Ping(context.Background()).Err(); err != nil {
        return nil, err
    }
    return &RedisLocationCache{client: client}, nil
}

// SetWorkerLocation stores worker location with 5-minute TTL
func (c *RedisLocationCache) SetWorkerLocation(location *domain.WorkerLocation) error {
    data, err := json.Marshal(location)
    if err != nil {
        return err
    }
    key := fmt.Sprintf("worker:location:%s", location.UserID.String())
    ctx := context.Background()

    pipe := c.client.Pipeline()
    pipe.Set(ctx, key, data, 5*time.Minute)
    pipe.SAdd(ctx, "active_workers", location.UserID.String())
    pipe.Expire(ctx, "active_workers", 5*time.Minute)
    _, err = pipe.Exec(ctx)
    return err
}

// GetActiveWorkers returns all workers with recent locations
func (c *RedisLocationCache) GetActiveWorkers() ([]*domain.WorkerLocation, error) {
    ctx := context.Background()
    memberIDs, err := c.client.SMembers(ctx, "active_workers").Result()
    if err != nil {
        return nil, err
    }

    var workers []*domain.WorkerLocation
    for _, id := range memberIDs {
        key := fmt.Sprintf("worker:location:%s", id)
        data, err := c.client.Get(ctx, key).Bytes()
        if err == redis.Nil {
            continue // TTL expired, skip
        }
        if err != nil {
            continue
        }
        var worker domain.WorkerLocation
        if json.Unmarshal(data, &worker) == nil {
            workers = append(workers, &worker)
        }
    }
    return workers, nil
}

func (c *RedisLocationCache) RemoveWorker(userID uuid.UUID) error {
    ctx := context.Background()
    pipe := c.client.Pipeline()
    pipe.Del(ctx, fmt.Sprintf("worker:location:%s", userID.String()))
    pipe.SRem(ctx, "active_workers", userID.String())
    _, err := pipe.Exec(ctx)
    return err
}
```

**Step 2:** Wire it into the location service. Update `UpdateWorkerLocation` in `location_repository.go` to call the Redis cache, and update `GetActiveWorkers` to try Redis first, fall back to PostgreSQL.

**Effect:** Admin map showing active workers loads in ~5ms instead of ~200ms. The heavy `DISTINCT ON` + `JOIN` query only runs as fallback.

**Verify:** Open admin map, verify active workers appear. Check Redis with `redis-cli KEYS "worker:location:*"`.

---

## Task 7: Batch Location Writes (Bulk INSERT)

**Why:** Currently each location update does a single-row INSERT. With 1,000 users syncing every 30 seconds, that's ~33 INSERTs/second sustained. Batching collects updates in a buffer and does one `INSERT ... VALUES (...), (...), (...)` for many rows at once. PostgreSQL handles 1 batch INSERT of 50 rows ~10x faster than 50 individual INSERTs.

**File:** `rally_backend/location-service/internal/repository/postgres/location_repository.go`

**How to do it:**

Create a write buffer that flushes every 2 seconds or when it reaches 50 items (whichever comes first):

Create file: `rally_backend/location-service/internal/repository/postgres/batch_writer.go`
```go
package postgres

import (
    "database/sql"
    "fmt"
    "strings"
    "sync"
    "time"

    "rally-point/location-service/internal/domain"
)

type BatchWriter struct {
    db        *sql.DB
    buffer    []*domain.LocationTrack
    mu        sync.Mutex
    maxSize   int
    flushInterval time.Duration
    done      chan struct{}
}

func NewBatchWriter(db *sql.DB) *BatchWriter {
    bw := &BatchWriter{
        db:            db,
        buffer:        make([]*domain.LocationTrack, 0, 50),
        maxSize:       50,
        flushInterval: 2 * time.Second,
        done:          make(chan struct{}),
    }
    go bw.flushLoop()
    return bw
}

func (bw *BatchWriter) Add(track *domain.LocationTrack) {
    bw.mu.Lock()
    bw.buffer = append(bw.buffer, track)
    shouldFlush := len(bw.buffer) >= bw.maxSize
    bw.mu.Unlock()

    if shouldFlush {
        bw.Flush()
    }
}

func (bw *BatchWriter) Flush() {
    bw.mu.Lock()
    if len(bw.buffer) == 0 {
        bw.mu.Unlock()
        return
    }
    tracks := bw.buffer
    bw.buffer = make([]*domain.LocationTrack, 0, 50)
    bw.mu.Unlock()

    // Build bulk INSERT
    valueStrings := make([]string, 0, len(tracks))
    valueArgs := make([]interface{}, 0, len(tracks)*12)
    for i, t := range tracks {
        base := i * 12
        valueStrings = append(valueStrings, fmt.Sprintf(
            "($%d,$%d,$%d,$%d,$%d,$%d,$%d,$%d,$%d,$%d,ST_SetSRID(ST_MakePoint($%d,$%d),4326))",
            base+1, base+2, base+3, base+4, base+5, base+6, base+7, base+8, base+9, base+10, base+11, base+12,
        ))
        valueArgs = append(valueArgs,
            t.ID, t.UserID, t.Latitude, t.Longitude, t.Accuracy, t.Speed,
            t.Heading, t.SessionID, t.TrackedAt, t.CreatedAt, t.Longitude, t.Latitude,
        )
    }

    query := fmt.Sprintf(`
        INSERT INTO location_tracks (id, user_id, latitude, longitude, accuracy, speed, heading, session_id, tracked_at, created_at, location)
        VALUES %s`, strings.Join(valueStrings, ","))

    _, err := bw.db.Exec(query, valueArgs...)
    if err != nil {
        fmt.Printf("Batch write failed (%d tracks): %v\n", len(tracks), err)
    }
}

func (bw *BatchWriter) flushLoop() {
    ticker := time.NewTicker(bw.flushInterval)
    defer ticker.Stop()
    for {
        select {
        case <-ticker.C:
            bw.Flush()
        case <-bw.done:
            bw.Flush() // Final flush
            return
        }
    }
}

func (bw *BatchWriter) Close() {
    close(bw.done)
}
```

Then update `CreateTrack` to use the batch writer instead of direct INSERT:
```go
func (r *locationRepository) CreateTrack(track *domain.LocationTrack) error {
    r.batchWriter.Add(track)
    return nil  // Written async in batch
}
```

**Important note:** The batch writer introduces a 0-2 second delay before tracks appear in the database. This is fine because:
- Session distance updates use the track data passed in memory (not re-read from DB)
- Geofence checks use lat/lng from the request, not from DB
- The only consumer of `location_tracks` table is analytics/history, where 2-second delay is invisible

**Verify:** Send 10 rapid location updates. Check `location_tracks` table — they should appear together (same `created_at` second) rather than one by one.

---

## Task 8: OS-Level Tuning in Docker Compose

**Why:** Default Linux limits (1024 file descriptors, 128 socket backlog) choke under load. WebSocket connections each consume a file descriptor. With 5,000 WebSocket connections, we'd hit the 1024 default limit and start rejecting connections.

**File:** `rally_backend/docker-compose.yml`

**How to do it:**

Add `ulimits` and `sysctls` to the api-gateway and location-service (the two highest-traffic services):

```yaml
api-gateway:
  # ... existing config ...
  ulimits:
    nofile:
      soft: 65535
      hard: 65535
  sysctls:
    - net.core.somaxconn=4096        # Socket backlog (default 128)
    - net.ipv4.tcp_keepalive_time=60  # Detect dead connections faster

location-service:
  # ... existing config ...
  ulimits:
    nofile:
      soft: 65535
      hard: 65535
```

Also add to the PostgreSQL container:
```yaml
postgres:
  # ... existing config ...
  ulimits:
    nofile:
      soft: 65535
      hard: 65535
  shm_size: '256mb'  # Shared memory for PostgreSQL (default 64mb, too low for 512MB shared_buffers)
```

**Note:** `shm_size` is critical. If PostgreSQL's `shared_buffers` is set to 512MB but Docker's shared memory is only 64MB, PostgreSQL will crash or silently fall back to smaller buffers.

**Verify:** After restart, exec into the container: `docker exec rally_api_gateway sh -c "ulimit -n"` should show 65535.

---

## Task 9: Nginx Reverse Proxy with HTTPS

**Why:** Currently the API gateway is directly exposed on port 8080 (no HTTPS). The admin SPA runs on a separate Python SimpleHTTPServer on port 3000. This is insecure (credentials sent in plain text), unprofessional (non-standard ports), and doesn't support HTTP/2. Nginx handles SSL termination, static file serving, connection pooling, and gzip — all things the Go services shouldn't handle themselves.

**How to do it:**

**Step 1:** Create Nginx config.

Create file: `rally_backend/nginx/nginx.conf`
```nginx
worker_processes auto;
events {
    worker_connections 4096;
}

http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;

    # Gzip compression
    gzip on;
    gzip_types text/plain application/json application/javascript text/css;
    gzip_min_length 1000;

    # Connection tuning
    keepalive_timeout 65;
    client_max_body_size 50M;

    # Rate limiting zone (backup to application-level)
    limit_req_zone $binary_remote_addr zone=api:10m rate=30r/s;

    # Upstream for API Gateway
    upstream api_backend {
        server api-gateway:8080;
        keepalive 32;  # Persistent connections to backend
    }

    # HTTP → HTTPS redirect
    server {
        listen 80;
        server_name _;
        return 301 https://$host$request_uri;
    }

    # HTTPS server
    server {
        listen 443 ssl http2;
        server_name _;

        ssl_certificate     /etc/nginx/ssl/cert.pem;
        ssl_certificate_key /etc/nginx/ssl/key.pem;
        ssl_protocols       TLSv1.2 TLSv1.3;

        # Admin SPA
        location / {
            root /var/www/admin;
            try_files $uri $uri/ /index.html;
            expires 1h;
            add_header Cache-Control "public, no-cache";
        }

        # API proxy
        location /api/ {
            limit_req zone=api burst=50 nodelay;
            proxy_pass http://api_backend;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
        }

        # WebSocket proxy
        location /ws {
            proxy_pass http://api_backend;
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection "upgrade";
            proxy_set_header Host $host;
            proxy_read_timeout 86400;  # 24 hours for WebSocket
        }
    }
}
```

**Step 2:** Add Nginx to docker-compose.yml:
```yaml
nginx:
  image: nginx:alpine
  container_name: rally_nginx
  ports:
    - "80:80"
    - "443:443"
  volumes:
    - ./nginx/nginx.conf:/etc/nginx/nginx.conf:ro
    - ./nginx/ssl:/etc/nginx/ssl:ro
    - /var/www/admin:/var/www/admin:ro
  depends_on:
    - api-gateway
  networks:
    - rally_network
  restart: unless-stopped
```

**Step 3:** Generate SSL cert (Let's Encrypt or self-signed for now):
```bash
# Self-signed for testing:
mkdir -p rally_backend/nginx/ssl
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout rally_backend/nginx/ssl/key.pem \
  -out rally_backend/nginx/ssl/cert.pem \
  -subj "/CN=18.188.1.122"
```

For production, use Let's Encrypt with certbot.

**Step 4:** Stop the Python SPA server (no longer needed — Nginx serves the admin SPA).

**Step 5:** Update Flutter app API URLs from `http://18.188.1.122:8080` to `https://18.188.1.122`.

**Files to modify:**
- `rally_backend/nginx/nginx.conf` — **NEW**
- `rally_backend/docker-compose.yml` — add nginx service, remove port 8080 exposure from api-gateway
- `ui_admin/lib/core/constants/api_constants.dart` — update baseUrl
- `ui_flutter/lib/core/constants/api_constants.dart` — update baseUrl

**Verify:** `curl -k https://18.188.1.122/api/health` returns 200. Admin SPA loads at `https://18.188.1.122/`.

---

## Task 10: Automated Database Backups

**Why:** Single PostgreSQL instance with no backups. If the Docker volume gets corrupted or the EC2 instance fails, all data is lost. This is a critical operational risk.

**How to do it:**

Create a backup script and cron job inside a dedicated backup container.

Create file: `rally_backend/backup/backup.sh`
```bash
#!/bin/bash
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR=/backups
BACKUP_FILE="$BACKUP_DIR/rally_point_$TIMESTAMP.sql.gz"

# Create backup with pg_dump, compress with gzip
PGPASSWORD=rally_password pg_dump -h postgres -U rally_user rally_point | gzip > "$BACKUP_FILE"

# Keep only last 7 days of backups
find $BACKUP_DIR -name "*.sql.gz" -mtime +7 -delete

echo "Backup created: $BACKUP_FILE ($(du -h $BACKUP_FILE | cut -f1))"
```

Add to docker-compose.yml:
```yaml
backup:
  image: postgres:15-alpine
  container_name: rally_backup
  volumes:
    - ./backup/backup.sh:/backup.sh:ro
    - backup_data:/backups
  environment:
    - PGPASSWORD=rally_password
  entrypoint: /bin/sh
  command: -c "chmod +x /backup.sh && while true; do /backup.sh; sleep 86400; done"
  depends_on:
    - postgres
  networks:
    - rally_network
  restart: unless-stopped

volumes:
  # ... existing volumes ...
  backup_data:
```

**Optional improvement:** Copy backups to S3 with `aws s3 cp` after each dump for off-site storage.

**Verify:** After starting, exec into container: `docker exec rally_backup ls -la /backups/` — should show a .sql.gz file. Test restore: `gunzip -c backup.sql.gz | psql -h postgres -U rally_user rally_point`.

---

## Task 11: Add Database Indexes for Hot Queries

**Why:** The location_tracks table grows continuously and becomes slow without proper indexes. The `GetActiveWorkers()` query does a JOIN + `tracked_at >= NOW() - INTERVAL '5 minutes'` which scans the entire table without an index on `tracked_at`.

**How to do it:**

Create a migration file: `rally_backend/shared/database/migrations/add_performance_indexes.sql`

```sql
-- Index for location_tracks: speeds up session track lookups and time-range queries
CREATE INDEX IF NOT EXISTS idx_location_tracks_session_tracked
    ON location_tracks (session_id, tracked_at DESC);

-- Index for active worker queries (tracked_at within last 5 minutes)
CREATE INDEX IF NOT EXISTS idx_location_tracks_user_tracked
    ON location_tracks (user_id, tracked_at DESC);

-- Index for location_sessions: active session lookup
CREATE INDEX IF NOT EXISTS idx_location_sessions_user_active
    ON location_sessions (user_id, is_active) WHERE is_active = true;

-- Index for geofence queries: spatial index should already exist, but ensure it
CREATE INDEX IF NOT EXISTS idx_territories_geom_gist
    ON territories USING GIST (geom);

-- Index for territory allocations lookup
CREATE INDEX IF NOT EXISTS idx_territory_allocations_team
    ON territory_allocations (team_id, status) WHERE status = 'active';
```

Run manually on the DB or add to init scripts.

**Verify:** `\di` in psql to list indexes. Run `EXPLAIN ANALYZE` on the active workers query — should show "Index Scan" instead of "Seq Scan".

---

## Summary: Implementation Order

| # | Task | Effort | Impact | Risk |
|---|------|--------|--------|------|
| 1 | PostgreSQL server tuning | 15 min | High | Low (just config flags) |
| 2 | Configurable connection pool | 30 min | Medium | Low |
| 3 | Fix session N+1 (incremental distance) | 1 hr | **Very High** | Medium (behavior change) |
| 4 | Jitter sync timer | 15 min | High | Low (Flutter only) |
| 5 | Async geofence via NATS | 2 hr | High | Medium (architecture change) |
| 6 | Redis worker location cache | 1.5 hr | Medium | Low (additive) |
| 7 | Batch location writes | 1.5 hr | High | Medium (async writes) |
| 8 | OS-level tuning | 15 min | Medium | Low (just config) |
| 9 | Nginx + HTTPS | 1 hr | Medium | Low (additive) |
| 10 | Database backups | 30 min | Critical (safety) | Low |
| 11 | Database indexes | 15 min | High | Low (additive) |

**Expected result after all tasks:** System should comfortably handle 3,000-5,000 concurrent users on the same single EC2 instance. To reach 10,000+, the next step would be moving PostgreSQL to RDS and running multiple api-gateway + location-service instances behind an ALB — but that's a separate plan for after these fundamentals are in place.

---

## Verification (End-to-End)

1. `docker compose down && docker compose up -d --build` — all services start healthy
2. `SHOW shared_buffers;` in psql → 512MB
3. Send location update → response time <50ms (no geofence blocking)
4. Check `location_sessions.total_distance` increases incrementally (not recalculated)
5. `redis-cli KEYS "worker:location:*"` → shows active worker entries
6. `curl -k https://18.188.1.122/api/health` → 200 via Nginx
7. Admin SPA loads at `https://18.188.1.122/`
8. `docker exec rally_backup ls /backups/` → backup files present
9. `EXPLAIN ANALYZE SELECT ... FROM location_tracks WHERE session_id = X ORDER BY tracked_at DESC LIMIT 1;` → Index Scan
