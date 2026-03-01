# Production Command Center — Full Map Dashboard Rewrite

## Context

Replace ALL existing map screens (5 separate screens + unified_map) with a single production-grade map dashboard (Uber/Swiggy-tier). The current `unified_map_screen.dart` is a 1,523-line monolith that: clears and redraws all annotations on every state change, uses 30s polling instead of the existing WebSocket infrastructure, has no follow-camera mode, no boundary breach detection, and no pulsing animations.

The backend already provides: 4 WebSocket endpoints (location, territory, walkie, chat), a `RealtimeProvider` singleton with cached `Map<String, WorkerLocationUpdate>`, comprehensive REST APIs for territories/workers/donations/prayers, and NATS-based event broadcasting.

**Goal**: One modular, high-performance screen with real-time WebSocket updates, follow-camera tracking, territory geofencing, pulsing active workers, incremental annotation updates (no full redraws), and clean architecture.

---

## Files to DELETE (old map screens)

| File | Reason |
|------|--------|
| `lib/presentation/screens/team_leader/unified_map_screen.dart` | Replaced by new command_center_screen.dart |
| `lib/presentation/screens/team_leader/unified_map/` (entire directory) | Replaced by new command_center/ directory |
| `lib/presentation/screens/team_leader/team_map_screen.dart` | Legacy, already redirected |
| `lib/presentation/screens/team_leader/worker_tracking_screen.dart` | Legacy, already redirected |
| `lib/presentation/screens/team_leader/territory_assignment_screen.dart` | Legacy, only import is territory_map_widget |
| `lib/presentation/screens/team_leader/worker_trail_screen.dart` | Legacy, already redirected |
| `lib/presentation/widgets/territory_map_widget.dart` | Only used by territory_assignment_screen |

---

## New File Structure

```
lib/presentation/screens/team_leader/command_center/
├── command_center_screen.dart          # Thin StatefulWidget orchestrator (~300 lines)
├── command_center_bloc.dart            # Orchestration BLoC merging all data sources
├── command_center_state.dart           # Equatable state with all map data
├── command_center_event.dart           # All events
├── command_center_controller.dart      # Imperative map operations (draw, camera)
│
├── layers/
│   ├── territory_layer.dart            # Polygon + boundary line annotations
│   ├── worker_layer.dart               # Worker circles + pulse animation
│   ├── activity_layer.dart             # Donation (green) + prayer (blue) markers
│   ├── trail_layer.dart                # GPS trail polyline + start/end markers
│   └── breach_layer.dart               # Red pulsing ring for boundary breach
│
├── services/
│   ├── annotation_registry.dart        # Maps domain IDs → Mapbox annotations for incremental updates
│   ├── camera_controller.dart          # Priority-based camera queue (autoFit < selection < follow < user)
│   ├── bounds_calculator.dart          # Collect LatLngBounds from heterogeneous data
│   ├── realtime_bridge.dart            # WebSocket → CommandCenterBloc event bridge
│   └── geofence_checker.dart           # Client-side point-in-polygon for breach detection
│
└── widgets/
    ├── mode_selector.dart              # SegmentedButton for overview/workers/territories
    ├── map_controls.dart               # Zoom +/-, style toggle, fit-all
    ├── overview_stats_bar.dart         # Bottom stats + legend (extracted from overview_overlay.dart)
    ├── worker_bottom_sheet.dart        # DraggableSheet: worker list + trail stats + empty state
    ├── territory_bottom_sheet.dart     # DraggableSheet: territory list + search + assignment
    ├── marker_detail_sheet.dart        # Bottom sheets for prayer/donation/worker tap
    ├── follow_mode_banner.dart         # "Following [Name]" banner with exit button
    ├── breach_alert_banner.dart        # Warning banner when worker leaves territory
    └── empty_state_overlay.dart        # Mode-specific empty states
```

---

## Architecture

### State Management

```
┌─────────────────────────────────────────────────────────┐
│ Existing BLoCs (data fetchers — keep as-is)             │
│  TeamMapBloc     → workers, prayers, donations, bounds  │
│  WorkerTrackingBloc → tracked workers, trail, stats     │
│  TerritoryBloc   → allocations, search, assign          │
│  TeamBloc        → team member list                     │
└──────────────────┬──────────────────────────────────────┘
                   │ stream.listen()
                   ▼
┌─────────────────────────────────────────────────────────┐
│ NEW: CommandCenterBloc (orchestrator)                    │
│  • Merges all sub-BLoC states into one                  │
│  • Receives real-time WS events via RealtimeBridge      │
│  • Manages: activeMode, followTarget, selectedTerritory │
│  • Manages: layerVisibility, breachedWorkerIds          │
│  • Runs client-side geofence checks on location updates │
└──────────────────┬──────────────────────────────────────┘
                   │ BlocListener (not BlocBuilder — map is imperative)
                   ▼
┌─────────────────────────────────────────────────────────┐
│ CommandCenterController (imperative bridge)              │
│  • Receives state diffs from BlocListener               │
│  • Calls layer.drawAll() / layer.updateSingle()         │
│  • Calls CameraController for animations                │
│  • Never rebuilds the MapWidget                         │
└─────────────────────────────────────────────────────────┘
```

