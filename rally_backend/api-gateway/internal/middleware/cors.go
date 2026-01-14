package middleware

import (
	"net/http"

	"github.com/gin-gonic/gin"
)

// CORSMiddleware handles Cross-Origin Resource Sharing
func CORSMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		origin := c.GetHeader("Origin")

		// In development, allow all localhost origins (Flutter web uses dynamic ports)
		// For production, this should be restricted to specific domains
		if origin != "" {
			c.Header("Access-Control-Allow-Origin", origin)
		} else {
			// Fallback for requests without Origin header
			c.Header("Access-Control-Allow-Origin", "*")
		}

		c.Header("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS, PATCH, HEAD")
		c.Header("Access-Control-Allow-Headers", "Origin, Content-Type, Authorization, X-Requested-With, X-User-ID, X-Team-ID, Accept")
		c.Header("Access-Control-Expose-Headers", "X-RateLimit-Remaining, X-RateLimit-Reset, Content-Length")
		c.Header("Access-Control-Allow-Credentials", "true")
		c.Header("Access-Control-Max-Age", "86400") // 24 hours

		// Handle preflight requests immediately
		if c.Request.Method == "OPTIONS" {
			c.AbortWithStatus(http.StatusNoContent)
			return
		}

		c.Next()
	}
}
