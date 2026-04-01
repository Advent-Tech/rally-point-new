package realtime

import (
	"sync"

	"github.com/google/uuid"
	"rally-point/location-service/internal/domain"
)

type subscriber struct {
	ch     chan *domain.WorkerLocation
	teamID string
}

type realtimeManager struct {
	subscribers map[uuid.UUID]*subscriber
	mu          sync.RWMutex
}

// NewRealtimeManager creates a new realtime manager
func NewRealtimeManager() domain.RealtimeManager {
	return &realtimeManager{
		subscribers: make(map[uuid.UUID]*subscriber),
	}
}

// AddSubscriber adds a subscriber for location updates
func (rm *realtimeManager) AddSubscriber(userID uuid.UUID, ch chan *domain.WorkerLocation, teamID string) error {
	rm.mu.Lock()
	defer rm.mu.Unlock()

	rm.subscribers[userID] = &subscriber{
		ch:     ch,
		teamID: teamID,
	}
	return nil
}

// RemoveSubscriber removes a subscriber
func (rm *realtimeManager) RemoveSubscriber(userID uuid.UUID) error {
	rm.mu.Lock()
	defer rm.mu.Unlock()

	if sub, exists := rm.subscribers[userID]; exists {
		close(sub.ch)
		delete(rm.subscribers, userID)
	}

	return nil
}

// Broadcast broadcasts a location update to subscribers in the same team
func (rm *realtimeManager) Broadcast(location *domain.WorkerLocation, teamID string) error {
	rm.mu.RLock()
	defer rm.mu.RUnlock()

	for _, sub := range rm.subscribers {
		// Only send to subscribers in the same team, or if teamID is empty (broadcast to all)
		if sub.teamID == teamID || teamID == "" {
			select {
			case sub.ch <- location:
				// Successfully sent
			default:
				// Subscriber is slow: drop one stale buffered item (if any)
				// and try enqueuing the latest update once.
				select {
				case <-sub.ch:
				default:
				}
				select {
				case sub.ch <- location:
				default:
					// Still blocked, skip this subscriber for this tick.
				}
			}
		}
	}

	return nil
}

// GetActiveSubscribers returns a list of active subscriber IDs
func (rm *realtimeManager) GetActiveSubscribers() []uuid.UUID {
	rm.mu.RLock()
	defer rm.mu.RUnlock()

	var subscribers []uuid.UUID
	for userID := range rm.subscribers {
		subscribers = append(subscribers, userID)
	}

	return subscribers
}
