package handler

import (
	"net/http"

	"rally-point/user-service/internal/domain"

	"github.com/gin-gonic/gin"
)

// VerificationHandler handles email verification and password reset requests
type VerificationHandler struct {
	verificationService domain.VerificationService
}

// NewVerificationHandler creates a new verification handler
func NewVerificationHandler(verificationService domain.VerificationService) *VerificationHandler {
	return &VerificationHandler{
		verificationService: verificationService,
	}
}

// ResendVerificationEmail handles resending verification email
// POST /api/auth/resend-verification
func (h *VerificationHandler) ResendVerificationEmail(c *gin.Context) {
	var req domain.RequestEmailVerificationRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "valid email is required"})
		return
	}

	// Always return success to prevent email enumeration
	// The service will silently handle non-existent or already verified emails
	_ = h.verificationService.ResendVerificationEmail(req.Email)

	c.JSON(http.StatusOK, domain.VerificationResponse{
		Message: "If an account exists with this email and is not yet verified, a verification email has been sent.",
		Success: true,
	})
}

// VerifyEmail handles email verification
// POST /api/auth/verify-email
func (h *VerificationHandler) VerifyEmail(c *gin.Context) {
	var req domain.VerifyEmailRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "token is required"})
		return
	}

	if err := h.verificationService.VerifyEmail(req.Token); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"error":   err.Error(),
			"success": false,
		})
		return
	}

	c.JSON(http.StatusOK, domain.VerificationResponse{
		Message: "Email verified successfully. You can now await approval from the administrator.",
		Success: true,
	})
}

// ForgotPassword handles forgot password request
// POST /api/auth/forgot-password
func (h *VerificationHandler) ForgotPassword(c *gin.Context) {
	var req domain.ForgotPasswordRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "valid email is required"})
		return
	}

	// Always return success to prevent email enumeration
	// The service will silently handle non-existent emails
	_ = h.verificationService.RequestPasswordReset(req.Email)

	c.JSON(http.StatusOK, domain.VerificationResponse{
		Message: "If an account exists with this email, a password reset link has been sent.",
		Success: true,
	})
}

// ResetPassword handles password reset
// POST /api/auth/reset-password
func (h *VerificationHandler) ResetPassword(c *gin.Context) {
	var req domain.TokenResetPasswordRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "token and new_password are required"})
		return
	}

	if len(req.NewPassword) < 8 {
		c.JSON(http.StatusBadRequest, gin.H{
			"error":   "password must be at least 8 characters",
			"success": false,
		})
		return
	}

	if err := h.verificationService.ResetPassword(req.Token, req.NewPassword); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"error":   err.Error(),
			"success": false,
		})
		return
	}

	c.JSON(http.StatusOK, domain.VerificationResponse{
		Message: "Password reset successfully. Please login with your new password.",
		Success: true,
	})
}
