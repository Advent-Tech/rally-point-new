package handler

import (
	"net/http"
	"strconv"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"rally-point/survey-service/internal/domain"
	"github.com/rally-point/shared/auth"
)

type SurveyHandler struct {
	surveyService domain.SurveyService
	jwtManager    *auth.JWTManager
}

// NewSurveyHandler creates a new survey handler
func NewSurveyHandler(surveyService domain.SurveyService, jwtManager *auth.JWTManager) *SurveyHandler {
	return &SurveyHandler{
		surveyService: surveyService,
		jwtManager:    jwtManager,
	}
}

// CreateSurvey handles survey creation
func (h *SurveyHandler) CreateSurvey(c *gin.Context) {
	userID := c.GetString("user_id")
	if userID == "" {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
		return
	}

	id, err := uuid.Parse(userID)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid user ID"})
		return
	}

	var req domain.CreateSurveyRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	survey, err := h.surveyService.CreateSurvey(id, &req)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusCreated, survey)
}

// ListSurveys handles listing all surveys (for admin)
func (h *SurveyHandler) ListSurveys(c *gin.Context) {
	userID := c.GetString("user_id")
	if userID == "" {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
		return
	}

	// Get all surveys from the repository
	surveys, err := h.surveyService.GetAllSurveys()
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"surveys": surveys,
		"count":   len(surveys),
	})
}

// GetSurvey handles getting a survey by ID
func (h *SurveyHandler) GetSurvey(c *gin.Context) {
	surveyIDStr := c.Param("id")
	surveyID, err := uuid.Parse(surveyIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid survey ID"})
		return
	}

	survey, err := h.surveyService.GetSurvey(surveyID)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, survey)
}

// UpdateSurvey handles survey updates
func (h *SurveyHandler) UpdateSurvey(c *gin.Context) {
	surveyIDStr := c.Param("id")
	surveyID, err := uuid.Parse(surveyIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid survey ID"})
		return
	}

	var req domain.UpdateSurveyRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	survey, err := h.surveyService.UpdateSurvey(surveyID, &req)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, survey)
}

// DeleteSurvey handles survey deletion
func (h *SurveyHandler) DeleteSurvey(c *gin.Context) {
	surveyIDStr := c.Param("id")
	surveyID, err := uuid.Parse(surveyIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid survey ID"})
		return
	}

	err = h.surveyService.DeleteSurvey(surveyID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "survey deleted successfully"})
}

// GetTeamSurveys handles getting surveys for a team
func (h *SurveyHandler) GetTeamSurveys(c *gin.Context) {
	teamIDStr := c.Param("teamId")
	teamID, err := uuid.Parse(teamIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid team ID"})
		return
	}

	surveys, err := h.surveyService.GetTeamSurveys(teamID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"surveys": surveys,
		"count":   len(surveys),
	})
}

// GetUserSurveys handles getting surveys created by a user
func (h *SurveyHandler) GetUserSurveys(c *gin.Context) {
	userID := c.GetString("user_id")
	if userID == "" {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
		return
	}

	id, err := uuid.Parse(userID)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid user ID"})
		return
	}

	surveys, err := h.surveyService.GetUserSurveys(id)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"surveys": surveys,
		"count":   len(surveys),
	})
}

// SubmitResponse handles survey response submission
func (h *SurveyHandler) SubmitResponse(c *gin.Context) {
	userID := c.GetString("user_id")
	if userID == "" {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
		return
	}

	id, err := uuid.Parse(userID)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid user ID"})
		return
	}

	var req domain.SubmitResponseRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	response, err := h.surveyService.SubmitResponse(id, &req)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusCreated, response)
}

// SubmitSurveyResponse handles survey response submission with survey ID from URL
func (h *SurveyHandler) SubmitSurveyResponse(c *gin.Context) {
	userID := c.GetString("user_id")
	if userID == "" {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
		return
	}

	userUUID, err := uuid.Parse(userID)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid user ID"})
		return
	}

	surveyIDStr := c.Param("id")
	surveyID, err := uuid.Parse(surveyIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid survey ID"})
		return
	}

	var req domain.SubmitResponseRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	// Override survey ID from URL parameter
	req.SurveyID = surveyID

	response, err := h.surveyService.SubmitResponse(userUUID, &req)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusCreated, response)
}

