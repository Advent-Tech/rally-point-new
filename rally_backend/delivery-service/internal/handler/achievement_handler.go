package handler

import (
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"rally-point/delivery-service/internal/domain"
	"rally-point/delivery-service/internal/service"
)

type AchievementHandler struct {
	achievementService *service.AchievementService
}

func NewAchievementHandler(achievementService *service.AchievementService) *AchievementHandler {
	return &AchievementHandler{
		achievementService: achievementService,
	}
}

type CreateAchievementRequest struct {
	Category      string  `json:"category" binding:"required"`
	Name          string  `json:"name" binding:"required"`
	Description   string  `json:"description"`
	Icon          string  `json:"icon"`
	Level         string  `json:"level" binding:"required"`
	LevelOrder    int     `json:"level_order"`
	CriteriaType  string  `json:"criteria_type" binding:"required"`
	CriteriaValue float64 `json:"criteria_value" binding:"required"`
	Points        int     `json:"points"`
}

func (h *AchievementHandler) GetAllAchievements(c *gin.Context) {
	achievements, err := h.achievementService.GetAllAchievements(c)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, achievements)
}

func (h *AchievementHandler) GetAchievementsByCategory(c *gin.Context) {
	category := c.Param("category")
	if category == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "category is required"})
		return
	}

	achievements, err := h.achievementService.GetAchievementsByCategory(c, category)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, achievements)
}

func (h *AchievementHandler) GetAchievementByID(c *gin.Context) {
	id := c.Param("id")
	achievementID, err := uuid.Parse(id)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid achievement ID"})
		return
	}

	achievement, err := h.achievementService.GetAchievementByID(c, achievementID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	if achievement == nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "achievement not found"})
		return
	}

	c.JSON(http.StatusOK, achievement)
}

func (h *AchievementHandler) CreateAchievement(c *gin.Context) {
	var req CreateAchievementRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	achievement := &domain.Achievement{
		Category:      domain.AchievementCategory(req.Category),
		Name:          req.Name,
		Description:   req.Description,
		Icon:          req.Icon,
		Level:         domain.AchievementLevel(req.Level),
		LevelOrder:    req.LevelOrder,
		CriteriaType:  req.CriteriaType,
		CriteriaValue: req.CriteriaValue,
		Points:        req.Points,
	}

	err := h.achievementService.CreateAchievement(c, achievement)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusCreated, achievement)
}

func (h *AchievementHandler) UpdateAchievement(c *gin.Context) {
	id := c.Param("id")
	achievementID, err := uuid.Parse(id)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid achievement ID"})
		return
	}

	var req CreateAchievementRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	achievement := &domain.Achievement{
		ID:            achievementID,
		Category:      domain.AchievementCategory(req.Category),
		Name:          req.Name,
		Description:   req.Description,
		Icon:          req.Icon,
		Level:         domain.AchievementLevel(req.Level),
		LevelOrder:    req.LevelOrder,
		CriteriaType:  req.CriteriaType,
		CriteriaValue: req.CriteriaValue,
		Points:        req.Points,
	}

	err = h.achievementService.UpdateAchievement(c, achievement)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "achievement updated"})
}

func (h *AchievementHandler) DeleteAchievement(c *gin.Context) {
	id := c.Param("id")
	achievementID, err := uuid.Parse(id)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid achievement ID"})
		return
	}

	err = h.achievementService.DeleteAchievement(c, achievementID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "achievement deleted"})
}

func (h *AchievementHandler) GetWorkerAchievements(c *gin.Context) {
	userID := c.GetString("user_id")
	workerID, err := uuid.Parse(userID)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid user ID"})
		return
	}

	achievements, err := h.achievementService.GetWorkerAchievements(c, workerID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, achievements)
}

func (h *AchievementHandler) GetWorkerAchievementsByCategory(c *gin.Context) {
	userID := c.GetString("user_id")
	workerID, err := uuid.Parse(userID)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid user ID"})
		return
	}

	category := c.Param("category")
	if category == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "category is required"})
		return
	}

	achievements, err := h.achievementService.GetWorkerAchievementsByCategory(c, workerID, category)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, achievements)
}

func (h *AchievementHandler) GetWorkerLevel(c *gin.Context) {
	userID := c.GetString("user_id")
	workerID, err := uuid.Parse(userID)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid user ID"})
		return
	}

	level, err := h.achievementService.GetWorkerLevel(c, workerID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, level)
}

func (h *AchievementHandler) GetWorkerStats(c *gin.Context) {
	userID := c.GetString("user_id")
	workerID, err := uuid.Parse(userID)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid user ID"})
		return
	}

	stats, err := h.achievementService.GetWorkerStats(c, workerID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, stats)
}
