package cache

import (
	"context"
	"encoding/json"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/redis/go-redis/v9"
	"rally-point/location-service/internal/domain"
)

const (
	workerKeyPrefix = "worker:location:"
	activeWorkersKey = "active_workers"
	workerTTL       = 5 * time.Minute
)

// RedisLocationCache implements WorkerLocationCache using Redis
type RedisLocationCache struct {
	client *redis.Client
}

// NewRedisLocationCache creates a new Redis-backed location cache
func NewRedisLocationCache(redisURL string) (*RedisLocationCache, error) {
	client := redis.NewClient(&redis.Options{
		Addr: redisURL,
	})

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	if err := client.Ping(ctx).Err(); err != nil {
		return nil, fmt.Errorf("failed to connect to Redis: %w", err)
	}

	return &RedisLocationCache{client: client}, nil
}

// SetWorkerLocation stores a worker's location in Redis with a 5-minute TTL
func (c *RedisLocationCache) SetWorkerLocation(location *domain.WorkerLocation) error {
	data, err := json.Marshal(location)
	if err != nil {
		return fmt.Errorf("failed to marshal worker location: %w", err)
	}

	ctx := context.Background()
	key := workerKeyPrefix + location.UserID.String()

	pipe := c.client.Pipeline()
	pipe.Set(ctx, key, data, workerTTL)
	pipe.SAdd(ctx, activeWorkersKey, location.UserID.String())
	_, err = pipe.Exec(ctx)
	return err
}

// GetActiveWorkers returns all workers with recent cached locations
func (c *RedisLocationCache) GetActiveWorkers() ([]*domain.WorkerLocation, error) {
	ctx := context.Background()
	memberIDs, err := c.client.SMembers(ctx, activeWorkersKey).Result()
	if err != nil {
		return nil, fmt.Errorf("failed to get active worker set: %w", err)
	}

	if len(memberIDs) == 0 {
		return nil, nil
	}

	// Build keys for MGET
	keys := make([]string, len(memberIDs))
	for i, id := range memberIDs {
		keys[i] = workerKeyPrefix + id
	}

	values, err := c.client.MGet(ctx, keys...).Result()
	if err != nil {
		return nil, fmt.Errorf("failed to get worker locations: %w", err)
	}

	var workers []*domain.WorkerLocation
	var expiredIDs []interface{}

	for i, val := range values {
		if val == nil {
			// TTL expired — clean up from the set
			expiredIDs = append(expiredIDs, memberIDs[i])
			continue
		}
		str, ok := val.(string)
		if !ok {
			continue
		}
		var worker domain.WorkerLocation
		if json.Unmarshal([]byte(str), &worker) == nil {
			workers = append(workers, &worker)
		}
	}

	// Clean up expired entries from the set
	if len(expiredIDs) > 0 {
		c.client.SRem(ctx, activeWorkersKey, expiredIDs...)
	}

	return workers, nil
}

// RemoveWorker removes a worker from the cache
func (c *RedisLocationCache) RemoveWorker(userID uuid.UUID) error {
	ctx := context.Background()
	pipe := c.client.Pipeline()
	pipe.Del(ctx, workerKeyPrefix+userID.String())
	pipe.SRem(ctx, activeWorkersKey, userID.String())
	_, err := pipe.Exec(ctx)
	return err
}