// GetSurveyResponses handles getting responses for a survey
func (h *SurveyHandler) GetSurveyResponses(c *gin.Context) {
	surveyIDStr := c.Param("id")
	surveyID, err := uuid.Parse(surveyIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid survey ID"})
		return
	}

	// Parse pagination parameters
	limitStr := c.DefaultQuery("limit", "50")
	offsetStr := c.DefaultQuery("offset", "0")

	limit, err := strconv.Atoi(limitStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid limit parameter"})
		return
	}

	offset, err := strconv.Atoi(offsetStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid offset parameter"})
		return
	}

	responses, err := h.surveyService.GetSurveyResponses(surveyID, limit, offset)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"responses": responses,
		"count":     len(responses),
	})
}

// GetUserResponses handles getting responses for a user
func (h *SurveyHandler) GetUserResponses(c *gin.Context) {
	userID := c.GetString("user_id")
	if userID == "" {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
		return
	}

	id, err := uuid.Parse(userID)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid user ID"})
		return
	}

	// Parse pagination parameters
	limitStr := c.DefaultQuery("limit", "50")
	offsetStr := c.DefaultQuery("offset", "0")

	limit, err := strconv.Atoi(limitStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid limit parameter"})
		return
	}

	offset, err := strconv.Atoi(offsetStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid offset parameter"})
		return
	}

	responses, err := h.surveyService.GetUserResponses(id, limit, offset)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"responses": responses,
		"count":     len(responses),
	})
}

// AssignSurvey handles survey assignment
func (h *SurveyHandler) AssignSurvey(c *gin.Context) {
	userID := c.GetString("user_id")
	if userID == "" {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
		return
	}

	id, err := uuid.Parse(userID)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid user ID"})
		return
	}

	var req domain.AssignSurveyRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	err = h.surveyService.AssignSurvey(id, &req)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "survey assigned successfully"})
}

// AssignSurveyToWorkers handles assigning a survey to workers via URL path
// POST /surveys/:id/assignments
func (h *SurveyHandler) AssignSurveyToWorkers(c *gin.Context) {
	userID := c.GetString("user_id")
	if userID == "" {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
		return
	}

	assignerID, err := uuid.Parse(userID)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid user ID"})
		return
	}

	// Get survey ID from URL path
	surveyIDStr := c.Param("id")
	surveyID, err := uuid.Parse(surveyIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid survey ID"})
		return
	}

	// Parse request body with worker_ids
	var body struct {
		WorkerIDs []uuid.UUID `json:"worker_ids" binding:"required,min=1"`
		DueDate   *time.Time  `json:"due_date,omitempty"`
	}
	if err := c.ShouldBindJSON(&body); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	// Create assign request
	req := &domain.AssignSurveyRequest{
		SurveyID: surveyID,
		UserIDs:  body.WorkerIDs,
		DueDate:  body.DueDate,
	}

	err = h.surveyService.AssignSurvey(assignerID, req)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"message":      "survey assigned successfully",
		"worker_count": len(body.WorkerIDs),
	})
}

// GetUserAssignments handles getting assignments for a user
func (h *SurveyHandler) GetUserAssignments(c *gin.Context) {
	userID := c.GetString("user_id")
	if userID == "" {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
		return
	}

	id, err := uuid.Parse(userID)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid user ID"})
		return
	}

	assignments, err := h.surveyService.GetUserAssignments(id)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"assignments": assignments,
		"count":       len(assignments),
	})
}

// GetSurveyAnalytics handles getting survey analytics
func (h *SurveyHandler) GetSurveyAnalytics(c *gin.Context) {
	surveyIDStr := c.Param("id")
	surveyID, err := uuid.Parse(surveyIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid survey ID"})
		return
	}

	analytics, err := h.surveyService.GetSurveyAnalytics(surveyID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, analytics)
}

// GetTeamSurveyStats handles getting team survey statistics
func (h *SurveyHandler) GetTeamSurveyStats(c *gin.Context) {
	teamIDStr := c.Param("teamId")
	teamID, err := uuid.Parse(teamIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid team ID"})
		return
	}

	stats, err := h.surveyService.GetTeamSurveyStats(teamID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, stats)
}

