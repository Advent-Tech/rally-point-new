package service

import (
	"database/sql"
	"fmt"
	"time"

	"rally-point/user-service/internal/domain"

	"github.com/google/uuid"
)

type adminService struct {
	userRepo domain.UserRepository
	teamRepo domain.TeamRepository
	db       *sql.DB
}

// NewAdminService creates a new admin service
func NewAdminService(userRepo domain.UserRepository, teamRepo domain.TeamRepository, db *sql.DB) domain.AdminService {
	return &adminService{
		userRepo: userRepo,
		teamRepo: teamRepo,
		db:       db,
	}
}

// GetTeamLeaders returns all team leaders with optional status filter
func (s *adminService) GetTeamLeaders(status string) (*domain.TeamLeaderListResponse, error) {
	var leaders []*domain.User
	var err error

	if status != "" {
		leaders, err = s.userRepo.GetByRoleAndStatus(domain.RoleTeamLeader, status)
	} else {
		leaders, err = s.userRepo.GetByRole(domain.RoleTeamLeader)
	}

	if err != nil {
		return nil, fmt.Errorf("failed to get team leaders: %w", err)
	}

	// Count by status
	allLeaders, _ := s.userRepo.GetByRole(domain.RoleTeamLeader)
	var pending, verified, rejected int
	for _, l := range allLeaders {
		switch l.VerificationStatus {
		case domain.VerificationPending:
			pending++
		case domain.VerificationVerified:
			verified++
		case domain.VerificationRejected:
			rejected++
		}
	}

	leaderInfos := make([]*domain.TeamLeaderInfo, 0, len(leaders))
	for _, leader := range leaders {
		info := &domain.TeamLeaderInfo{
			ID:                 leader.ID,
			Email:              leader.Email,
			DisplayName:        leader.DisplayName,
			Role:               leader.Role,
			Phone:              leader.Phone,
			ProfilePhotoURL:    leader.ProfilePhotoURL,
			TeamID:             leader.TeamID,
			VerificationStatus: leader.VerificationStatus,
			VerifiedBy:         leader.VerifiedBy,
			VerifiedAt:         leader.VerifiedAt,
			RejectionReason:    leader.RejectionReason,
			CreatedAt:          leader.CreatedAt,
		}

		// Get team name if assigned
		if leader.TeamID != nil {
			team, err := s.teamRepo.GetByID(*leader.TeamID)
			if err == nil {
				info.TeamName = &team.Name
			}
		}

		leaderInfos = append(leaderInfos, info)
	}

	return &domain.TeamLeaderListResponse{
		Leaders:  leaderInfos,
		Total:    len(allLeaders),
		Pending:  pending,
		Verified: verified,
		Rejected: rejected,
	}, nil
}

// GetTeamLeaderByID returns a team leader by ID
func (s *adminService) GetTeamLeaderByID(id uuid.UUID) (*domain.TeamLeaderInfo, error) {
	user, err := s.userRepo.GetByID(id)
	if err != nil {
		return nil, fmt.Errorf("team leader not found: %w", err)
	}

	if user.Role != domain.RoleTeamLeader {
		return nil, fmt.Errorf("user is not a team leader")
	}

	info := &domain.TeamLeaderInfo{
		ID:                 user.ID,
		Email:              user.Email,
		DisplayName:        user.DisplayName,
		Role:               user.Role,
		Phone:              user.Phone,
		ProfilePhotoURL:    user.ProfilePhotoURL,
		TeamID:             user.TeamID,
		VerificationStatus: user.VerificationStatus,
		VerifiedBy:         user.VerifiedBy,
		VerifiedAt:         user.VerifiedAt,
		RejectionReason:    user.RejectionReason,
		CreatedAt:          user.CreatedAt,
	}

	// Get team name if assigned
	if user.TeamID != nil {
		team, err := s.teamRepo.GetByID(*user.TeamID)
		if err == nil {
			info.TeamName = &team.Name
		}
	}

	return info, nil
}

