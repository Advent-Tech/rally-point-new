package domain

import (
	"time"

	"github.com/google/uuid"
)

// Survey represents a survey in the system
type Survey struct {
	ID               uuid.UUID  `json:"id" db:"id"`
	Title            string     `json:"title" db:"title"`
	Description      *string    `json:"description,omitempty" db:"description"`
	TeamID           *uuid.UUID `json:"team_id,omitempty" db:"team_id"`
	CreatorID        uuid.UUID  `json:"creator_id" db:"creator_id"`
	IsActive         bool       `json:"is_active" db:"is_active"`
	RequiresLocation bool       `json:"requires_location" db:"requires_location"`
	StartDate        *time.Time `json:"start_date,omitempty" db:"start_date"`
	EndDate          *time.Time `json:"end_date,omitempty" db:"end_date"`
	CreatedAt        time.Time  `json:"created_at" db:"created_at"`
	UpdatedAt        time.Time  `json:"updated_at" db:"updated_at"`
}

// SurveyQuestion represents a question in a survey
type SurveyQuestion struct {
	ID           uuid.UUID `json:"id" db:"id"`
	SurveyID     uuid.UUID `json:"survey_id" db:"survey_id"`
	QuestionText string    `json:"question_text" db:"question_text"`
	QuestionType string    `json:"question_type" db:"question_type"` // "text", "textarea", "number", "date", "select", "radio", "checkbox", "photo", "signature", "rating", "boolean"
	Placeholder  *string   `json:"placeholder,omitempty" db:"placeholder"`
	Options      *string   `json:"options,omitempty" db:"options"`     // JSON array for select/radio/checkbox
	Validation   *string   `json:"validation,omitempty" db:"validation"` // JSON object: {min, max, minLength, maxLength, pattern}
	IsRequired   bool      `json:"is_required" db:"is_required"`
	OrderIndex   int       `json:"order_index" db:"order_index"`
	CreatedAt    time.Time `json:"created_at" db:"created_at"`
}

// SurveyResponse represents a response to a survey
type SurveyResponse struct {
	ID           uuid.UUID  `json:"id" db:"id"`
	SurveyID     uuid.UUID  `json:"survey_id" db:"survey_id"`
	AssignmentID *uuid.UUID `json:"assignment_id,omitempty" db:"assignment_id"`
	RespondentID uuid.UUID  `json:"respondent_id" db:"respondent_id"`
	Answers      string     `json:"answers" db:"answers"` // JSONB stored as string
	Latitude     *float64   `json:"latitude,omitempty"`   // Extracted from location
	Longitude    *float64   `json:"longitude,omitempty"`  // Extracted from location
	SubmittedAt  time.Time  `json:"submitted_at" db:"submitted_at"`
}

// SurveyAnswer represents an answer to a survey question
type SurveyAnswer struct {
	ID           uuid.UUID `json:"id" db:"id"`
	ResponseID   uuid.UUID `json:"response_id" db:"response_id"`
	QuestionID   uuid.UUID `json:"question_id" db:"question_id"`
	Answer       string    `json:"answer" db:"answer"`                         // For text, number, date, rating, boolean
	PhotoURLs    *string   `json:"photo_urls,omitempty" db:"photo_urls"`       // JSON array of photo URLs
	SignatureURL *string   `json:"signature_url,omitempty" db:"signature_url"` // URL of signature image
	CreatedAt    time.Time `json:"created_at" db:"created_at"`
}

// SurveyAssignment represents assignment of a survey to workers
type SurveyAssignment struct {
	ID          uuid.UUID  `json:"id" db:"id"`
	SurveyID    uuid.UUID  `json:"survey_id" db:"survey_id"`
	AssignedTo  uuid.UUID  `json:"assigned_to" db:"assigned_to"`
	AssignedBy  uuid.UUID  `json:"assigned_by" db:"assigned_by"`
	DueDate     *time.Time `json:"due_date,omitempty" db:"due_date"`
	IsCompleted bool       `json:"is_completed" db:"is_completed"`
	AssignedAt  time.Time  `json:"assigned_at" db:"assigned_at"`
	CompletedAt *time.Time `json:"completed_at,omitempty" db:"completed_at"`
}