// AuthMiddleware validates JWT tokens
func (h *SurveyHandler) AuthMiddleware() gin.HandlerFunc {
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

// HealthCheck handles health check
func (h *SurveyHandler) HealthCheck(c *gin.Context) {
	c.JSON(http.StatusOK, gin.H{
		"status":    "healthy",
		"service":   "survey-service",
		"timestamp": time.Now().Format(time.RFC3339),
	})
}

// GetWorkerSurveyStats handles getting survey statistics for a specific worker
// Accessible by team leaders and admins
func (h *SurveyHandler) GetWorkerSurveyStats(c *gin.Context) {
	// Verify caller is authenticated
	callerRole := c.GetString("user_role")
	if callerRole != "admin" && callerRole != "team_leader" {
		c.JSON(http.StatusForbidden, gin.H{"error": "insufficient permissions"})
		return
	}

	workerIDStr := c.Param("workerId")
	workerID, err := uuid.Parse(workerIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid worker ID"})
		return
	}

	// Get assignments for this worker
	assignments, err := h.surveyService.GetUserAssignments(workerID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	// Get responses for this worker
	responses, err := h.surveyService.GetUserResponses(workerID, 1000, 0)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	// Calculate stats
	now := time.Now()
	today := time.Date(now.Year(), now.Month(), now.Day(), 0, 0, 0, 0, now.Location())
	weekAgo := today.AddDate(0, 0, -7)
	monthAgo := today.AddDate(0, -1, 0)

	assignedCount := len(assignments)
	completedCount := 0
	pendingCount := 0
	overdueCount := 0
	todayCompleted := 0
	weekCompleted := 0
	monthCompleted := 0

	// Count completed assignments
	for _, assignment := range assignments {
		if assignment.IsCompleted {
			completedCount++
		} else {
			pendingCount++
			// Check if overdue
			if assignment.DueDate != nil && assignment.DueDate.Before(now) {
				overdueCount++
			}
		}
	}

	// Count responses by time period
	for _, resp := range responses {
		if resp.Response != nil {
			responseTime := resp.Response.SubmittedAt
			if responseTime.After(today) {
				todayCompleted++
			}
			if responseTime.After(weekAgo) {
				weekCompleted++
			}
			if responseTime.After(monthAgo) {
				monthCompleted++
			}
		}
	}

	// Calculate completion rate
	var completionRate float64
	if assignedCount > 0 {
		completionRate = float64(completedCount) / float64(assignedCount) * 100
	}

	stats := domain.WorkerSurveyStats{
		WorkerID:       workerID,
		AssignedCount:  assignedCount,
		CompletedCount: completedCount,
		PendingCount:   pendingCount,
		OverdueCount:   overdueCount,
		CompletionRate: completionRate,
		TodayCompleted: todayCompleted,
		WeekCompleted:  weekCompleted,
		MonthCompleted: monthCompleted,
	}

	c.JSON(http.StatusOK, stats)
}

// AddQuestion handles adding a new question to a survey
func (h *SurveyHandler) AddQuestion(c *gin.Context) {
	surveyIDStr := c.Param("id")
	surveyID, err := uuid.Parse(surveyIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid survey ID"})
		return
	}

	var req domain.CreateQuestionRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	question, err := h.surveyService.AddQuestion(surveyID, &req)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusCreated, question)
}

// UpdateQuestion handles updating a survey question
func (h *SurveyHandler) UpdateQuestion(c *gin.Context) {
	surveyIDStr := c.Param("id")
	surveyID, err := uuid.Parse(surveyIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid survey ID"})
		return
	}

	questionIDStr := c.Param("questionId")
	questionID, err := uuid.Parse(questionIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid question ID"})
		return
	}

	var req domain.UpdateQuestionRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	question, err := h.surveyService.UpdateQuestion(surveyID, questionID, &req)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, question)
}

// DeleteQuestion handles deleting a survey question
func (h *SurveyHandler) DeleteQuestion(c *gin.Context) {
	surveyIDStr := c.Param("id")
	surveyID, err := uuid.Parse(surveyIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid survey ID"})
		return
	}

	questionIDStr := c.Param("questionId")
	questionID, err := uuid.Parse(questionIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid question ID"})
		return
	}

	err = h.surveyService.DeleteQuestion(surveyID, questionID)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "question deleted successfully"})
}

// ReorderQuestions handles reordering survey questions
func (h *SurveyHandler) ReorderQuestions(c *gin.Context) {
	surveyIDStr := c.Param("id")
	surveyID, err := uuid.Parse(surveyIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid survey ID"})
		return
	}

	var req domain.ReorderQuestionsRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	err = h.surveyService.ReorderQuestions(surveyID, &req)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "questions reordered successfully"})
}
