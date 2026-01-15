package service

import (
	"encoding/json"
	"fmt"
	"time"

	"github.com/google/uuid"
	"rally-point/survey-service/internal/domain"
)

type surveyService struct {
	surveyRepo domain.SurveyRepository
}

// NewSurveyService creates a new survey service
func NewSurveyService(surveyRepo domain.SurveyRepository) domain.SurveyService {
	return &surveyService{
		surveyRepo: surveyRepo,
	}
}

// CreateSurvey creates a new survey with questions
func (s *surveyService) CreateSurvey(creatorID uuid.UUID, req *domain.CreateSurveyRequest) (*domain.SurveyWithQuestions, error) {
	// Validate request
	if len(req.Questions) == 0 {
		return nil, fmt.Errorf("survey must have at least one question")
	}

	// Determine team IDs for multi-team assignment
	var teamIDs []uuid.UUID
	if req.AssignToAllTeams {
		// Get all active team IDs
		allTeamIDs, err := s.surveyRepo.GetAllTeamIDs()
		if err != nil {
			return nil, fmt.Errorf("failed to get all teams: %w", err)
		}
		teamIDs = allTeamIDs
	} else if len(req.TeamIDs) > 0 {
		// Use provided team IDs
		teamIDs = req.TeamIDs
	} else if req.TeamID != nil {
		// Backward compatibility: use single team ID
		teamIDs = []uuid.UUID{*req.TeamID}
	}

	// Create survey (team_id is now optional in DB)
	survey := &domain.Survey{
		ID:               uuid.New(),
		Title:            req.Title,
		TeamID:           req.TeamID, // Keep for backward compatibility
		TeamIDs:          teamIDs,    // Assigned teams
		CreatorID:        creatorID,
		IsActive:         true,
		RequiresLocation: req.RequiresLocation,
		StartDate:        req.StartDate,
		EndDate:          req.EndDate,
		CreatedAt:        time.Now(),
		UpdatedAt:        time.Now(),
	}

	if req.Description != "" {
		survey.Description = &req.Description
	}

	err := s.surveyRepo.CreateSurvey(survey)
	if err != nil {
		return nil, fmt.Errorf("failed to create survey: %w", err)
	}

	// Add team associations to junction table
	if len(teamIDs) > 0 {
		err = s.surveyRepo.AddSurveyTeams(survey.ID, teamIDs)
		if err != nil {
			return nil, fmt.Errorf("failed to assign survey to teams: %w", err)
		}
	}

	// Create questions
	questions, err := s.createQuestionsFromRequests(survey.ID, req.Questions)
	if err != nil {
		return nil, err
	}

	return &domain.SurveyWithQuestions{
		Survey:    survey,
		Questions: questions,
	}, nil
}

// createQuestionsFromRequests creates questions from request data
func (s *surveyService) createQuestionsFromRequests(surveyID uuid.UUID, questionReqs []domain.CreateQuestionRequest) ([]*domain.SurveyQuestion, error) {
	var questions []*domain.SurveyQuestion
	for i, questionReq := range questionReqs {
		question := &domain.SurveyQuestion{
			ID:           uuid.New(),
			SurveyID:     surveyID,
			QuestionText: questionReq.QuestionText,
			QuestionType: questionReq.QuestionType,
			IsRequired:   questionReq.IsRequired,
			OrderIndex:   questionReq.OrderIndex,
			CreatedAt:    time.Now(),
		}

		// Set order index if not provided
		if question.OrderIndex == 0 {
			question.OrderIndex = i + 1
		}

		// Handle placeholder
		if questionReq.Placeholder != "" {
			question.Placeholder = &questionReq.Placeholder
		}

		// Handle options for choice-based questions
		if len(questionReq.Options) > 0 {
			optionsJSON, err := json.Marshal(questionReq.Options)
			if err != nil {
				return nil, fmt.Errorf("failed to marshal options: %w", err)
			}
			optionsStr := string(optionsJSON)
			question.Options = &optionsStr
		}

		// Handle validation rules
		if len(questionReq.Validation) > 0 {
			validationJSON, err := json.Marshal(questionReq.Validation)
			if err != nil {
				return nil, fmt.Errorf("failed to marshal validation: %w", err)
			}
			validationStr := string(validationJSON)
			question.Validation = &validationStr
		}

		err := s.surveyRepo.CreateQuestion(question)
		if err != nil {
			return nil, fmt.Errorf("failed to create question: %w", err)
		}

		questions = append(questions, question)
	}
	return questions, nil
}

