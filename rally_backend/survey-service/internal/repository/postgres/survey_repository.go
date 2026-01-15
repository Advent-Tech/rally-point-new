package postgres

import (
	"database/sql"
	"fmt"
	"time"

	"github.com/google/uuid"
	"rally-point/survey-service/internal/domain"
)

type surveyRepository struct {
	db *sql.DB
}

// NewSurveyRepository creates a new survey repository
func NewSurveyRepository(db *sql.DB) domain.SurveyRepository {
	return &surveyRepository{db: db}
}

// CreateSurvey creates a new survey
func (r *surveyRepository) CreateSurvey(survey *domain.Survey) error {
	query := `
		INSERT INTO surveys (id, title, description, team_id, created_by, is_active, requires_location, start_date, end_date, created_at, updated_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
	`

	_, err := r.db.Exec(
		query,
		survey.ID, survey.Title, survey.Description, survey.TeamID, survey.CreatorID,
		survey.IsActive, survey.RequiresLocation, survey.StartDate, survey.EndDate, survey.CreatedAt, survey.UpdatedAt,
	)

	return err
}

// GetSurveyByID retrieves a survey by ID
func (r *surveyRepository) GetSurveyByID(id uuid.UUID) (*domain.Survey, error) {
	query := `
		SELECT id, title, description, team_id, created_by, is_active, COALESCE(requires_location, false), start_date, end_date, created_at, updated_at
		FROM surveys WHERE id = $1
	`

	survey := &domain.Survey{}
	err := r.db.QueryRow(query, id).Scan(
		&survey.ID, &survey.Title, &survey.Description, &survey.TeamID, &survey.CreatorID,
		&survey.IsActive, &survey.RequiresLocation, &survey.StartDate, &survey.EndDate, &survey.CreatedAt, &survey.UpdatedAt,
	)

	if err == sql.ErrNoRows {
		return nil, fmt.Errorf("survey not found")
	}
	return survey, err
}

// GetAllSurveys retrieves all surveys
func (r *surveyRepository) GetAllSurveys() ([]*domain.Survey, error) {
	query := `SELECT id, title, description, team_id, created_by, is_active, COALESCE(requires_location, false), start_date, end_date, created_at, updated_at
		FROM surveys ORDER BY created_at DESC`

	rows, err := r.db.Query(query)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var surveys []*domain.Survey
	for rows.Next() {
		survey := &domain.Survey{}
		err := rows.Scan(
			&survey.ID, &survey.Title, &survey.Description, &survey.TeamID, &survey.CreatorID,
			&survey.IsActive, &survey.RequiresLocation, &survey.StartDate, &survey.EndDate, &survey.CreatedAt, &survey.UpdatedAt,
		)
		if err != nil {
			return nil, err
		}
		surveys = append(surveys, survey)
	}
	return surveys, nil
}

