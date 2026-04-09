package websocket

import (
	"encoding/json"
	"log"
	"net/http"
	"sync"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"github.com/gorilla/websocket"
)

// Hub maintains the set of active clients and broadcasts messages to the clients
type Hub struct {
	// Registered clients
	clients map[*Client]bool

	// Inbound messages from the clients
	broadcast chan []byte

	// Register requests from the clients
	register chan *Client

	// Unregister requests from clients
	unregister chan *Client

	// Client groups for targeted messaging
	groups map[string]map[*Client]bool

	// Mutex for thread-safe operations
	mutex sync.RWMutex
}

// Client represents a websocket client
type Client struct {
	// The websocket connection
	conn *websocket.Conn

	// Buffered channel of outbound messages
	send chan []byte

	// Client metadata
	ID     string
	UserID string
	TeamID string
	Role   string

	// Reference to the hub
	hub *Hub
}

// Message represents a websocket message
type Message struct {
	Type      string      `json:"type"`
	Data      interface{} `json:"data"`
	Timestamp int64       `json:"timestamp"`
	From      string      `json:"from,omitempty"`
	To        string      `json:"to,omitempty"`
	Channel   string      `json:"channel,omitempty"`
}

var upgrader = websocket.Upgrader{
	CheckOrigin: func(r *http.Request) bool {
		// Allow connections from any origin in development
		return true
	},
}

// NewHub creates a new websocket hub
func NewHub() *Hub {
	return &Hub{
		clients:    make(map[*Client]bool),
		broadcast:  make(chan []byte),
		register:   make(chan *Client),
		unregister: make(chan *Client),
		groups:     make(map[string]map[*Client]bool),
	}
}

// Run starts the hub
func (h *Hub) Run() {
	for {
		select {
		case client := <-h.register:
			h.mutex.Lock()
			h.clients[client] = true
			
			// Add client to team group
			if client.TeamID != "" {
				if h.groups[client.TeamID] == nil {
					h.groups[client.TeamID] = make(map[*Client]bool)
				}
				h.groups[client.TeamID][client] = true
			}
			h.mutex.Unlock()
			
			log.Printf("Client connected: %s (User: %s, Team: %s)", client.ID, client.UserID, client.TeamID)
			
			// Send welcome message
			welcome := Message{
				Type: "connected",
				Data: map[string]string{
					"client_id": client.ID,
					"message":   "Connected to Rally Point WebSocket",
				},
			}
			h.SendToClient(client, welcome)

		case client := <-h.unregister:
			h.mutex.Lock()
			if _, ok := h.clients[client]; ok {
				delete(h.clients, client)
				close(client.send)
				
				// Remove from team group
				if client.TeamID != "" && h.groups[client.TeamID] != nil {
					delete(h.groups[client.TeamID], client)
					if len(h.groups[client.TeamID]) == 0 {
						delete(h.groups, client.TeamID)
					}
				}
			}
			h.mutex.Unlock()
			
			log.Printf("Client disconnected: %s", client.ID)

		case message := <-h.broadcast:
			h.mutex.RLock()
			for client := range h.clients {
				select {
				case client.send <- message:
				default:
					close(client.send)
					delete(h.clients, client)
				}
			}
			h.mutex.RUnlock()
		}
	}
}

// HandleWebSocket handles websocket connections
func (h *Hub) HandleWebSocket() gin.HandlerFunc {
	return func(c *gin.Context) {
		conn, err := upgrader.Upgrade(c.Writer, c.Request, nil)
		if err != nil {
			log.Printf("WebSocket upgrade error: %v", err)
			return
		}

		// Get user context from middleware
		userID, _ := c.Get("user_id")
		teamID, _ := c.Get("team_id")
		role, _ := c.Get("user_role")

		client := &Client{
			conn:   conn,
			send:   make(chan []byte, 256),
			ID:     uuid.New().String(),
			UserID: getString(userID),
			TeamID: getString(teamID),
			Role:   getString(role),
			hub:    h,
		}

		client.hub.register <- client

		// Start goroutines for reading and writing
		go client.writePump()
		go client.readPump()
	}
}