// GetSurvey retrieves a survey with its questions
func (s *surveyService) GetSurvey(id uuid.UUID) (*domain.SurveyWithQuestions, error) {
	survey, err := s.surveyRepo.GetSurveyByID(id)
	if err != nil {
		return nil, fmt.Errorf("failed to get survey: %w", err)
	}

	questions, err := s.surveyRepo.GetQuestionsBySurveyID(id)
	if err != nil {
		return nil, fmt.Errorf("failed to get questions: %w", err)
	}

	return &domain.SurveyWithQuestions{
		Survey:    survey,
		Questions: questions,
	}, nil
}

// GetAllSurveys retrieves all surveys with their questions
func (s *surveyService) GetAllSurveys() ([]*domain.SurveyWithQuestions, error) {
	surveys, err := s.surveyRepo.GetAllSurveys()
	if err != nil {
		return nil, fmt.Errorf("failed to get surveys: %w", err)
	}

	var result []*domain.SurveyWithQuestions
	for _, survey := range surveys {
		questions, err := s.surveyRepo.GetQuestionsBySurveyID(survey.ID)
		if err != nil {
			return nil, fmt.Errorf("failed to get questions for survey %s: %w", survey.ID, err)
		}
		result = append(result, &domain.SurveyWithQuestions{
			Survey:    survey,
			Questions: questions,
		})
	}
	return result, nil
}

// UpdateSurvey updates a survey
func (s *surveyService) UpdateSurvey(id uuid.UUID, req *domain.UpdateSurveyRequest) (*domain.Survey, error) {
	survey, err := s.surveyRepo.GetSurveyByID(id)
	if err != nil {
		return nil, fmt.Errorf("survey not found: %w", err)
	}

	// Update fields if provided
	if req.Title != nil {
		survey.Title = *req.Title
	}
	if req.Description != nil {
		survey.Description = req.Description
	}
	if req.IsActive != nil {
		survey.IsActive = *req.IsActive
	}
	if req.RequiresLocation != nil {
		survey.RequiresLocation = *req.RequiresLocation
	}
	if req.StartDate != nil {
		survey.StartDate = req.StartDate
	}
	if req.EndDate != nil {
		survey.EndDate = req.EndDate
	}

	err = s.surveyRepo.UpdateSurvey(survey)
	if err != nil {
		return nil, fmt.Errorf("failed to update survey: %w", err)
	}

	return survey, nil
}

// DeleteSurvey deletes a survey
func (s *surveyService) DeleteSurvey(id uuid.UUID) error {
	return s.surveyRepo.DeleteSurvey(id)
}

// GetTeamSurveys retrieves surveys for a team with questions
func (s *surveyService) GetTeamSurveys(teamID uuid.UUID) ([]*domain.SurveyWithQuestions, error) {
	surveys, err := s.surveyRepo.GetSurveysByTeamID(teamID)
	if err != nil {
		return nil, err
	}

	// Fetch questions for each survey
	result := make([]*domain.SurveyWithQuestions, 0, len(surveys))
	for _, survey := range surveys {
		questions, err := s.surveyRepo.GetQuestionsBySurveyID(survey.ID)
		if err != nil {
			// Log error but continue - return survey without questions
			questions = []*domain.SurveyQuestion{}
		}
		result = append(result, &domain.SurveyWithQuestions{
			Survey:    survey,
			Questions: questions,
		})
	}

	return result, nil
}

// GetUserSurveys retrieves surveys created by a user
func (s *surveyService) GetUserSurveys(userID uuid.UUID) ([]*domain.Survey, error) {
	return s.surveyRepo.GetSurveysByCreatorID(userID)
}

