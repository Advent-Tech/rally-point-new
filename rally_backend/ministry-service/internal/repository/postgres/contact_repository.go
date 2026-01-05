package postgres

import (
	"database/sql"
	"encoding/json"
	"fmt"
	"time"

	"rally-point/ministry-service/internal/domain"

	"github.com/google/uuid"
)

type ministryContactRepository struct {
	db *sql.DB
}

// NewMinistryContactRepository creates a new repository
func NewMinistryContactRepository(db *sql.DB) domain.MinistryContactRepository {
	return &ministryContactRepository{db: db}
}

func (r *ministryContactRepository) Create(contact *domain.MinistryContact, interestsJSON string) error {
	query := `INSERT INTO ministry_contacts (
		id, worker_id, name, phone, email, address,
		interests, contact_method, contact_sent, contact_sent_at,
		appointment_scheduled, appointment_date, appointment_time, appointment_notes,
		notes, created_at, updated_at
	) VALUES (
		$1, $2, $3, $4, $5, $6,
		$7::jsonb, $8, $9, $10,
		$11, $12, $13, $14,
		$15, $16, $17
	)`

	_, err := r.db.Exec(
		query,
		contact.ID,
		contact.WorkerID,
		contact.Name,
		contact.Phone,
		contact.Email,
		contact.Address,
		interestsJSON,
		contact.ContactMethod,
		contact.ContactSent,
		contact.ContactSentAt,
		contact.AppointmentScheduled,
		contact.AppointmentDate,
		contact.AppointmentTime,
		contact.AppointmentNotes,
		contact.Notes,
		contact.CreatedAt,
		contact.UpdatedAt,
	)
	if err != nil {
		return fmt.Errorf("failed to create ministry contact: %w", err)
	}
	return nil
}

func (r *ministryContactRepository) GetByID(id uuid.UUID) (*domain.MinistryContact, string, error) {
	query := `SELECT 
		id, worker_id, name, phone, email, address,
		interests::text, contact_method, contact_sent, contact_sent_at,
		appointment_scheduled, appointment_date, appointment_time, appointment_notes,
		notes, created_at, updated_at
		FROM ministry_contacts WHERE id = $1`

	contact := &domain.MinistryContact{}
	var interestsText sql.NullString

	err := r.db.QueryRow(query, id).Scan(
		&contact.ID,
		&contact.WorkerID,
		&contact.Name,
		&contact.Phone,
		&contact.Email,
		&contact.Address,
		&interestsText,
		&contact.ContactMethod,
		&contact.ContactSent,
		&contact.ContactSentAt,
		&contact.AppointmentScheduled,
		&contact.AppointmentDate,
		&contact.AppointmentTime,
		&contact.AppointmentNotes,
		&contact.Notes,
		&contact.CreatedAt,
		&contact.UpdatedAt,
	)
	if err == sql.ErrNoRows {
		return nil, "", fmt.Errorf("ministry contact not found")
	}
	if err != nil {
		return nil, "", fmt.Errorf("failed to get ministry contact: %w", err)
	}

	if interestsText.Valid {
		return contact, interestsText.String, nil
	}
	return contact, "{}", nil
}

func (r *ministryContactRepository) ListByWorker(workerID uuid.UUID, start, end *time.Time) ([]*domain.MinistryContact, []string, error) {
	query := `SELECT 
		id, worker_id, name, phone, email, address,
		interests::text, contact_method, contact_sent, contact_sent_at,
		appointment_scheduled, appointment_date, appointment_time, appointment_notes,
		notes, created_at, updated_at
		FROM ministry_contacts
		WHERE worker_id = $1`

	args := []interface{}{workerID}
	if start != nil {
		query += " AND created_at >= $2"
		args = append(args, *start)
	}
	if end != nil {
		if len(args) == 1 {
			query += " AND created_at <= $2"
		} else {
			query += " AND created_at <= $3"
		}
		args = append(args, *end)
	}
	query += " ORDER BY created_at DESC"

	rows, err := r.db.Query(query, args...)
	if err != nil {
		return nil, nil, fmt.Errorf("failed to list ministry contacts: %w", err)
	}
	defer rows.Close()

	var contacts []*domain.MinistryContact
	var interestsList []string

	for rows.Next() {
		contact := &domain.MinistryContact{}
		var interestsText sql.NullString
		if err := rows.Scan(
			&contact.ID,
			&contact.WorkerID,
			&contact.Name,
			&contact.Phone,
			&contact.Email,
			&contact.Address,
			&interestsText,
			&contact.ContactMethod,
			&contact.ContactSent,
			&contact.ContactSentAt,
			&contact.AppointmentScheduled,
			&contact.AppointmentDate,
			&contact.AppointmentTime,
			&contact.AppointmentNotes,
			&contact.Notes,
			&contact.CreatedAt,
			&contact.UpdatedAt,
		); err != nil {
			return nil, nil, fmt.Errorf("failed to scan ministry contact: %w", err)
		}
		contacts = append(contacts, contact)
		if interestsText.Valid {
			interestsList = append(interestsList, interestsText.String)
		} else {
			interestsList = append(interestsList, "{}")
		}
	}

	return contacts, interestsList, nil
}

