package domain

import (
	"time"

	"github.com/google/uuid"
)

type AchievementCategory string
type AchievementLevel string

const (
	AchievementCategoryTerritory AchievementCategory = "territory"
	AchievementCategoryDonation  AchievementCategory = "donation"
	AchievementCategoryBookSale  AchievementCategory = "book_sale"
	AchievementCategoryPrayer    AchievementCategory = "prayer"
	AchievementCategoryVisit     AchievementCategory = "visit"
	AchievementCategoryStreak    AchievementCategory = "streak"
	AchievementCategorySession   AchievementCategory = "session"
	AchievementCategoryTeam      AchievementCategory = "team"
)

const (
	AchievementLevelBronze   AchievementLevel = "bronze"
	AchievementLevelSilver   AchievementLevel = "silver"
	AchievementLevelGold     AchievementLevel = "gold"
	AchievementLevelPlatinum AchievementLevel = "platinum"
)

// Achievement represents an achievement definition
type Achievement struct {
	ID            uuid.UUID           `json:"id"`
	Category      AchievementCategory `json:"category"`
	Name          string              `json:"name"`
	Description   string              `json:"description"`
	Icon          string              `json:"icon"`
	Level         AchievementLevel    `json:"level"`
	LevelOrder    int                 `json:"level_order"`
	CriteriaType  string              `json:"criteria_type"`
	CriteriaValue float64             `json:"criteria_value"`
	Points        int                 `json:"points"`
	IsActive      bool                `json:"is_active"`
	CreatedAt     time.Time           `json:"created_at"`
}

// WorkerAchievement represents a worker's earned achievement
type WorkerAchievement struct {
	ID            uuid.UUID    `json:"id"`
	WorkerID      uuid.UUID    `json:"worker_id"`
	AchievementID uuid.UUID    `json:"achievement_id"`
	Achievement   *Achievement `json:"achievement,omitempty"`
	EarnedAt      time.Time    `json:"earned_at"`
	Progress      float64      `json:"progress"`
}

// WorkerLevel represents a worker's overall level and points
type WorkerLevel struct {
	WorkerID        uuid.UUID `json:"worker_id"`
	TotalPoints     int       `json:"total_points"`
	CurrentLevel    string    `json:"current_level"`
	LevelProgress   float64   `json:"level_progress"`
	TerritoryBadges int       `json:"territory_badges"`
	DonationBadges  int       `json:"donation_badges"`
	BookSaleBadges  int       `json:"book_sale_badges"`
	PrayerBadges    int       `json:"prayer_badges"`
	VisitBadges     int       `json:"visit_badges"`
	StreakBadges    int       `json:"streak_badges"`
	SessionBadges   int       `json:"session_badges"`
	TeamBadges      int       `json:"team_badges"`
	UpdatedAt       time.Time `json:"updated_at"`
}

// WorkerAchievementWithDetails represents achievement with full details
type WorkerAchievementWithDetails struct {
	WorkerAchievement
	Name        string `json:"name"`
	Description string `json:"description"`
	Icon        string `json:"icon"`
	Level       string `json:"level"`
	Points      int    `json:"points"`
	Category    string `json:"category"`
}
