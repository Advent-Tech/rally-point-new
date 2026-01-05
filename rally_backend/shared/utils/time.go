package utils

import (
	"fmt"
	"time"
)

// TimeZone constants
const (
	UTCTimeZone = "UTC"
	ESTTimeZone = "America/New_York"
	PSTTimeZone = "America/Los_Angeles"
	CSTTimeZone = "America/Chicago"
	MSTTimeZone = "America/Denver"
)

// GetCurrentUTC returns current time in UTC
func GetCurrentUTC() time.Time {
	return time.Now().UTC()
}

// ParseTimeWithTimezone parses time string with timezone
func ParseTimeWithTimezone(timeStr, timezone string) (time.Time, error) {
	loc, err := time.LoadLocation(timezone)
	if err != nil {
		return time.Time{}, err
	}
	
	return time.ParseInLocation(time.RFC3339, timeStr, loc)
}

// ConvertToTimezone converts time to specified timezone
func ConvertToTimezone(t time.Time, timezone string) (time.Time, error) {
	loc, err := time.LoadLocation(timezone)
	if err != nil {
		return time.Time{}, err
	}
	
	return t.In(loc), nil
}

// FormatTimeForAPI formats time for API response
func FormatTimeForAPI(t time.Time) string {
	return t.UTC().Format(time.RFC3339)
}

// ParseAPITime parses time from API request
func ParseAPITime(timeStr string) (time.Time, error) {
	return time.Parse(time.RFC3339, timeStr)
}

// IsBusinessHours checks if given time is within business hours (9 AM - 5 PM)
func IsBusinessHours(t time.Time, timezone string) (bool, error) {
	loc, err := time.LoadLocation(timezone)
	if err != nil {
		return false, err
	}
	
	localTime := t.In(loc)
	hour := localTime.Hour()
	
	// Business hours: 9 AM to 5 PM (17:00)
	return hour >= 9 && hour < 17, nil
}

// GetStartOfDay returns the start of the day (00:00:00) for given time
func GetStartOfDay(t time.Time) time.Time {
	return time.Date(t.Year(), t.Month(), t.Day(), 0, 0, 0, 0, t.Location())
}

// GetEndOfDay returns the end of the day (23:59:59) for given time
func GetEndOfDay(t time.Time) time.Time {
	return time.Date(t.Year(), t.Month(), t.Day(), 23, 59, 59, 999999999, t.Location())
}

// GetStartOfWeek returns the start of the week (Monday 00:00:00)
func GetStartOfWeek(t time.Time) time.Time {
	weekday := int(t.Weekday())
	if weekday == 0 { // Sunday
		weekday = 7
	}
	
	days := weekday - 1 // Days since Monday
	startOfWeek := t.AddDate(0, 0, -days)
	return GetStartOfDay(startOfWeek)
}

// GetEndOfWeek returns the end of the week (Sunday 23:59:59)
func GetEndOfWeek(t time.Time) time.Time {
	startOfWeek := GetStartOfWeek(t)
	endOfWeek := startOfWeek.AddDate(0, 0, 6)
	return GetEndOfDay(endOfWeek)
}

// GetStartOfMonth returns the start of the month
func GetStartOfMonth(t time.Time) time.Time {
	return time.Date(t.Year(), t.Month(), 1, 0, 0, 0, 0, t.Location())
}

// GetEndOfMonth returns the end of the month
func GetEndOfMonth(t time.Time) time.Time {
	startOfNextMonth := GetStartOfMonth(t).AddDate(0, 1, 0)
	return startOfNextMonth.Add(-time.Nanosecond)
}

// DurationToMinutes converts duration to minutes
func DurationToMinutes(d time.Duration) int {
	return int(d.Minutes())
}

// MinutesToDuration converts minutes to duration
func MinutesToDuration(minutes int) time.Duration {
	return time.Duration(minutes) * time.Minute
}

// IsExpired checks if a time has expired (is before now)
func IsExpired(t time.Time) bool {
	return t.Before(time.Now().UTC())
}

// TimeUntilExpiry returns duration until expiry
func TimeUntilExpiry(t time.Time) time.Duration {
	return t.Sub(time.Now().UTC())
}

// AddBusinessDays adds business days to a date (excludes weekends)
func AddBusinessDays(t time.Time, days int) time.Time {
	result := t
	
	for i := 0; i < days; i++ {
		result = result.AddDate(0, 0, 1)
		
		// Skip weekends
		for result.Weekday() == time.Saturday || result.Weekday() == time.Sunday {
			result = result.AddDate(0, 0, 1)
		}
	}
	
	return result
}

// GetBusinessDaysBetween calculates business days between two dates
func GetBusinessDaysBetween(start, end time.Time) int {
	if start.After(end) {
		start, end = end, start
	}
	
	days := 0
	current := GetStartOfDay(start)
	endDay := GetStartOfDay(end)
	
	for current.Before(endDay) {
		if current.Weekday() != time.Saturday && current.Weekday() != time.Sunday {
			days++
		}
		current = current.AddDate(0, 0, 1)
	}
	
	return days
}

// FormatDuration formats duration in human-readable format
func FormatDuration(d time.Duration) string {
	if d < time.Minute {
		return "less than a minute"
	}
	
	if d < time.Hour {
		minutes := int(d.Minutes())
		if minutes == 1 {
			return "1 minute"
		}
		return fmt.Sprintf("%d minutes", minutes)
	}
	
	if d < 24*time.Hour {
		hours := int(d.Hours())
		if hours == 1 {
			return "1 hour"
		}
		return fmt.Sprintf("%d hours", hours)
	}
	
	days := int(d.Hours() / 24)
	if days == 1 {
		return "1 day"
	}
	return fmt.Sprintf("%d days", days)
}

// GetTimeRangeForPeriod returns start and end times for common periods
func GetTimeRangeForPeriod(period string, referenceTime time.Time) (time.Time, time.Time) {
	switch period {
	case "today":
		return GetStartOfDay(referenceTime), GetEndOfDay(referenceTime)
	case "yesterday":
		yesterday := referenceTime.AddDate(0, 0, -1)
		return GetStartOfDay(yesterday), GetEndOfDay(yesterday)
	case "this_week":
		return GetStartOfWeek(referenceTime), GetEndOfWeek(referenceTime)
	case "last_week":
		lastWeek := referenceTime.AddDate(0, 0, -7)
		return GetStartOfWeek(lastWeek), GetEndOfWeek(lastWeek)
	case "this_month":
		return GetStartOfMonth(referenceTime), GetEndOfMonth(referenceTime)
	case "last_month":
		lastMonth := referenceTime.AddDate(0, -1, 0)
		return GetStartOfMonth(lastMonth), GetEndOfMonth(lastMonth)
	case "last_7_days":
		start := GetStartOfDay(referenceTime.AddDate(0, 0, -6))
		end := GetEndOfDay(referenceTime)
		return start, end
	case "last_30_days":
		start := GetStartOfDay(referenceTime.AddDate(0, 0, -29))
		end := GetEndOfDay(referenceTime)
		return start, end
	default:
		// Default to today
		return GetStartOfDay(referenceTime), GetEndOfDay(referenceTime)
	}
}
