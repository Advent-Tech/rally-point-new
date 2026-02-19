package service

import (
	"encoding/json"
	"fmt"
	"log"
	"math"
	"time"

	"rally-point/delivery-service/internal/domain"

	"github.com/google/uuid"
	"github.com/nats-io/nats.go"
)

type PrayerRequestService struct {
	repo domain.PrayerRequestRepository
	nc   *nats.Conn
}

func NewPrayerRequestService(repo domain.PrayerRequestRepository, nc *nats.Conn) *PrayerRequestService {
	return &PrayerRequestService{repo: repo, nc: nc}
}

// publishNotify publishes a notification event to NATS
func (s *PrayerRequestService) publishNotify(subject string, event map[string]interface{}) {
	if s.nc == nil {
		return
	}
	data, err := json.Marshal(event)
	if err != nil {
		log.Printf("Failed to marshal notification: %v", err)
		return
	}
	if err := s.nc.Publish(subject, data); err != nil {
		log.Printf("Failed to publish notification %s: %v", subject, err)
	}
}

func (s *PrayerRequestService) CreatePrayerRequest(workerID, teamID uuid.UUID, req *domain.CreatePrayerRequestRequest) (*domain.PrayerRequest, error) {
	// Validate request type
	if req.RequestType != domain.PrayerTypeChurch && req.RequestType != domain.PrayerTypeHomeVisit {
		return nil, fmt.Errorf("invalid request type: must be '%s' or '%s'", domain.PrayerTypeChurch, domain.PrayerTypeHomeVisit)
	}

	// Set default category if not provided
	category := req.PrayerCategory
	if category == "" {
		category = domain.PrayerCategoryGeneral
	}

	// Set default urgency if not provided
	urgency := req.Urgency
	if urgency == "" {
		urgency = domain.UrgencyNormal
	}

	// Parse territory ID if provided
	var territoryID *uuid.UUID
	if req.TerritoryID != nil && *req.TerritoryID != "" {
		parsed, err := uuid.Parse(*req.TerritoryID)
		if err == nil {
			territoryID = &parsed
		}
	}

	prayerRequest := &domain.PrayerRequest{
		ID:                 uuid.New(),
		WorkerID:           workerID,
		TeamID:             &teamID,
		TerritoryID:        territoryID,
		RequesterName:      req.RequesterName,
		RequesterPhone:     req.RequesterPhone,
		RequesterEmail:     req.RequesterEmail,
		RequesterAddress:   req.RequesterAddress,
		Latitude:           req.Latitude,
		Longitude:          req.Longitude,
		PrayerSubject:      req.PrayerSubject,
		PrayerDetails:      req.PrayerDetails,
		PrayerCategory:     category,
		RequestType:        req.RequestType,
		PreferredVisitDate: req.PreferredVisitDate,
		PreferredVisitTime: req.PreferredVisitTime,
		Status:             domain.PrayerStatusPending,
		Urgency:            urgency,
		Notes:              req.Notes,
	}

	err := s.repo.Create(prayerRequest)
	if err != nil {
		return nil, fmt.Errorf("failed to create prayer request: %w", err)
	}

	// Publish notification for new prayer request (target: team)
	s.publishNotify("notify.prayer.created", map[string]interface{}{
		"event_type":        "prayer.created",
		"target_type":       "team",
		"target_id":         teamID.String(),
		"actor_id":          workerID.String(),
		"title":             fmt.Sprintf("Prayer request: %s", req.PrayerSubject),
		"body":              fmt.Sprintf("From %s - %s", req.RequesterName, category),
		"data":              map[string]interface{}{"prayer_request_id": prayerRequest.ID.String()},
		"priority":          "normal",
		"notification_type": "prayer",
		"group_key":         "prayer:" + prayerRequest.ID.String(),
		"created_at":        time.Now().Format(time.RFC3339),
	})

	return prayerRequest, nil
}

func (s *PrayerRequestService) GetPrayerRequest(id uuid.UUID) (*domain.PrayerRequest, error) {
	return s.repo.GetByID(id)
}

func (s *PrayerRequestService) UpdatePrayerRequest(id uuid.UUID, req *domain.UpdatePrayerRequestRequest) (*domain.PrayerRequest, error) {
	// Get existing request
	existing, err := s.repo.GetByID(id)
	if err != nil {
		return nil, err
	}

	// Update fields if provided
	if req.RequesterName != nil {
		existing.RequesterName = *req.RequesterName
	}
	if req.RequesterPhone != nil {
		existing.RequesterPhone = req.RequesterPhone
	}
	if req.RequesterEmail != nil {
		existing.RequesterEmail = req.RequesterEmail
	}
	if req.RequesterAddress != nil {
		existing.RequesterAddress = req.RequesterAddress
	}
	if req.Latitude != nil {
		existing.Latitude = req.Latitude
	}
	if req.Longitude != nil {
		existing.Longitude = req.Longitude
	}
	if req.PrayerSubject != nil {
		existing.PrayerSubject = *req.PrayerSubject
	}
	if req.PrayerDetails != nil {
		existing.PrayerDetails = *req.PrayerDetails
	}
	if req.PrayerCategory != nil {
		existing.PrayerCategory = *req.PrayerCategory
	}
	if req.RequestType != nil {
		if *req.RequestType != domain.PrayerTypeChurch && *req.RequestType != domain.PrayerTypeHomeVisit {
			return nil, fmt.Errorf("invalid request type")
		}
		existing.RequestType = *req.RequestType
	}
	if req.PreferredVisitDate != nil {
		existing.PreferredVisitDate = req.PreferredVisitDate
	}
	if req.PreferredVisitTime != nil {
		existing.PreferredVisitTime = req.PreferredVisitTime
	}
	if req.Urgency != nil {
		existing.Urgency = *req.Urgency
	}
	if req.Notes != nil {
		existing.Notes = req.Notes
	}

	err = s.repo.Update(existing)
	if err != nil {
		return nil, fmt.Errorf("failed to update prayer request: %w", err)
	}

	return existing, nil
}