// CreateSurveyRequest represents the request to create a survey
type CreateSurveyRequest struct {
	Title            string                  `json:"title" binding:"required"`
	Description      string                  `json:"description,omitempty"`
	TeamID           *uuid.UUID              `json:"team_id,omitempty"`
	RequiresLocation bool                    `json:"requires_location"`
	StartDate        *time.Time              `json:"start_date,omitempty"`
	EndDate          *time.Time              `json:"end_date,omitempty"`
	Questions        []CreateQuestionRequest `json:"questions" binding:"required,min=1"`
}

// CreateQuestionRequest represents the request to create a survey question
type CreateQuestionRequest struct {
	QuestionText string                 `json:"question_text" binding:"required"`
	QuestionType string                 `json:"question_type" binding:"required"`
	Placeholder  string                 `json:"placeholder,omitempty"`
	Options      []string               `json:"options,omitempty"`
	Validation   map[string]interface{} `json:"validation,omitempty"`
	IsRequired   bool                   `json:"is_required"`
	OrderIndex   int                    `json:"order_index"`
}

// UpdateSurveyRequest represents the request to update a survey
type UpdateSurveyRequest struct {
	Title            *string    `json:"title,omitempty"`
	Description      *string    `json:"description,omitempty"`
	IsActive         *bool      `json:"is_active,omitempty"`
	RequiresLocation *bool      `json:"requires_location,omitempty"`
	StartDate        *time.Time `json:"start_date,omitempty"`
	EndDate          *time.Time `json:"end_date,omitempty"`
}

// SubmitResponseRequest represents the request to submit a survey response
type SubmitResponseRequest struct {
	SurveyID  uuid.UUID `json:"survey_id" binding:"required"`
	Latitude  *float64  `json:"latitude,omitempty"`
	Longitude *float64  `json:"longitude,omitempty"`
	Answers   []SubmitAnswerRequest `json:"answers" binding:"required"`
}

// SubmitAnswerRequest represents an answer in a response submission
type SubmitAnswerRequest struct {
	QuestionID   uuid.UUID `json:"question_id" binding:"required"`
	Answer       string    `json:"answer"`
	PhotoURLs    []string  `json:"photo_urls,omitempty"`
	SignatureURL string    `json:"signature_url,omitempty"`
}

// AssignSurveyRequest represents the request to assign a survey to users
type AssignSurveyRequest struct {
	SurveyID uuid.UUID   `json:"survey_id" binding:"required"`
	UserIDs  []uuid.UUID `json:"user_ids" binding:"required,min=1"`
	DueDate  *time.Time  `json:"due_date,omitempty"`
}

// UpdateQuestionRequest represents the request to update a survey question
type UpdateQuestionRequest struct {
	QuestionText *string                `json:"question_text,omitempty"`
	QuestionType *string                `json:"question_type,omitempty"`
	Placeholder  *string                `json:"placeholder,omitempty"`
	Options      []string               `json:"options,omitempty"`
	Validation   map[string]interface{} `json:"validation,omitempty"`
	IsRequired   *bool                  `json:"is_required,omitempty"`
	OrderIndex   *int                   `json:"order_index,omitempty"`
}

// ReorderQuestionsRequest represents the request to reorder survey questions
type ReorderQuestionsRequest struct {
	QuestionOrders []QuestionOrder `json:"question_orders" binding:"required"`
}

// QuestionOrder represents the order for a single question
type QuestionOrder struct {
	QuestionID uuid.UUID `json:"question_id" binding:"required"`
	OrderIndex int       `json:"order_index" binding:"required"`
}