func (r *ministryContactRepository) ListAll(start, end *time.Time) ([]*domain.MinistryContact, []string, error) {
	query := `SELECT 
		id, worker_id, name, phone, email, address,
		interests::text, contact_method, contact_sent, contact_sent_at,
		appointment_scheduled, appointment_date, appointment_time, appointment_notes,
		notes, created_at, updated_at
		FROM ministry_contacts`

	var args []interface{}
	if start != nil {
		query += " WHERE created_at >= $1"
		args = append(args, *start)
	}
	if end != nil {
		if len(args) == 0 {
			query += " WHERE created_at <= $1"
		} else {
			query += " AND created_at <= $2"
		}
		args = append(args, *end)
	}
	query += " ORDER BY created_at DESC"

	rows, err := r.db.Query(query, args...)
	if err != nil {
		return nil, nil, fmt.Errorf("failed to list ministry contacts: %w", err)
	}
	defer rows.Close()

	var contacts []*domain.MinistryContact
	var interestsList []string

	for rows.Next() {
		contact := &domain.MinistryContact{}
		var interestsText sql.NullString
		if err := rows.Scan(
			&contact.ID,
			&contact.WorkerID,
			&contact.Name,
			&contact.Phone,
			&contact.Email,
			&contact.Address,
			&interestsText,
			&contact.ContactMethod,
			&contact.ContactSent,
			&contact.ContactSentAt,
			&contact.AppointmentScheduled,
			&contact.AppointmentDate,
			&contact.AppointmentTime,
			&contact.AppointmentNotes,
			&contact.Notes,
			&contact.CreatedAt,
			&contact.UpdatedAt,
		); err != nil {
			return nil, nil, fmt.Errorf("failed to scan ministry contact: %w", err)
		}
		contacts = append(contacts, contact)
		if interestsText.Valid {
			interestsList = append(interestsList, interestsText.String)
		} else {
			interestsList = append(interestsList, "{}")
		}
	}

	return contacts, interestsList, nil
}

func (r *ministryContactRepository) Update(contact *domain.MinistryContact, interestsJSON string) error {
	query := `UPDATE ministry_contacts SET
		name = $2,
		phone = $3,
		email = $4,
		address = $5,
		interests = $6::jsonb,
		contact_method = $7,
		contact_sent = $8,
		contact_sent_at = $9,
		appointment_scheduled = $10,
		appointment_date = $11,
		appointment_time = $12,
		appointment_notes = $13,
		notes = $14,
		updated_at = $15
		WHERE id = $1`

	_, err := r.db.Exec(
		query,
		contact.ID,
		contact.Name,
		contact.Phone,
		contact.Email,
		contact.Address,
		interestsJSON,
		contact.ContactMethod,
		contact.ContactSent,
		contact.ContactSentAt,
		contact.AppointmentScheduled,
		contact.AppointmentDate,
		contact.AppointmentTime,
		contact.AppointmentNotes,
		contact.Notes,
		contact.UpdatedAt,
	)
	if err != nil {
		return fmt.Errorf("failed to update ministry contact: %w", err)
	}
	return nil
}

func (r *ministryContactRepository) Delete(id uuid.UUID) error {
	_, err := r.db.Exec(`DELETE FROM ministry_contacts WHERE id = $1`, id)
	if err != nil {
		return fmt.Errorf("failed to delete ministry contact: %w", err)
	}
	return nil
}

// helper to build interests JSON from contact booleans
func BuildInterestsJSONFromContact(contact *domain.MinistryContact) (string, error) {
	m := map[string]bool{
		"personal_bible_studies": contact.PersonalBibleStudies,
		"group_bible_studies":    contact.GroupBibleStudies,
		"health_seminar":         contact.HealthSeminar,
		"health_expo":            contact.HealthExpo,
		"vbs":                    contact.VBS,
		"health_consultation":    contact.HealthConsultation,
	}
	b, err := json.Marshal(m)
	if err != nil {
		return "{}", err
	}
	return string(b), nil
}

// helper to apply interests JSON to contact booleans
func ApplyInterestsJSONToContact(contact *domain.MinistryContact, interestsJSON string) {
	if interestsJSON == "" {
		return
	}
	var m map[string]bool
	if err := json.Unmarshal([]byte(interestsJSON), &m); err != nil {
		return
	}
	if v, ok := m["personal_bible_studies"]; ok {
		contact.PersonalBibleStudies = v
	}
	if v, ok := m["group_bible_studies"]; ok {
		contact.GroupBibleStudies = v
	}
	if v, ok := m["health_seminar"]; ok {
		contact.HealthSeminar = v
	}
	if v, ok := m["health_expo"]; ok {
		contact.HealthExpo = v
	}
	if v, ok := m["vbs"]; ok {
		contact.VBS = v
	}
	if v, ok := m["health_consultation"]; ok {
		contact.HealthConsultation = v
	}
}
