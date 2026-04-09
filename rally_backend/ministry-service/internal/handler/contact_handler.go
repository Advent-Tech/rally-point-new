package handler

import (
	"net/http"
	"strconv"
	"time"

	"rally-point/ministry-service/internal/domain"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"github.com/rally-point/shared/auth"
)

type MinistryContactHandler struct {
	service    domain.MinistryContactService
	jwtManager *auth.JWTManager
}

// NewMinistryContactHandler creates a new handler
func NewMinistryContactHandler(service domain.MinistryContactService, jwtManager *auth.JWTManager) *MinistryContactHandler {
	return &MinistryContactHandler{
		service:    service,
		jwtManager: jwtManager,
	}
}

// CreateContact handles contact creation
func (h *MinistryContactHandler) CreateContact(c *gin.Context) {
	userID := c.GetString("user_id")
	if userID == "" {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
		return
	}

	creatorID, err := uuid.Parse(userID)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid user ID"})
		return
	}

	var req domain.CreateMinistryContactRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	contact, err := h.service.CreateContact(creatorID, &req)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusCreated, contact)
}

// GetContact handles getting a contact by ID
func (h *MinistryContactHandler) GetContact(c *gin.Context) {
	idStr := c.Param("id")
	id, err := uuid.Parse(idStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid contact ID"})
		return
	}

	contact, err := h.service.GetContact(id)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, contact)
}

// UpdateContact handles updating a contact
func (h *MinistryContactHandler) UpdateContact(c *gin.Context) {
	idStr := c.Param("id")
	id, err := uuid.Parse(idStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid contact ID"})
		return
	}

	var req domain.UpdateMinistryContactRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	contact, err := h.service.UpdateContact(id, &req)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, contact)
}

// DeleteContact handles deleting a contact
func (h *MinistryContactHandler) DeleteContact(c *gin.Context) {
	idStr := c.Param("id")
	id, err := uuid.Parse(idStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid contact ID"})
		return
	}

	if err := h.service.DeleteContact(id); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "ministry contact deleted successfully"})
}

// ListContacts handles listing contacts (optionally filtered by worker and date range)
func (h *MinistryContactHandler) ListContacts(c *gin.Context) {
	var (
		workerID *uuid.UUID
		start    *time.Time
		end      *time.Time
	)

	if workerIDStr := c.Query("worker_id"); workerIDStr != "" {
		id, err := uuid.Parse(workerIDStr)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "invalid worker_id"})
			return
		}
		workerID = &id
	}

	if startStr := c.Query("start_date"); startStr != "" {
		if t, err := time.Parse(time.RFC3339, startStr); err == nil {
			start = &t
		} else {
			c.JSON(http.StatusBadRequest, gin.H{"error": "invalid start_date"})
			return
		}
	}

	if endStr := c.Query("end_date"); endStr != "" {
		if t, err := time.Parse(time.RFC3339, endStr); err == nil {
			end = &t
		} else {
			c.JSON(http.StatusBadRequest, gin.H{"error": "invalid end_date"})
			return
		}
	}

	contacts, err := h.service.ListContacts(workerID, start, end)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, contacts)
}

// GetStats handles getting worker stats
func (h *MinistryContactHandler) GetStats(c *gin.Context) {
	workerIDStr := c.Query("worker_id")
	if workerIDStr == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "worker_id is required"})
		return
	}

	workerID, err := uuid.Parse(workerIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid worker_id"})
		return
	}

	daysStr := c.DefaultQuery("days", "30")
	days, err := strconv.Atoi(daysStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid days"})
		return
	}

	stats, err := h.service.GetStats(workerID, days)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, stats)
}

// ExportContacts handles exporting contacts
func (h *MinistryContactHandler) ExportContacts(c *gin.Context) {
	var workerID *uuid.UUID
	if workerIDStr := c.Query("worker_id"); workerIDStr != "" {
		id, err := uuid.Parse(workerIDStr)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "invalid worker_id"})
			return
		}
		workerID = &id
	}

	format := c.DefaultQuery("format", "csv")
	if format != "csv" && format != "json" && format != "pdf" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid format"})
		return
	}

	userID := c.GetString("user_id")
	if userID == "" {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
		return
	}

	data, err := h.service.ExportContacts(workerID, format, userID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, data)
}

// AuthMiddleware validates JWT tokens
func (h *MinistryContactHandler) AuthMiddleware() gin.HandlerFunc {
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

		claims, err := h.jwtManager.VerifyToken(token)
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

		c.Set("user_id", claims.UserID.String())
		c.Set("user_email", claims.Email)
		c.Set("user_role", claims.Role)
		if claims.TeamID != nil {
			c.Set("team_id", claims.TeamID.String())
		}

		c.Next()
	}
}

// HealthCheck handles health checks
func (h *MinistryContactHandler) HealthCheck(c *gin.Context) {
	c.JSON(http.StatusOK, gin.H{
		"status":    "healthy",
		"service":   "ministry-service",
		"timestamp": time.Now().Format(time.RFC3339),
	})
}
