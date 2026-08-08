package handler

import (
	"net/http"

	"rally-point/user-service/internal/domain"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
)

type SuperAdminHandler struct {
	superAdminService domain.SuperAdminService
}

// NewSuperAdminHandler creates a new superadmin handler
func NewSuperAdminHandler(superAdminService domain.SuperAdminService) *SuperAdminHandler {
	return &SuperAdminHandler{
		superAdminService: superAdminService,
	}
}

// CreateAdmin handles admin account creation
// POST /api/superadmin/admins
func (h *SuperAdminHandler) CreateAdmin(c *gin.Context) {
	var req domain.CreateAdminRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	admin, err := h.superAdminService.CreateAdmin(&req)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusCreated, gin.H{
		"message": "Admin account created successfully",
		"admin":   admin,
	})
}

// InviteAdmin handles inviting an admin/superadmin by email
// POST /api/superadmin/admins/invite
func (h *SuperAdminHandler) InviteAdmin(c *gin.Context) {
	var req domain.InviteAdminRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	err := h.superAdminService.InviteAdmin(&req)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"message": "Invitation sent successfully",
	})
}

// ListAdmins handles listing all admin accounts
// GET /api/superadmin/admins
func (h *SuperAdminHandler) ListAdmins(c *gin.Context) {
	response, err := h.superAdminService.GetAllAdmins()
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, response)
}

// GetAdmin handles getting a specific admin
// GET /api/superadmin/admins/:id
func (h *SuperAdminHandler) GetAdmin(c *gin.Context) {
	idStr := c.Param("id")
	id, err := uuid.Parse(idStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid admin ID"})
		return
	}

	admin, err := h.superAdminService.GetAdminByID(id)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, admin)
}

// DeleteAdmin handles admin account deletion
// DELETE /api/superadmin/admins/:id
func (h *SuperAdminHandler) DeleteAdmin(c *gin.Context) {
	idStr := c.Param("id")
	id, err := uuid.Parse(idStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid admin ID"})
		return
	}

	currentUserID := c.GetString("user_id")
	if currentUserID != "" {
		currentID, err := uuid.Parse(currentUserID)
		if err == nil && currentID == id {
			c.JSON(http.StatusBadRequest, gin.H{"error": "you cannot delete your own account"})
			return
		}
	}

	err = h.superAdminService.DeleteAdmin(id)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "Admin account deleted successfully"})
}

// ResetAdminPassword handles resetting an admin's password
// PUT /api/superadmin/admins/:id/reset-password
func (h *SuperAdminHandler) ResetAdminPassword(c *gin.Context) {
	idStr := c.Param("id")
	id, err := uuid.Parse(idStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid admin ID"})
		return
	}

	var req domain.ResetPasswordRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	err = h.superAdminService.ResetAdminPassword(id, req.NewPassword)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "Admin password reset successfully"})
}

// SuperAdminMiddleware ensures only superadmin can access certain routes
func SuperAdminMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		role := c.GetString("user_role")
		if role != domain.RoleSuperAdmin {
			c.JSON(http.StatusForbidden, gin.H{"error": "superadmin access required"})
			c.Abort()
			return
		}
		c.Next()
	}
}
