package service

import (
	"encoding/json"
	"fmt"
	"log"
	"time"

	"rally-point/ministry-service/internal/domain"
	"rally-point/ministry-service/internal/repository/postgres"

	"github.com/google/uuid"
	nats "github.com/nats-io/nats.go"
)

type ministryContactService struct {
	repo     domain.MinistryContactRepository
	natsConn *nats.Conn
}

// NewMinistryContactService creates a new service
func NewMinistryContactService(repo domain.MinistryContactRepository, natsConn *nats.Conn) domain.MinistryContactService {
	return &ministryContactService{
		repo:     repo,
		natsConn: natsConn,
	}
}

func (s *ministryContactService) CreateContact(creatorID uuid.UUID, req *domain.CreateMinistryContactRequest) (*domain.MinistryContact, error) {
	contact := &domain.MinistryContact{
		ID:        uuid.New(),
		WorkerID:  req.WorkerID,
		Name:      req.Name,
		CreatedAt: time.Now(),
		UpdatedAt: time.Now(),
	}

	// Optional fields
	if req.Address != "" {
		contact.Address = &req.Address
	}
	if req.Email != "" {
		contact.Email = &req.Email
	}
	if req.Phone != "" {
		contact.Phone = &req.Phone
	}
	if req.Misc != "" {
		contact.Misc = &req.Misc
	}

	contact.PersonalBibleStudies = req.PersonalBibleStudies
	contact.GroupBibleStudies = req.GroupBibleStudies
	contact.HealthSeminar = req.HealthSeminar
	contact.HealthExpo = req.HealthExpo
	contact.VBS = req.VBS
	contact.HealthConsultation = req.HealthConsultation

	contact.AppointmentScheduled = req.AppointmentScheduled
	if req.AppointmentDate != "" {
		if t, err := time.Parse(time.RFC3339, req.AppointmentDate); err == nil {
			contact.AppointmentDate = &t
		}
	}
	if req.AppointmentTime != "" {
		contact.AppointmentTime = &req.AppointmentTime
	}
	if req.AppointmentNotes != "" {
		contact.AppointmentNotes = &req.AppointmentNotes
	}

	interestsJSON, err := postgres.BuildInterestsJSONFromContact(contact)
	if err != nil {
		return nil, fmt.Errorf("failed to encode interests: %w", err)
	}

	if err := s.repo.Create(contact, interestsJSON); err != nil {
		return nil, err
	}

	s.publishEvent("contact.created", contact)

	return contact, nil
}

func (s *ministryContactService) GetContact(id uuid.UUID) (*domain.MinistryContact, error) {
	contact, interestsJSON, err := s.repo.GetByID(id)
	if err != nil {
		return nil, err
	}
	postgres.ApplyInterestsJSONToContact(contact, interestsJSON)
	return contact, nil
}

func (s *ministryContactService) UpdateContact(id uuid.UUID, req *domain.UpdateMinistryContactRequest) (*domain.MinistryContact, error) {
	contact, interestsJSON, err := s.repo.GetByID(id)
	if err != nil {
		return nil, err
	}
	postgres.ApplyInterestsJSONToContact(contact, interestsJSON)

	// Apply updates
	if req.Name != nil {
		contact.Name = *req.Name
	}
	if req.Address != nil {
		contact.Address = req.Address
	}
	if req.Email != nil {
		contact.Email = req.Email
	}
	if req.Phone != nil {
		contact.Phone = req.Phone
	}
	if req.Misc != nil {
		contact.Misc = req.Misc
	}
	if req.PersonalBibleStudies != nil {
		contact.PersonalBibleStudies = *req.PersonalBibleStudies
	}
	if req.GroupBibleStudies != nil {
		contact.GroupBibleStudies = *req.GroupBibleStudies
	}
	if req.HealthSeminar != nil {
		contact.HealthSeminar = *req.HealthSeminar
	}
	if req.HealthExpo != nil {
		contact.HealthExpo = *req.HealthExpo
	}
	if req.VBS != nil {
		contact.VBS = *req.VBS
	}
	if req.HealthConsultation != nil {
		contact.HealthConsultation = *req.HealthConsultation
	}
	if req.ContactSent != nil {
		contact.ContactSent = *req.ContactSent
		if *req.ContactSent && contact.ContactSentAt == nil {
			now := time.Now()
			contact.ContactSentAt = &now
		}
	}
	if req.ContactMethod != nil {
		contact.ContactMethod = req.ContactMethod
	}
	if req.AppointmentScheduled != nil {
		contact.AppointmentScheduled = *req.AppointmentScheduled
	}
	if req.AppointmentDate != nil {
		if *req.AppointmentDate == "" {
			contact.AppointmentDate = nil
		} else if t, err := time.Parse(time.RFC3339, *req.AppointmentDate); err == nil {
			contact.AppointmentDate = &t
		}
	}
	if req.AppointmentTime != nil {
		contact.AppointmentTime = req.AppointmentTime
	}
	if req.AppointmentNotes != nil {
		contact.AppointmentNotes = req.AppointmentNotes
	}
	if req.Notes != nil {
		contact.Notes = req.Notes
	}

	contact.UpdatedAt = time.Now()

	interestsJSON, err = postgres.BuildInterestsJSONFromContact(contact)
	if err != nil {
		return nil, fmt.Errorf("failed to encode interests: %w", err)
	}

	if err := s.repo.Update(contact, interestsJSON); err != nil {
		return nil, err
	}

	s.publishEvent("contact.updated", contact)

	return contact, nil
}

