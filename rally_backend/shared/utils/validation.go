package utils

import (
	"regexp"
	"strings"
	"unicode"

	"github.com/google/uuid"
)

// IsValidEmail validates email format
func IsValidEmail(email string) bool {
	emailRegex := regexp.MustCompile(`^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$`)
	return emailRegex.MatchString(email)
}

// IsValidPassword validates password strength
func IsValidPassword(password string) bool {
	if len(password) < 8 {
		return false
	}

	var (
		hasUpper   = false
		hasLower   = false
		hasNumber  = false
		hasSpecial = false
	)

	for _, char := range password {
		switch {
		case unicode.IsUpper(char):
			hasUpper = true
		case unicode.IsLower(char):
			hasLower = true
		case unicode.IsNumber(char):
			hasNumber = true
		case unicode.IsPunct(char) || unicode.IsSymbol(char):
			hasSpecial = true
		}
	}

	return hasUpper && hasLower && hasNumber && hasSpecial
}

// IsValidUUID validates UUID format
func IsValidUUID(id string) bool {
	_, err := uuid.Parse(id)
	return err == nil
}

// IsValidPhoneNumber validates phone number format (basic validation)
func IsValidPhoneNumber(phone string) bool {
	// Remove all non-digit characters
	cleaned := regexp.MustCompile(`\D`).ReplaceAllString(phone, "")
	
	// Check if it's between 10-15 digits
	return len(cleaned) >= 10 && len(cleaned) <= 15
}

// SanitizeString removes potentially harmful characters from string
func SanitizeString(input string) string {
	// Remove leading/trailing whitespace
	input = strings.TrimSpace(input)
	
	// Remove null bytes
	input = strings.ReplaceAll(input, "\x00", "")
	
	return input
}

// ValidateRequired checks if required fields are present
func ValidateRequired(fields map[string]interface{}) map[string]string {
	errors := make(map[string]string)
	
	for field, value := range fields {
		if value == nil {
			errors[field] = "This field is required"
			continue
		}
		
		switch v := value.(type) {
		case string:
			if strings.TrimSpace(v) == "" {
				errors[field] = "This field is required"
			}
		case *string:
			if v == nil || strings.TrimSpace(*v) == "" {
				errors[field] = "This field is required"
			}
		}
	}
	
	return errors
}

// ValidateStringLength validates string length
func ValidateStringLength(value string, min, max int) bool {
	length := len(strings.TrimSpace(value))
	return length >= min && length <= max
}

// ValidateEnum validates if value is in allowed enum values
func ValidateEnum(value string, allowedValues []string) bool {
	for _, allowed := range allowedValues {
		if value == allowed {
			return true
		}
	}
	return false
}

// ValidateLatitude validates latitude coordinate
func ValidateLatitude(lat float64) bool {
	return lat >= -90.0 && lat <= 90.0
}

// ValidateLongitude validates longitude coordinate
func ValidateLongitude(lng float64) bool {
	return lng >= -180.0 && lng <= 180.0
}

// ValidateCoordinates validates both latitude and longitude
func ValidateCoordinates(lat, lng float64) bool {
	return ValidateLatitude(lat) && ValidateLongitude(lng)
}

// IsValidURL validates URL format
func IsValidURL(url string) bool {
	urlRegex := regexp.MustCompile(`^https?://[^\s/$.?#].[^\s]*$`)
	return urlRegex.MatchString(url)
}

// ValidateTeamCode validates team invitation code format
func ValidateTeamCode(code string) bool {
	// Team codes should be 6-8 alphanumeric characters
	codeRegex := regexp.MustCompile(`^[A-Z0-9]{6,8}$`)
	return codeRegex.MatchString(strings.ToUpper(code))
}

// ValidateUserRole validates user role
func ValidateUserRole(role string) bool {
	allowedRoles := []string{"admin", "team_leader", "worker", "viewer"}
	return ValidateEnum(role, allowedRoles)
}

// ValidateDeliveryStatus validates delivery status
func ValidateDeliveryStatus(status string) bool {
	allowedStatuses := []string{"pending", "assigned", "in_progress", "delivered", "failed", "cancelled"}
	return ValidateEnum(status, allowedStatuses)
}

// ValidateDeliveryPriority validates delivery priority
func ValidateDeliveryPriority(priority string) bool {
	allowedPriorities := []string{"low", "medium", "high", "urgent"}
	return ValidateEnum(priority, allowedPriorities)
}

// ValidateTerritoryStatus validates territory status
func ValidateTerritoryStatus(status string) bool {
	allowedStatuses := []string{"available", "assigned", "in_progress", "completed", "on_hold"}
	return ValidateEnum(status, allowedStatuses)
}
