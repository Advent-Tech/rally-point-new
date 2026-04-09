package events

import (
	"encoding/json"
	"fmt"
	"time"

	"github.com/nats-io/nats.go"
	"rally-point/location-service/internal/domain"
)

// NATSPublisher publishes location events to NATS
type NATSPublisher struct {
	nc *nats.Conn
}

// NewNATSPublisher connects to NATS and returns a publisher
func NewNATSPublisher(natsURL string) (*NATSPublisher, error) {
	nc, err := nats.Connect(natsURL,
		nats.RetryOnFailedConnect(true),
		nats.MaxReconnects(10),
		nats.ReconnectWait(2*time.Second),
	)
	if err != nil {
		return nil, fmt.Errorf("failed to connect to NATS: %w", err)
	}
	return &NATSPublisher{nc: nc}, nil
}

// PublishLocationUpdate publishes a location update event to NATS
func (p *NATSPublisher) PublishLocationUpdate(event *domain.LocationEventMessage) error {
	data, err := json.Marshal(event)
	if err != nil {
		return fmt.Errorf("failed to marshal event: %w", err)
	}
	return p.nc.Publish("location.update", data)
}

// Close drains and closes the NATS connection
func (p *NATSPublisher) Close() {
	p.nc.Drain()
}
