package service

import (
	"errors"
	"rally-point/user-service/internal/domain"

	"github.com/google/uuid"
)

type MockSessionService struct{}

func NewMockSessionService() *MockSessionService {
	return &MockSessionService{}
}

func (m *MockSessionService) Create(session *domain.UserSession) error {
	return nil // Mock implementation
}

func (m *MockSessionService) GetByRefreshToken(token string) (*domain.UserSession, error) {
	return nil, errors.New("not implemented")
}

func (m *MockSessionService) DeleteByUserID(userID uuid.UUID) error {
	return nil // Mock implementation
}

func (m *MockSessionService) DeleteExpired() error {
	return nil // Mock implementation
}
