package client

import (
	"bytes"
	"encoding/json"
	"fmt"
	"net/http"
	"time"

	"github.com/google/uuid"
	"rally-point/location-service/internal/domain"
)

// LocationUpdateResponse from the territory service geofence endpoint
type LocationUpdateResponse struct {
	Event   *domain.GeofenceEvent `json:"event,omitempty"`
	Message string                `json:"message"`
}

// GeofenceCheckResult represents the result of a geofence check (for helper methods)
type GeofenceCheckResult struct {
	IsInside       bool       `json:"is_inside"`
	TerritoryID    *uuid.UUID `json:"territory_id,omitempty"`
	AssignmentID   *uuid.UUID `json:"assignment_id,omitempty"`
	TerritorySOLID *string    `json:"territory_solid,omitempty"`
	EntityName     *string    `json:"entity_name,omitempty"`
	EntityID       *string    `json:"entity_id,omitempty"`
}

// GeofenceClient handles communication with the territory service for geofencing
type GeofenceClient struct {
	baseURL    string
	httpClient *http.Client
}

// NewGeofenceClient creates a new geofence client
func NewGeofenceClient(territoryServiceURL string) *GeofenceClient {
	return &GeofenceClient{
		baseURL: territoryServiceURL,
		httpClient: &http.Client{
			Timeout: 5 * time.Second,
		},
	}
}

// ProcessLocationUpdate sends a location update to the territory service for geofence checking
func (c *GeofenceClient) ProcessLocationUpdate(workerID uuid.UUID, teamID *uuid.UUID, lat, lng float64) (*domain.GeofenceEvent, error) {
	requestBody := map[string]interface{}{
		"worker_id": workerID.String(),
		"latitude":  lat,
		"longitude": lng,
	}

	if teamID != nil {
		requestBody["team_id"] = teamID.String()
	}

	jsonBody, err := json.Marshal(requestBody)
	if err != nil {
		return nil, fmt.Errorf("failed to marshal request: %w", err)
	}

	url := fmt.Sprintf("%s/api/geofence/location-update", c.baseURL)
	resp, err := c.httpClient.Post(url, "application/json", bytes.NewBuffer(jsonBody))
	if err != nil {
		return nil, fmt.Errorf("failed to call territory service: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("territory service returned status %d", resp.StatusCode)
	}

	var result LocationUpdateResponse
	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		return nil, fmt.Errorf("failed to decode response: %w", err)
	}

	return result.Event, nil
}

// CheckWorkerLocation checks if a worker is inside any assigned territory
func (c *GeofenceClient) CheckWorkerLocation(workerID uuid.UUID, teamID *uuid.UUID, lat, lng float64) (*GeofenceCheckResult, error) {
	requestBody := map[string]interface{}{
		"worker_id": workerID.String(),
		"latitude":  lat,
		"longitude": lng,
	}

	if teamID != nil {
		requestBody["team_id"] = teamID.String()
	}

	jsonBody, err := json.Marshal(requestBody)
	if err != nil {
		return nil, fmt.Errorf("failed to marshal request: %w", err)
	}

	url := fmt.Sprintf("%s/api/geofence/check", c.baseURL)
	resp, err := c.httpClient.Post(url, "application/json", bytes.NewBuffer(jsonBody))
	if err != nil {
		return nil, fmt.Errorf("failed to call territory service: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("territory service returned status %d", resp.StatusCode)
	}

	var result GeofenceCheckResult
	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		return nil, fmt.Errorf("failed to decode response: %w", err)
	}

	return &result, nil
}

// GetWorkerCurrentTerritory gets the worker's current territory from active session
func (c *GeofenceClient) GetWorkerCurrentTerritory(workerID uuid.UUID) (*GeofenceCheckResult, error) {
	url := fmt.Sprintf("%s/api/geofence/worker/%s/current", c.baseURL, workerID.String())
	resp, err := c.httpClient.Get(url)
	if err != nil {
		return nil, fmt.Errorf("failed to call territory service: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("territory service returned status %d", resp.StatusCode)
	}

	var result GeofenceCheckResult
	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		return nil, fmt.Errorf("failed to decode response: %w", err)
	}

	return &result, nil
}
