package proxy

import (
	"bytes"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/gorilla/websocket"
)

// ServiceProxy handles proxying requests to microservices
type ServiceProxy struct {
	client   *http.Client
	services map[string]string
}

// NewServiceProxy creates a new service proxy
func NewServiceProxy(services map[string]string) *ServiceProxy {
	return &ServiceProxy{
		client: &http.Client{
			Timeout: 30 * time.Second,
		},
		services: services,
	}
}

// ProxyRequest proxies a request to the appropriate microservice
func (sp *ServiceProxy) ProxyRequest(serviceName string) gin.HandlerFunc {
	return sp.proxyWithPath(serviceName, "")
}

// ProxyRequestWithPath proxies a request with a custom target path
func (sp *ServiceProxy) ProxyRequestWithPath(serviceName string, targetPath string) gin.HandlerFunc {
	return sp.proxyWithPath(serviceName, targetPath)
}

// proxyWithPath is the internal proxy implementation
func (sp *ServiceProxy) proxyWithPath(serviceName string, targetPath string) gin.HandlerFunc {
	return func(c *gin.Context) {
		serviceURL, exists := sp.services[serviceName]
		if !exists {
			c.JSON(http.StatusNotFound, gin.H{"error": "service not found"})
			return
		}

		// Build target URL
		targetURL, err := url.Parse(serviceURL)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "invalid service URL"})
			return
		}

		// Use custom path if provided, otherwise preserve original path
		if targetPath != "" {
			// Replace path parameters like :teamId with actual values from the request
			finalPath := targetPath
			for _, param := range c.Params {
				finalPath = strings.Replace(finalPath, ":"+param.Key, param.Value, -1)
			}
			targetURL.Path = finalPath
		} else {
			targetURL.Path = c.Request.URL.Path
		}

		// Add user context to query string
		query := c.Request.URL.Query()
		if userID, exists := c.Get("user_id"); exists {
			if query.Get("user_id") == "" {
				query.Set("user_id", userID.(string))
			}
		}
		if teamID, exists := c.Get("team_id"); exists {
			if query.Get("team_id") == "" {
				query.Set("team_id", teamID.(string))
			}
		}
		targetURL.RawQuery = query.Encode()

		// Read request body
		var bodyBytes []byte
		if c.Request.Body != nil {
			bodyBytes, err = io.ReadAll(c.Request.Body)
			if err != nil {
				c.JSON(http.StatusBadRequest, gin.H{"error": "failed to read request body"})
				return
			}
		}

		// Create new request
		req, err := http.NewRequest(c.Request.Method, targetURL.String(), bytes.NewBuffer(bodyBytes))
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to create request"})
			return
		}

		// Copy headers from original request
		sp.copyHeaders(c.Request.Header, req.Header)

		// Add service authentication and user context headers
		sp.addServiceHeaders(c, req)

		// Make the request
		resp, err := sp.client.Do(req)
		if err != nil {
			c.JSON(http.StatusBadGateway, gin.H{"error": "service unavailable"})
			return
		}
		defer resp.Body.Close()

		// Copy response headers
		sp.copyHeaders(resp.Header, c.Writer.Header())

		// Set status code
		c.Status(resp.StatusCode)

		// Copy response body
		io.Copy(c.Writer, resp.Body)
	}
}

// copyHeaders copies HTTP headers from source to destination
func (sp *ServiceProxy) copyHeaders(src, dst http.Header) {
	for key, values := range src {
		// Skip hop-by-hop headers
		if sp.isHopByHopHeader(key) {
			continue
		}

		for _, value := range values {
			dst.Add(key, value)
		}
	}
}

// isHopByHopHeader checks if a header is hop-by-hop or should be skipped
func (sp *ServiceProxy) isHopByHopHeader(header string) bool {
	// Headers that should not be copied from backend responses
	skipHeaders := []string{
		// Hop-by-hop headers
		"Connection",
		"Keep-Alive",
		"Proxy-Authenticate",
		"Proxy-Authorization",
		"Te",
		"Trailers",
		"Transfer-Encoding",
		"Upgrade",
		// CORS headers - these are handled by the gateway's CORS middleware
		// Copying them from backend would cause duplicate values
		"Access-Control-Allow-Origin",
		"Access-Control-Allow-Methods",
		"Access-Control-Allow-Headers",
		"Access-Control-Allow-Credentials",
		"Access-Control-Expose-Headers",
		"Access-Control-Max-Age",
	}

	header = strings.ToLower(header)
	for _, skipHeader := range skipHeaders {
		if strings.ToLower(skipHeader) == header {
			return true
		}
	}
	return false
}

// addServiceHeaders adds service authentication and user context headers
func (sp *ServiceProxy) addServiceHeaders(c *gin.Context, req *http.Request) {
	// Add service authentication header
	req.Header.Set("X-Service-Auth", "internal-service")

	// Forward user context headers
	if userID, exists := c.Get("user_id"); exists {
		req.Header.Set("X-User-ID", userID.(string))
	}
	if userEmail, exists := c.Get("user_email"); exists {
		req.Header.Set("X-User-Email", userEmail.(string))
	}
	if userRole, exists := c.Get("user_role"); exists {
		req.Header.Set("X-User-Role", userRole.(string))
	}
	if displayName, exists := c.Get("user_display_name"); exists {
		req.Header.Set("X-User-DisplayName", displayName.(string))
	}
	if teamID, exists := c.Get("team_id"); exists {
		req.Header.Set("X-Team-ID", teamID.(string))
	}

	// Add request ID for tracing
	requestID := c.GetHeader("X-Request-ID")
	if requestID == "" {
		requestID = generateRequestID()
	}
	req.Header.Set("X-Request-ID", requestID)
}

