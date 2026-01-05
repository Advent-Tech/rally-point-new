package middleware

import (
	"context"
	"fmt"
	"net/http"
	"strconv"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/redis/go-redis/v9"
	"golang.org/x/time/rate"
)

// RateLimiter interface for different rate limiting strategies
type RateLimiter interface {
	Allow(key string) (bool, error)
	GetInfo(key string) (remaining int, resetTime time.Time, err error)
}

// RedisRateLimiter implements rate limiting using Redis
type RedisRateLimiter struct {
	client   *redis.Client
	limit    int
	window   time.Duration
}

// NewRedisRateLimiter creates a new Redis-based rate limiter
func NewRedisRateLimiter(client *redis.Client, requestsPerMinute int) *RedisRateLimiter {
	return &RedisRateLimiter{
		client: client,
		limit:  requestsPerMinute,
		window: time.Minute,
	}
}

// Allow checks if a request is allowed for the given key
func (rl *RedisRateLimiter) Allow(key string) (bool, error) {
	ctx := context.Background()
	
	// Use sliding window log algorithm
	now := time.Now()
	windowStart := now.Add(-rl.window)
	
	pipe := rl.client.Pipeline()
	
	// Remove expired entries
	pipe.ZRemRangeByScore(ctx, key, "0", strconv.FormatInt(windowStart.UnixNano(), 10))
	
	// Count current requests in window
	pipe.ZCard(ctx, key)
	
	// Add current request
	pipe.ZAdd(ctx, key, redis.Z{
		Score:  float64(now.UnixNano()),
		Member: fmt.Sprintf("%d", now.UnixNano()),
	})
	
	// Set expiration
	pipe.Expire(ctx, key, rl.window+time.Second)
	
	results, err := pipe.Exec(ctx)
	if err != nil {
		return false, err
	}
	
	// Get count from second command (ZCard)
	count := results[1].(*redis.IntCmd).Val()
	
	return count < int64(rl.limit), nil
}

// GetInfo returns rate limit information for the given key
func (rl *RedisRateLimiter) GetInfo(key string) (remaining int, resetTime time.Time, err error) {
	ctx := context.Background()
	
	now := time.Now()
	windowStart := now.Add(-rl.window)
	
	// Count current requests in window
	count, err := rl.client.ZCount(ctx, key, strconv.FormatInt(windowStart.UnixNano(), 10), "+inf").Result()
	if err != nil {
		return 0, time.Time{}, err
	}
	
	remaining = rl.limit - int(count)
	if remaining < 0 {
		remaining = 0
	}
	
	resetTime = now.Add(rl.window)
	
	return remaining, resetTime, nil
}

// InMemoryRateLimiter implements rate limiting using in-memory token bucket
type InMemoryRateLimiter struct {
	limiters map[string]*rate.Limiter
	limit    rate.Limit
	burst    int
}

// NewInMemoryRateLimiter creates a new in-memory rate limiter
func NewInMemoryRateLimiter(requestsPerMinute, burstSize int) *InMemoryRateLimiter {
	return &InMemoryRateLimiter{
		limiters: make(map[string]*rate.Limiter),
		limit:    rate.Limit(float64(requestsPerMinute) / 60.0), // Convert to per-second
		burst:    burstSize,
	}
}

// Allow checks if a request is allowed for the given key
func (rl *InMemoryRateLimiter) Allow(key string) (bool, error) {
	limiter, exists := rl.limiters[key]
	if !exists {
		limiter = rate.NewLimiter(rl.limit, rl.burst)
		rl.limiters[key] = limiter
	}
	
	return limiter.Allow(), nil
}

// GetInfo returns rate limit information for the given key
func (rl *InMemoryRateLimiter) GetInfo(key string) (remaining int, resetTime time.Time, err error) {
	limiter, exists := rl.limiters[key]
	if !exists {
		return rl.burst, time.Now().Add(time.Minute), nil
	}
	
	// Estimate remaining tokens
	tokens := limiter.Tokens()
	remaining = int(tokens)
	if remaining < 0 {
		remaining = 0
	}
	
	// Estimate reset time (approximate)
	resetTime = time.Now().Add(time.Duration(float64(time.Second) / float64(rl.limit)))
	
	return remaining, resetTime, nil
}

// RateLimitMiddleware creates a rate limiting middleware
func RateLimitMiddleware(rateLimiter RateLimiter) gin.HandlerFunc {
	return func(c *gin.Context) {
		// Use IP address as the key by default
		key := c.ClientIP()
		
		// Use user ID if authenticated
		if userID, exists := c.Get("user_id"); exists {
			key = fmt.Sprintf("user:%s", userID.(string))
		}
		
		allowed, err := rateLimiter.Allow(key)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "rate limit check failed"})
			c.Abort()
			return
		}
		
		// Get rate limit info
		remaining, resetTime, err := rateLimiter.GetInfo(key)
		if err == nil {
			c.Header("X-RateLimit-Remaining", strconv.Itoa(remaining))
			c.Header("X-RateLimit-Reset", strconv.FormatInt(resetTime.Unix(), 10))
		}
		
		if !allowed {
			c.Header("Retry-After", strconv.FormatInt(resetTime.Unix()-time.Now().Unix(), 10))
			c.JSON(http.StatusTooManyRequests, gin.H{
				"error":   "rate limit exceeded",
				"message": "too many requests, please try again later",
			})
			c.Abort()
			return
		}
		
		c.Next()
	}
}

// CustomRateLimitMiddleware allows custom rate limits for different endpoints
func CustomRateLimitMiddleware(rateLimiter RateLimiter, customLimits map[string]int) gin.HandlerFunc {
	return func(c *gin.Context) {
		// Check if this endpoint has custom limits
		endpoint := c.FullPath()
		if customLimit, exists := customLimits[endpoint]; exists {
			// Create a temporary rate limiter with custom limit
			var customRateLimiter RateLimiter
			
			switch rl := rateLimiter.(type) {
			case *RedisRateLimiter:
				customRateLimiter = &RedisRateLimiter{
					client: rl.client,
					limit:  customLimit,
					window: rl.window,
				}
			case *InMemoryRateLimiter:
				customRateLimiter = &InMemoryRateLimiter{
					limiters: make(map[string]*rate.Limiter),
					limit:    rate.Limit(float64(customLimit) / 60.0),
					burst:    rl.burst,
				}
			default:
				customRateLimiter = rateLimiter
			}
			
			// Use the custom rate limiter
			RateLimitMiddleware(customRateLimiter)(c)
			return
		}
		
		// Use default rate limiter
		RateLimitMiddleware(rateLimiter)(c)
	}
}
