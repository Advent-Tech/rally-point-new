package postgres

import (
	"context"
	"database/sql"

	"rally-point/delivery-service/internal/domain"

	"github.com/google/uuid"
)

type AchievementRepository struct {
	db *sql.DB
}

func NewAchievementRepository(db *sql.DB) *AchievementRepository {
	return &AchievementRepository{db: db}
}

func (r *AchievementRepository) GetAllAchievements(ctx context.Context) ([]domain.Achievement, error) {
	query := `
		SELECT id, category, name, description, icon, level, level_order, criteria_type, criteria_value, points, is_active, created_at
		FROM achievements WHERE is_active = true ORDER BY category, level_order
	`
	rows, err := r.db.QueryContext(ctx, query)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var achievements []domain.Achievement
	for rows.Next() {
		var a domain.Achievement
		err := rows.Scan(
			&a.ID, &a.Category, &a.Name, &a.Description, &a.Icon, &a.Level, &a.LevelOrder,
			&a.CriteriaType, &a.CriteriaValue, &a.Points, &a.IsActive, &a.CreatedAt,
		)
		if err != nil {
			return nil, err
		}
		achievements = append(achievements, a)
	}
	return achievements, nil
}

func (r *AchievementRepository) GetAchievementsByCategory(ctx context.Context, category string) ([]domain.Achievement, error) {
	query := `
		SELECT id, category, name, description, icon, level, level_order, criteria_type, criteria_value, points, is_active, created_at
		FROM achievements WHERE is_active = true AND category = $1 ORDER BY level_order
	`
	rows, err := r.db.QueryContext(ctx, query, category)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var achievements []domain.Achievement
	for rows.Next() {
		var a domain.Achievement
		err := rows.Scan(
			&a.ID, &a.Category, &a.Name, &a.Description, &a.Icon, &a.Level, &a.LevelOrder,
			&a.CriteriaType, &a.CriteriaValue, &a.Points, &a.IsActive, &a.CreatedAt,
		)
		if err != nil {
			return nil, err
		}
		achievements = append(achievements, a)
	}
	return achievements, nil
}

func (r *AchievementRepository) GetAchievementByID(ctx context.Context, id uuid.UUID) (*domain.Achievement, error) {
	query := `
		SELECT id, category, name, description, icon, level, level_order, criteria_type, criteria_value, points, is_active, created_at
		FROM achievements WHERE id = $1
	`
	a := &domain.Achievement{}
	err := r.db.QueryRowContext(ctx, query, id).Scan(
		&a.ID, &a.Category, &a.Name, &a.Description, &a.Icon, &a.Level, &a.LevelOrder,
		&a.CriteriaType, &a.CriteriaValue, &a.Points, &a.IsActive, &a.CreatedAt,
	)
	if err == sql.ErrNoRows {
		return nil, nil
	}
	return a, err
}

func (r *AchievementRepository) CreateAchievement(ctx context.Context, achievement *domain.Achievement) error {
	query := `
		INSERT INTO achievements (id, category, name, description, icon, level, level_order, criteria_type, criteria_value, points, is_active, created_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)
	`
	_, err := r.db.ExecContext(ctx, query,
		achievement.ID, achievement.Category, achievement.Name, achievement.Description, achievement.Icon,
		achievement.Level, achievement.LevelOrder, achievement.CriteriaType, achievement.CriteriaValue,
		achievement.Points, achievement.IsActive, achievement.CreatedAt,
	)
	return err
}

func (r *AchievementRepository) UpdateAchievement(ctx context.Context, achievement *domain.Achievement) error {
	query := `
		UPDATE achievements SET category = $1, name = $2, description = $3, icon = $4, level = $5,
		level_order = $6, criteria_type = $7, criteria_value = $8, points = $9, is_active = $10
		WHERE id = $11
	`
	_, err := r.db.ExecContext(ctx, query,
		achievement.Category, achievement.Name, achievement.Description, achievement.Icon,
		achievement.Level, achievement.LevelOrder, achievement.CriteriaType, achievement.CriteriaValue,
		achievement.Points, achievement.IsActive, achievement.ID,
	)
	return err
}

