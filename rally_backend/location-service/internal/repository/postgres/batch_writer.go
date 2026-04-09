package postgres

import (
	"database/sql"
	"fmt"
	"strings"
	"sync"
	"time"

	"rally-point/location-service/internal/domain"
)

// BatchWriter collects location tracks and writes them in bulk INSERTs
type BatchWriter struct {
	db            *sql.DB
	buffer        []*domain.LocationTrack
	mu            sync.Mutex
	maxSize       int
	flushInterval time.Duration
	done          chan struct{}
}

// NewBatchWriter creates a batch writer that flushes every 2 seconds or at 50 items
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

// Add queues a track for batch writing. Flushes immediately if buffer is full.
func (bw *BatchWriter) Add(track *domain.LocationTrack) {
	bw.mu.Lock()
	bw.buffer = append(bw.buffer, track)
	shouldFlush := len(bw.buffer) >= bw.maxSize
	bw.mu.Unlock()

	if shouldFlush {
		bw.Flush()
	}
}

// Flush writes all buffered tracks to the database in a single INSERT
func (bw *BatchWriter) Flush() {
	bw.mu.Lock()
	if len(bw.buffer) == 0 {
		bw.mu.Unlock()
		return
	}
	tracks := bw.buffer
	bw.buffer = make([]*domain.LocationTrack, 0, 50)
	bw.mu.Unlock()

	bw.bulkInsert(tracks)
}

func (bw *BatchWriter) bulkInsert(tracks []*domain.LocationTrack) {
	if len(tracks) == 0 {
		return
	}

	valueStrings := make([]string, 0, len(tracks))
	valueArgs := make([]interface{}, 0, len(tracks)*12)

	for i, t := range tracks {
		base := i * 12
		valueStrings = append(valueStrings, fmt.Sprintf(
			"($%d,$%d,$%d,$%d,$%d,$%d,$%d,$%d,$%d,$%d,ST_SetSRID(ST_MakePoint($%d,$%d),4326))",
			base+1, base+2, base+3, base+4, base+5, base+6,
			base+7, base+8, base+9, base+10, base+11, base+12,
		))
		valueArgs = append(valueArgs,
			t.ID, t.UserID, t.Latitude, t.Longitude, t.Accuracy, t.Speed,
			t.Heading, t.SessionID, t.TrackedAt, t.CreatedAt,
			t.Longitude, t.Latitude, // ST_MakePoint(lng, lat)
		)
	}

	query := fmt.Sprintf(
		`INSERT INTO location_tracks (id, user_id, latitude, longitude, accuracy, speed, heading, session_id, tracked_at, created_at, location) VALUES %s`,
		strings.Join(valueStrings, ","),
	)

	_, err := bw.db.Exec(query, valueArgs...)
	if err != nil {
		fmt.Printf("Batch write failed (%d tracks): %v — falling back to individual inserts\n", len(tracks), err)
		bw.individualInsert(tracks)
	}
}

func (bw *BatchWriter) individualInsert(tracks []*domain.LocationTrack) {
	query := `
		INSERT INTO location_tracks (id, user_id, latitude, longitude, accuracy, speed, heading, session_id, tracked_at, created_at, location)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, ST_SetSRID(ST_MakePoint($11, $12), 4326))
	`
	for _, t := range tracks {
		_, err := bw.db.Exec(query,
			t.ID, t.UserID, t.Latitude, t.Longitude, t.Accuracy, t.Speed,
			t.Heading, t.SessionID, t.TrackedAt, t.CreatedAt,
			t.Longitude, t.Latitude,
		)
		if err != nil {
			fmt.Printf("Individual insert failed for track %s: %v\n", t.ID, err)
		}
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
			bw.Flush() // Final flush on shutdown
			return
		}
	}
}

// Close stops the flush loop and performs a final flush
func (bw *BatchWriter) Close() {
	close(bw.done)
}