// AddQuestion adds a new question to an existing survey
func (s *surveyService) AddQuestion(surveyID uuid.UUID, req *domain.CreateQuestionRequest) (*domain.SurveyQuestion, error) {
	// Validate survey exists
	_, err := s.surveyRepo.GetSurveyByID(surveyID)
	if err != nil {
		return nil, fmt.Errorf("survey not found: %w", err)
	}

	// Get existing questions to determine order index
	existingQuestions, err := s.surveyRepo.GetQuestionsBySurveyID(surveyID)
	if err != nil {
		return nil, fmt.Errorf("failed to get existing questions: %w", err)
	}

	question := &domain.SurveyQuestion{
		ID:           uuid.New(),
		SurveyID:     surveyID,
		QuestionText: req.QuestionText,
		QuestionType: req.QuestionType,
		IsRequired:   req.IsRequired,
		OrderIndex:   req.OrderIndex,
		CreatedAt:    time.Now(),
	}

	// Set order index if not provided
	if question.OrderIndex == 0 {
		question.OrderIndex = len(existingQuestions) + 1
	}

	// Handle placeholder
	if req.Placeholder != "" {
		question.Placeholder = &req.Placeholder
	}

	// Handle options
	if len(req.Options) > 0 {
		optionsJSON, err := json.Marshal(req.Options)
		if err != nil {
			return nil, fmt.Errorf("failed to marshal options: %w", err)
		}
		optionsStr := string(optionsJSON)
		question.Options = &optionsStr
	}

	// Handle validation
	if len(req.Validation) > 0 {
		validationJSON, err := json.Marshal(req.Validation)
		if err != nil {
			return nil, fmt.Errorf("failed to marshal validation: %w", err)
		}
		validationStr := string(validationJSON)
		question.Validation = &validationStr
	}

	err = s.surveyRepo.CreateQuestion(question)
	if err != nil {
		return nil, fmt.Errorf("failed to create question: %w", err)
	}

	return question, nil
}

// UpdateQuestion updates an existing question
func (s *surveyService) UpdateQuestion(surveyID, questionID uuid.UUID, req *domain.UpdateQuestionRequest) (*domain.SurveyQuestion, error) {
	// Get existing question
	question, err := s.surveyRepo.GetQuestionByID(questionID)
	if err != nil {
		return nil, fmt.Errorf("question not found: %w", err)
	}

	// Verify question belongs to survey
	if question.SurveyID != surveyID {
		return nil, fmt.Errorf("question does not belong to this survey")
	}

	// Update fields if provided
	if req.QuestionText != nil {
		question.QuestionText = *req.QuestionText
	}
	if req.QuestionType != nil {
		question.QuestionType = *req.QuestionType
	}
	if req.Placeholder != nil {
		question.Placeholder = req.Placeholder
	}
	if req.IsRequired != nil {
		question.IsRequired = *req.IsRequired
	}
	if req.OrderIndex != nil {
		question.OrderIndex = *req.OrderIndex
	}

	// Handle options
	if len(req.Options) > 0 {
		optionsJSON, err := json.Marshal(req.Options)
		if err != nil {
			return nil, fmt.Errorf("failed to marshal options: %w", err)
		}
		optionsStr := string(optionsJSON)
		question.Options = &optionsStr
	}

	// Handle validation
	if len(req.Validation) > 0 {
		validationJSON, err := json.Marshal(req.Validation)
		if err != nil {
			return nil, fmt.Errorf("failed to marshal validation: %w", err)
		}
		validationStr := string(validationJSON)
		question.Validation = &validationStr
	}

	err = s.surveyRepo.UpdateQuestion(question)
	if err != nil {
		return nil, fmt.Errorf("failed to update question: %w", err)
	}

	return question, nil
}

// DeleteQuestion deletes a question from a survey
func (s *surveyService) DeleteQuestion(surveyID, questionID uuid.UUID) error {
	// Get existing question
	question, err := s.surveyRepo.GetQuestionByID(questionID)
	if err != nil {
		return fmt.Errorf("question not found: %w", err)
	}

	// Verify question belongs to survey
	if question.SurveyID != surveyID {
		return fmt.Errorf("question does not belong to this survey")
	}

	return s.surveyRepo.DeleteQuestion(questionID)
}

// ReorderQuestions reorders questions in a survey
func (s *surveyService) ReorderQuestions(surveyID uuid.UUID, req *domain.ReorderQuestionsRequest) error {
	// Validate survey exists
	_, err := s.surveyRepo.GetSurveyByID(surveyID)
	if err != nil {
		return fmt.Errorf("survey not found: %w", err)
	}

	return s.surveyRepo.ReorderQuestions(surveyID, req.QuestionOrders)
}

