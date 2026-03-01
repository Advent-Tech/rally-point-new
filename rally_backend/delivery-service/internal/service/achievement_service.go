package service

import (
	"context"
	"time"

	"rally-point/delivery-service/internal/domain"
	"rally-point/delivery-service/internal/repository/postgres"

	"github.com/google/uuid"
)

type AchievementService struct {
	achievementRepo *postgres.AchievementRepository
}

func NewAchievementService(achievementRepo *postgres.AchievementRepository) *AchievementService {
	return &AchievementService{
		achievementRepo: achievementRepo,
	}
}

func (s *AchievementService) GetAllAchievements(ctx context.Context) ([]domain.Achievement, error) {
	return s.achievementRepo.GetAllAchievements(ctx)
}

func (s *AchievementService) GetAchievementsByCategory(ctx context.Context, category string) ([]domain.Achievement, error) {
	return s.achievementRepo.GetAchievementsByCategory(ctx, category)
}

func (s *AchievementService) GetAchievementByID(ctx context.Context, id uuid.UUID) (*domain.Achievement, error) {
	return s.achievementRepo.GetAchievementByID(ctx, id)
}

func (s *AchievementService) CreateAchievement(ctx context.Context, achievement *domain.Achievement) error {
	achievement.ID = uuid.New()
	achievement.CreatedAt = time.Now()
	achievement.IsActive = true
	return s.achievementRepo.CreateAchievement(ctx, achievement)
}

func (s *AchievementService) UpdateAchievement(ctx context.Context, achievement *domain.Achievement) error {
	return s.achievementRepo.UpdateAchievement(ctx, achievement)
}

func (s *AchievementService) DeleteAchievement(ctx context.Context, id uuid.UUID) error {
	return s.achievementRepo.DeleteAchievement(ctx, id)
}

func (s *AchievementService) GetWorkerAchievements(ctx context.Context, workerID uuid.UUID) ([]domain.WorkerAchievement, error) {
	return s.achievementRepo.GetWorkerAchievements(ctx, workerID)
}

func (s *AchievementService) GetWorkerAchievementsByCategory(ctx context.Context, workerID uuid.UUID, category string) ([]domain.WorkerAchievement, error) {
	return s.achievementRepo.GetWorkerAchievementsByCategory(ctx, workerID, category)
}

func (s *AchievementService) GetWorkerLevel(ctx context.Context, workerID uuid.UUID) (*domain.WorkerLevel, error) {
	return s.achievementRepo.GetOrCreateWorkerLevel(ctx, workerID)
}

func (s *AchievementService) CheckAndAwardAchievements(ctx context.Context, workerID uuid.UUID, category string, currentValue float64) ([]domain.Achievement, error) {
	achievements, err := s.achievementRepo.GetAchievementsByCategory(ctx, category)
	if err != nil {
		return nil, err
	}

	var newlyEarned []domain.Achievement

	for _, achievement := range achievements {
		hasIt, err := s.achievementRepo.HasAchievement(ctx, workerID, achievement.ID)
		if err != nil {
			continue
		}

		if !hasIt && currentValue >= achievement.CriteriaValue {
			err := s.achievementRepo.AwardAchievement(ctx, workerID, achievement.ID)
			if err != nil {
				continue
			}

			err = s.achievementRepo.UpdateWorkerPoints(ctx, workerID, achievement.Points)
			if err != nil {
				continue
			}

			err = s.achievementRepo.IncrementBadgeCount(ctx, workerID, category)
			if err != nil {
				continue
			}

			newlyEarned = append(newlyEarned, achievement)
		}
	}

	return newlyEarned, nil
}

func (s *AchievementService) GetWorkerStats(ctx context.Context, workerID uuid.UUID) (map[string]interface{}, error) {
	achievements, err := s.achievementRepo.GetWorkerAchievements(ctx, workerID)
	if err != nil {
		return nil, err
	}

	level, err := s.achievementRepo.GetOrCreateWorkerLevel(ctx, workerID)
	if err != nil {
		return nil, err
	}

	allAchievements, err := s.achievementRepo.GetAllAchievements(ctx)
	if err != nil {
		return nil, err
	}

	categoryCount := make(map[string]int)
	levelCount := make(map[string]int)
	for _, a := range achievements {
		if a.Achievement != nil {
			categoryCount[string(a.Achievement.Category)]++
			levelCount[string(a.Achievement.Level)]++
		}
	}

	totalBadges := len(achievements)
	totalAvailable := len(allAchievements)

	return map[string]interface{}{
		"total_points":     level.TotalPoints,
		"current_level":    level.CurrentLevel,
		"level_progress":   level.LevelProgress,
		"badges_earned":    totalBadges,
		"badges_available": totalAvailable,
		"by_category":      categoryCount,
		"by_level":         levelCount,
		"territory_badges": level.TerritoryBadges,
		"donation_badges":  level.DonationBadges,
		"prayer_badges":    level.PrayerBadges,
		"visit_badges":     level.VisitBadges,
		"streak_badges":    level.StreakBadges,
	}, nil
}
