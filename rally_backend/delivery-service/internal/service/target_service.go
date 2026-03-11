package service

import (
	"context"
	"time"

	"rally-point/delivery-service/internal/domain"
	"rally-point/delivery-service/internal/repository/postgres"

	"github.com/google/uuid"
)

type TargetService struct {
	targetRepo *postgres.TargetRepository
}

func NewTargetService(targetRepo *postgres.TargetRepository) *TargetService {
	return &TargetService{
		targetRepo: targetRepo,
	}
}

func (s *TargetService) CreateTarget(ctx context.Context, target *domain.Target) error {
	target.ID = uuid.New()
	target.CreatedAt = time.Now()
	target.UpdatedAt = time.Now()
	target.IsActive = true
	return s.targetRepo.CreateTarget(ctx, target)
}

func (s *TargetService) GetTargetByID(ctx context.Context, id uuid.UUID) (*domain.Target, error) {
	return s.targetRepo.GetTargetByID(ctx, id)
}

func (s *TargetService) GetTargetsByCreator(ctx context.Context, creatorID uuid.UUID) ([]domain.Target, error) {
	return s.targetRepo.GetTargetsByCreator(ctx, creatorID)
}

func (s *TargetService) UpdateTarget(ctx context.Context, target *domain.Target) error {
	return s.targetRepo.UpdateTarget(ctx, target)
}

func (s *TargetService) DeleteTarget(ctx context.Context, id uuid.UUID) error {
	return s.targetRepo.DeleteTarget(ctx, id)
}

func (s *TargetService) AssignTargetToWorker(ctx context.Context, targetID, workerID, assignedBy uuid.UUID, periodStart, periodEnd *time.Time) error {
	assignment := &domain.TargetAssignment{
		ID:             uuid.New(),
		TargetID:       targetID,
		AssignedToType: domain.AssignedToWorker,
		AssignedToID:   workerID,
		AssignedBy:     assignedBy,
		PeriodStart:    periodStart,
		PeriodEnd:      periodEnd,
		Status:         domain.TargetStatusActive,
		CreatedAt:      time.Now(),
	}
	return s.targetRepo.CreateAssignment(ctx, assignment)
}

func (s *TargetService) AssignTargetToTeam(ctx context.Context, targetID, teamID, assignedBy uuid.UUID, periodStart, periodEnd *time.Time) error {
	assignment := &domain.TargetAssignment{
		ID:             uuid.New(),
		TargetID:       targetID,
		AssignedToType: domain.AssignedToTeam,
		AssignedToID:   teamID,
		AssignedBy:     assignedBy,
		PeriodStart:    periodStart,
		PeriodEnd:      periodEnd,
		Status:         domain.TargetStatusActive,
		CreatedAt:      time.Now(),
	}
	return s.targetRepo.CreateAssignment(ctx, assignment)
}

func (s *TargetService) GetWorkerTargets(ctx context.Context, workerID uuid.UUID) ([]domain.WorkerTarget, error) {
	return s.targetRepo.GetWorkerTargetsWithProgress(ctx, workerID)
}

func (s *TargetService) GetTeamTargets(ctx context.Context, teamID uuid.UUID) ([]domain.WorkerTarget, error) {
	return s.targetRepo.GetTeamTargetsWithProgress(ctx, teamID)
}

func (s *TargetService) DeleteAssignment(ctx context.Context, id uuid.UUID) error {
	return s.targetRepo.DeleteAssignment(ctx, id)
}

func (s *TargetService) UpdateProgress(ctx context.Context, assignmentID uuid.UUID, value float64) error {
	progress := &domain.TargetProgress{
		ID:           uuid.New(),
		AssignmentID: assignmentID,
		CurrentValue: value,
		LastUpdated:  time.Now(),
	}
	return s.targetRepo.UpsertProgress(ctx, progress)
}
