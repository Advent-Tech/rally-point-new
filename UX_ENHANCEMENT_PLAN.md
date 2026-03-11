# Rally Point — UI/UX Enhancement Plan

> **Goal:** Make the app self-explanatory so clients immediately understand how it works.
> **Constraint:** Visual & interaction changes only — no data models, API calls, or mapping logic changes.

---

## Table of Contents

1. [Current State Assessment](#1-current-state-assessment)
2. [Task 1 — Onboarding Flow](#task-1--onboarding-flow-for-first-time-users)
3. [Task 2 — Contextual Coach Marks](#task-2--contextual-coach-marks-tooltips)
4. [Task 3 — Team Leader Bottom Navigation](#task-3--team-leader-bottom-navigation)
5. [Task 4 — Simplify Home Screen](#task-4--simplify-home-screen-layout)
6. [Task 5 — "Today's Plan" Summary Card](#task-5--todays-plan-summary-card)
7. [Task 6 — Territory Map UX](#task-6--territory-map-ux-improvements)
8. [Task 7 — Walkie-Talkie PTT Polish](#task-7--walkie-talkie-push-to-talk-polish)
9. [Task 8 — Standardize Empty States](#task-8--standardize-empty-states)
10. [Task 9 — Pull-to-Refresh Everywhere](#task-9--pull-to-refresh-consistency)
11. [Task 10 — Micro-Animations](#task-10--micro-animations)
12. [Task 11 — Donation Flow Stepper](#task-11--donation-flow-step-indicator)
13. [Task 12 — Role Indicators & Breadcrumbs](#task-12--role-indicators--breadcrumbs)
14. [Task 13 — Form Validation UX](#task-13--inline-form-validation)
15. [Task 14 — Success Animations](#task-14--success-animations)
16. [Task 15 — Quick-Action Tile Redesign](#task-15--quick-action-tile-redesign)
17. [Task 16 — Help/Demo Mode](#task-16--helpdemo-mode-floating-button)
18. [Task 17 — Notification Tile Redesign](#task-17--notification-tile-visual-hierarchy)
19. [Task 18 — Page Transition Consistency](#task-18--page-transition-standardization)
20. [Implementation Order](#implementation-order)

---

## 1. Current State Assessment

### What's Working Well
- **Design system** is solid: `AppColors`, `AppTypography`, `AppSpacing` use a 4px grid
- **Component library** covers buttons, cards, sheets, snackbars, skeletons
- **Dark mode** fully supported across all theme tokens
- **Material 3** compliance with `useMaterial3: true`
- **Haptic feedback** and semantic labels present in reusable widgets

### Critical Problems
| Problem | Impact | Root Cause |
|---------|--------|------------|
| No onboarding | Client has no idea what the app does | Missing feature |
| Team Leader has no bottom nav | Leader gets lost after 1 tap | `app_router.dart` uses stack-only routes for `/leader/*` |
| Home screen overload (1881 lines) | Cognitive overload, 8 quick actions + stats + session + territory + activity | Everything on one scroll |
| Hidden features | Expandable FAB, long-press menus, map tap targets | No affordance or coaching |
| Walkie PTT is basic | `_PushToTalkButton` is a flat rectangle, no visual feedback during recording | Minimal implementation |
| Inconsistent states | Some screens use `EmptyState` widget, others build inline | Mixed patterns |

### File Structure Reference
```
lib/
├── core/theme/
│   ├── app_colors.dart          # Color palette (primary #3B82F6, secondary #8B5CF6, accent #06B6D4)
│   ├── app_typography.dart      # Inter font, Material 3 scale
│   ├── app_spacing.dart         # 4px base unit (xs=4, sm=8, smd=12, md=16, lg=24, xl=32)
│   ├── app_theme.dart           # Light & dark ThemeData
│   ├── app_theme_extensions.dart # Custom tokens (cardRadius=16, buttonRadius=12, etc.)
│   └── app_color_utils.dart     # Opacity helpers, shadows, gradients
├── presentation/
│   ├── navigation/app_router.dart          # GoRouter with ShellRoute for worker bottom nav
│   ├── widgets/
│   │   ├── bottom_nav_shell.dart           # Rounded floating bottom nav (28px radius, 56px height)
│   │   ├── custom_button.dart              # CustomButton (Primary/Secondary/Outline/Text/Danger/Success)
│   │   ├── custom_text_field.dart          # CustomTextField, CustomSearchField, CustomTextArea
│   │   ├── cards/app_card.dart             # AppCard (Elevated/Outlined/Filled/Gradient variants)
│   │   ├── states/empty_state.dart         # EmptyState, ErrorState, NoConnectionState, NoResultsState
│   │   ├── feedback/app_snackbar.dart      # AppSnackbar.success/error/warning/info, AppToast
│   │   ├── loading/skeleton_loader.dart    # ShimmerEffect, SkeletonCard, SkeletonList, etc.
│   │   ├── sheets/app_bottom_sheet.dart    # AppBottomSheet.show/showActions/showConfirmation
│   │   ├── home/quick_action_tile.dart     # QuickActionTile, QuickActionGrid, QuickActionColors
│   │   ├── home/overview_stat_card.dart    # OverviewStatCard (icon + value + trend)
│   │   └── widgets.dart                    # Barrel export
│   └── screens/
│       ├── home/home_screen.dart           # 1881 lines — worker + leader home
│       ├── territory/territory_screen.dart # Tabs: My Areas + Map, expandable FAB
│       ├── delivery/delivery_screen.dart   # Donation list + record form sheet
│       ├── walkie/walkie_screen.dart       # Channel list + PTT (918 lines)
│       └── ... (35 screens total)
```

---

## Task 1 — Onboarding Flow for First-Time Users

### Priority: CRITICAL — #1 impact for client understanding

### What to Build
A 4-screen onboarding carousel shown after first login (or before login for demo purposes). Stored in SharedPreferences so it only shows once.

### New Files to Create
```
lib/presentation/screens/onboarding/
├── onboarding_screen.dart        # Main PageView controller
└── onboarding_page.dart          # Single page widget (reusable)
```

### Screen Content (4 pages)

**Page 1 — "Welcome to Rally Point"**
- Icon: `Icons.explore` (80px, white on primary gradient circle)
- Title: "Field Ministry Management"
- Subtitle: "Organize territories, track visits, and collaborate with your team — all in one place."
- Background: Subtle `AppColors.primaryGradient` at 10% opacity

**Page 2 — "Track Your Territory"**
- Icon: `Icons.map_outlined` (80px, white on `AppColors.secondary` circle)
- Title: "Territory & GPS Tracking"
- Subtitle: "View your assigned areas on a map, log visits, and track your ministry hours automatically."

**Page 3 — "Stay Connected"**
- Icon: `Icons.groups_outlined` (80px, white on `AppColors.accent` circle)
- Title: "Team Communication"
- Subtitle: "Chat with your team, use walkie-talkie for quick voice messages, and share prayer requests."

**Page 4 — "Let's Get Started"**
- Icon: `Icons.rocket_launch` (80px, white on `AppColors.success` circle)
- Title: "You're All Set!"
- Subtitle: "Start your field ministry journey. Your team leader will assign territories and schedules."
- CTA Button: `CustomButton(text: 'Get Started', type: ButtonType.primary, size: ButtonSize.large)`

### Visual Specifications
```
┌─────────────────────────────────┐
│                                 │
│          ┌──────────┐           │
│          │   Icon    │  80x80   │
│          │  Circle   │          │
│          └──────────┘           │
│                                 │
│      "Title Goes Here"          │  headlineSmall, bold
│                                 │
│   "Subtitle description text    │  bodyLarge, textSecondary
│    goes here with two lines"    │
│                                 │
│                                 │
│         ● ○ ○ ○                 │  Dot indicators
│                                 │
│   ┌─────────────────────┐       │
│   │    Next / Get Started│       │  CustomButton, full width
│   └─────────────────────┘       │
│                                 │
│          Skip                   │  TextButton, textSecondary
└─────────────────────────────────┘
```

### Implementation Details

1. **PageView with PageController**
   - `physics: BouncingScrollPhysics()`
   - Track current page with `ValueNotifier<int>`

2. **Dot indicators**
   - Row of 4 `AnimatedContainer` widgets
   - Active: 24x8px, `AppColors.primary`, `radiusFull`
   - Inactive: 8x8px, `AppColors.primary.withAlpha(50)`, circle
   - Duration: `200ms`, curve: `Curves.easeInOut`

3. **"Skip" button** (top-right or bottom)
   - `TextButton` with `AppColors.textSecondaryLight`
   - Hidden on last page (replaced by CTA)

4. **Navigation button**
   - Pages 1-3: "Next" → advances PageView with `animateToPage`
   - Page 4: "Get Started" → saves `hasSeenOnboarding=true` to SharedPreferences, navigates to `/home` or `/leader/dashboard`

5. **Animations per page**
   - Icon: `ScaleTransition` 0.0→1.0 with `Curves.elasticOut` (600ms)
   - Title: `FadeTransition` + `SlideTransition` up 20px (400ms, 100ms delay)
   - Subtitle: `FadeTransition` + `SlideTransition` up 20px (400ms, 200ms delay)

6. **Router integration** (`app_router.dart`)
   - Add check in redirect: if `AuthAuthenticated` and `!hasSeenOnboarding` → `/onboarding`
   - Add route: `GoRoute(path: '/onboarding', builder: ... => OnboardingScreen())`

7. **Storage key**: `SharedPreferences` key `has_seen_onboarding` (bool)

### Files to Modify
- `lib/presentation/navigation/app_router.dart` — add `/onboarding` route + redirect logic
- `lib/core/storage/local_storage.dart` — add `hasSeenOnboarding` getter/setter
- `lib/presentation/widgets/widgets.dart` — export onboarding page widget if reusable

---

## Task 2 — Contextual Coach Marks (Tooltips)

### Priority: HIGH — teaches features in-context after onboarding

### What to Build
First-visit overlay tooltips that highlight key UI elements with a spotlight cutout and explanation text.

### New Files to Create
```
lib/presentation/widgets/coaching/
├── coach_mark_overlay.dart       # Full-screen overlay with spotlight cutout
├── coach_mark_tooltip.dart       # Tooltip bubble (positioned relative to target)
└── coach_mark_controller.dart    # Manages sequence and persistence
```

### Screens That Need Coach Marks

**Home Screen** (first visit)
1. Point to quick-action grid → "Tap any tile to access features like Territory, Donations, Surveys, and more."
2. Point to session tracking card → "Start a work session to track your time and location."

**Territory Screen** (first visit)
1. Point to Map tab → "Switch to Map view to see your territories on the map."
2. Point to FAB → "Tap here to quickly chat or walkie-talkie your team."

**Delivery Screen** (first visit)
1. Point to "Record Donation" button → "Tap here to record a new donation from the field."

**Chat Screen** (first visit)
1. Point to new chat button → "Start a 1-on-1 or team chat with your team members."

### Visual Specifications
```
┌─────────────────────────────────┐
│  ░░░░░░░░░░░░░░░░░░░░░░░░░░░░  │  Semi-transparent overlay
│  ░░░░░░░░░░░░░░░░░░░░░░░░░░░░  │  (Colors.black54)
│  ░░░░░┌────────────┐░░░░░░░░░  │
│  ░░░░░│  Spotlight  │░░░░░░░░░  │  Clear cutout around target
│  ░░░░░│   (clear)   │░░░░░░░░░  │  with 8px padding + 12px radius
│  ░░░░░└────────────┘░░░░░░░░░  │
│  ░░░░░░░░░░░░░░░░░░░░░░░░░░░░  │
│  ░░┌──────────────────────┐░░░  │
│  ░░│ "Explanation text     │░░░  │  Tooltip bubble
│  ░░│  goes here"           │░░░  │  AppColors.surfaceLight, 12px radius
│  ░░│       [Got it]        │░░░  │  Shadow, positioned below/above target
│  ░░└──────────────────────┘░░░  │
│  ░░░░░░░░░░░░░░░░░░░░░░░░░░░░  │
│  ░░░░░░░░░   Skip All  ░░░░░░  │  Bottom skip option
└─────────────────────────────────┘
```

### Implementation Details

1. **Spotlight overlay** — Use `CustomPainter` with `Path.combine(PathOperation.difference, ...)` to cut out a rounded rect from the full-screen overlay.

2. **Target identification** — Use `GlobalKey` on target widgets. Get position with `RenderBox.localToGlobal`.

3. **Tooltip positioning** — Calculate whether to place above or below target based on available screen space. Arrow indicator points to target.

4. **Sequence management** — `CoachMarkController` holds a `List<CoachMarkStep>`, advances with "Got it" tap or tap on spotlight area.

5. **Persistence** — SharedPreferences keys per screen: `coach_mark_home_seen`, `coach_mark_territory_seen`, etc.

6. **Display trigger** — In each screen's `initState`, check if coach marks seen. If not, show after a 500ms delay (post frame callback + Future.delayed) to let the screen render first.

7. **Animation** — Tooltip fades in (300ms) with slight scale (0.95→1.0). Spotlight cutout animates position when advancing between steps.

### Files to Modify
- `lib/presentation/screens/home/home_screen.dart` — add GlobalKeys to quick action grid and session card
- `lib/presentation/screens/territory/territory_screen.dart` — add GlobalKeys to map tab and FAB
- `lib/presentation/screens/delivery/delivery_screen.dart` — add GlobalKey to record button
- `lib/presentation/screens/chat/conversations_screen.dart` — add GlobalKey to new chat button
- `lib/core/storage/local_storage.dart` — add coach mark persistence methods

---

## Task 3 — Team Leader Bottom Navigation

### Priority: HIGH — leaders currently have no persistent navigation anchor

### Current Problem
Workers get `BottomNavShell` via `ShellRoute` in `app_router.dart:142-221`. Team leaders use standalone routes (`/leader/dashboard`, `/leader/team-members`, etc.) with **no shell** — back button is the only navigation.

### What to Build
A `ShellRoute` for leader routes wrapping the existing `BottomNavShell`, which already has `_buildLeaderNavItems` logic (lines 129-136 in `bottom_nav_shell.dart`).

### Current BottomNavShell Leader Nav Items (already defined!)
```dart
// bottom_nav_shell.dart:130-135 — these already exist but are never used
_NavItemData(Icons.dashboard_outlined, Icons.dashboard, 'Dashboard', 0),
_NavItemData(Icons.people_outline, Icons.people, 'Team', 1),
_NavItemData(Icons.assignment_outlined, Icons.assignment, 'Surveys', 2),
_NavItemData(Icons.bar_chart_outlined, Icons.bar_chart, 'Reports', 3),
```

### Changes to `app_router.dart`

**Add a new ShellRoute for leader primary tabs:**
```
ShellRoute(
  navigatorKey: _leaderShellNavigatorKey,
  builder: (context, state, child) => BottomNavShell(child: child),
  routes: [
    GoRoute(path: '/leader/dashboard', pageBuilder: ... => TeamLeaderDashboard()),
    GoRoute(path: '/leader/team-members', pageBuilder: ... => TeamMembersScreen()),
    GoRoute(path: '/leader/survey', pageBuilder: ... => SurveyScreen()),
    GoRoute(path: '/leader/reports', pageBuilder: ... => ReportsScreen()),
    GoRoute(path: '/leader/profile', pageBuilder: ... => ProfileScreen()),
  ],
)
```

**Keep existing stack routes for deep screens:**
```
/leader/territory-assignment    → stays as stack (no bottom nav)
/leader/schedule               → stays as stack
/leader/team-map               → stays as stack
/leader/worker-activity/:id    → stays as stack
/leader/worker-tracking        → stays as stack
/leader/worker-trail/:id       → stays as stack
/leader/worker-verification    → stays as stack
/leader/chat/*                 → stays as stack
/leader/walkie                 → stays as stack
/leader/blogs/*                → stays as stack
/leader/prayer-requests/*      → stays as stack
```

### Changes to `bottom_nav_shell.dart`

**Update `_getCurrentIndex` leader routes (line 30-40):**
```dart
// Currently maps to /home, /team, /survey, /reports
// Change to match new leader shell routes:
case '/leader/dashboard': return 0;
case '/leader/team-members': return 1;
case '/leader/survey': return 2;
case '/leader/reports': return 3;
```

**Update `_onItemTapped` leader routing (line 62-74):**
```dart
case 0: context.go('/leader/dashboard');
case 1: context.go('/leader/team-members');
case 2: context.go('/leader/survey');
case 3: context.go('/leader/reports');
```

### Add Profile Access for Leaders
Add a 5th nav item or keep profile in the app bar (current pattern). Recommendation: add profile icon in app bar consistently (already present in home_screen.dart:216-218).

### Files to Modify
- `lib/presentation/navigation/app_router.dart` — restructure leader routes into ShellRoute + stack routes
- `lib/presentation/widgets/bottom_nav_shell.dart` — update leader route paths in `_getCurrentIndex` and `_onItemTapped`

---

## Task 4 — Simplify Home Screen Layout

### Priority: HIGH — reduces cognitive overload by ~40%

### Current Home Screen Sections (Worker — 1881 lines)
1. SliverAppBar (logo + notifications + avatar)
2. Welcome greeting (name)
3. Today's Schedule card
4. Location Status Banner
5. **Quick Action grid (8 tiles)** ← too many
6. Session Tracking card
7. **Ministry Overview (4 stat cards)** ← not primary action
8. **Territory Overview card** ← duplicates territory screen
9. **Recent Activity list** ← low priority
10. 100px bottom spacer

### Proposed Simplified Layout
```
┌─────────────────────────────────┐
│ [Logo]           🔔  [Avatar]   │  SliverAppBar (keep as-is)
├─────────────────────────────────┤
│ Welcome back,                   │
│ John Doe                        │  Keep greeting
├─────────────────────────────────┤
│ ┌─────────────────────────────┐ │
│ │ TODAY'S PLAN (new - Task 5) │ │  NEW: unified daily summary
│ └─────────────────────────────┘ │
├─────────────────────────────────┤
│ Today's Schedule Card           │  Keep as-is
├─────────────────────────────────┤
│ 🟢 GPS Active / Start Session  │  Keep Location Banner
├─────────────────────────────────┤
│ Quick Actions                   │
│ ┌────┐ ┌────┐ ┌────┐ ┌────┐   │  REDUCE to 4 primary tiles:
│ │Terr│ │Dona│ │Surv│ │Team│   │  Territory, Donation, Survey, Team
│ └────┘ └────┘ └────┘ └────┘   │
│            See All →            │  "See All" expands to full 8
├─────────────────────────────────┤
│ Session Tracking Card           │  Keep as-is
├─────────────────────────────────┤
│ ▼ My Stats (collapsed)         │  COLLAPSIBLE: tap to expand
│   Distance | Prayers | Hours | $│  Show 4 stat cards when expanded
├─────────────────────────────────┤
│ Recent Activity (3 items max)   │  Keep, limit to 3 + "View All"
│            View All →           │
└─────────────────────────────────┘
```

### Implementation Details

**1. Reduce quick actions from 8 to 4 + "See All"**

In `home_screen.dart` around line 690-757, change the `QuickActionGrid` to show only the first 4 actions by default:

```dart
// State variable
bool _showAllActions = false;

// In build: show 4 or 8 based on state
QuickActionGrid(
  actions: _showAllActions ? _allActions : _allActions.take(4).toList(),
)

// "See All" / "Show Less" button below grid
TextButton(
  onPressed: () => setState(() => _showAllActions = !_showAllActions),
  child: Text(_showAllActions ? 'Show Less' : 'See All Actions'),
)
```

Primary 4 actions (keep these visible): My Territory, Donation, Survey Form, Team Group.
Secondary 4 (hidden by default): Prayer Request, GPS Tracking, News, Achievements.

**2. Make Ministry Overview collapsible**

Wrap the stats section (lines 784-897) in an `AnimatedCrossFade` or `AnimatedSize`:

```dart
// State variable
bool _statsExpanded = false;

// Collapsible header
GestureDetector(
  onTap: () => setState(() => _statsExpanded = !_statsExpanded),
  child: Row(
    children: [
      Text('Ministry Overview'),
      Spacer(),
      AnimatedRotation(
        turns: _statsExpanded ? 0.5 : 0,
        duration: Duration(milliseconds: 200),
        child: Icon(Icons.expand_more),
      ),
    ],
  ),
)

// Content
AnimatedSize(
  duration: Duration(milliseconds: 300),
  curve: Curves.easeInOut,
  child: _statsExpanded ? _buildStatsGrid() : SizedBox.shrink(),
)
```

**3. Remove Territory Overview section**

Lines 900-1073 (`My Territory` section) duplicates the Territory screen. Remove entirely — quick action tile already links to `/territory`.

**4. Limit Recent Activity to 3 items**

Already limited at line 1118: `state.deliveries.take(3).toList()` — keep as-is.

### Files to Modify
- `lib/presentation/screens/home/home_screen.dart` — restructure `_buildWorkerHome` method

---

## Task 5 — "Today's Plan" Summary Card

### Priority: HIGH — answers "what should I do right now?"

### What to Build
A prominent gradient card at the top of the worker home screen that summarizes today's tasks.

### Visual Specification
```
┌─────────────────────────────────────────┐
│  ┌─ Primary Gradient Background ──────┐ │
│  │                                     │ │
│  │  📋 Today's Plan                   │ │  Title: white, titleMedium, bold
│  │                                     │ │
│  │  3 territories · 12 visits due     │ │  Subtitle: white70, bodyMedium
│  │  2 pending donations               │ │
│  │                                     │ │
│  │  ┌─────────────────────────────┐   │ │
│  │  │      Start Working          │   │ │  White button on gradient
│  │  └─────────────────────────────┘   │ │  OR "Continue Session" if active
│  │                                     │ │
│  └─────────────────────────────────────┘ │
└─────────────────────────────────────────┘
```

### Implementation Details

**New widget** in `lib/presentation/widgets/home/todays_plan_card.dart`:

```dart
class TodaysPlanCard extends StatelessWidget {
  final int territoryCount;
  final int pendingDonations;
  final bool hasActiveSession;
  final String? activeSessionTerritory;
  final VoidCallback onStartWorking;
  final VoidCallback onContinueSession;
  // ...
}
```

**Data sources** (read from existing BLoCs, no new API calls):
- `TerritoryBloc` → `TerritoryAssignmentsLoaded.assignments.length`
- `DeliveryBloc` → `DeliveryListLoaded.deliveries.length` (today's count)
- `WorkSessionBloc` → `WorkSessionActive` vs `WorkSessionInactive`
- `WorkerScheduleBloc` → `WorkerScheduleLoaded.currentOrNextSchedule`

**Styling:**
- Background: `AppColors.primaryGradient` (blue → purple)
- Border radius: `AppSpacing.radiusLg` (16px)
- Padding: `AppSpacing.md` (16px)
- Text: White with varying opacity
- Button: White background, primary text color
- Shadow: `AppShadows.cardShadow` with primary tint

**Placement:** Insert as first `SliverToBoxAdapter` after the welcome greeting in `_buildWorkerHome`.

### Files to Create
- `lib/presentation/widgets/home/todays_plan_card.dart`

### Files to Modify
- `lib/presentation/screens/home/home_screen.dart` — add TodaysPlanCard after welcome section
- `lib/presentation/widgets/widgets.dart` — add export

---

## Task 6 — Territory Map UX Improvements

### Priority: MEDIUM — map is powerful but undiscoverable

### Current State
`territory_screen.dart` has a two-tab layout (My Areas list + Map). The map uses `MapboxMap` widget with territory polygons. There's a collapsible visit legend and a tap hint that may show once.

### Enhancements

**1. Auto zoom-to-fit territories on load**

After territories load, calculate the bounding box of all territory polygons and call:
```dart
mapboxMap.cameraForCoordinateBounds(
  CoordinateBounds(southwest: sw, northeast: ne),
  MbxEdgeInsets(top: 50, left: 50, bottom: 50, right: 50),
)
```

**2. Animated tap hint overlay (first visit)**
```
┌─────────────────────────────────┐
│          MAP CONTENT            │
│                                 │
│    ┌───────────────────────┐    │
│    │  👆 Tap a territory   │    │  Centered, semi-transparent
│    │     to see details    │    │  card, auto-dismiss after 3s
│    └───────────────────────┘    │
│                                 │
└─────────────────────────────────┘
```
- Show for 3 seconds on first visit, fade out
- Store `territory_map_hint_seen` in SharedPreferences

**3. Always-visible legend**
- Remove the collapsible behavior
- Show legend as a small floating card in bottom-left corner
- Use existing color constants: `AppColors.territoryActive`, `.territoryCompleted`, `.territoryPaused`

**4. "My Location" recenter button**
- Small circular FAB in bottom-right (above the existing communication FAB)
- Icon: `Icons.my_location`
- On tap: animate camera to user's GPS position

**5. Territory polygons pulse on initial load**
- Brief opacity animation (0.2 → 0.4 → 0.2) over 1 second when territories first render
- Use `MapboxMap` layer opacity animation

### Files to Modify
- `lib/presentation/screens/territory/territory_screen.dart` — all 5 enhancements
- `lib/core/storage/local_storage.dart` — add `territory_map_hint_seen` key

---

## Task 7 — Walkie-Talkie Push-to-Talk Polish

### Priority: MEDIUM — prominent feature with basic UI

### Current State
`walkie_screen.dart:850-917` has `_PushToTalkButton` — a rectangular `AnimatedContainer` (64px height, pill shape) that changes color between blue/red/grey. No visual audio feedback.

### Redesign Specification

**Replace rectangular PTT with circular PTT + visual feedback:**
```
         Normal State              Speaking State
      ┌──────────────┐          ┌──────────────┐
      │              │          │   ╭ pulse ╮   │
      │   ┌──────┐   │          │  ╭┌──────┐╮  │
      │   │ 🎙️  │   │  ──▶    │  │ 🔴  │  │
      │   │ 120px│   │          │  ╰└──────┘╯  │
      │   └──────┘   │          │   ╰ pulse ╯   │
      │              │          │              │
      │ Hold to Talk │          │  Recording...│
      └──────────────┘          └──────────────┘
```

### Implementation Details

**1. Large circular PTT button (120px diameter)**
```dart
Container(
  width: 120,
  height: 120,
  decoration: BoxDecoration(
    shape: BoxShape.circle,
    color: isSpeaking ? AppColors.error : AppColors.primary,
    boxShadow: [AppShadows.fabShadow],
  ),
  child: Icon(
    isSpeaking ? Icons.mic : Icons.mic_none,
    size: 48,
    color: Colors.white,
  ),
)
```

**2. Animated pulse rings while recording**
- 3 concentric circles expanding outward from the PTT button
- Use `AnimationController` with `repeat()`:
  - Ring 1: 0→1.5x scale, 0→0 opacity, 1500ms duration
  - Ring 2: same, 500ms delay
  - Ring 3: same, 1000ms delay
- Color: `AppColors.error.withAlpha(60)` (red ripple while recording)

**3. Audio level indicator**
- Thin circular progress ring around the PTT button
- Value driven by audio input level (0.0-1.0)
- Color: `AppColors.success` (green ring)
- Use `CircularProgressIndicator` with `strokeWidth: 3`

**4. State labels below button**
- Normal: "Hold to Talk" — `bodyLarge`, `textSecondaryLight`
- Speaking: "Recording..." — `bodyLarge`, `AppColors.error`, with pulsing opacity
- Muted: "Unmute to Talk" — `bodyLarge`, `AppColors.textTertiaryLight`
- Sending: "Sending..." — `bodyLarge`, `AppColors.primary`

**5. Reorganize layout**
```
┌─────────────────────────────────┐
│ [Channel Header]                │  Keep existing
├─────────────────────────────────┤
│ [Speaker indicator]             │  Keep existing
├─────────────────────────────────┤
│ [Participants row]              │  Keep existing
├─────────────────────────────────┤
│ [Messages list]                 │  Keep existing, takes remaining space
├─────────────────────────────────┤
│                                 │
│        ┌──────────┐             │
│        │   PTT    │  120px      │  NEW: centered circular PTT
│        │  Button  │             │
│        └──────────┘             │
│      "Hold to Talk"             │  State label
│                                 │
│  ┌──────────────────────────┐   │
│  │  Type a message...  [>]  │   │  Keep text input, move below PTT
│  └──────────────────────────┘   │
└─────────────────────────────────┘
```

### Files to Modify
- `lib/presentation/screens/walkie/walkie_screen.dart` — redesign `_PushToTalkButton` and `_buildActiveChannel` layout

---

## Task 8 — Standardize Empty States

### Priority: MEDIUM — every blank screen should guide the user

### Current State
The `EmptyState` widget exists (`lib/presentation/widgets/states/empty_state.dart`) with animated icon, gradient background, and action buttons. But not all screens use it consistently — some build inline empty views.

### Audit & Standardization

| Screen | Current Empty State | Target |
|--------|-------------------|--------|
| Territory list | Inline Column (line ~1032-1067) | `EmptyState(icon: Icons.map_outlined, title: 'No territories assigned', description: 'Your team leader will assign areas to you.', actionLabel: 'Browse Territories', onAction: () => context.go('/territory'))` |
| Delivery list | Inline Column | `EmptyState(icon: Icons.volunteer_activism_outlined, title: 'No donations yet', description: 'Tap the button below to record your first donation.', actionLabel: 'Record Donation')` |
| Chat conversations | Uses EmptyState ✓ | Keep |
| Blog list | Inline | `EmptyState(icon: Icons.article_outlined, title: 'No posts yet', description: 'Check back later for news and updates.')` |
| Survey list | Inline | `EmptyState(icon: Icons.assignment_outlined, title: 'No surveys available', description: 'Your team leader will create surveys for you to complete.')` |
| Prayer requests | Inline | `EmptyState(icon: Icons.volunteer_activism, title: 'No prayer requests', description: 'Share a prayer request with your team.', actionLabel: 'Create Request')` |
| Schedule (worker) | Inline | `EmptyState(icon: Icons.calendar_month, title: 'No schedule set', description: 'Your team leader will assign your shifts.', actionLabel: 'View Schedule')` |
| Walkie channels | Inline (line 169-194) | `EmptyState(icon: Icons.speaker_phone, title: 'No channels available', description: 'Your team has no walkie-talkie channels yet.')` |
| Notifications | Uses EmptyState ✓ | Keep |
| Team members (leader) | Inline | `EmptyState(icon: Icons.people_outline, title: 'No team members', description: 'Workers will appear here once they join your team.')` |

### Implementation
For each screen listed above, replace the inline empty view with the `EmptyState` widget from `widgets.dart`. Use consistent icon sizes (64px via `iconSize` parameter) and always include descriptive guidance text.

### Files to Modify
- `lib/presentation/screens/home/home_screen.dart` — territory empty state (line ~1032)
- `lib/presentation/screens/territory/territory_screen.dart` — territory list empty
- `lib/presentation/screens/delivery/delivery_screen.dart` — delivery empty
- `lib/presentation/screens/blog/blog_screen.dart` — blog empty
- `lib/presentation/screens/survey/survey_screen.dart` — survey empty
- `lib/presentation/screens/prayer/prayer_request_screen.dart` — prayer empty
- `lib/presentation/screens/worker/my_schedule_screen.dart` — schedule empty
- `lib/presentation/screens/walkie/walkie_screen.dart` — channels empty (line 169-194) and no team empty (line 141-166)
- `lib/presentation/screens/team_leader/team_members_screen.dart` — team empty

---

## Task 9 — Pull-to-Refresh Consistency

### Priority: MEDIUM — basic mobile UX expectation

### Current State
Some screens use `pull_to_refresh` package (`SmartRefresher`), others use `RefreshIndicator`, some have no refresh at all.

### Standardization
Use Flutter's built-in `RefreshIndicator` (not the package) for simplicity and consistency. Wrap the scrollable content in each screen.

### Screens to Add RefreshIndicator

| Screen | Scrollable Widget | BLoC Event to Dispatch |
|--------|------------------|----------------------|
| Territory (list tab) | ListView.builder | `TerritoryLoadAssignments()` |
| Delivery | SingleChildScrollView | `DeliveryLoadList()` |
| Survey | ListView.builder | `SurveyLoadList()` |
| Blog | ListView.builder | `BlogLoadList()` |
| Prayer Requests | ListView.builder | `PrayerRequestLoadMy()` |
| Chat Conversations | ListView.builder | `ChatLoadConversations()` |
| Notifications | ListView.builder | `NotificationLoad()` |
| Team Members (leader) | ListView.builder | `TeamLoadMembers()` |
| Reports (leader) | SingleChildScrollView | `DashboardLoadStats()` |

### Implementation Pattern
```dart
RefreshIndicator(
  color: AppColors.primary,
  onRefresh: () async {
    context.read<XxxBloc>().add(const XxxLoadEvent());
    // Wait for state change
    await context.read<XxxBloc>().stream.firstWhere(
      (state) => state is! XxxLoading,
    );
  },
  child: existingScrollableWidget,
)
```

### Files to Modify
All screen files listed in the table above.

---

## Task 10 — Micro-Animations

### Priority: LOW — polish, not critical

### What to Add

**1. Staggered list item fade-in**

New helper widget `lib/presentation/widgets/animations/staggered_fade_in.dart`:
```dart
class StaggeredFadeIn extends StatelessWidget {
  final int index;
  final Widget child;
  final int delayMs; // default 50ms per item

  // Uses AnimatedOpacity + AnimatedSlide
  // Initial state: opacity 0, offset (0, 0.05)
  // Final state: opacity 1, offset (0, 0)
  // Duration: 300ms, delay: index * delayMs
}
```

Apply to: Territory list items, delivery list items, blog cards, chat conversations, notification tiles.

**2. Stat card number counting animation**

In `OverviewStatCard`, animate the `value` text from "0" to actual value:
```dart
// Use TweenAnimationBuilder<double>
TweenAnimationBuilder<double>(
  tween: Tween(begin: 0, end: double.tryParse(value) ?? 0),
  duration: Duration(milliseconds: 800),
  curve: Curves.easeOutCubic,
  builder: (context, val, child) => Text(val.toStringAsFixed(precision)),
)
```

**3. Tab switch cross-fade**

Territory screen and Survey screen use `TabBarView`. Add `AnimatedSwitcher` or set `TabBarView`'s physics to `NeverScrollableScrollPhysics()` with manual cross-fade.

**4. Status badge scale-in**

For status badges (ACTIVE, COMPLETED, etc.), add a brief scale animation on first render:
```dart
AnimatedScale(
  scale: 1.0, // from 0.0
  duration: Duration(milliseconds: 200),
  curve: Curves.easeOutBack,
  child: statusBadge,
)
```

### New Files to Create
- `lib/presentation/widgets/animations/staggered_fade_in.dart`
- `lib/presentation/widgets/animations/counting_text.dart`

### Files to Modify
- `lib/presentation/widgets/home/overview_stat_card.dart` — add counting animation
- All list screens — wrap items in `StaggeredFadeIn`

---

## Task 11 — Donation Flow Step Indicator

### Priority: MEDIUM — complex form needs progress cues

### Current State
`delivery_screen.dart` opens a `DraggableScrollableSheet` with all form fields at once: donor name, amount, address, phone, payment method, notes.

### Redesign — 3-Step Flow
```
Step 1: Donor Info          Step 2: Amount & Method      Step 3: Review & Confirm
┌─────────────────────┐    ┌─────────────────────┐    ┌─────────────────────┐
│ ━━━━━━ ─── ─── (1/3)│    │ ━━━━━━ ━━━━━━ ─── (2/3)│    │ ━━━━━━ ━━━━━━ ━━━━━━ (3/3)│
│                     │    │                     │    │                     │
│ Donor Name *        │    │ Amount ($) *        │    │ REVIEW              │
│ ┌─────────────────┐ │    │ ┌─────────────────┐ │    │                     │
│ │                 │ │    │ │                 │ │    │ Donor: John Doe     │
│ └─────────────────┘ │    │ └─────────────────┘ │    │ Amount: $50.00      │
│                     │    │                     │    │ Method: Cash        │
│ Address (optional)  │    │ Payment Method      │    │ Address: 123 Main   │
│ ┌─────────────────┐ │    │ ┌──────┐ ┌────────┐│    │ Phone: 555-1234     │
│ │                 │ │    │ │ Cash │ │Send Lnk││    │                     │
│ └─────────────────┘ │    │ └──────┘ └────────┘│    │                     │
│                     │    │                     │    │ ┌─────────────────┐ │
│ Phone (optional)    │    │ Notes (optional)    │    │ │    Confirm      │ │
│ ┌─────────────────┐ │    │ ┌─────────────────┐ │    │ └─────────────────┘ │
│ │                 │ │    │ │                 │ │    │                     │
│ └─────────────────┘ │    │ └─────────────────┘ │    │                     │
│                     │    │                     │    │                     │
│     [Next →]        │    │  [← Back] [Next →]  │    │  [← Back] [Submit]  │
└─────────────────────┘    └─────────────────────┘    └─────────────────────┘
```

### Implementation Details

**1. Step indicator widget** — new reusable widget
```
lib/presentation/widgets/stepper/step_progress_bar.dart
```
- 3 segments, each a rounded rectangle
- Active: `AppColors.primary`, filled
- Upcoming: `AppColors.borderLight`, outlined
- Height: 4px
- Animation: segment fills left-to-right (300ms)

**2. Step content** — Use `PageView` with `NeverScrollableScrollPhysics` (controlled by Next/Back buttons):
- Page 0: Donor name, address, phone
- Page 1: Amount, payment method, notes
- Page 2: Summary review with all entered data

**3. Navigation buttons:**
- "Next" validates current page fields before advancing
- "Back" goes to previous page
- "Confirm" on final page submits
- Buttons use `CustomButton`

**4. Review page styling:**
- Key-value pairs in a card
- Each row: label (bodySmall, secondary) + value (bodyMedium, primary)
- Dividers between rows

### Files to Create
- `lib/presentation/widgets/stepper/step_progress_bar.dart`

### Files to Modify
- `lib/presentation/screens/delivery/delivery_screen.dart` — refactor `_RecordDonationSheet` into 3-step flow

---

## Task 12 — Role Indicators & Breadcrumbs

### Priority: MEDIUM — clarity during role-switching demos

### What to Add

**1. App bar role badge**

Add a subtle chip next to the logo in every screen's AppBar:
```dart
// In AppBar title or actions:
Container(
  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
  decoration: BoxDecoration(
    color: isLeader
        ? AppColors.secondary.withAlpha(30)   // purple tint
        : AppColors.primary.withAlpha(30),     // blue tint
    borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
  ),
  child: Text(
    isLeader ? 'Leader' : 'Worker',
    style: TextStyle(
      fontSize: 10,
      fontWeight: FontWeight.w600,
      color: isLeader ? AppColors.secondary : AppColors.primary,
    ),
  ),
)
```

**Note:** The leader dashboard already has this at line 252-273 of `home_screen.dart`. Extend this pattern to all screens.

**2. Contextual header on leader sub-screens**

When a leader views a specific worker's data (worker-activity, worker-trail), show a persistent header:
```
┌─────────────────────────────────┐
│ ← Worker Activity               │
│ ┌─────────────────────────────┐ │
│ │ 👤 Viewing: Sarah Miller     │ │  Small banner below app bar
│ └─────────────────────────────┘ │  AppColors.primary at 8% opacity
│                                 │
│ [Screen content...]             │
└─────────────────────────────────┘
```

**3. Breadcrumb on deep screens**

For screens 3+ levels deep (e.g., Dashboard → Team → Worker Activity → Trail), add breadcrumb text in the app bar subtitle:
```dart
AppBar(
  title: Text('Location Trail'),
  // subtitle via bottom or a small text widget:
  // "Team > Sarah Miller > Trail"
)
```

### Files to Modify
- `lib/presentation/widgets/bottom_nav_shell.dart` — add role badge helper
- `lib/presentation/screens/team_leader/worker_activity_screen.dart` — add worker context header
- `lib/presentation/screens/team_leader/worker_trail_screen.dart` — add worker context header
- `lib/presentation/screens/team_leader/worker_tracking_screen.dart` — add breadcrumb

---

## Task 13 — Inline Form Validation

### Priority: MEDIUM — forms feel unresponsive without real-time feedback

### Current State
`CustomTextField` has a `validator` property used with `Form.validate()` on submit. No real-time validation as user types.

### Enhancements

**1. Real-time validation (debounced)**

Add to `CustomTextField`:
```dart
// New property
final bool realtimeValidation; // default false

// In build, wrap with ValueListenableBuilder on controller:
controller.addListener(() {
  if (realtimeValidation) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(Duration(milliseconds: 500), () {
      _formFieldKey.currentState?.validate();
    });
  }
});
```

**2. Green checkmark on valid fields**

Add suffix icon when field is valid and non-empty:
```dart
suffixIcon: _isValid && controller.text.isNotEmpty
    ? Icon(Icons.check_circle, color: AppColors.success, size: 20)
    : existingSuffixIcon,
```

**3. Error text slide-in animation**

Wrap the error text in `AnimatedSize` + `AnimatedOpacity`:
```dart
AnimatedSize(
  duration: Duration(milliseconds: 200),
  child: AnimatedOpacity(
    opacity: hasError ? 1.0 : 0.0,
    duration: Duration(milliseconds: 200),
    child: errorText,
  ),
)
```

**4. Auto-scroll to first error**

In form screens, after `Form.validate()` returns false:
```dart
Scrollable.ensureVisible(
  firstErrorKey.currentContext!,
  duration: Duration(milliseconds: 300),
  curve: Curves.easeInOut,
);
```

### Apply To
- Login screen (`login_screen.dart`)
- Register screen (`register_screen.dart`)
- Donation form (`delivery_screen.dart`)
- Visit log form (`log_visit_screen.dart`)
- Prayer request form (`prayer_request_form_screen.dart`)
- Survey form (`survey_form_screen.dart`)

### Files to Modify
- `lib/presentation/widgets/custom_text_field.dart` — add realtime validation, checkmark, error animation
- All form screens listed above — enable `realtimeValidation: true`

---

## Task 14 — Success Animations

### Priority: LOW — polish, moments of delight

### What to Add

**1. Animated checkmark widget**

New file: `lib/presentation/widgets/animations/success_check.dart`
```dart
class AnimatedSuccessCheck extends StatefulWidget {
  final double size;       // default 80
  final Color color;       // default AppColors.success
  final Duration duration; // default 600ms
}
```

Animation sequence:
- Circle draws (0→360°) with `CustomPainter` — 300ms
- Checkmark draws (two line segments) — 300ms after circle
- Brief scale bounce (1.0→1.1→1.0) — 200ms after checkmark
- Uses `Curves.easeInOut`

**2. Apply to these flows:**

| Action | When | Duration |
|--------|------|----------|
| Donation recorded | After successful API response in bottom sheet | Show for 1.5s, then close sheet |
| Visit logged | After submit in `log_visit_screen.dart` | Show for 1s, then clear form |
| Survey submitted | After submit in `survey_form_screen.dart` | Show for 1.5s, then pop back |
| Prayer request created | After submit in `prayer_request_form_screen.dart` | Show for 1.5s, then pop back |
| Session started | After check-in in `home_screen.dart` | Show for 1s inline |
| Session ended | After check-out | Show for 1s inline |

**3. Implementation pattern:**

Replace snackbar-only feedback with a brief fullscreen/inline overlay:
```dart
// In BlocListener success handler:
showDialog(
  context: context,
  barrierDismissible: false,
  barrierColor: Colors.black38,
  builder: (_) => Center(
    child: AnimatedSuccessCheck(size: 100),
  ),
);
await Future.delayed(Duration(milliseconds: 1500));
Navigator.pop(context); // dismiss overlay
// ... continue with navigation/form reset
```

### Files to Create
- `lib/presentation/widgets/animations/success_check.dart`

### Files to Modify
- `lib/presentation/screens/delivery/delivery_screen.dart` — donation success
- `lib/presentation/screens/home/log_visit_screen.dart` — visit success
- `lib/presentation/screens/survey/survey_form_screen.dart` — survey success
- `lib/presentation/screens/prayer/prayer_request_form_screen.dart` — prayer success
- `lib/presentation/screens/home/home_screen.dart` — session start/end success

---

## Task 15 — Quick-Action Tile Redesign

### Priority: MEDIUM — tiles are icon-only, unclear to new users

### Current State
`QuickActionTile` (`quick_action_tile.dart`) shows: colored background + icon (24px) + label text (12px). No subtitle or badge.

### Enhancements

**1. Add subtitle text**

Add optional `subtitle` parameter to `QuickActionTileData`:
```dart
class QuickActionTileData {
  final IconData icon;
  final String label;
  final String? subtitle;      // NEW
  final Color backgroundColor;
  final VoidCallback onTap;
  final int? badgeCount;       // NEW
}
```

Subtitles:
| Tile | Subtitle |
|------|----------|
| My Territory | "View assigned areas" |
| Donation | "Record donations" |
| Survey Form | "Complete surveys" |
| Prayer Request | "Share with team" |
| Team Group | "Chat & walkie" |
| GPS Tracking | "Track location" |
| News | "Read updates" |
| Achievements | "View progress" |

**2. Add notification badge**

Show a small badge (circle with count) on tiles that have pending items:
```dart
// Top-right corner of tile
if (badgeCount != null && badgeCount! > 0)
  Positioned(
    right: 4,
    top: 4,
    child: Container(
      padding: EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.error,
        shape: BoxShape.circle,
      ),
      constraints: BoxConstraints(minWidth: 20, minHeight: 20),
      child: Text('$badgeCount', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
    ),
  )
```

Badge sources (from existing BLoCs):
- Survey: pending survey count from `SurveyBloc`
- Prayer Request: could show "NEW" if recent

**3. Visual layout update**

```
Current:                    New:
┌──────────────┐           ┌──────────────┐
│              │           │          (3) │  badge
│    🗺️       │           │    🗺️       │
│              │           │              │
│ My Territory │           │ My Territory │  label (bold)
│              │           │ View areas   │  subtitle (muted)
└──────────────┘           └──────────────┘
```

### Files to Modify
- `lib/presentation/widgets/home/quick_action_tile.dart` — add subtitle, badge support
- `lib/presentation/screens/home/home_screen.dart` — pass subtitle strings and badge counts

---

## Task 16 — Help/Demo Mode Floating Button

### Priority: HIGH — specifically for client demos

### What to Build
A toggleable "Help Mode" that shows a floating "?" button on every screen. Tapping it shows an overlay explaining the current screen.

### New Files to Create
```
lib/presentation/widgets/help/
├── help_mode_provider.dart    # InheritedWidget / ValueNotifier for help mode state
├── help_fab.dart              # Floating "?" button
└── help_overlay.dart          # Screen explanation overlay
```

### Help Content Map

```dart
const Map<String, HelpContent> helpContent = {
  '/home': HelpContent(
    title: 'Home Dashboard',
    audience: 'Workers',
    bullets: [
      'See your daily schedule and active work session',
      'Quick access to Territory, Donations, Surveys, and more',
      'Track your ministry hours and distance',
    ],
  ),
  '/territory': HelpContent(
    title: 'My Territories',
    audience: 'Workers',
    bullets: [
      'View all territories assigned to you by your team leader',
      'Switch between list view and interactive map',
      'Tap a territory to see details and start working',
    ],
  ),
  '/delivery': HelpContent(
    title: 'Donations',
    audience: 'Workers',
    bullets: [
      'Record cash or online donations in the field',
      'Generate receipts automatically',
      'View today\'s donation summary and history',
    ],
  ),
  '/leader/dashboard': HelpContent(
    title: 'Team Dashboard',
    audience: 'Team Leaders',
    bullets: [
      'Overview of your team\'s activity and stats',
      'Quick access to manage workers, schedules, and territories',
      'View recent team activity feed',
    ],
  ),
  // ... one entry per route
};
```

### Visual Specification
```
Normal screen:                    Help overlay:
┌─────────────────────────┐      ┌─────────────────────────┐
│                         │      │ ░░░░░░░░░░░░░░░░░░░░░░░ │
│   [Screen content]      │      │ ░░░░░░░░░░░░░░░░░░░░░░░ │
│                         │      │ ░┌─────────────────────┐░ │
│                         │      │ ░│ 📋 Home Dashboard    │░ │
│                         │      │ ░│ For: Workers         │░ │
│                         │      │ ░│                     │░ │
│                         │      │ ░│ • See your daily... │░ │
│                         │      │ ░│ • Quick access to.. │░ │
│                         │      │ ░│ • Track your min... │░ │
│                         │      │ ░│                     │░ │
│                         │      │ ░│     [Got it]        │░ │
│                         │      │ ░└─────────────────────┘░ │
│                    (?)  │      │ ░░░░░░░░░░░░░░░░░░░░░░░ │
└─────────────────────────┘      └─────────────────────────┘
```

### Implementation Details

**1. Toggle** — Add "Help Mode" switch in `profile_screen.dart` settings section (alongside Dark Mode toggle).

**2. HelpModeProvider** — `ValueNotifier<bool>` provided via `ValueListenableBuilder` at the app level (in `main.dart`).

**3. HelpFab** — Conditionally rendered when help mode is on. Uses `GoRouterState.of(context).matchedLocation` to determine which help content to show.

**4. Help overlay** — Uses `showDialog` with transparent barrier + centered card. Card uses `AppCard(variant: AppCardVariant.elevated)`.

**5. Persistence** — `SharedPreferences` key: `help_mode_enabled` (bool, default false).

### Files to Create
- `lib/presentation/widgets/help/help_mode_provider.dart`
- `lib/presentation/widgets/help/help_fab.dart`
- `lib/presentation/widgets/help/help_overlay.dart`
- `lib/presentation/widgets/help/help_content.dart` (content map)

### Files to Modify
- `lib/main.dart` — wrap app in HelpModeProvider
- `lib/presentation/screens/profile/profile_screen.dart` — add Help Mode toggle in settings
- `lib/presentation/widgets/bottom_nav_shell.dart` — add HelpFab to Scaffold body stack
- `lib/presentation/navigation/app_router.dart` — add HelpFab to non-shell routes

---

## Task 17 — Notification Tile Visual Hierarchy

### Priority: LOW — refinement

### Current State
`notification_tile.dart` shows: icon badge + title + description + timestamp. All tiles look the same regardless of type.

### Enhancements

**1. Colored left border by notification type**
```dart
Container(
  decoration: BoxDecoration(
    border: Border(
      left: BorderSide(
        color: _getTypeColor(notification.type), // chat=blue, territory=green, etc.
        width: 4,
      ),
    ),
  ),
  child: existingTileContent,
)
```

Color mapping:
| Type | Color |
|------|-------|
| chat | `AppColors.primary` (blue) |
| walkie | `AppColors.warning` (amber) |
| territory, geofence | `AppColors.success` (green) |
| delivery | `AppColors.accent` (cyan) |
| prayer | `AppColors.secondary` (purple) |
| survey | `AppColors.info` (blue) |
| team | `AppColors.primary` (blue) |
| session | `AppColors.success` (green) |

**2. Unread background tint**
```dart
// For unread notifications:
Container(
  color: AppColors.primary.withAlpha(8), // very subtle blue tint
  child: tileContent,
)
```

**3. Swipe-to-dismiss actions**

Use `Dismissible` widget:
- Swipe right: mark as read (green background + check icon)
- Swipe left: delete (red background + delete icon)
```dart
Dismissible(
  key: Key(notification.id),
  background: Container(color: AppColors.success, child: Icon(Icons.check, color: Colors.white)),
  secondaryBackground: Container(color: AppColors.error, child: Icon(Icons.delete, color: Colors.white)),
  confirmDismiss: (direction) async {
    if (direction == DismissDirection.endToStart) {
      return await showConfirmDialog(); // confirm delete
    }
    markAsRead(notification.id);
    return false; // don't actually dismiss, just mark read
  },
)
```

### Files to Modify
- `lib/presentation/widgets/notification/notification_tile.dart` — add left border, unread tint
- `lib/presentation/screens/notification/notification_center_screen.dart` — add Dismissible wrapper

---

## Task 18 — Page Transition Standardization

### Priority: LOW — cohesive feel

### Current State
`page_transitions.dart` defines: Slide, SlideUp, Fade, Scale, SharedAxis, Cupertino, None. But `app_router.dart` mostly uses `NoTransitionPage` (for shell routes) and default `builder` (no explicit transition) for other routes.

### Standardization Rules

| Navigation Type | Transition | Duration |
|----------------|------------|----------|
| Bottom nav tab switch | `NoTransitionPage` (keep) | instant |
| Forward navigation (deeper) | `PageTransitions.slide` (right-to-left) | 300ms |
| Modal/form screen | `PageTransitions.slideUp` (bottom-to-top) | 350ms |
| Back navigation | Automatic reverse of forward | — |
| Dialog/overlay | `showDialog` / `showModalBottomSheet` (keep) | — |

### Apply Transitions in `app_router.dart`

**Forward navigation routes** (use `pageBuilder` with slide):
- `/chat/:conversationId`
- `/chat/team/:teamId`
- `/notifications`
- `/blogs/:id`
- All `/leader/*` stack routes (territory-assignment, schedule, team-map, worker-activity, etc.)

**Modal/form routes** (use `pageBuilder` with slideUp):
- `/prayer-requests/new`
- `/notifications/settings`
- `/onboarding` (when added)

### Implementation
```dart
// In app_router.dart, change builder to pageBuilder:
GoRoute(
  path: '/notifications',
  pageBuilder: (context, state) => PageTransitions.slide(
    key: state.pageKey,
    child: const NotificationCenterScreen(),
  ),
),
```

### Files to Modify
- `lib/presentation/navigation/app_router.dart` — add `pageBuilder` with appropriate transition to all non-shell routes

---

## Implementation Order

### Phase 1 — "Client Understanding" (Tasks 1, 16, 3, 5)
These 4 tasks directly solve the stated problem: "letting the client understand how the app works."

| Order | Task | Effort | Impact |
|-------|------|--------|--------|
| 1.1 | **Task 1: Onboarding Flow** | ~3h | Explains app on first launch |
| 1.2 | **Task 16: Help/Demo Mode** | ~2h | Per-screen explanation for demos |
| 1.3 | **Task 3: Leader Bottom Nav** | ~1h | Leaders can actually navigate |
| 1.4 | **Task 5: Today's Plan Card** | ~1h | Clear daily call-to-action |

### Phase 2 — "Reduce Confusion" (Tasks 4, 15, 12, 8)
Simplify what's on screen and make roles/features clear.

| Order | Task | Effort | Impact |
|-------|------|--------|--------|
| 2.1 | **Task 4: Simplify Home** | ~2h | 40% less visual noise |
| 2.2 | **Task 15: Quick-Action Redesign** | ~1h | Tiles explain themselves |
| 2.3 | **Task 12: Role Indicators** | ~1h | Clear role context |
| 2.4 | **Task 8: Empty States** | ~1.5h | Every blank screen guides |

### Phase 3 — "Feature Polish" (Tasks 7, 6, 11, 2)
Make key features feel complete and teach interaction patterns.

| Order | Task | Effort | Impact |
|-------|------|--------|--------|
| 3.1 | **Task 7: Walkie PTT** | ~2h | Prominent feature, needs polish |
| 3.2 | **Task 6: Territory Map** | ~2h | Map becomes self-explanatory |
| 3.3 | **Task 11: Donation Stepper** | ~2h | Complex flow simplified |
| 3.4 | **Task 2: Coach Marks** | ~3h | In-context teaching |

### Phase 4 — "Consistency & Delight" (Tasks 9, 13, 18, 10, 14, 17)
Standard UX patterns and visual polish.

| Order | Task | Effort | Impact |
|-------|------|--------|--------|
| 4.1 | **Task 9: Pull-to-Refresh** | ~1h | Basic UX expectation |
| 4.2 | **Task 13: Form Validation** | ~2h | Forms feel responsive |
| 4.3 | **Task 18: Page Transitions** | ~1h | Cohesive navigation |
| 4.4 | **Task 10: Micro-Animations** | ~2h | App feels alive |
| 4.5 | **Task 14: Success Animations** | ~1.5h | Moments of delight |
| 4.6 | **Task 17: Notification Tiles** | ~1h | Better notification UX |

---

### Total Estimated Effort: ~30 hours across 18 tasks

### Dependencies
```
Task 1 (Onboarding) → must be done before Task 2 (Coach Marks)
Task 3 (Leader Nav)  → should be done before Task 12 (Role Indicators)
Task 4 (Simplify Home) → should include Task 5 (Today's Plan) changes
Task 15 (Tile Redesign) → can be done alongside Task 4
```

### No-Touch Zones (per user request)
- Data models (`lib/data/models/`)
- API client (`lib/core/network/api_client.dart`)
- Repository logic (`lib/data/repositories/`)
- BLoC event/state definitions (no new events/states — only consume existing ones)
- Database/API mapping logic
