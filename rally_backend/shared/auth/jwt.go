package auth

import (
	"errors"
	"time"

	"github.com/golang-jwt/jwt/v5"
	"github.com/google/uuid"
)

var (
	ErrInvalidToken = errors.New("invalid token")
	ErrExpiredToken = errors.New("token has expired")
)

// Claims represents the JWT claims
type Claims struct {
	UserID      uuid.UUID  `json:"user_id"`
	Email       string     `json:"email"`
	Role        string     `json:"role"`
	TeamID      *uuid.UUID `json:"team_id,omitempty"`
	DisplayName string     `json:"display_name,omitempty"`
	TokenType   string     `json:"token_type"` // "access" or "refresh"
	jwt.RegisteredClaims
}

// JWTManager handles JWT token operations
type JWTManager struct {
	secretKey     string
	tokenDuration time.Duration
	refreshDuration time.Duration
}

// NewJWTManager creates a new JWT manager
func NewJWTManager(secretKey string, tokenDuration, refreshDuration time.Duration) *JWTManager {
	return &JWTManager{
		secretKey:       secretKey,
		tokenDuration:   tokenDuration,
		refreshDuration: refreshDuration,
	}
}

// GenerateAccessToken generates a new access token
func (manager *JWTManager) GenerateAccessToken(userID uuid.UUID, email, role string, teamID *uuid.UUID, displayName string) (string, error) {
	claims := &Claims{
		UserID:      userID,
		Email:       email,
		Role:        role,
		TeamID:      teamID,
		DisplayName: displayName,
		TokenType:   "access",
		RegisteredClaims: jwt.RegisteredClaims{
			ExpiresAt: jwt.NewNumericDate(time.Now().Add(manager.tokenDuration)),
			IssuedAt:  jwt.NewNumericDate(time.Now()),
			NotBefore: jwt.NewNumericDate(time.Now()),
			Issuer:    "rally-point-api",
			Subject:   userID.String(),
		},
	}

	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	return token.SignedString([]byte(manager.secretKey))
}

// GenerateRefreshToken generates a new refresh token
func (manager *JWTManager) GenerateRefreshToken(userID uuid.UUID, email, role string, teamID *uuid.UUID, displayName string) (string, error) {
	claims := &Claims{
		UserID:      userID,
		Email:       email,
		Role:        role,
		TeamID:      teamID,
		DisplayName: displayName,
		TokenType:   "refresh",
		RegisteredClaims: jwt.RegisteredClaims{
			ExpiresAt: jwt.NewNumericDate(time.Now().Add(manager.refreshDuration)),
			IssuedAt:  jwt.NewNumericDate(time.Now()),
			NotBefore: jwt.NewNumericDate(time.Now()),
			Issuer:    "rally-point-api",
			Subject:   userID.String(),
		},
	}

	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	return token.SignedString([]byte(manager.secretKey))
}

// VerifyToken verifies a token and returns the claims
func (manager *JWTManager) VerifyToken(tokenString string) (*Claims, error) {
	token, err := jwt.ParseWithClaims(
		tokenString,
		&Claims{},
		func(token *jwt.Token) (interface{}, error) {
			return []byte(manager.secretKey), nil
		},
	)

	if err != nil {
		return nil, ErrInvalidToken
	}

	claims, ok := token.Claims.(*Claims)
	if !ok || !token.Valid {
		return nil, ErrInvalidToken
	}

	if claims.ExpiresAt.Time.Before(time.Now()) {
		return nil, ErrExpiredToken
	}

	return claims, nil
}

// ExtractTokenFromHeader extracts token from Authorization header
func ExtractTokenFromHeader(authHeader string) string {
	const bearerPrefix = "Bearer "
	if len(authHeader) > len(bearerPrefix) && authHeader[:len(bearerPrefix)] == bearerPrefix {
		return authHeader[len(bearerPrefix):]
	}
	return ""
}

// TokenPair represents access and refresh tokens
type TokenPair struct {
	AccessToken  string `json:"access_token"`
	RefreshToken string `json:"refresh_token"`
	ExpiresIn    int64  `json:"expires_in"`
}

// GenerateTokenPair generates both access and refresh tokens
func (manager *JWTManager) GenerateTokenPair(userID uuid.UUID, email, role string, teamID *uuid.UUID, displayName string) (*TokenPair, error) {
	accessToken, err := manager.GenerateAccessToken(userID, email, role, teamID, displayName)
	if err != nil {
		return nil, err
	}

	refreshToken, err := manager.GenerateRefreshToken(userID, email, role, teamID, displayName)
	if err != nil {
		return nil, err
	}

	return &TokenPair{
		AccessToken:  accessToken,
		RefreshToken: refreshToken,
		ExpiresIn:    int64(manager.tokenDuration.Seconds()),
	}, nil
}
