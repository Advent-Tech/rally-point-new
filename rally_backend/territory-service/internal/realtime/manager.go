package realtime

import (
	"sync"

	"github.com/google/uuid"
	"rally-point/territory-service/internal/domain"
)

type realtimeManager struct {
	subscribers map[uuid.UUID]chan<- *domain.TerritoryAlert
	mu          sync.RWMutex
}

// NewRealtimeManager creates a new realtime manager
func NewRealtimeManager() domain.RealtimeManager {
	return &realtimeManager{
		subscribers: make(map[uuid.UUID]chan<- *domain.TerritoryAlert),
	}
}

// AddSubscriber adds a subscriber for territory alerts
func (rm *realtimeManager) AddSubscriber(userID uuid.UUID, ch chan<- *domain.TerritoryAlert) error {
	rm.mu.Lock()
	defer rm.mu.Unlock()
	
	rm.subscribers[userID] = ch
	return nil
}

// RemoveSubscriber removes a subscriber
func (rm *realtimeManager) RemoveSubscriber(userID uuid.UUID) error {
	rm.mu.Lock()
	defer rm.mu.Unlock()
	
	if ch, exists := rm.subscribers[userID]; exists {
		close(ch)
		delete(rm.subscribers, userID)
	}
	
	return nil
}

// Broadcast broadcasts a territory alert to all subscribers
func (rm *realtimeManager) Broadcast(alert *domain.TerritoryAlert) error {
	rm.mu.RLock()
	defer rm.mu.RUnlock()
	
	for _, ch := range rm.subscribers {
		select {
		case ch <- alert:
			// Successfully sent
		default:
			// Channel is full, skip this subscriber
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
