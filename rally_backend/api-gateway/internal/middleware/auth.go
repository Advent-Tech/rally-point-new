package middleware

import (
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/rally-point/shared/auth"
)

// AuthMiddleware validates JWT tokens
func AuthMiddleware(jwtManager *auth.JWTManager) gin.HandlerFunc {
	return func(c *gin.Context) {
		authHeader := c.GetHeader("Authorization")
		if authHeader == "" {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "authorization header required"})
			c.Abort()
			return
		}

		token := auth.ExtractTokenFromHeader(authHeader)
		if token == "" {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "invalid authorization header format"})
			c.Abort()
			return
		}

		claims, err := jwtManager.VerifyToken(token)
		if err != nil {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "invalid token"})
			c.Abort()
			return
		}

		if claims.TokenType != "access" {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "invalid token type"})
			c.Abort()
			return
		}

		// Set user context
		c.Set("user_id", claims.UserID.String())
		c.Set("user_email", claims.Email)
		c.Set("user_role", claims.Role)
		c.Set("user_display_name", claims.DisplayName)
		if claims.TeamID != nil {
			c.Set("team_id", claims.TeamID.String())
		}

		c.Next()
	}
}

// OptionalAuthMiddleware validates JWT tokens but doesn't require them
func OptionalAuthMiddleware(jwtManager *auth.JWTManager) gin.HandlerFunc {
	return func(c *gin.Context) {
		authHeader := c.GetHeader("Authorization")
		if authHeader == "" {
			c.Next()
			return
		}

		token := auth.ExtractTokenFromHeader(authHeader)
		if token == "" {
			c.Next()
			return
		}

		claims, err := jwtManager.VerifyToken(token)
		if err != nil {
			c.Next()
			return
		}

		if claims.TokenType == "access" {
			c.Set("user_id", claims.UserID.String())
			c.Set("user_email", claims.Email)
			c.Set("user_role", claims.Role)
			c.Set("user_display_name", claims.DisplayName)
			if claims.TeamID != nil {
				c.Set("team_id", claims.TeamID.String())
			}
		}

		c.Next()
	}
}

// RoleMiddleware checks if user has required role
func RoleMiddleware(requiredRoles ...string) gin.HandlerFunc {
	return func(c *gin.Context) {
		userRole, exists := c.Get("user_role")
		if !exists {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "user role not found"})
			c.Abort()
			return
		}

		role, ok := userRole.(string)
		if !ok {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "invalid user role"})
			c.Abort()
			return
		}

		// Check if user has any of the required roles
		for _, requiredRole := range requiredRoles {
			if role == requiredRole || role == "admin" { // Admin can access everything
				c.Next()
				return
			}
		}

		c.JSON(http.StatusForbidden, gin.H{"error": "insufficient permissions"})
		c.Abort()
	}
}

// TeamMiddleware ensures user belongs to the team in the request
func TeamMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		userTeamID, exists := c.Get("team_id")
		if !exists {
			c.JSON(http.StatusForbidden, gin.H{"error": "user not assigned to any team"})
			c.Abort()
			return
		}

		// Check if request contains team ID parameter
		requestTeamID := c.Param("teamId")
		if requestTeamID == "" {
			requestTeamID = c.Query("team_id")
		}

		if requestTeamID != "" && requestTeamID != userTeamID {
			c.JSON(http.StatusForbidden, gin.H{"error": "access denied to this team's resources"})
			c.Abort()
			return
		}

		c.Next()
	}
}

// ServiceAuthMiddleware adds service authentication headers for internal service calls
func ServiceAuthMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		// Add service authentication header
		c.Header("X-Service-Auth", "internal-service")

		// Forward user context to downstream services
		if userID, exists := c.Get("user_id"); exists {
			c.Header("X-User-ID", userID.(string))
		}
		if userEmail, exists := c.Get("user_email"); exists {
			c.Header("X-User-Email", userEmail.(string))
		}
		if userRole, exists := c.Get("user_role"); exists {
			c.Header("X-User-Role", userRole.(string))
		}
		if displayName, exists := c.Get("user_display_name"); exists {
			c.Header("X-User-DisplayName", displayName.(string))
		}
		if teamID, exists := c.Get("team_id"); exists {
			c.Header("X-Team-ID", teamID.(string))
		}

		c.Next()
	}
}
