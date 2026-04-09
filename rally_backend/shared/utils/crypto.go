package utils

import (
	"crypto/rand"
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"math/big"
	"strings"

	"golang.org/x/crypto/bcrypt"
)

// HashPassword hashes a password using bcrypt
func HashPassword(password string) (string, error) {
	bytes, err := bcrypt.GenerateFromPassword([]byte(password), bcrypt.DefaultCost)
	return string(bytes), err
}

// CheckPasswordHash compares a password with its hash
func CheckPasswordHash(password, hash string) bool {
	err := bcrypt.CompareHashAndPassword([]byte(hash), []byte(password))
	return err == nil
}

// GenerateRandomString generates a random string of specified length
func GenerateRandomString(length int) (string, error) {
	const charset = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
	b := make([]byte, length)
	
	for i := range b {
		n, err := rand.Int(rand.Reader, big.NewInt(int64(len(charset))))
		if err != nil {
			return "", err
		}
		b[i] = charset[n.Int64()]
	}
	
	return string(b), nil
}

// GenerateTeamCode generates a random team invitation code
func GenerateTeamCode() (string, error) {
	const charset = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
	const length = 6
	
	b := make([]byte, length)
	
	for i := range b {
		n, err := rand.Int(rand.Reader, big.NewInt(int64(len(charset))))
		if err != nil {
			return "", err
		}
		b[i] = charset[n.Int64()]
	}
	
	return string(b), nil
}

// GenerateSecureToken generates a secure random token
func GenerateSecureToken(length int) (string, error) {
	bytes := make([]byte, length)
	if _, err := rand.Read(bytes); err != nil {
		return "", err
	}
	return hex.EncodeToString(bytes), nil
}

// HashSHA256 creates a SHA256 hash of the input string
func HashSHA256(input string) string {
	hash := sha256.Sum256([]byte(input))
	return hex.EncodeToString(hash[:])
}

// GenerateAPIKey generates a secure API key
func GenerateAPIKey() (string, error) {
	// Generate 32 random bytes (256 bits)
	bytes := make([]byte, 32)
	if _, err := rand.Read(bytes); err != nil {
		return "", err
	}
	
	// Convert to hex string and add prefix
	key := hex.EncodeToString(bytes)
	return fmt.Sprintf("rp_%s", key), nil
}

// MaskSensitiveData masks sensitive data for logging
func MaskSensitiveData(data string) string {
	if len(data) <= 4 {
		return strings.Repeat("*", len(data))
	}
	
	// Show first 2 and last 2 characters, mask the rest
	return data[:2] + strings.Repeat("*", len(data)-4) + data[len(data)-2:]
}

// MaskEmail masks email address for logging
func MaskEmail(email string) string {
	parts := strings.Split(email, "@")
	if len(parts) != 2 {
		return MaskSensitiveData(email)
	}
	
	username := parts[0]
	domain := parts[1]
	
	if len(username) <= 2 {
		return strings.Repeat("*", len(username)) + "@" + domain
	}
	
	maskedUsername := username[:1] + strings.Repeat("*", len(username)-2) + username[len(username)-1:]
	return maskedUsername + "@" + domain
}

// MaskPhone masks phone number for logging
func MaskPhone(phone string) string {
	if len(phone) <= 4 {
		return strings.Repeat("*", len(phone))
	}
	
	// Show last 4 digits only
	return strings.Repeat("*", len(phone)-4) + phone[len(phone)-4:]
}

// GenerateResetToken generates a password reset token
func GenerateResetToken() (string, error) {
	return GenerateSecureToken(32) // 64 character hex string
}

// GenerateVerificationCode generates a 6-digit verification code
func GenerateVerificationCode() (string, error) {
	code := make([]byte, 6)
	
	for i := range code {
		n, err := rand.Int(rand.Reader, big.NewInt(10))
		if err != nil {
			return "", err
		}
		code[i] = byte('0' + n.Int64())
	}
	
	return string(code), nil
}