// VerifyTeamLeader verifies a team leader
func (s *adminService) VerifyTeamLeader(leaderID, adminID uuid.UUID) error {
	// Get the team leader
	user, err := s.userRepo.GetByID(leaderID)
	if err != nil {
		return fmt.Errorf("team leader not found: %w", err)
	}

	if user.Role != domain.RoleTeamLeader {
		return fmt.Errorf("user is not a team leader")
	}

	if user.VerificationStatus == domain.VerificationVerified {
		return fmt.Errorf("team leader is already verified")
	}

	// Update verification status
	err = s.userRepo.UpdateVerificationStatus(leaderID, domain.VerificationVerified, &adminID, nil)
	if err != nil {
		return fmt.Errorf("failed to verify team leader: %w", err)
	}

	fmt.Printf("✅ Team leader verified: %s by admin %s\n", user.DisplayName, adminID)

	return nil
}

// RejectTeamLeader rejects a team leader
func (s *adminService) RejectTeamLeader(leaderID, adminID uuid.UUID, reason string) error {
	// Get the team leader
	user, err := s.userRepo.GetByID(leaderID)
	if err != nil {
		return fmt.Errorf("team leader not found: %w", err)
	}

	if user.Role != domain.RoleTeamLeader {
		return fmt.Errorf("user is not a team leader")
	}

	if user.VerificationStatus == domain.VerificationRejected {
		return fmt.Errorf("team leader is already rejected")
	}

	// Update verification status
	err = s.userRepo.UpdateVerificationStatus(leaderID, domain.VerificationRejected, &adminID, &reason)
	if err != nil {
		return fmt.Errorf("failed to reject team leader: %w", err)
	}

	fmt.Printf("❌ Team leader rejected: %s (reason: %s)\n", user.DisplayName, reason)

	return nil
}

// CreateTeam creates a new team
func (s *adminService) CreateTeam(req *domain.AdminCreateTeamRequest) (*domain.Team, error) {
	team := &domain.Team{
		ID:          uuid.New(),
		Name:        req.Name,
		WorkerCount: 0,
		CreatedAt:   time.Now(),
		UpdatedAt:   time.Now(),
	}

	if req.Description != "" {
		team.Description = &req.Description
	}

	if req.PhotoURL != "" {
		team.PhotoURL = &req.PhotoURL
	}

	// If leader is specified, verify they exist and are verified
	if req.LeaderID != nil {
		leader, err := s.userRepo.GetByID(*req.LeaderID)
		if err != nil {
			return nil, fmt.Errorf("leader not found: %w", err)
		}

		if leader.Role != domain.RoleTeamLeader {
			return nil, fmt.Errorf("specified user is not a team leader")
		}

		if leader.VerificationStatus != domain.VerificationVerified {
			return nil, fmt.Errorf("team leader must be verified before being assigned a team")
		}

		team.LeaderID = *req.LeaderID
	}

	// Create team in database
	query := `
		INSERT INTO teams (id, name, description, leader_id, photo_url, worker_count, created_at, updated_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
	`

	var leaderID interface{}
	if req.LeaderID != nil {
		leaderID = *req.LeaderID
	}

	_, err := s.db.Exec(query, team.ID, team.Name, team.Description, leaderID, team.PhotoURL, team.WorkerCount, team.CreatedAt, team.UpdatedAt)
	if err != nil {
		return nil, fmt.Errorf("failed to create team: %w", err)
	}

	// If leader was assigned, update their team_id
	if req.LeaderID != nil {
		err = s.teamRepo.AddWorker(team.ID, *req.LeaderID)
		if err != nil {
			fmt.Printf("Warning: failed to update leader's team_id: %v\n", err)
		}
	}

	fmt.Printf("🏢 Team created: %s\n", req.Name)

	return team, nil
}