### Real-Time Data Flow

```
WebSocket Server → workerLocationBroadcast
    ↓
WebSocketService (singleton, messageStream)
    ↓
RealtimeBridge (filters WsMessageType.workerLocationBroadcast)
    ↓
CommandCenterBloc.add(WorkerLocationReceived(update))
    ↓ handler:
    ├── state.liveLocations[workerId] = update
    ├── GeofenceChecker.check() → breach detection
    └── emit(newState)
    ↓ BlocListener:
    ├── WorkerLayer.updateWorkerPosition(id, lat, lng)  ← single delete+create
    ├── if following: CameraController.updateFollowPosition()
    ├── if following: TrailLayer.appendPoints()
    └── if breached: BreachLayer.showBreachRing()
```

### Annotation Strategy (Incremental, No Full Redraws)

**AnnotationRegistry**: Each layer maintains a `Map<String, Annotation>` mapping domain IDs to Mapbox annotation objects. On updates:
- **Single worker moves**: Delete that one circle, create new at new position (1 op, not N)
- **Territory selection**: Delete old highlight polygon+line, redraw with selected style, delete new territory's normal style, redraw as selected (4 ops, not full redraw)
- **New prayer/donation**: Add single circle annotation
- **Mode switch**: Only mode switches call `layer.clear()` + `layer.drawAll()`

### Camera Priority System

```
enum CameraPriority { idle, autoFit, selection, follow, userGesture }
```
- **autoFit**: Initial bounds fit on load (lowest, easily overridden)
- **selection**: User tapped territory/worker (medium)
- **follow**: Following worker in real-time (high, but broken by user gesture)
- **userGesture**: User manually panned/zoomed (highest, auto-resets after 2s)

When in follow mode and user manually pans, follow mode exits automatically. Follow debounces at 300ms to avoid animation jitter from rapid GPS updates.

---

## CommandCenterState Shape

```dart
class CommandCenterState extends Equatable {
  final MapMode activeMode;            // overview | workers | territories
  final LayerVisibility visibility;    // filter toggles per layer
  final bool isInitialLoading;
  final String? errorMessage;
  final String? teamId;

  // Data (cached from sub-BLoCs)
  final List<ActiveWorkerLocation> overviewWorkers;
  final List<MapPrayerMarker> prayers;
  final List<MapDonationMarker> donations;
  final List<TerritoryBoundary> territoryBoundaries;
  final List<GeoTerritory> geoTerritories;
  final List<TrackedWorker> trackedWorkers;

  // Real-time (from WebSocket)
  final Map<String, WorkerLocationUpdate> liveLocations;

  // Interaction
  final FollowTarget? followTarget;    // worker being followed
  final WorkerTrackingTrailLoaded? activeTrail;
  final GeoTerritory? selectedTerritory;
  final Set<String> breachedWorkerIds;
}
```

---

## Key Features Implementation

### 1. Territory Polygons
- `TerritoryLayer.drawAll()` renders GeoTerritory list with color palette
- `TerritoryLayer.highlightTerritory(id)` does incremental highlight (4 annotation ops)
- Colors match between list tile and polygon via index-based `geoTerritoryColors[i % len]`
- Data sources: `TerritoryBloc` allocations + `TeamMapBloc` boundaries as fallback

### 2. Activity Markers
- `ActivityLayer.drawAll(prayers, donations)` — prayers=blue circles, donations=green circles
- Click handling via `CircleAnnotationClickListener` → lat/lng proximity lookup in registry
- On click: zoom to marker, show `MarkerDetailSheet`, highlight parent territory

### 3. Active Worker Pulse
- `WorkerLayer` uses `Timer.periodic(800ms)` to alternate pulse ring radius/opacity
- Only for workers with `isActive == true` — typically <20 workers
- Inner solid circle is stable (never recreated), only the outer pulse ring animates

### 4. Auto-Zoom
- `BoundsCalculator.collectPoints(state)` gathers all visible data per mode
- Overview: territory bounds > worker+prayer+donation positions (fallback chain)
- Workers: trail points (if trail active) > worker positions
- Territories: geoTerritory polygon coordinates
- Called with `CameraPriority.autoFit` on initial load

### 5. Follow Mode (Real-Time Tracking)
- Tap worker in list → `CommandCenterBloc.add(FollowWorker(id, name))`
- `CameraController.startFollowing(id)` — zoom 16, smooth easeTo
- Each WS location update: move worker dot + extend trail polyline + pan camera
- `FollowModeBanner` shows "Following [Name]" with X button
- User pan gesture → `onFollowBroken` callback → exits follow mode
- Can re-enter by tapping worker again

### 6. Boundary Breach Detection
- `GeofenceChecker` uses ray-casting point-in-polygon on each WS location update
- If worker outside assigned territory → add to `breachedWorkerIds`
- `BreachLayer` draws pulsing red ring around breached worker
- `BreachAlertBanner` shows warning with worker name, tap to zoom