// SubmitResponse submits a response to a survey
func (s *surveyService) SubmitResponse(userID uuid.UUID, req *domain.SubmitResponseRequest) (*domain.SurveyResponseWithAnswers, error) {
	// Validate survey exists
	survey, err := s.surveyRepo.GetSurveyByID(req.SurveyID)
	if err != nil {
		return nil, fmt.Errorf("survey not found: %w", err)
	}

	if !survey.IsActive {
		return nil, fmt.Errorf("survey is not active")
	}

	// Check if survey is within date range
	now := time.Now()
	if survey.StartDate != nil && now.Before(*survey.StartDate) {
		return nil, fmt.Errorf("survey has not started yet")
	}
	if survey.EndDate != nil && now.After(*survey.EndDate) {
		return nil, fmt.Errorf("survey has ended")
	}

	// Enforce location requirement
	if survey.RequiresLocation {
		if req.Latitude == nil || req.Longitude == nil {
			return nil, fmt.Errorf("this survey requires GPS location")
		}
	}

	// Get survey questions to validate answers
	questions, err := s.surveyRepo.GetQuestionsBySurveyID(req.SurveyID)
	if err != nil {
		return nil, fmt.Errorf("failed to get questions: %w", err)
	}

	// Create question map for validation
	questionMap := make(map[uuid.UUID]*domain.SurveyQuestion)
	for _, question := range questions {
		questionMap[question.ID] = question
	}

	// Validate required questions are answered
	answeredQuestions := make(map[uuid.UUID]bool)
	for _, answer := range req.Answers {
		answeredQuestions[answer.QuestionID] = true
	}

	for _, question := range questions {
		if question.IsRequired && !answeredQuestions[question.ID] {
			return nil, fmt.Errorf("required question not answered: %s", question.QuestionText)
		}
	}

	// Convert answers to JSON for storage
	answersJSON, err := json.Marshal(req.Answers)
	if err != nil {
		return nil, fmt.Errorf("failed to marshal answers: %w", err)
	}

	// Create response
	response := &domain.SurveyResponse{
		ID:           uuid.New(),
		SurveyID:     req.SurveyID,
		RespondentID: userID,
		Answers:      string(answersJSON),
		Latitude:     req.Latitude,
		Longitude:    req.Longitude,
		SubmittedAt:  time.Now(),
	}

	err = s.surveyRepo.CreateResponse(response)
	if err != nil {
		return nil, fmt.Errorf("failed to create response: %w", err)
	}

	// Create answers
	var answers []*domain.SurveyAnswer
	for _, answerReq := range req.Answers {
		// Validate question exists
		question, exists := questionMap[answerReq.QuestionID]
		if !exists {
			return nil, fmt.Errorf("invalid question ID: %s", answerReq.QuestionID)
		}

		answer := &domain.SurveyAnswer{
			ID:         uuid.New(),
			ResponseID: response.ID,
			QuestionID: answerReq.QuestionID,
			Answer:     answerReq.Answer,
			CreatedAt:  time.Now(),
		}

		// Handle photo URLs for photo type questions
		if question.QuestionType == domain.QuestionTypePhoto && len(answerReq.PhotoURLs) > 0 {
			photoURLsJSON, err := json.Marshal(answerReq.PhotoURLs)
			if err != nil {
				return nil, fmt.Errorf("failed to marshal photo URLs: %w", err)
			}
			photoURLsStr := string(photoURLsJSON)
			answer.PhotoURLs = &photoURLsStr
		}

		// Handle signature URL for signature type questions
		if question.QuestionType == domain.QuestionTypeSignature && answerReq.SignatureURL != "" {
			answer.SignatureURL = &answerReq.SignatureURL
		}

		err := s.surveyRepo.CreateAnswer(answer)
		if err != nil {
			return nil, fmt.Errorf("failed to create answer: %w", err)
		}

		answers = append(answers, answer)
	}

	return &domain.SurveyResponseWithAnswers{
		Response: response,
		Answers:  answers,
	}, nil
}

// GetSurveyResponses retrieves responses for a survey
func (s *surveyService) GetSurveyResponses(surveyID uuid.UUID, limit, offset int) ([]*domain.SurveyResponseWithAnswers, error) {
	if limit <= 0 {
		limit = domain.DefaultResponseLimit
	}
	if limit > domain.MaxResponseLimit {
		limit = domain.MaxResponseLimit
	}

	responses, err := s.surveyRepo.GetResponsesBySurveyID(surveyID, limit, offset)
	if err != nil {
		return nil, fmt.Errorf("failed to get responses: %w", err)
	}

	var responseWithAnswers []*domain.SurveyResponseWithAnswers
	for _, response := range responses {
		answers, err := s.surveyRepo.GetAnswersByResponseID(response.ID)
		if err != nil {
			return nil, fmt.Errorf("failed to get answers for response %s: %w", response.ID, err)
		}

		responseWithAnswers = append(responseWithAnswers, &domain.SurveyResponseWithAnswers{
			Response: response,
			Answers:  answers,
		})
	}

	return responseWithAnswers, nil
}