// SurveyWithQuestions represents a survey with its questions
type SurveyWithQuestions struct {
	Survey    *Survey           `json:"survey"`
	Questions []*SurveyQuestion `json:"questions"`
}

// SurveyResponseWithAnswers represents a response with its answers
type SurveyResponseWithAnswers struct {
	Response *SurveyResponse `json:"response"`
	Answers  []*SurveyAnswer `json:"answers"`
}

// SurveyStats represents survey statistics
type SurveyStats struct {
	TotalSurveys      int     `json:"total_surveys"`
	ActiveSurveys     int     `json:"active_surveys"`
	TotalResponses    int     `json:"total_responses"`
	CompletionRate    float64 `json:"completion_rate"`
	AverageCompletion float64 `json:"average_completion_minutes"`
}

// QuestionStats represents statistics for a specific question
type QuestionStats struct {
	QuestionID   uuid.UUID              `json:"question_id"`
	QuestionText string                 `json:"question_text"`
	QuestionType string                 `json:"question_type"`
	TotalAnswers int                    `json:"total_answers"`
	Answers      map[string]int         `json:"answers"` // Answer -> Count
	Statistics   map[string]interface{} `json:"statistics,omitempty"` // Additional stats like average for ratings
}

// SurveyAnalytics represents comprehensive survey analytics
type SurveyAnalytics struct {
	Survey         *Survey          `json:"survey"`
	Stats          *SurveyStats     `json:"stats"`
	QuestionStats  []*QuestionStats `json:"question_stats"`
	ResponseTrends []ResponseTrend  `json:"response_trends"`
}

// ResponseTrend represents response trends over time
type ResponseTrend struct {
	Date      time.Time `json:"date"`
	Responses int       `json:"responses"`
}

// SurveyRepository defines the interface for survey data access
type SurveyRepository interface {
	// Survey management
	CreateSurvey(survey *Survey) error
	GetSurveyByID(id uuid.UUID) (*Survey, error)
	GetAllSurveys() ([]*Survey, error)
	GetSurveysByTeamID(teamID uuid.UUID) ([]*Survey, error)
	GetSurveysByCreatorID(creatorID uuid.UUID) ([]*Survey, error)
	UpdateSurvey(survey *Survey) error
	DeleteSurvey(id uuid.UUID) error
	
	// Question management
	CreateQuestion(question *SurveyQuestion) error
	GetQuestionByID(id uuid.UUID) (*SurveyQuestion, error)
	GetQuestionsBySurveyID(surveyID uuid.UUID) ([]*SurveyQuestion, error)
	UpdateQuestion(question *SurveyQuestion) error
	DeleteQuestion(id uuid.UUID) error
	ReorderQuestions(surveyID uuid.UUID, orders []QuestionOrder) error
	
	// Response management
	CreateResponse(response *SurveyResponse) error
	GetResponseByID(id uuid.UUID) (*SurveyResponse, error)
	GetResponsesBySurveyID(surveyID uuid.UUID, limit, offset int) ([]*SurveyResponse, error)
	GetResponsesByUserID(userID uuid.UUID, limit, offset int) ([]*SurveyResponse, error)
	UpdateResponse(response *SurveyResponse) error
	
	// Answer management
	CreateAnswer(answer *SurveyAnswer) error
	GetAnswersByResponseID(responseID uuid.UUID) ([]*SurveyAnswer, error)
	GetAnswersByQuestionID(questionID uuid.UUID) ([]*SurveyAnswer, error)
	
	// Assignment management
	CreateAssignment(assignment *SurveyAssignment) error
	GetAssignmentsByUserID(userID uuid.UUID) ([]*SurveyAssignment, error)
	GetAssignmentsBySurveyID(surveyID uuid.UUID) ([]*SurveyAssignment, error)
	UpdateAssignment(assignment *SurveyAssignment) error
	
	// Analytics
	GetSurveyStats(surveyID uuid.UUID) (*SurveyStats, error)
	GetTeamSurveyStats(teamID uuid.UUID) (*SurveyStats, error)
	GetQuestionStats(questionID uuid.UUID) (*QuestionStats, error)
	GetResponseTrends(surveyID uuid.UUID, days int) ([]ResponseTrend, error)
}