// GetSurveysByTeamID retrieves surveys by team ID
func (r *surveyRepository) GetSurveysByTeamID(teamID uuid.UUID) ([]*domain.Survey, error) {
	query := `SELECT id, title, description, team_id, created_by, is_active, COALESCE(requires_location, false), start_date, end_date, created_at, updated_at
		FROM surveys WHERE team_id = $1 ORDER BY created_at DESC`

	rows, err := r.db.Query(query, teamID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var surveys []*domain.Survey
	for rows.Next() {
		survey := &domain.Survey{}
		err := rows.Scan(&survey.ID, &survey.Title, &survey.Description, &survey.TeamID, &survey.CreatorID,
			&survey.IsActive, &survey.RequiresLocation, &survey.StartDate, &survey.EndDate, &survey.CreatedAt, &survey.UpdatedAt)
		if err != nil {
			return nil, err
		}
		surveys = append(surveys, survey)
	}
	return surveys, nil
}

// GetSurveysByCreatorID retrieves surveys by creator ID
func (r *surveyRepository) GetSurveysByCreatorID(creatorID uuid.UUID) ([]*domain.Survey, error) {
	query := `SELECT id, title, description, team_id, created_by, is_active, COALESCE(requires_location, false), start_date, end_date, created_at, updated_at
		FROM surveys WHERE created_by = $1 ORDER BY created_at DESC`

	rows, err := r.db.Query(query, creatorID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var surveys []*domain.Survey
	for rows.Next() {
		survey := &domain.Survey{}
		err := rows.Scan(&survey.ID, &survey.Title, &survey.Description, &survey.TeamID, &survey.CreatorID,
			&survey.IsActive, &survey.RequiresLocation, &survey.StartDate, &survey.EndDate, &survey.CreatedAt, &survey.UpdatedAt)
		if err != nil {
			return nil, err
		}
		surveys = append(surveys, survey)
	}
	return surveys, nil
}

// UpdateSurvey updates a survey
func (r *surveyRepository) UpdateSurvey(survey *domain.Survey) error {
	query := `UPDATE surveys SET title = $2, description = $3, is_active = $4, requires_location = $5, start_date = $6, end_date = $7, updated_at = $8 WHERE id = $1`
	survey.UpdatedAt = time.Now()
	_, err := r.db.Exec(query, survey.ID, survey.Title, survey.Description, survey.IsActive, survey.RequiresLocation, survey.StartDate, survey.EndDate, survey.UpdatedAt)
	return err
}

// DeleteSurvey deletes a survey
func (r *surveyRepository) DeleteSurvey(id uuid.UUID) error {
	_, err := r.db.Exec(`DELETE FROM surveys WHERE id = $1`, id)
	return err
}

// CreateQuestion creates a new survey question
func (r *surveyRepository) CreateQuestion(question *domain.SurveyQuestion) error {
	query := `INSERT INTO survey_questions (id, survey_id, question_text, question_type, placeholder, options, validation, is_required, order_index, created_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)`

	_, err := r.db.Exec(query, question.ID, question.SurveyID, question.QuestionText, question.QuestionType,
		question.Placeholder, question.Options, question.Validation, question.IsRequired, question.OrderIndex, question.CreatedAt)
	return err
}

// GetQuestionByID retrieves a question by ID
func (r *surveyRepository) GetQuestionByID(id uuid.UUID) (*domain.SurveyQuestion, error) {
	query := `SELECT id, survey_id, question_text, question_type, placeholder, options, validation, is_required, order_index, created_at
		FROM survey_questions WHERE id = $1`

	question := &domain.SurveyQuestion{}
	err := r.db.QueryRow(query, id).Scan(&question.ID, &question.SurveyID, &question.QuestionText, &question.QuestionType,
		&question.Placeholder, &question.Options, &question.Validation, &question.IsRequired, &question.OrderIndex, &question.CreatedAt)

	if err == sql.ErrNoRows {
		return nil, fmt.Errorf("question not found")
	}
	return question, err
}

// GetQuestionsBySurveyID retrieves questions by survey ID
func (r *surveyRepository) GetQuestionsBySurveyID(surveyID uuid.UUID) ([]*domain.SurveyQuestion, error) {
	query := `SELECT id, survey_id, question_text, question_type, placeholder, options, validation, is_required, order_index, created_at
		FROM survey_questions WHERE survey_id = $1 ORDER BY order_index, created_at`

	rows, err := r.db.Query(query, surveyID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var questions []*domain.SurveyQuestion
	for rows.Next() {
		question := &domain.SurveyQuestion{}
		err := rows.Scan(&question.ID, &question.SurveyID, &question.QuestionText, &question.QuestionType,
			&question.Placeholder, &question.Options, &question.Validation, &question.IsRequired, &question.OrderIndex, &question.CreatedAt)
		if err != nil {
			return nil, err
		}
		questions = append(questions, question)
	}
	return questions, nil
}

// UpdateQuestion updates a survey question
func (r *surveyRepository) UpdateQuestion(question *domain.SurveyQuestion) error {
	query := `UPDATE survey_questions SET question_text = $2, question_type = $3, placeholder = $4, options = $5, validation = $6, is_required = $7, order_index = $8 WHERE id = $1`
	_, err := r.db.Exec(query, question.ID, question.QuestionText, question.QuestionType, question.Placeholder, question.Options, question.Validation, question.IsRequired, question.OrderIndex)
	return err
}

// DeleteQuestion deletes a survey question
func (r *surveyRepository) DeleteQuestion(id uuid.UUID) error {
	_, err := r.db.Exec(`DELETE FROM survey_questions WHERE id = $1`, id)
	return err
}

// ReorderQuestions updates the order of questions in a survey
func (r *surveyRepository) ReorderQuestions(surveyID uuid.UUID, orders []domain.QuestionOrder) error {
	tx, err := r.db.Begin()
	if err != nil {
		return err
	}
	defer tx.Rollback()

	stmt, err := tx.Prepare(`UPDATE survey_questions SET order_index = $2 WHERE id = $1 AND survey_id = $3`)
	if err != nil {
		return err
	}
	defer stmt.Close()

	for _, order := range orders {
		_, err := stmt.Exec(order.QuestionID, order.OrderIndex, surveyID)
		if err != nil {
			return err
		}
	}

	return tx.Commit()
}

// Implement remaining methods with similar shortened patterns...
func (r *surveyRepository) CreateResponse(response *domain.SurveyResponse) error {
	query := `INSERT INTO survey_responses (id, survey_id, assignment_id, respondent_id, answers, location, submitted_at)
		VALUES ($1, $2, $3, $4, $5::jsonb, ST_SetSRID(ST_MakePoint($6, $7), 4326), $8)`
	_, err := r.db.Exec(query, response.ID, response.SurveyID, response.AssignmentID, response.RespondentID,
		response.Answers, response.Longitude, response.Latitude, response.SubmittedAt)
	return err
}

func (r *surveyRepository) GetResponseByID(id uuid.UUID) (*domain.SurveyResponse, error) {
	query := `SELECT id, survey_id, assignment_id, respondent_id, answers::text,
		ST_X(location) as longitude, ST_Y(location) as latitude, submitted_at
		FROM survey_responses WHERE id = $1`
	response := &domain.SurveyResponse{}
	err := r.db.QueryRow(query, id).Scan(&response.ID, &response.SurveyID, &response.AssignmentID, &response.RespondentID,
		&response.Answers, &response.Longitude, &response.Latitude, &response.SubmittedAt)
	if err == sql.ErrNoRows {
		return nil, fmt.Errorf("response not found")
	}
	return response, err
}

func (r *surveyRepository) GetResponsesBySurveyID(surveyID uuid.UUID, limit, offset int) ([]*domain.SurveyResponse, error) {
	query := `SELECT id, survey_id, assignment_id, respondent_id, answers::text,
		ST_X(location) as longitude, ST_Y(location) as latitude, submitted_at
		FROM survey_responses WHERE survey_id = $1 ORDER BY submitted_at DESC LIMIT $2 OFFSET $3`

	rows, err := r.db.Query(query, surveyID, limit, offset)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var responses []*domain.SurveyResponse
	for rows.Next() {
		response := &domain.SurveyResponse{}
		err := rows.Scan(&response.ID, &response.SurveyID, &response.AssignmentID, &response.RespondentID,
			&response.Answers, &response.Longitude, &response.Latitude, &response.SubmittedAt)
		if err != nil {
			return nil, err
		}
		responses = append(responses, response)
	}
	return responses, nil
}

func (r *surveyRepository) GetResponsesByUserID(userID uuid.UUID, limit, offset int) ([]*domain.SurveyResponse, error) {
	query := `SELECT id, survey_id, assignment_id, respondent_id, answers::text,
		ST_X(location) as longitude, ST_Y(location) as latitude, submitted_at
		FROM survey_responses WHERE respondent_id = $1 ORDER BY submitted_at DESC LIMIT $2 OFFSET $3`

	rows, err := r.db.Query(query, userID, limit, offset)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var responses []*domain.SurveyResponse
	for rows.Next() {
		response := &domain.SurveyResponse{}
		err := rows.Scan(&response.ID, &response.SurveyID, &response.AssignmentID, &response.RespondentID,
			&response.Answers, &response.Longitude, &response.Latitude, &response.SubmittedAt)
		if err != nil {
			return nil, err
		}
		responses = append(responses, response)
	}
	return responses, nil
}

func (r *surveyRepository) UpdateResponse(response *domain.SurveyResponse) error {
	query := `UPDATE survey_responses SET answers = $2::jsonb WHERE id = $1`
	_, err := r.db.Exec(query, response.ID, response.Answers)
	return err
}

func (r *surveyRepository) CreateAnswer(answer *domain.SurveyAnswer) error {
	query := `INSERT INTO survey_answers (id, response_id, question_id, answer, photo_urls, signature_url, created_at) VALUES ($1, $2, $3, $4, $5, $6, $7)`
	_, err := r.db.Exec(query, answer.ID, answer.ResponseID, answer.QuestionID, answer.Answer, answer.PhotoURLs, answer.SignatureURL, answer.CreatedAt)
	return err
}

func (r *surveyRepository) GetAnswersByResponseID(responseID uuid.UUID) ([]*domain.SurveyAnswer, error) {
	query := `SELECT id, response_id, question_id, answer, photo_urls, signature_url, created_at FROM survey_answers WHERE response_id = $1 ORDER BY created_at`

	rows, err := r.db.Query(query, responseID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var answers []*domain.SurveyAnswer
	for rows.Next() {
		answer := &domain.SurveyAnswer{}
		err := rows.Scan(&answer.ID, &answer.ResponseID, &answer.QuestionID, &answer.Answer, &answer.PhotoURLs, &answer.SignatureURL, &answer.CreatedAt)
		if err != nil {
			return nil, err
		}
		answers = append(answers, answer)
	}
	return answers, nil
}

func (r *surveyRepository) GetAnswersByQuestionID(questionID uuid.UUID) ([]*domain.SurveyAnswer, error) {
	query := `SELECT id, response_id, question_id, answer, photo_urls, signature_url, created_at FROM survey_answers WHERE question_id = $1 ORDER BY created_at`

	rows, err := r.db.Query(query, questionID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var answers []*domain.SurveyAnswer
	for rows.Next() {
		answer := &domain.SurveyAnswer{}
		err := rows.Scan(&answer.ID, &answer.ResponseID, &answer.QuestionID, &answer.Answer, &answer.PhotoURLs, &answer.SignatureURL, &answer.CreatedAt)
		if err != nil {
			return nil, err
		}
		answers = append(answers, answer)
	}
	return answers, nil
}

func (r *surveyRepository) CreateAssignment(assignment *domain.SurveyAssignment) error {
	query := `INSERT INTO survey_assignments (id, survey_id, assigned_to, assigned_by, due_date, is_completed, assigned_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7)`
	_, err := r.db.Exec(query, assignment.ID, assignment.SurveyID, assignment.AssignedTo, assignment.AssignedBy,
		assignment.DueDate, assignment.IsCompleted, assignment.AssignedAt)
	return err
}

func (r *surveyRepository) GetAssignmentsByUserID(userID uuid.UUID) ([]*domain.SurveyAssignment, error) {
	query := `SELECT id, survey_id, assigned_to, assigned_by, due_date, is_completed, assigned_at, completed_at
		FROM survey_assignments WHERE assigned_to = $1 ORDER BY assigned_at DESC`

	rows, err := r.db.Query(query, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var assignments []*domain.SurveyAssignment
	for rows.Next() {
		assignment := &domain.SurveyAssignment{}
		err := rows.Scan(&assignment.ID, &assignment.SurveyID, &assignment.AssignedTo, &assignment.AssignedBy,
			&assignment.DueDate, &assignment.IsCompleted, &assignment.AssignedAt, &assignment.CompletedAt)
		if err != nil {
			return nil, err
		}
		assignments = append(assignments, assignment)
	}
	return assignments, nil
}

func (r *surveyRepository) GetAssignmentsBySurveyID(surveyID uuid.UUID) ([]*domain.SurveyAssignment, error) {
	query := `SELECT id, survey_id, assigned_to, assigned_by, due_date, is_completed, assigned_at, completed_at
		FROM survey_assignments WHERE survey_id = $1 ORDER BY assigned_at DESC`

	rows, err := r.db.Query(query, surveyID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var assignments []*domain.SurveyAssignment
	for rows.Next() {
		assignment := &domain.SurveyAssignment{}
		err := rows.Scan(&assignment.ID, &assignment.SurveyID, &assignment.AssignedTo, &assignment.AssignedBy,
			&assignment.DueDate, &assignment.IsCompleted, &assignment.AssignedAt, &assignment.CompletedAt)
		if err != nil {
			return nil, err
		}
		assignments = append(assignments, assignment)
	}
	return assignments, nil
}

func (r *surveyRepository) UpdateAssignment(assignment *domain.SurveyAssignment) error {
	query := `UPDATE survey_assignments SET is_completed = $2, completed_at = $3 WHERE id = $1`
	_, err := r.db.Exec(query, assignment.ID, assignment.IsCompleted, assignment.CompletedAt)
	return err
}

func (r *surveyRepository) GetSurveyStats(surveyID uuid.UUID) (*domain.SurveyStats, error) {
	// All submitted responses are considered complete
	query := `SELECT COUNT(*) as total_responses FROM survey_responses WHERE survey_id = $1`

	stats := &domain.SurveyStats{}
	err := r.db.QueryRow(query, surveyID).Scan(&stats.TotalResponses)
	if err != nil {
		return nil, err
	}

	// All responses are complete once submitted
	stats.CompletionRate = 100.0
	return stats, nil
}

func (r *surveyRepository) GetTeamSurveyStats(teamID uuid.UUID) (*domain.SurveyStats, error) {
	query := `SELECT COUNT(DISTINCT s.id) as total_surveys, 
		COUNT(DISTINCT CASE WHEN s.is_active = true THEN s.id END) as active_surveys,
		COUNT(DISTINCT sr.id) as total_responses
		FROM surveys s LEFT JOIN survey_responses sr ON s.id = sr.survey_id WHERE s.team_id = $1`
	
	stats := &domain.SurveyStats{}
	err := r.db.QueryRow(query, teamID).Scan(&stats.TotalSurveys, &stats.ActiveSurveys, &stats.TotalResponses)
	return stats, err
}

func (r *surveyRepository) GetQuestionStats(questionID uuid.UUID) (*domain.QuestionStats, error) {
	stats := &domain.QuestionStats{
		QuestionID: questionID,
		Answers:    make(map[string]int),
	}
	
	// Get question details
	questionQuery := `SELECT question_text, question_type FROM survey_questions WHERE id = $1`
	err := r.db.QueryRow(questionQuery, questionID).Scan(&stats.QuestionText, &stats.QuestionType)
	if err != nil {
		return nil, err
	}
	
	// Get answer counts
	answerQuery := `SELECT answer, COUNT(*) FROM survey_answers WHERE question_id = $1 GROUP BY answer`
	rows, err := r.db.Query(answerQuery, questionID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	
	for rows.Next() {
		var answer string
		var count int
		err := rows.Scan(&answer, &count)
		if err != nil {
			return nil, err
		}
		stats.Answers[answer] = count
		stats.TotalAnswers += count
	}
	
	return stats, nil
}

func (r *surveyRepository) GetResponseTrends(surveyID uuid.UUID, days int) ([]domain.ResponseTrend, error) {
	query := `SELECT DATE(created_at) as date, COUNT(*) as responses
		FROM survey_responses
		WHERE survey_id = $1 AND created_at >= NOW() - INTERVAL '%d days'
		GROUP BY DATE(created_at) ORDER BY date`

	rows, err := r.db.Query(fmt.Sprintf(query, days), surveyID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var trends []domain.ResponseTrend
	for rows.Next() {
		var trend domain.ResponseTrend
		err := rows.Scan(&trend.Date, &trend.Responses)
		if err != nil {
			return nil, err
		}
		trends = append(trends, trend)
	}

	return trends, nil
}

// AddSurveyTeams adds team associations for a survey
func (r *surveyRepository) AddSurveyTeams(surveyID uuid.UUID, teamIDs []uuid.UUID) error {
	if len(teamIDs) == 0 {
		return nil
	}

	tx, err := r.db.Begin()
	if err != nil {
		return err
	}
	defer tx.Rollback()

	stmt, err := tx.Prepare(`INSERT INTO survey_teams (id, survey_id, team_id, created_at) VALUES ($1, $2, $3, NOW()) ON CONFLICT (survey_id, team_id) DO NOTHING`)
	if err != nil {
		return err
	}
	defer stmt.Close()

	for _, teamID := range teamIDs {
		_, err := stmt.Exec(uuid.New(), surveyID, teamID)
		if err != nil {
			return err
		}
	}

	return tx.Commit()
}

// GetSurveyTeams retrieves all team IDs associated with a survey
func (r *surveyRepository) GetSurveyTeams(surveyID uuid.UUID) ([]uuid.UUID, error) {
	query := `SELECT team_id FROM survey_teams WHERE survey_id = $1`

	rows, err := r.db.Query(query, surveyID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var teamIDs []uuid.UUID
	for rows.Next() {
		var teamID uuid.UUID
		err := rows.Scan(&teamID)
		if err != nil {
			return nil, err
		}
		teamIDs = append(teamIDs, teamID)
	}

	return teamIDs, nil
}

// RemoveSurveyTeams removes all team associations for a survey
func (r *surveyRepository) RemoveSurveyTeams(surveyID uuid.UUID) error {
	_, err := r.db.Exec(`DELETE FROM survey_teams WHERE survey_id = $1`, surveyID)
	return err
}

// GetAllTeamIDs retrieves all team IDs from the teams table
func (r *surveyRepository) GetAllTeamIDs() ([]uuid.UUID, error) {
	query := `SELECT id FROM teams`

	rows, err := r.db.Query(query)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var teamIDs []uuid.UUID
	for rows.Next() {
		var teamID uuid.UUID
		err := rows.Scan(&teamID)
		if err != nil {
			return nil, err
		}
		teamIDs = append(teamIDs, teamID)
	}

	return teamIDs, nil
}