func (r *AchievementRepository) DeleteAchievement(ctx context.Context, id uuid.UUID) error {
	_, err := r.db.ExecContext(ctx, "DELETE FROM achievements WHERE id = $1", id)
	return err
}

func (r *AchievementRepository) GetWorkerAchievements(ctx context.Context, workerID uuid.UUID) ([]domain.WorkerAchievement, error) {
	query := `
		SELECT wa.id, wa.worker_id, wa.achievement_id, wa.earned_at, wa.progress,
		       a.id, a.category, a.name, a.description, a.icon, a.level, a.level_order, a.criteria_type, a.criteria_value, a.points
		FROM worker_achievements wa
		JOIN achievements a ON wa.achievement_id = a.id
		WHERE wa.worker_id = $1
		ORDER BY wa.earned_at DESC
	`
	rows, err := r.db.QueryContext(ctx, query, workerID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var achievements []domain.WorkerAchievement
	for rows.Next() {
		var wa domain.WorkerAchievement
		var a domain.Achievement
		err := rows.Scan(
			&wa.ID, &wa.WorkerID, &wa.AchievementID, &wa.EarnedAt, &wa.Progress,
			&a.ID, &a.Category, &a.Name, &a.Description, &a.Icon, &a.Level, &a.LevelOrder,
			&a.CriteriaType, &a.CriteriaValue, &a.Points,
		)
		if err != nil {
			return nil, err
		}
		wa.Achievement = &a
		achievements = append(achievements, wa)
	}
	return achievements, nil
}

func (r *AchievementRepository) GetWorkerAchievementsByCategory(ctx context.Context, workerID uuid.UUID, category string) ([]domain.WorkerAchievement, error) {
	query := `
		SELECT wa.id, wa.worker_id, wa.achievement_id, wa.earned_at, wa.progress,
		       a.id, a.category, a.name, a.description, a.icon, a.level, a.level_order, a.criteria_type, a.criteria_value, a.points
		FROM worker_achievements wa
		JOIN achievements a ON wa.achievement_id = a.id
		WHERE wa.worker_id = $1 AND a.category = $2
		ORDER BY a.level_order
	`
	rows, err := r.db.QueryContext(ctx, query, workerID, category)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var achievements []domain.WorkerAchievement
	for rows.Next() {
		var wa domain.WorkerAchievement
		var a domain.Achievement
		err := rows.Scan(
			&wa.ID, &wa.WorkerID, &wa.AchievementID, &wa.EarnedAt, &wa.Progress,
			&a.ID, &a.Category, &a.Name, &a.Description, &a.Icon, &a.Level, &a.LevelOrder,
			&a.CriteriaType, &a.CriteriaValue, &a.Points,
		)
		if err != nil {
			return nil, err
		}
		wa.Achievement = &a
		achievements = append(achievements, wa)
	}
	return achievements, nil
}

func (r *AchievementRepository) AwardAchievement(ctx context.Context, workerID, achievementID uuid.UUID) error {
	query := `
		INSERT INTO worker_achievements (id, worker_id, achievement_id, earned_at, progress)
		VALUES ($1, $2, $3, NOW(), 1.0)
		ON CONFLICT (worker_id, achievement_id) DO UPDATE SET progress = 1.0, earned_at = NOW()
	`
	_, err := r.db.ExecContext(ctx, query, uuid.New(), workerID, achievementID)
	return err
}

func (r *AchievementRepository) HasAchievement(ctx context.Context, workerID, achievementID uuid.UUID) (bool, error) {
	query := `SELECT EXISTS(SELECT 1 FROM worker_achievements WHERE worker_id = $1 AND achievement_id = $2)`
	var exists bool
	err := r.db.QueryRowContext(ctx, query, workerID, achievementID).Scan(&exists)
	return exists, err
}

func (r *AchievementRepository) GetOrCreateWorkerLevel(ctx context.Context, workerID uuid.UUID) (*domain.WorkerLevel, error) {
	query := `SELECT worker_id, total_points, current_level, level_progress, territory_badges, donation_badges, prayer_badges, visit_badges, streak_badges, session_badges, team_badges, updated_at FROM worker_levels WHERE worker_id = $1`
	wl := &domain.WorkerLevel{WorkerID: workerID}
	err := r.db.QueryRowContext(ctx, query, workerID).Scan(
		&wl.WorkerID, &wl.TotalPoints, &wl.CurrentLevel, &wl.LevelProgress,
		&wl.TerritoryBadges, &wl.DonationBadges, &wl.PrayerBadges, &wl.VisitBadges,
		&wl.StreakBadges, &wl.SessionBadges, &wl.TeamBadges, &wl.UpdatedAt,
	)
	if err == sql.ErrNoRows {
		insertQuery := `
			INSERT INTO worker_levels (worker_id, total_points, current_level, level_progress, territory_badges, donation_badges, prayer_badges, visit_badges, streak_badges, session_badges, team_badges, updated_at)
			VALUES ($1, 0, 'bronze', 0, 0, 0, 0, 0, 0, 0, 0, NOW())
			RETURNING worker_id, total_points, current_level, level_progress, territory_badges, donation_badges, prayer_badges, visit_badges, streak_badges, session_badges, team_badges, updated_at
		`
		err = r.db.QueryRowContext(ctx, insertQuery, workerID).Scan(
			&wl.WorkerID, &wl.TotalPoints, &wl.CurrentLevel, &wl.LevelProgress,
			&wl.TerritoryBadges, &wl.DonationBadges, &wl.PrayerBadges, &wl.VisitBadges,
			&wl.StreakBadges, &wl.SessionBadges, &wl.TeamBadges, &wl.UpdatedAt,
		)
		return wl, err
	}
	return wl, err
}

func (r *AchievementRepository) UpdateWorkerPoints(ctx context.Context, workerID uuid.UUID, pointsToAdd int) error {
	query := `
		UPDATE worker_levels 
		SET total_points = total_points + $1,
		    current_level = CASE
		        WHEN total_points + $1 >= 1000 THEN 'platinum'
		        WHEN total_points + $1 >= 500 THEN 'gold'
		        WHEN total_points + $1 >= 200 THEN 'silver'
		        ELSE 'bronze'
		    END,
		    level_progress = CASE
		        WHEN total_points + $1 >= 1000 THEN ((total_points + $1 - 1000)::float / 1000) * 100
		        WHEN total_points + $1 >= 500 THEN ((total_points + $1 - 500)::float / 500) * 100
		        WHEN total_points + $1 >= 200 THEN ((total_points + $1 - 200)::float / 300) * 100
		        ELSE ((total_points + $1)::float / 200) * 100
		    END,
		    updated_at = NOW()
		WHERE worker_id = $2
	`
	_, err := r.db.ExecContext(ctx, query, pointsToAdd, workerID)
	return err
}

func (r *AchievementRepository) IncrementBadgeCount(ctx context.Context, workerID uuid.UUID, category string) error {
	column := ""
	switch category {
	case "territory":
		column = "territory_badges"
	case "donation":
		column = "donation_badges"
	case "prayer":
		column = "prayer_badges"
	case "visit":
		column = "visit_badges"
	case "streak", "session":
		column = "streak_badges"
	case "team":
		column = "team_badges"
	default:
		return nil
	}

	query := `UPDATE worker_levels SET ` + column + ` = ` + column + ` + 1, updated_at = NOW() WHERE worker_id = $1`
	_, err := r.db.ExecContext(ctx, query, workerID)
	return err
}
