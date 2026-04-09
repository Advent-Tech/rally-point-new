# GPS Real-Time Tracking Enhancement Plan

**Project:** Rally Point - Worker Location Tracking  
**Date:** 2026-02-28  
**Version:** 2.0

---

## 1. Overview

This plan implements GPS filtering at **backend level** to ensure clean data in database and WebSocket broadcasts, with minimal frontend changes for battery optimization.

---

## 2. Problem Statement

| Problem | Current State | Impact |
|---------|---------------|--------|
| GPS Zigzag | No filtering | Confusing map display |
| Outliers | Only 100km filter | Contaminated trail history |
| Raw data broadcast | Sends all points | Leader receives bad data |
| Battery drain | GPS runs constantly | Poor worker experience |

---

## 3. Architecture

```
┌──────────────┐      ┌─────────────────┐      ┌──────────────┐
│  WORKER      │      │   BACKEND       │      │   LEADER    │
│  Device      │      │   (Go)          │      │   UI        │
├──────────────┤      ├─────────────────┤      ├──────────────┤
│              │      │                 │      │              │
│ GPS (Raw)    │─────►│  Layer 1:       │      │              │
│              │      │  Accuracy       │      │              │
│              │      │  (<50m)         │      │              │
│              │      │                 │      │              │
│              │      │  Layer 2:       │      │              │
│              │      │  Speed Check    │─────►│  Receive     │
│              │      │  (Variable)     │      │  Clean Data  │
│              │      │                 │      │              │
│              │      │  Layer 3:       │      │  Animation  │
│              │      │  Outlier        │      │  (Optional) │
│              │      │  (>50km)        │      │              │
│              │      │                 │      │              │
│              │      │  Save to DB     │      │              │
│              │      │  (Clean Trail)  │      │              │
│              │      │                 │      │              │
│              │      │  Broadcast WS  │─────►│              │
│              │      │  (Team Channel)│      │              │
└──────────────┘      └─────────────────┘      └──────────────┘
```

---

## 4. Configuration

### Speed Threshold (Variable)

| Mode | Max Speed | Description |
|------|-----------|-------------|
| Foot | 15 km/h | Walking/running workers |
| Car | 80 km/h | Workers in vehicle |
| Default | 80 km/h | Auto-detect based on speed |

**Logic:** Auto-detect mode based on speed. If speed > 20 km/h for > 30 seconds → treat as vehicle.

### Other Thresholds

| Parameter | Value | Description |
|-----------|-------|-------------|
| Accuracy | 50 meters | Reject inaccurate GPS |
| Outlier | 50 km | Reject impossible jumps |
| Min Update Interval | 3 seconds | Prevent spam |
| Distance Filter | 10 meters | Minimum movement to send |

---

## 5. Backend Implementation

### File: `rally_backend/location-service/internal/handler/location.go`

#### Add Filter Struct

```go
type LocationFilter struct {
    MaxSpeedKmh       float64   // 80 km/h default
    MinSpeedKmh       float64   // 0.5 km/h minimum (not stationary)
    MaxDistanceKm     float64   // 50 km outlier check
    MinAccuracyMeters float64   // 50m accuracy threshold
    MinIntervalSeconds int      // 3 seconds minimum
}
```

#### Filter Function

```go
func (f *LocationFilter) Validate(newLoc, prevLoc *Location) (bool, string) {
    // 1. Accuracy check
    if newLoc.Accuracy > f.MinAccuracyMeters {
        return false, "accuracy_too_low"
    }
    
    // 2. Time interval check
    if prevLoc != nil {
        timeDiff := newLoc.Timestamp.Sub(prevLoc.Timestamp).Seconds()
        if timeDiff < float64(f.MinIntervalSeconds) {
            return false, "too_frequent"
        }
        
        // 3. Speed check
        distanceKm := f.calculateDistance(
            newLoc.Latitude, newLoc.Longitude,
            prevLoc.Latitude, prevLoc.Longitude,
        )
        speedKmh := (distanceKm / timeDiff) * 3600
        
        // Allow both foot and car speeds
        if speedKmh > f.MaxSpeedKmh {
            return false, "speed_too_high"
        }
        
        // Optional: reject if completely stationary
        if speedKmh < f.MinSpeedKmh && timeDiff > 30 {
            return false, "stationary_too_long"
        }
        
        // 4. Outlier check (sudden jump)
        if distanceKm > f.MaxDistanceKm {
            return false, "outlier_jump"
        }
    }
    
    return true, ""
}
```