func (s *PrayerRequestService) DeletePrayerRequest(id uuid.UUID) error {
	return s.repo.Delete(id)
}

func (s *PrayerRequestService) ListPrayerRequests(filter *domain.PrayerRequestFilter, page, pageSize int) (*domain.PrayerRequestListResponse, error) {
	if page < 1 {
		page = 1
	}
	if pageSize < 1 || pageSize > 100 {
		pageSize = 20
	}

	requests, total, err := s.repo.List(filter, page, pageSize)
	if err != nil {
		return nil, err
	}

	totalPages := int(math.Ceil(float64(total) / float64(pageSize)))

	return &domain.PrayerRequestListResponse{
		PrayerRequests: requests,
		Total:          total,
		Page:           page,
		PageSize:       pageSize,
		TotalPages:     totalPages,
	}, nil
}

func (s *PrayerRequestService) GetMapMarkers(filter *domain.PrayerRequestFilter) ([]domain.PrayerRequestMapMarker, error) {
	return s.repo.GetMapMarkers(filter)
}

func (s *PrayerRequestService) GetWorkerPrayerRequests(workerID uuid.UUID, page, pageSize int) (*domain.PrayerRequestListResponse, error) {
	filter := &domain.PrayerRequestFilter{WorkerID: &workerID}
	return s.ListPrayerRequests(filter, page, pageSize)
}

func (s *PrayerRequestService) GetTeamPrayerRequests(teamID uuid.UUID, page, pageSize int) (*domain.PrayerRequestListResponse, error) {
	filter := &domain.PrayerRequestFilter{TeamID: &teamID}
	return s.ListPrayerRequests(filter, page, pageSize)
}

func (s *PrayerRequestService) GetTerritoryPrayerRequests(territoryID uuid.UUID, page, pageSize int) (*domain.PrayerRequestListResponse, error) {
	filter := &domain.PrayerRequestFilter{TerritoryID: &territoryID}
	return s.ListPrayerRequests(filter, page, pageSize)
}

func (s *PrayerRequestService) GetStats(filter *domain.PrayerRequestFilter) (*domain.PrayerRequestStats, error) {
	return s.repo.GetStats(filter)
}

func (s *PrayerRequestService) UpdateStatus(id uuid.UUID, status string, completedBy *uuid.UUID, notes *string) error {
	// Validate status
	validStatuses := map[string]bool{
		domain.PrayerStatusPending:    true,
		domain.PrayerStatusScheduled:  true,
		domain.PrayerStatusInProgress: true,
		domain.PrayerStatusCompleted:  true,
		domain.PrayerStatusCancelled:  true,
	}

	if !validStatuses[status] {
		return fmt.Errorf("invalid status: %s", status)
	}

	err := s.repo.UpdateStatus(id, status, completedBy, notes)
	if err != nil {
		return err
	}

	// Publish notification for status change
	request, _ := s.repo.GetByID(id)
	if request != nil {
		actorID := ""
		if completedBy != nil {
			actorID = completedBy.String()
		}
		s.publishNotify("notify.prayer.status_changed", map[string]interface{}{
			"event_type":        "prayer.status_changed",
			"target_type":       "user",
			"target_id":         request.WorkerID.String(),
			"actor_id":          actorID,
			"title":             fmt.Sprintf("Prayer request %s", status),
			"body":              fmt.Sprintf("%s is now %s", request.PrayerSubject, status),
			"data":              map[string]interface{}{"prayer_request_id": id.String(), "status": status},
			"priority":          "normal",
			"notification_type": "prayer",
			"group_key":         "prayer:" + id.String(),
			"created_at":        time.Now().Format(time.RFC3339),
		})
	}

	return nil
}

func (s *PrayerRequestService) AssignPreacher(id uuid.UUID, preacherID uuid.UUID, scheduledAt *time.Time, notes *string) error {
	// Verify the request exists and is a home visit type
	request, err := s.repo.GetByID(id)
	if err != nil {
		return err
	}

	if request.RequestType != domain.PrayerTypeHomeVisit {
		return fmt.Errorf("can only assign preacher to home visit requests")
	}

	err = s.repo.AssignPreacher(id, preacherID, scheduledAt, notes)
	if err != nil {
		return err
	}

	// Publish notification for preacher assignment
	s.publishNotify("notify.prayer.assigned", map[string]interface{}{
		"event_type":        "prayer.assigned",
		"target_type":       "user",
		"target_id":         preacherID.String(),
		"actor_id":          preacherID.String(),
		"title":             "Home visit assigned",
		"body":              fmt.Sprintf("Prayer request: %s", request.PrayerSubject),
		"data":              map[string]interface{}{"prayer_request_id": id.String()},
		"priority":          "high",
		"notification_type": "prayer",
		"group_key":         "prayer:" + id.String(),
		"created_at":        time.Now().Format(time.RFC3339),
	})

	return nil
}

func (s *PrayerRequestService) CompletePrayerRequest(id uuid.UUID, completedBy uuid.UUID, notes *string) error {
	return s.repo.UpdateStatus(id, domain.PrayerStatusCompleted, &completedBy, notes)
}