// AssignTeamToLeader assigns a team to a verified leader
func (s *adminService) AssignTeamToLeader(teamID, leaderID uuid.UUID) error {
	// Get the team
	team, err := s.teamRepo.GetByID(teamID)
	if err != nil {
		return fmt.Errorf("team not found: %w", err)
	}

	// Get the leader
	leader, err := s.userRepo.GetByID(leaderID)
	if err != nil {
		return fmt.Errorf("team leader not found: %w", err)
	}

	if leader.Role != domain.RoleTeamLeader {
		return fmt.Errorf("user is not a team leader")
	}

	if leader.VerificationStatus != domain.VerificationVerified {
		return fmt.Errorf("team leader must be verified before being assigned a team")
	}

	// Update team's leader_id
	query := `UPDATE teams SET leader_id = $2, updated_at = $3 WHERE id = $1`
	_, err = s.db.Exec(query, teamID, leaderID, time.Now())
	if err != nil {
		return fmt.Errorf("failed to assign team to leader: %w", err)
	}

	// Update leader's team_id
	err = s.teamRepo.AddWorker(teamID, leaderID)
	if err != nil {
		fmt.Printf("Warning: failed to update leader's team_id: %v\n", err)
	}

	fmt.Printf("🔗 Team %s assigned to leader %s\n", team.Name, leader.DisplayName)

	return nil
}

// UnassignTeamFromLeader removes a leader from a team
func (s *adminService) UnassignTeamFromLeader(teamID uuid.UUID) error {
	team, err := s.teamRepo.GetByID(teamID)
	if err != nil {
		return fmt.Errorf("team not found: %w", err)
	}

	// Get current leader to update their team_id
	currentLeaderID := team.LeaderID
	if currentLeaderID != uuid.Nil {
		err = s.teamRepo.RemoveWorker(teamID, currentLeaderID)
		if err != nil {
			fmt.Printf("Warning: failed to update leader's team_id: %v\n", err)
		}
	}

	// Set team's leader_id to NULL
	query := `UPDATE teams SET leader_id = NULL, updated_at = $2 WHERE id = $1`
	_, err = s.db.Exec(query, teamID, time.Now())
	if err != nil {
		return fmt.Errorf("failed to unassign team from leader: %w", err)
	}

	fmt.Printf("🔓 Team %s unassigned from leader\n", team.Name)

	return nil
}

// GetPendingWorkers returns all workers pending verification
func (s *adminService) GetPendingWorkers() ([]*domain.User, error) {
	workers, err := s.userRepo.GetByRoleAndStatus(domain.RoleWorker, domain.VerificationPending)
	if err != nil {
		return nil, fmt.Errorf("failed to get pending workers: %w", err)
	}

	// Remove password hashes
	for _, w := range workers {
		w.PasswordHash = ""
	}

	return workers, nil
}

// GetVerifiedWorkers returns all verified workers
func (s *adminService) GetVerifiedWorkers() ([]*domain.User, error) {
	workers, err := s.userRepo.GetByRoleAndStatus(domain.RoleWorker, domain.VerificationVerified)
	if err != nil {
		return nil, fmt.Errorf("failed to get verified workers: %w", err)
	}

	// Remove password hashes
	for _, w := range workers {
		w.PasswordHash = ""
	}

	return workers, nil
}

// VerifyWorker verifies a worker (admin can directly verify workers)
func (s *adminService) VerifyWorker(workerID, adminID uuid.UUID) error {
	user, err := s.userRepo.GetByID(workerID)
	if err != nil {
		return fmt.Errorf("worker not found: %w", err)
	}

	if user.Role != domain.RoleWorker {
		return fmt.Errorf("user is not a worker")
	}

	if user.VerificationStatus == domain.VerificationVerified {
		return fmt.Errorf("worker is already verified")
	}

	err = s.userRepo.UpdateVerificationStatus(workerID, domain.VerificationVerified, &adminID, nil)
	if err != nil {
		return fmt.Errorf("failed to verify worker: %w", err)
	}

	fmt.Printf("✅ Worker verified: %s by admin %s\n", user.DisplayName, adminID)

	return nil
}

// RejectWorker rejects a worker
func (s *adminService) RejectWorker(workerID, adminID uuid.UUID, reason string) error {
	user, err := s.userRepo.GetByID(workerID)
	if err != nil {
		return fmt.Errorf("worker not found: %w", err)
	}

	if user.Role != domain.RoleWorker {
		return fmt.Errorf("user is not a worker")
	}

	err = s.userRepo.UpdateVerificationStatus(workerID, domain.VerificationRejected, &adminID, &reason)
	if err != nil {
		return fmt.Errorf("failed to reject worker: %w", err)
	}

	fmt.Printf("❌ Worker rejected: %s (reason: %s)\n", user.DisplayName, reason)

	return nil
}