### 7. Empty States
- Per-mode illustrated empty state (icon + title + description + refresh button)
- Workers mode: shows full team member list from `TeamBloc` even when no active workers
- Camera stays at default position (US center, zoom 4)

### 8. Territory Assignment
- Extracted from existing `TerritoriesPanel` + `_AssignmentSheet` code
- Select territory → highlight + camera fly → detail sheet → assign modal
- Reuses `TerritoryBloc.add(TerritoryAssignToWorker(...))` flow

---

## Implementation Phases

### Phase 1: Foundation (~services + models)
1. Create `command_center_state.dart` + `command_center_event.dart`
2. Create `annotation_registry.dart` — domain ID → annotation tracking
3. Create `camera_controller.dart` — priority queue + follow mode
4. Create `bounds_calculator.dart` — multi-source bounds collection
5. Create `realtime_bridge.dart` — WS messageStream → BLoC events
6. Create `geofence_checker.dart` — ray-casting point-in-polygon

### Phase 2: Annotation Layers
7. Create `territory_layer.dart` — polygons + lines + incremental highlight
8. Create `worker_layer.dart` — circles + pulse timer + single-update
9. Create `activity_layer.dart` — prayer/donation circles + click registry
10. Create `trail_layer.dart` — polyline + start/end markers + append
11. Create `breach_layer.dart` — red pulse ring

### Phase 3: BLoC + Controller
12. Create `command_center_bloc.dart` — orchestration, subscribes to sub-BLoCs + RealtimeBridge
13. Create `command_center_controller.dart` — state diff → layer calls

### Phase 4: Widgets
14. Create `mode_selector.dart` (extract from SegmentedButton)
15. Create `worker_bottom_sheet.dart` (from workers_panel.dart — add empty state + team list + follow)
16. Create `territory_bottom_sheet.dart` (from territories_panel.dart — add color dots + camera fly)
17. Create `overview_stats_bar.dart` (from overview_overlay.dart)
18. Create `marker_detail_sheet.dart` (from overview_overlay.dart detail sheets)
19. Create `map_controls.dart`, `follow_mode_banner.dart`, `breach_alert_banner.dart`, `empty_state_overlay.dart`

### Phase 5: Screen Assembly + Router
20. Create `command_center_screen.dart` — thin orchestrator wiring everything together
21. Update `app_router.dart` — point `/leader/command-center` to new screen, provide CommandCenterBloc
22. Verify all deep links work (worker trail, territory assignment, mode params)

### Phase 6: Cleanup + Polish
23. Delete old screens: unified_map_screen.dart, team_map_screen.dart, worker_tracking_screen.dart, territory_assignment_screen.dart, worker_trail_screen.dart, territory_map_widget.dart, unified_map/ directory
24. Remove unused imports from app_router.dart and widgets.dart
25. Add pulsing animation, follow-mode tracking, breach detection
26. `flutter analyze` — zero new issues
27. Build + test on emulator

---

## Files to Reuse (not modify)

| File | What we reuse |
|------|---------------|
| `lib/presentation/blocs/team_map/team_map_bloc.dart` | Data fetcher for overview mode |
| `lib/presentation/blocs/worker_tracking/worker_tracking_bloc.dart` | Data fetcher for workers + trails |
| `lib/presentation/blocs/territory/territory_bloc.dart` | Territory allocations, search, assignment |
| `lib/presentation/blocs/team/team_bloc.dart` | Team member list |
| `lib/services/websocket_service.dart` | WebSocket singleton + message types |
| `lib/services/realtime_provider.dart` | WorkerLocationUpdate model, connection management |
| `lib/data/models/territory_model.dart` | GeoTerritory, TerritoryAssignment models |
| `lib/core/constants/map_constants.dart` | Mapbox config, style URIs, default center |
| `lib/core/theme/app_colors.dart` | Color constants |

## Files to Modify

| File | Change |
|------|--------|
| `lib/presentation/navigation/app_router.dart` | Point `/leader/command-center` to new CommandCenterScreen, add CommandCenterBloc provider, remove old screen imports |
| `lib/presentation/widgets/widgets.dart` | Remove `territory_map_widget.dart` export |

---

## Verification

1. `flutter analyze` — zero new issues
2. **Overview mode**: territory polygons render with fill+stroke; worker/prayer/donation markers clickable with detail sheets; stats bar at bottom; camera auto-zooms to data
3. **Workers mode (no active)**: "0 of N active" header, illustrated empty state, full team member list, tap member → view historical trail
4. **Workers mode (active)**: pulsing dots on map, list in bottom sheet, tap → enter follow mode with live camera tracking + trail polyline; "Following [Name]" banner; pan to exit
5. **Territories mode**: colored polygons match list tile colors; tap territory → camera flies to bounds + highlights polygon; assignment sheet works
6. **Real-time**: WebSocket location updates move worker dots without full redraw; new events add single markers
7. **Boundary breach**: worker leaving territory shows red ring + warning banner
8. **Mode switching**: layers clear/redraw correctly, camera re-fits
9. **Deep links**: `/leader/command-center?mode=workers&workerId=X` opens trail view; territory assignment pre-selection works
10. **Performance**: no visible jank with 50+ annotations; map widget never rebuilds