// SendToClient sends a message to a specific client
func (h *Hub) SendToClient(client *Client, message Message) {
	data, err := json.Marshal(message)
	if err != nil {
		log.Printf("Error marshaling message: %v", err)
		return
	}

	select {
	case client.send <- data:
	default:
		close(client.send)
		h.mutex.Lock()
		delete(h.clients, client)
		h.mutex.Unlock()
	}
}

// SendToUser sends a message to all connections of a specific user
func (h *Hub) SendToUser(userID string, message Message) {
	h.mutex.RLock()
	defer h.mutex.RUnlock()

	for client := range h.clients {
		if client.UserID == userID {
			h.SendToClient(client, message)
		}
	}
}

// SendToTeam sends a message to all clients in a team
func (h *Hub) SendToTeam(teamID string, message Message) {
	h.mutex.RLock()
	defer h.mutex.RUnlock()

	if group, exists := h.groups[teamID]; exists {
		for client := range group {
			h.SendToClient(client, message)
		}
	}
}

// BroadcastToAll sends a message to all connected clients
func (h *Hub) BroadcastToAll(message Message) {
	data, err := json.Marshal(message)
	if err != nil {
		log.Printf("Error marshaling broadcast message: %v", err)
		return
	}

	h.broadcast <- data
}

// IsUserConnected checks if a user has any active WebSocket connections
func (h *Hub) IsUserConnected(userID string) bool {
	h.mutex.RLock()
	defer h.mutex.RUnlock()

	for client := range h.clients {
		if client.UserID == userID {
			return true
		}
	}
	return false
}

// GetStats returns hub statistics
func (h *Hub) GetStats() map[string]interface{} {
	h.mutex.RLock()
	defer h.mutex.RUnlock()

	teamCounts := make(map[string]int)
	for teamID, group := range h.groups {
		teamCounts[teamID] = len(group)
	}

	return map[string]interface{}{
		"total_clients": len(h.clients),
		"team_groups":   len(h.groups),
		"team_counts":   teamCounts,
	}
}

// readPump pumps messages from the websocket connection to the hub
func (c *Client) readPump() {
	defer func() {
		c.hub.unregister <- c
		c.conn.Close()
	}()

	for {
		_, messageBytes, err := c.conn.ReadMessage()
		if err != nil {
			if websocket.IsUnexpectedCloseError(err, websocket.CloseGoingAway, websocket.CloseAbnormalClosure) {
				log.Printf("WebSocket error: %v", err)
			}
			break
		}

		// Parse incoming message
		var msg Message
		if err := json.Unmarshal(messageBytes, &msg); err != nil {
			log.Printf("Error parsing message: %v", err)
			continue
		}

		// Handle different message types
		c.handleMessage(msg)
	}
}

// writePump pumps messages from the hub to the websocket connection
func (c *Client) writePump() {
	defer c.conn.Close()

	for {
		select {
		case message, ok := <-c.send:
			if !ok {
				c.conn.WriteMessage(websocket.CloseMessage, []byte{})
				return
			}

			if err := c.conn.WriteMessage(websocket.TextMessage, message); err != nil {
				log.Printf("WebSocket write error: %v", err)
				return
			}
		}
	}
}

// handleMessage processes incoming messages from clients
func (c *Client) handleMessage(msg Message) {
	switch msg.Type {
	case "ping":
		// Respond with pong
		pong := Message{
			Type: "pong",
			Data: map[string]string{"message": "pong"},
		}
		c.hub.SendToClient(c, pong)

	case "join_team":
		// Handle team joining
		if teamID, ok := msg.Data.(string); ok && teamID != "" {
			c.TeamID = teamID
			// Re-register to update team groups
			c.hub.register <- c
		}

	case "team_message":
		// Broadcast message to team
		if c.TeamID != "" {
			msg.From = c.UserID
			c.hub.SendToTeam(c.TeamID, msg)
		}

	case "user_message":
		// Send message to specific user
		if targetUser := msg.To; targetUser != "" {
			msg.From = c.UserID
			c.hub.SendToUser(targetUser, msg)
		}

	default:
		log.Printf("Unknown message type: %s", msg.Type)
	}
}

// getString safely converts interface{} to string
func getString(v interface{}) string {
	if v == nil {
		return ""
	}
	if s, ok := v.(string); ok {
		return s
	}
	return ""
}