#### Update Handler

```go
func (h *LocationHandler) HandleUpdate(w http.ResponseWriter, r *http.Request) {
    // ... existing parsing ...
    
    // Get previous location from Redis/cache
    prevLoc := h.cache.GetLocation(workerId)
    
    // Apply filters
    filter := &LocationFilter{
        MaxSpeedKmh:       80,  // km/h
        MaxDistanceKm:     50,  // km
        MinAccuracyMeters: 50,  // meters
        MinIntervalSeconds: 3,   // seconds
    }
    
    valid, reason := filter.Validate(newLoc, prevLoc)
    if !valid {
        // Log but don't fail - just don't broadcast
        log.Printf("Location filtered for worker %s: %s", workerId, reason)
        w.WriteHeader(http.StatusAccepted) // Return OK to prevent retry spam
        return
    }
    
    // Save to database
    h.db.SaveLocation(newLoc)
    
    // Update cache
    h.cache.SetLocation(workerId, newLoc)
    
    // Broadcast to team channel (clean data only)
    h.broadcastToTeam(teamId, newLoc)
}
```

---

## 6. Frontend Changes (Minimal)

### Worker Side: Battery Optimization

**File:** `ui_flutter/lib/services/session_tracking_service.dart`

```dart
// Optimize GPS settings for battery
Geolocator.getPositionStream(
  locationSettings: LocationSettings(
    accuracy: LocationAccuracy.high,
    distanceFilter: 10, // Only update if moved 10m
    timeLimit: Duration(seconds: 5), // Timeout if GPS stuck
  ),
)
```

### Leader Side: Smooth Display (Optional Enhancement)

**File:** `worker_layer.dart`

```dart
// Simple animation between updates
Future<void> animateMarker(Marker marker, LatLng newPos) async {
  const duration = Duration(milliseconds: 300);
  final start = marker.position;
  const steps = 6;
  
  for (int i = 1; i <= steps; i++) {
    await Future.delayed(Duration(milliseconds: duration.inMilliseconds ~/ steps));
    final t = i / steps;
    marker.position = LatLng(
      start.latitude + (newPos.latitude - start.latitude) * t,
      start.longitude + (newPos.longitude - start.longitude) * t,
    );
  }
}
```

---

## 7. Files to Modify

### Backend (Go)

| File | Changes |
|------|---------|
| `location-service/internal/handler/location.go` | Add validation + filtering |

### Frontend (Flutter) - Optional

| File | Changes |
|------|---------|
| `session_tracking_service.dart` | Add distance filter |
| `worker_layer.dart` | Add marker animation |

---

## 8. Testing Checklist

- [ ] Worker walks → Points recorded (foot mode)
- [ ] Worker stands still → No zigzag
- [ ] Worker in car → Points recorded (car mode, up to 80km/h)
- [ ] Worker teleports 60km → Rejected as outlier
- [ ] GPS accuracy poor (>50m) → Rejected
- [ ] Updates < 3 seconds apart → Rejected
- [ ] Trail history is clean (no zigzag)
- [ ] Leader receives filtered data only

---

## 9. Rollout

1. **Deploy backend** - Filter at source
2. **Deploy frontend** - Battery optimization
3. **Monitor** - Check for false positives
4. **Tune** - Adjust thresholds if needed

---

## 10. Monitoring

Add logs for filtered requests:

```go
log.Printf("[GPS_FILTER] worker_id=%s reason=%s location=%v", 
    workerId, reason, newLoc)
```

**Key metrics to monitor:**
- Filter rate: % of locations rejected
- Outlier count: Sudden jump detections
- Speed distribution: Foot vs Car mode