// GetUserResponses retrieves responses for a user
func (s *surveyService) GetUserResponses(userID uuid.UUID, limit, offset int) ([]*domain.SurveyResponseWithAnswers, error) {
	if limit <= 0 {
		limit = domain.DefaultResponseLimit
	}
	if limit > domain.MaxResponseLimit {
		limit = domain.MaxResponseLimit
	}

	responses, err := s.surveyRepo.GetResponsesByUserID(userID, limit, offset)
	if err != nil {
		return nil, fmt.Errorf("failed to get responses: %w", err)
	}

	var responseWithAnswers []*domain.SurveyResponseWithAnswers
	for _, response := range responses {
		answers, err := s.surveyRepo.GetAnswersByResponseID(response.ID)
		if err != nil {
			return nil, fmt.Errorf("failed to get answers for response %s: %w", response.ID, err)
		}

		responseWithAnswers = append(responseWithAnswers, &domain.SurveyResponseWithAnswers{
			Response: response,
			Answers:  answers,
		})
	}

	return responseWithAnswers, nil
}

// AssignSurvey assigns a survey to users
func (s *surveyService) AssignSurvey(assignerID uuid.UUID, req *domain.AssignSurveyRequest) error {
	// Validate survey exists
	_, err := s.surveyRepo.GetSurveyByID(req.SurveyID)
	if err != nil {
		return fmt.Errorf("survey not found: %w", err)
	}

	// Create assignments for each user
	for _, userID := range req.UserIDs {
		assignment := &domain.SurveyAssignment{
			ID:          uuid.New(),
			SurveyID:    req.SurveyID,
			AssignedTo:  userID,
			AssignedBy:  assignerID,
			DueDate:     req.DueDate,
			IsCompleted: false,
			AssignedAt:  time.Now(),
		}

		err := s.surveyRepo.CreateAssignment(assignment)
		if err != nil {
			return fmt.Errorf("failed to create assignment for user %s: %w", userID, err)
		}
	}

	return nil
}

// GetUserAssignments retrieves assignments for a user
func (s *surveyService) GetUserAssignments(userID uuid.UUID) ([]*domain.SurveyAssignment, error) {
	return s.surveyRepo.GetAssignmentsByUserID(userID)
}

// GetSurveyAnalytics retrieves comprehensive analytics for a survey
func (s *surveyService) GetSurveyAnalytics(surveyID uuid.UUID) (*domain.SurveyAnalytics, error) {
	// Get survey
	survey, err := s.surveyRepo.GetSurveyByID(surveyID)
	if err != nil {
		return nil, fmt.Errorf("failed to get survey: %w", err)
	}

	// Get survey stats
	stats, err := s.surveyRepo.GetSurveyStats(surveyID)
	if err != nil {
		return nil, fmt.Errorf("failed to get survey stats: %w", err)
	}

	// Get questions for question stats
	questions, err := s.surveyRepo.GetQuestionsBySurveyID(surveyID)
	if err != nil {
		return nil, fmt.Errorf("failed to get questions: %w", err)
	}

	// Get question stats
	var questionStats []*domain.QuestionStats
	for _, question := range questions {
		qStats, err := s.surveyRepo.GetQuestionStats(question.ID)
		if err != nil {
			continue // Skip questions with errors
		}
		questionStats = append(questionStats, qStats)
	}

	// Get response trends
	trends, err := s.surveyRepo.GetResponseTrends(surveyID, domain.DefaultTrendDays)
	if err != nil {
		trends = []domain.ResponseTrend{} // Empty trends if error
	}

	return &domain.SurveyAnalytics{
		Survey:         survey,
		Stats:          stats,
		QuestionStats:  questionStats,
		ResponseTrends: trends,
	}, nil
}

// GetTeamSurveyStats retrieves survey statistics for a team
func (s *surveyService) GetTeamSurveyStats(teamID uuid.UUID) (*domain.SurveyStats, error) {
	return s.surveyRepo.GetTeamSurveyStats(teamID)
}
