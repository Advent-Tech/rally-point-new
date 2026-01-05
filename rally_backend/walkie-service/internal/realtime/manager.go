package realtime

import (
	"sync"
	"time"

	"github.com/google/uuid"
	"github.com/gorilla/websocket"
	"rally-point/walkie-service/internal/domain"
)

type realtimeManager struct {
	connections map[uuid.UUID]*domain.WebSocketConnection
	teamStates  map[uuid.UUID]*domain.WalkieState
	mu          sync.RWMutex
}

// NewRealtimeManager creates a new realtime manager
func NewRealtimeManager() domain.RealtimeManager {
	return &realtimeManager{
		connections: make(map[uuid.UUID]*domain.WebSocketConnection),
		teamStates:  make(map[uuid.UUID]*domain.WalkieState),
	}
}

// AddConnection adds a WebSocket connection
func (rm *realtimeManager) AddConnection(userID, teamID uuid.UUID, conn interface{}) error {
	rm.mu.Lock()
	defer rm.mu.Unlock()

	connection := &domain.WebSocketConnection{
		UserID:     userID,
		TeamID:     teamID,
		Connection: conn,
		LastPing:   time.Now(),
	}

	rm.connections[userID] = connection

	// Broadcast user joined message to team
	message := &domain.WebSocketMessage{
		Type:      domain.WSMessageTypeUserJoined,
		TeamID:    teamID,
		UserID:    userID,
		Data:      map[string]interface{}{"user_id": userID},
		Timestamp: time.Now(),
	}

	go rm.broadcastToTeamExcept(teamID, userID, message)

	return nil
}

// RemoveConnection removes a WebSocket connection
func (rm *realtimeManager) RemoveConnection(userID uuid.UUID) error {
	rm.mu.Lock()
	defer rm.mu.Unlock()

	connection, exists := rm.connections[userID]
	if !exists {
		return nil
	}

	teamID := connection.TeamID

	// Close websocket
	if ws, ok := connection.Connection.(*websocket.Conn); ok {
		_ = ws.Close()
	}

	delete(rm.connections, userID)

	// Broadcast user left message to team
	message := &domain.WebSocketMessage{
		Type:      domain.WSMessageTypeUserLeft,
		TeamID:    teamID,
		UserID:    userID,
		Data:      map[string]interface{}{"user_id": userID},
		Timestamp: time.Now(),
	}

	go rm.broadcastToTeamExcept(teamID, userID, message)

	return nil
}

// GetTeamConnections returns all connections for a team
func (rm *realtimeManager) GetTeamConnections(teamID uuid.UUID) []*domain.WebSocketConnection {
	rm.mu.RLock()
	defer rm.mu.RUnlock()

	var connections []*domain.WebSocketConnection
	for _, conn := range rm.connections {
		if conn.TeamID == teamID {
			connections = append(connections, conn)
		}
	}

	return connections
}

// BroadcastToTeam broadcasts a message to all team members
func (rm *realtimeManager) BroadcastToTeam(teamID uuid.UUID, message *domain.WebSocketMessage) error {
	return rm.broadcastToTeamExcept(teamID, uuid.Nil, message)
}

// BroadcastToUser broadcasts a message to a specific user
func (rm *realtimeManager) BroadcastToUser(userID uuid.UUID, message *domain.WebSocketMessage) error {
	rm.mu.RLock()
	connection, exists := rm.connections[userID]
	rm.mu.RUnlock()

	if !exists {
		return nil // User not connected
	}

	// In a real implementation, this would send the message through the WebSocket
	// For now, we'll just log it
	if ws, ok := connection.Connection.(*websocket.Conn); ok {
		_ = ws.WriteJSON(message)
	}
	return nil
}

// broadcastToTeamExcept broadcasts to all team members except the specified user
func (rm *realtimeManager) broadcastToTeamExcept(teamID, exceptUserID uuid.UUID, message *domain.WebSocketMessage) error {
	rm.mu.RLock()
	defer rm.mu.RUnlock()

	for userID, conn := range rm.connections {
		if conn.TeamID == teamID && userID != exceptUserID {
			// In a real implementation, this would send the message through the WebSocket
			// For now, we'll just log it
			if ws, ok := conn.Connection.(*websocket.Conn); ok {
				_ = ws.WriteJSON(message)
			}
		}
	}

	return nil
}

// UpdateTeamState updates the state for a team
func (rm *realtimeManager) UpdateTeamState(teamID uuid.UUID, state *domain.WalkieState) error {
	rm.mu.Lock()
	defer rm.mu.Unlock()

	rm.teamStates[teamID] = state

	// Broadcast state update to team
	message := &domain.WebSocketMessage{
		Type:      domain.WSMessageTypeTeamState,
		TeamID:    teamID,
		Data:      state,
		Timestamp: time.Now(),
	}

	go rm.broadcastToTeamExcept(teamID, uuid.Nil, message)

	return nil
}

// GetTeamState retrieves the current state for a team
func (rm *realtimeManager) GetTeamState(teamID uuid.UUID) (*domain.WalkieState, error) {
	rm.mu.RLock()
	defer rm.mu.RUnlock()

	state, exists := rm.teamStates[teamID]
	if !exists {
		return nil, nil
	}

	return state, nil
}