func (s *ministryContactService) DeleteContact(id uuid.UUID) error {
	contact, interestsJSON, err := s.repo.GetByID(id)
	if err != nil {
		return err
	}
	postgres.ApplyInterestsJSONToContact(contact, interestsJSON)

	if err := s.repo.Delete(id); err != nil {
		return err
	}

	s.publishEvent("contact.deleted", contact)

	return nil
}

func (s *ministryContactService) ListContacts(workerID *uuid.UUID, start, end *time.Time) ([]*domain.MinistryContact, error) {
	var (
		contacts  []*domain.MinistryContact
		interests []string
		err       error
	)
	if workerID != nil {
		contacts, interests, err = s.repo.ListByWorker(*workerID, start, end)
	} else {
		contacts, interests, err = s.repo.ListAll(start, end)
	}
	if err != nil {
		return nil, err
	}
	for i := range contacts {
		postgres.ApplyInterestsJSONToContact(contacts[i], interests[i])
	}
	return contacts, nil
}

func (s *ministryContactService) GetStats(workerID uuid.UUID, days int) (*domain.MinistryContactStats, error) {
	if days <= 0 {
		days = 30
	}
	if days > 365 {
		days = 365
	}

	end := time.Now()
	start := end.AddDate(0, 0, -days)

	contacts, err := s.ListContacts(&workerID, &start, &end)
	if err != nil {
		return nil, err
	}

	stats := &domain.MinistryContactStats{}
	stats.TotalContacts = len(contacts)
	for _, c := range contacts {
		if c.AppointmentScheduled {
			stats.AppointmentsScheduled++
		}
		if c.ContactSent {
			stats.ContactsSent++
		}
		if c.PersonalBibleStudies {
			stats.InterestsByType.PersonalBibleStudies++
		}
		if c.GroupBibleStudies {
			stats.InterestsByType.GroupBibleStudies++
		}
		if c.HealthSeminar {
			stats.InterestsByType.HealthSeminar++
		}
		if c.HealthExpo {
			stats.InterestsByType.HealthExpo++
		}
		if c.VBS {
			stats.InterestsByType.VBS++
		}
		if c.HealthConsultation {
			stats.InterestsByType.HealthConsultation++
		}
	}
	if days > 0 {
		stats.AveragePerDay = float64(stats.TotalContacts) / float64(days)
	}
	return stats, nil
}

func (s *ministryContactService) ExportContacts(workerID *uuid.UUID, format, exportedBy string) (*domain.ContactExportData, error) {
	contacts, err := s.ListContacts(workerID, nil, nil)
	if err != nil {
		return nil, err
	}
	data := &domain.ContactExportData{
		Contacts:   contacts,
		ExportedAt: time.Now(),
		ExportedBy: exportedBy,
		Format:     format,
	}
	return data, nil
}

func (s *ministryContactService) publishEvent(eventType string, contact *domain.MinistryContact) {
	if s.natsConn == nil || contact == nil {
		return
	}

	event := map[string]interface{}{
		"type":      eventType,
		"contact":   contact,
		"timestamp": time.Now().UTC(),
	}

	data, err := json.Marshal(event)
	if err != nil {
		log.Printf("failed to marshal ministry contact event: %v", err)
		return
	}

	subject := fmt.Sprintf("ministry.contacts.worker.%s", contact.WorkerID.String())

	if err := s.natsConn.Publish(subject, data); err != nil {
		log.Printf("failed to publish ministry contact event to NATS: %v", err)
		return
	}

	if err := s.natsConn.Flush(); err != nil {
		log.Printf("failed to flush NATS connection: %v", err)
	}
}
