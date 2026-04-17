package handler

import (
	"net/http"
	"strings"

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

// VerifyEmailFromLink handles email verification from direct browser link
// GET /api/auth/verify-email/:token
func (h *VerificationHandler) VerifyEmailFromLink(c *gin.Context) {
	token := c.Param("token")
	if strings.TrimSpace(token) == "" {
		c.Data(http.StatusBadRequest, "text/html; charset=utf-8", []byte(renderVerificationHTML(false, "Invalid verification link.")))
		return
	}

	err := h.verificationService.VerifyEmail(token)
	if err != nil {
		if strings.Contains(strings.ToLower(err.Error()), "already verified") {
			c.Data(http.StatusOK, "text/html; charset=utf-8", []byte(renderVerificationHTML(true, "Your email is already verified.")))
			return
		}
		c.Data(http.StatusBadRequest, "text/html; charset=utf-8", []byte(renderVerificationHTML(false, err.Error())))
		return
	}

	c.Data(http.StatusOK, "text/html; charset=utf-8", []byte(renderVerificationHTML(true, "Your email has been verified successfully.")))
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

func renderVerificationHTML(success bool, message string) string {
	statusTitle := "Verification Failed"
	statusColor := "#DC2626"
	bgColor := "#FEF2F2"
	borderColor := "#FECACA"
	if success {
		statusTitle = "Email Verified"
		statusColor = "#16A34A"
		bgColor = "#F0FDF4"
		borderColor = "#BBF7D0"
	}

	return `<!doctype html>
<html>
<head>
  <meta charset="utf-8"/>
  <meta name="viewport" content="width=device-width,initial-scale=1"/>
  <title>light point - Email Verification</title>
  <style>
    body { margin:0; font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Arial,sans-serif; background:#F8FAFC; color:#0F172A; }
    .wrap { min-height:100vh; display:flex; align-items:center; justify-content:center; padding:20px; }
    .card { width:100%; max-width:520px; background:#fff; border-radius:16px; border:1px solid #E2E8F0; box-shadow:0 8px 30px rgba(15,23,42,.08); padding:28px; }
    .brand { font-weight:700; font-size:28px; margin:0 0 12px; }
    .status { margin:0 0 10px; font-size:24px; font-weight:700; color:` + statusColor + `; }
    .msg { margin:0; font-size:16px; line-height:1.5; }
    .note { margin-top:18px; padding:12px 14px; border-radius:10px; border:1px solid ` + borderColor + `; background:` + bgColor + `; color:#334155; font-size:14px; }
  </style>
</head>
<body>
  <div class="wrap">
    <div class="card">
      <h1 class="brand">light point</h1>
      <h2 class="status">` + statusTitle + `</h2>
      <p class="msg">` + message + `</p>
      <div class="note">You can now return to the app and sign in.</div>
    </div>
  </div>
</body>
</html>`
}
