package client

import (
	"bytes"
	"encoding/json"
	"fmt"
	"net/http"
	"time"

	"github.com/google/uuid"
	"rally-point/delivery-service/internal/domain"
)

// territoryClient implements TerritoryClient using HTTP
type territoryClient struct {
	baseURL    string
	httpClient *http.Client
}

// NewTerritoryClient creates a new HTTP-based territory client
func NewTerritoryClient(baseURL string) domain.TerritoryClient {
	return &territoryClient{
		baseURL: baseURL,
		httpClient: &http.Client{
			Timeout: 10 * time.Second,
		},
	}
}

// RecordVisit records a visit for a worker's territory assignment
func (c *territoryClient) RecordVisit(territoryID, workerID uuid.UUID) error {
	url := fmt.Sprintf("%s/api/geo/assignments/record-visit", c.baseURL)

	payload := map[string]string{
		"territory_id": territoryID.String(),
		"worker_id":    workerID.String(),
	}

	jsonData, err := json.Marshal(payload)
	if err != nil {
		return fmt.Errorf("failed to marshal request: %w", err)
	}

	req, err := http.NewRequest("POST", url, bytes.NewBuffer(jsonData))
	if err != nil {
		return fmt.Errorf("failed to create request: %w", err)
	}

	req.Header.Set("Content-Type", "application/json")

	resp, err := c.httpClient.Do(req)
	if err != nil {
		return fmt.Errorf("failed to send request: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("territory service returned status %d", resp.StatusCode)
	}

	return nil
}

// NoopTerritoryClient is a no-op implementation for when territory service is unavailable
type noopTerritoryClient struct{}

// NewNoopTerritoryClient creates a no-op territory client
func NewNoopTerritoryClient() domain.TerritoryClient {
	return &noopTerritoryClient{}
}

// RecordVisit does nothing (for use when territory service is not configured)
func (c *noopTerritoryClient) RecordVisit(territoryID, workerID uuid.UUID) error {
	return nil
}