// SurveyService defines the interface for survey business logic
type SurveyService interface {
	// Survey management
	CreateSurvey(creatorID uuid.UUID, req *CreateSurveyRequest) (*SurveyWithQuestions, error)
	GetSurvey(id uuid.UUID) (*SurveyWithQuestions, error)
	GetAllSurveys() ([]*SurveyWithQuestions, error)
	UpdateSurvey(id uuid.UUID, req *UpdateSurveyRequest) (*Survey, error)
	DeleteSurvey(id uuid.UUID) error
	GetTeamSurveys(teamID uuid.UUID) ([]*SurveyWithQuestions, error)
	GetUserSurveys(userID uuid.UUID) ([]*Survey, error)

	// Question management
	AddQuestion(surveyID uuid.UUID, req *CreateQuestionRequest) (*SurveyQuestion, error)
	UpdateQuestion(surveyID, questionID uuid.UUID, req *UpdateQuestionRequest) (*SurveyQuestion, error)
	DeleteQuestion(surveyID, questionID uuid.UUID) error
	ReorderQuestions(surveyID uuid.UUID, req *ReorderQuestionsRequest) error

	// Response management
	SubmitResponse(userID uuid.UUID, req *SubmitResponseRequest) (*SurveyResponseWithAnswers, error)
	GetSurveyResponses(surveyID uuid.UUID, limit, offset int) ([]*SurveyResponseWithAnswers, error)
	GetUserResponses(userID uuid.UUID, limit, offset int) ([]*SurveyResponseWithAnswers, error)

	// Assignment management
	AssignSurvey(assignerID uuid.UUID, req *AssignSurveyRequest) error
	GetUserAssignments(userID uuid.UUID) ([]*SurveyAssignment, error)

	// Analytics
	GetSurveyAnalytics(surveyID uuid.UUID) (*SurveyAnalytics, error)
	GetTeamSurveyStats(teamID uuid.UUID) (*SurveyStats, error)
}

// WorkerSurveyStats represents survey statistics for a specific worker
type WorkerSurveyStats struct {
	WorkerID         uuid.UUID `json:"worker_id"`
	AssignedCount    int       `json:"assigned_count"`
	CompletedCount   int       `json:"completed_count"`
	PendingCount     int       `json:"pending_count"`
	OverdueCount     int       `json:"overdue_count"`
	CompletionRate   float64   `json:"completion_rate"`
	TodayCompleted   int       `json:"today_completed"`
	WeekCompleted    int       `json:"week_completed"`
	MonthCompleted   int       `json:"month_completed"`
}

// Constants
const (
	// Question types
	QuestionTypeText           = "text"
	QuestionTypeTextarea       = "textarea"
	QuestionTypeNumber         = "number"
	QuestionTypeDate           = "date"
	QuestionTypeSelect         = "select"
	QuestionTypeRadio          = "radio"
	QuestionTypeCheckbox       = "checkbox"
	QuestionTypePhoto          = "photo"
	QuestionTypeSignature      = "signature"
	QuestionTypeRating         = "rating"
	QuestionTypeBoolean        = "boolean"
	QuestionTypeMultipleChoice = "multiple_choice" // Legacy, same as radio
	QuestionTypeYesNo          = "yes_no"          // Legacy, same as boolean

	// Default values
	DefaultResponseLimit = 50
	DefaultStatsLimit    = 100
	MaxResponseLimit     = 200
	MaxStatsLimit        = 500

	// Analytics
	DefaultTrendDays = 30
	MaxTrendDays     = 365
)
