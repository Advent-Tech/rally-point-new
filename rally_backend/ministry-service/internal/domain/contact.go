package domain

import (
	"time"

	"github.com/google/uuid"
)

// MinistryContact represents a ministry contact record
type MinistryContact struct {
	ID                   uuid.UUID  `json:"id" db:"id"`
	WorkerID             uuid.UUID  `json:"worker_id" db:"worker_id"`
	Name                 string     `json:"name" db:"name"`
	Phone                *string    `json:"phone,omitempty" db:"phone"`
	Email                *string    `json:"email,omitempty" db:"email"`
	Address              *string    `json:"address,omitempty" db:"address"`
	PersonalBibleStudies bool       `json:"personal_bible_studies"`
	GroupBibleStudies    bool       `json:"group_bible_studies"`
	HealthSeminar        bool       `json:"health_seminar"`
	HealthExpo           bool       `json:"health_expo"`
	VBS                  bool       `json:"vbs"`
	HealthConsultation   bool       `json:"health_consultation"`
	Misc                 *string    `json:"misc,omitempty"`
	ContactMethod        *string    `json:"contact_method,omitempty" db:"contact_method"`
	ContactSent          bool       `json:"contact_sent" db:"contact_sent"`
	ContactSentAt        *time.Time `json:"contact_sent_at,omitempty" db:"contact_sent_at"`
	AppointmentScheduled bool       `json:"appointment_scheduled" db:"appointment_scheduled"`
	AppointmentDate      *time.Time `json:"appointment_date,omitempty" db:"appointment_date"`
	AppointmentTime      *string    `json:"appointment_time,omitempty" db:"appointment_time"`
	AppointmentNotes     *string    `json:"appointment_notes,omitempty" db:"appointment_notes"`
	Notes                *string    `json:"notes,omitempty" db:"notes"`
	CreatedAt            time.Time  `json:"created_at" db:"created_at"`
	UpdatedAt            time.Time  `json:"updated_at" db:"updated_at"`
}

// CreateMinistryContactRequest mirrors the UI create payload
type CreateMinistryContactRequest struct {
	WorkerID             uuid.UUID `json:"worker_id" binding:"required"`
	Name                 string    `json:"name" binding:"required"`
	Address              string    `json:"address,omitempty"`
	Email                string    `json:"email,omitempty"`
	Phone                string    `json:"phone,omitempty"`
	PersonalBibleStudies bool      `json:"personal_bible_studies"`
	GroupBibleStudies    bool      `json:"group_bible_studies"`
	HealthSeminar        bool      `json:"health_seminar"`
	HealthExpo           bool      `json:"health_expo"`
	VBS                  bool      `json:"vbs"`
	HealthConsultation   bool      `json:"health_consultation"`
	Misc                 string    `json:"misc,omitempty"`
	AppointmentScheduled bool      `json:"appointment_scheduled"`
	AppointmentDate      string    `json:"appointment_date,omitempty"`
	AppointmentTime      string    `json:"appointment_time,omitempty"`
	AppointmentNotes     string    `json:"appointment_notes,omitempty"`
}

// UpdateMinistryContactRequest mirrors the UI update payload
type UpdateMinistryContactRequest struct {
	Name                 *string `json:"name,omitempty"`
	Address              *string `json:"address,omitempty"`
	Email                *string `json:"email,omitempty"`
	Phone                *string `json:"phone,omitempty"`
	PersonalBibleStudies *bool   `json:"personal_bible_studies,omitempty"`
	GroupBibleStudies    *bool   `json:"group_bible_studies,omitempty"`
	HealthSeminar        *bool   `json:"health_seminar,omitempty"`
	HealthExpo           *bool   `json:"health_expo,omitempty"`
	VBS                  *bool   `json:"vbs,omitempty"`
	HealthConsultation   *bool   `json:"health_consultation,omitempty"`
	Misc                 *string `json:"misc,omitempty"`
	ContactSent          *bool   `json:"contact_sent,omitempty"`
	ContactMethod        *string `json:"contact_method,omitempty"`
	AppointmentScheduled *bool   `json:"appointment_scheduled,omitempty"`
	AppointmentDate      *string `json:"appointment_date,omitempty"`
	AppointmentTime      *string `json:"appointment_time,omitempty"`
	AppointmentNotes     *string `json:"appointment_notes,omitempty"`
	Notes                *string `json:"notes,omitempty"`
}

// MinistryContactStats aggregates stats for a worker's contacts
type MinistryContactStats struct {
	TotalContacts         int `json:"total_contacts"`
	AppointmentsScheduled int `json:"appointments_scheduled"`
	ContactsSent          int `json:"contacts_sent"`
	InterestsByType       struct {
		PersonalBibleStudies int `json:"personal_bible_studies"`
		GroupBibleStudies    int `json:"group_bible_studies"`
		HealthSeminar        int `json:"health_seminar"`
		HealthExpo           int `json:"health_expo"`
		VBS                  int `json:"vbs"`
		HealthConsultation   int `json:"health_consultation"`
	} `json:"interests_by_type"`
	AveragePerDay float64 `json:"average_per_day"`
}

// ContactExportData mirrors the UI export structure
type ContactExportData struct {
	Contacts   []*MinistryContact `json:"contacts"`
	ExportedAt time.Time          `json:"exported_at"`
	ExportedBy string             `json:"exported_by"`
	Format     string             `json:"format"`
}

// MinistryContactRepository defines data access methods
type MinistryContactRepository interface {
	Create(contact *MinistryContact, interestsJSON string) error
	GetByID(id uuid.UUID) (*MinistryContact, string, error)
	ListByWorker(workerID uuid.UUID, start, end *time.Time) ([]*MinistryContact, []string, error)
	ListAll(start, end *time.Time) ([]*MinistryContact, []string, error)
	Update(contact *MinistryContact, interestsJSON string) error
	Delete(id uuid.UUID) error
}

// MinistryContactService defines business logic
type MinistryContactService interface {
	CreateContact(creatorID uuid.UUID, req *CreateMinistryContactRequest) (*MinistryContact, error)
	GetContact(id uuid.UUID) (*MinistryContact, error)
	UpdateContact(id uuid.UUID, req *UpdateMinistryContactRequest) (*MinistryContact, error)
	DeleteContact(id uuid.UUID) error
	ListContacts(workerID *uuid.UUID, start, end *time.Time) ([]*MinistryContact, error)
	GetStats(workerID uuid.UUID, days int) (*MinistryContactStats, error)
	ExportContacts(workerID *uuid.UUID, format, exportedBy string) (*ContactExportData, error)
}