// generateRequestID generates a simple request ID
func generateRequestID() string {
	return fmt.Sprintf("%d", time.Now().UnixNano())
}

// HealthCheckProxy creates a health check proxy for all services
func (sp *ServiceProxy) HealthCheckProxy() gin.HandlerFunc {
	return func(c *gin.Context) {
		results := make(map[string]interface{})

		for serviceName, serviceURL := range sp.services {
			healthURL := serviceURL + "/health"

			req, err := http.NewRequest("GET", healthURL, nil)
			if err != nil {
				results[serviceName] = map[string]interface{}{
					"status": "error",
					"error":  "failed to create request",
				}
				continue
			}

			// Set timeout for health checks
			client := &http.Client{Timeout: 5 * time.Second}
			resp, err := client.Do(req)
			if err != nil {
				results[serviceName] = map[string]interface{}{
					"status": "unhealthy",
					"error":  err.Error(),
				}
				continue
			}
			defer resp.Body.Close()

			if resp.StatusCode == http.StatusOK {
				results[serviceName] = map[string]interface{}{
					"status": "healthy",
				}
			} else {
				results[serviceName] = map[string]interface{}{
					"status": "unhealthy",
					"code":   resp.StatusCode,
				}
			}
		}

		// Determine overall health
		overallHealthy := true
		for _, result := range results {
			if resultMap, ok := result.(map[string]interface{}); ok {
				if status, ok := resultMap["status"].(string); ok && status != "healthy" {
					overallHealthy = false
					break
				}
			}
		}

		status := http.StatusOK
		if !overallHealthy {
			status = http.StatusServiceUnavailable
		}

		c.JSON(status, gin.H{
			"status":    map[string]bool{"healthy": overallHealthy},
			"services":  results,
			"timestamp": time.Now().Format(time.RFC3339),
		})
	}
}

// WebSocket upgrader for proxying
var wsUpgrader = websocket.Upgrader{
	CheckOrigin: func(r *http.Request) bool {
		return true // Allow all origins for now
	},
}

// ProxyWebSocket proxies WebSocket connections to a service
func (sp *ServiceProxy) ProxyWebSocket(serviceName string, targetPath string) gin.HandlerFunc {
	return func(c *gin.Context) {
		serviceURL, exists := sp.services[serviceName]
		if !exists {
			c.JSON(http.StatusNotFound, gin.H{"error": "service not found"})
			return
		}

		// Parse service URL
		targetURL, err := url.Parse(serviceURL)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "invalid service URL"})
			return
		}

		// Build WebSocket URL
		wsScheme := "ws"
		if targetURL.Scheme == "https" {
			wsScheme = "wss"
		}

		// Build query params: start with client's original params, then inject auth context
		query := c.Request.URL.Query()
		if userID, exists := c.Get("user_id"); exists {
			if query.Get("user_id") == "" {
				query.Set("user_id", userID.(string))
			}
		}
		if teamID, exists := c.Get("team_id"); exists {
			if query.Get("team_id") == "" {
				query.Set("team_id", teamID.(string))
			}
		}
		// Pass the original token for the location service to verify
		if token := c.Query("token"); token != "" {
			query.Set("token", token)
		}

		wsURL := fmt.Sprintf("%s://%s%s", wsScheme, targetURL.Host, targetPath)
		if encoded := query.Encode(); encoded != "" {
			wsURL += "?" + encoded
		}

		// Connect to backend WebSocket
		backendHeaders := http.Header{}
		// Forward authorization header
		if auth := c.GetHeader("Authorization"); auth != "" {
			backendHeaders.Set("Authorization", auth)
		}

		backendConn, _, err := websocket.DefaultDialer.Dial(wsURL, backendHeaders)
		if err != nil {
			c.JSON(http.StatusBadGateway, gin.H{"error": "failed to connect to backend WebSocket: " + err.Error()})
			return
		}
		defer backendConn.Close()

		// Upgrade client connection
		clientConn, err := wsUpgrader.Upgrade(c.Writer, c.Request, nil)
		if err != nil {
			return
		}
		defer clientConn.Close()

		// Create channels to signal when a connection is closed
		done := make(chan struct{})

		// Proxy messages from client to backend
		go func() {
			defer close(done)
			for {
				messageType, message, err := clientConn.ReadMessage()
				if err != nil {
					return
				}
				if err := backendConn.WriteMessage(messageType, message); err != nil {
					return
				}
			}
		}()

		// Proxy messages from backend to client
		for {
			messageType, message, err := backendConn.ReadMessage()
			if err != nil {
				break
			}
			if err := clientConn.WriteMessage(messageType, message); err != nil {
				break
			}
		}

		<-done
	}
}

// GetServiceURL returns the URL for a service (for external use)
func (sp *ServiceProxy) GetServiceURL(serviceName string) (string, bool) {
	url, exists := sp.services[serviceName]
	return url, exists
}
