# Light Point - Complete User Guide

> A step-by-step guide for Admins, Team Leaders, and Workers.

---

## Table of Contents

1. [System Overview](#1-system-overview)
2. [User Roles & Permissions](#2-user-roles--permissions)
3. [Getting Started](#3-getting-started)
4. [Admin Panel Guide](#4-admin-panel-guide)
5. [Mobile App - Worker Guide](#5-mobile-app---worker-guide)
6. [Mobile App - Team Leader Guide](#6-mobile-app---team-leader-guide)
7. [Feature Reference](#7-feature-reference)
8. [Troubleshooting](#8-troubleshooting)

---

## 1. System Overview

Light Point is a field ministry management platform with three components:

| Component | URL | Purpose |
|-----------|-----|---------|
| **Admin Panel** (web) | https://admin.lightsquads.com | Manage users, territories, teams, surveys, content |
| **Mobile App** (iOS/Android) | Installed on phones | Field work: territory tracking, deliveries, chat, walkie-talkie |
| **Backend API** | https://backend.lightsquads.com | Server that powers everything |

### How It All Connects

```
ADMIN (web)                    MOBILE APP (phone)
    |                                |
    |  Creates territories           |  Workers view territories
    |  Allocates to leaders          |  Leaders assign to workers
    |  Verifies users                |  Workers do field work
    |  Creates surveys               |  Workers fill surveys
    |  Manages content               |  Everyone communicates
    |                                |
    +-----------> BACKEND API <------+
```

---

## 2. User Roles & Permissions

### Role Hierarchy

```
Super Admin  (highest access)
     |
   Admin     (manages everything)
     |
 Team Leader (manages a team of workers)
     |
  Worker     (does field work)
```

### What Each Role Can Do

| Feature | Super Admin | Admin | Team Leader | Worker |
|---------|:-----------:|:-----:|:-----------:|:------:|
| **Create admin accounts** | ✅ | ❌ | ❌ | ❌ |
| **Verify team leaders** | ✅ | ✅ | ❌ | ❌ |
| **Verify workers** | ✅ | ✅ | ❌ | ❌ |
| **Create teams** | ✅ | ✅ | ✅ | ❌ |
| **Allocate territories to leaders** | ✅ | ✅ | ❌ | ❌ |
| **Assign territories to workers** | ✅ | ✅ | ✅ | ❌ |
| **Create/edit/delete territories** | ✅ | ✅ | ✅* | ❌ |
| **Create surveys** | ✅ | ✅ | ✅ | ❌ |
| **View all donations** | ✅ | ✅ | ❌ | ❌ |
| **View team donations** | ✅ | ✅ | ✅ | ❌ |
| **Record donations** | ✅ | ✅ | ✅ | ✅ |
| **View worker locations** | ✅ | ✅ | ✅ | ❌ |
| **View team members** | ✅ | ✅ | ✅ | ❌ |
| **Approve/reject join requests** | ✅ | ✅ | ✅ | ❌ |
| **Create schedules** | ✅ | ✅ | ✅ | ❌ |
| **View own schedule** | ✅ | ✅ | ✅ | ✅ |
| **Create blog posts** | ✅ | ✅ | ❌ | ❌ |
| **Fill surveys** | ✅ | ✅ | ✅ | ✅ |
| **Record deliveries** | ✅ | ✅ | ✅ | ✅ |
| **Use walkie-talkie** | ✅ | ✅ | ✅ | ✅ |
| **Chat with team** | ✅ | ✅ | ✅ | ✅ |
| **Submit prayer requests** | ✅ | ✅ | ✅ | ✅ |
| **View team prayer requests** | ✅ | ✅ | ✅ | ❌ |
| **View targets & achievements** | ✅ | ✅ | ✅ | ✅ |
| **Create targets** | ✅ | ✅ | ✅ | ❌ |

*\* Team Leaders can only edit territories allocated to them.*

---

## 3. Getting Started

### For Admins

1. Go to **https://admin.lightsquads.com**
2. Log in with your admin credentials
3. You'll see the **Dashboard** with stats and quick actions
4. First-time setup steps:
   - Verify pending team leaders (see [Verifying Users](#verifying-users))
   - Create teams (see [Managing Teams](#managing-teams))
   - Allocate territories to leaders (see [Allocating Territories](#allocating-territories))

### For Team Leaders (Mobile App)

1. Download the Light Point app
2. Tap **"Create Account"**
3. Select **"Team Leader"** as your role
4. Enter your details and create a team name
5. You'll receive an email verification link — tap it
6. Wait for an admin to verify your account
7. Once verified, log in and you'll see your **Team Leader Dashboard**

### For Workers (Mobile App)

1. Download the Light Point app
2. Tap **"Create Account"**
3. Select **"Worker"** as your role
4. Search for and select your team
5. Enter your details and submit
6. You'll receive an email verification link — tap it
7. Your team leader will approve your request
8. Once approved, log in and you'll see your **Worker Home**

---

## 4. Admin Panel Guide

### Dashboard

The dashboard is your home screen. It shows:

- **4 stat cards**: Team Leaders (with pending count), Active Teams, Territories (with allocated count), Surveys
- **4 quick action buttons**:
  - "Verify Team Leaders" — takes you to pending leaders
  - "Allocate Territories" — takes you to territory management
  - "Create Survey" — takes you to survey builder
  - "View Donations" — takes you to donation reports

### Verifying Users

**Path:** Sidebar → Users

This page has 3 tabs:

#### Tab 1: Pending Leaders
Shows team leaders waiting for admin approval.

**How to verify a leader:**
1. Click the **"Verify"** button next to their name
2. The leader is now approved and can log in

**How to reject a leader:**
1. Click the **"Reject"** button
2. Enter a reason (e.g., "Incomplete application")
3. The leader will see the rejection reason

#### Tab 2: Pending Workers
Same as above, but for workers. Team leaders can also verify workers.

#### Tab 3: All Users
Shows everyone in the system with their role badge (SUPERADMIN, ADMIN, LEADER, WORKER) and status (VERIFIED, PENDING, REJECTED).

---

### Managing Teams

**Path:** Sidebar → Teams

**How to create a team:**
1. Click **"Create Team"**
2. Enter team name (required)
3. Enter description (optional)
4. Optionally assign a leader from the dropdown
5. Click **"Create"**

**How to assign a leader to a team:**
1. Find the team without a leader
2. Click **"Assign Leader"**
3. Search for a verified leader in the dropdown
4. Select the leader

> **Important:** A team must have a leader before workers can be assigned to it.

---

### Managing Territories

**Path:** Sidebar → Territories

This page has 3 tabs:

#### Tab 1: Overview (Map View)
Shows an interactive map with all territory polygons. You can:
- Zoom in/out to see territory boundaries
- Click a territory to see its details
- Use "Jump to Union" dropdown to navigate to specific areas
- See statistics: total unions, territories, allocated count

#### Tab 2: Allocations
Shows which territories are allocated to which leaders.

**How to allocate a territory to a leader:**
1. Go to the **"Search & Allocate"** tab
2. Search for a territory by name or SOLID code
3. Select the territory
4. Choose a team leader from the dropdown
5. Click **"Allocate"**

> **This is the critical first step.** Admins must allocate territories to leaders BEFORE leaders can assign them to workers.

#### Tab 3: Search & Allocate
Search and allocate territories (see above).

**How to create a new territory:**
1. Click **"Create Territory"**
2. On the map, click to draw polygon vertices (corners)
3. Close the polygon by clicking near the first point
4. Fill in the metadata form:
   - **Entity Name** (required): Name of the area
   - **Entity ID** (required): Unique identifier
   - Union Name, Conference, City, State, Zipcode, Population, Housing Units
5. Click **"Save"**

**How to edit a territory:**
1. Find the territory in the list
2. Click **"Edit"**
3. Redraw the polygon or update metadata
4. Click **"Save"**

**How to delete a territory:**
1. Find the territory
2. Click **"Delete"**
3. Confirm the deletion

---

### Managing Surveys

**Path:** Sidebar → Surveys

**How to create a survey:**
1. Click **"Create Survey"**
2. Enter title and description
3. Choose assignment:
   - Toggle "Assign to all teams" OR select specific teams
   - Toggle "Assign to all workers" OR select specific workers
4. Toggle "Require GPS location" if needed
5. Add questions by clicking **"Add Question"**:
   - Enter question text
   - Select type: Short Text, Long Text, Number, Date, Dropdown, Single Choice, Multiple Choice, Rating (1-5), Yes/No, Photo Upload, or Signature
   - Toggle "Required" if the question is mandatory
   - For Dropdown/Choice types, add options
6. Drag questions to reorder them
7. Click **"Create"**

**How to view responses:**
1. Click on a survey in the list
2. The right panel shows response count and details
3. Click individual responses to see answers

> **Note:** Workers fill out surveys from the mobile app. Admins and leaders can only view responses.

---

### Managing Donations

**Path:** Sidebar → Donations

This page has 3 tabs:

#### Tab 1: Overview
Shows summary stats: Total Donations, Average, Online Pending.

#### Tab 2: Donations
Lists all donations with: donor name, type, payment method, date, amount, status.

**Status meanings:**
- **received** — donation collected, not yet deposited
- **deposited** — donation deposited to bank
- **cancelled** — donation was cancelled

#### Tab 3: Receipts
Lists all receipts from book sales and donations.

**Filtering:** Use the team dropdown to filter by a specific team.

---

### Managing Blog Posts

**Path:** Sidebar → Blog Posts

**How to create a blog post:**
1. Click **"Create Post"**
2. Upload a featured image (JPG, PNG, GIF, or WebP)
3. Enter title, excerpt, and content
4. Toggle "Publish immediately" (or save as draft)
5. Click **"Create"**

**How to edit a blog post:**
1. Click on a post
2. Click **"Edit"** in the preview panel
3. Make changes and click **"Save"**

**How to delete a blog post:**
1. Click on a post
2. Click **"Delete"** in the preview panel
3. Confirm the deletion

---

### Managing Prayer Requests

**Path:** Sidebar → Prayer Requests

This page has 2 tabs:

#### Tab 1: Overview
Shows stats: Total, Pending, Completed, Home Visits. Plus breakdowns by category and urgency.

#### Tab 2: All Requests
Lists all prayer requests from workers.

**How to update a prayer request status:**
1. Click on a request to see details
2. Change the status: pending → scheduled → in_progress → completed
3. Save

---

### Managing Analytics

**Path:** Sidebar → Analytics

4 tabs with detailed reports:

- **Overview**: Summary grid with worker counts, team counts, territory counts, donation totals
- **Donations**: Breakdown by payment method, one-time vs recurring
- **Prayer Requests**: Breakdown by category and urgency
- **Workers**: Per-worker performance table (deliveries, completion rate, avg time, distance)

Use the **team filter** dropdown to focus on a specific team.

---

### Managing the Activity Map

**Path:** Sidebar → Activity Map

A full-screen interactive map with 5 toggleable layers:

| Layer | What It Shows |
|-------|--------------|
| Territories | Territory polygons (blue outlines) |
| Active Workers | Green person markers with real-time locations |
| Churches | Blue church markers |
| Prayer Requests | Colored markers by urgency (red=urgent, orange=high, yellow=medium, blue=normal) |
| Donations | Green dollar markers |

**How to use:**
1. Toggle layers on/off using the layer menu (top-right)
2. Filter workers by team using the team dropdown
3. Switch map style: Streets, Satellite, or Outdoors
4. Click any marker to see details
5. Use the legend card for reference

---

### Managing Admin Accounts (Super Admin Only)

**Path:** Sidebar → Admin Accounts

Only visible to Super Admins.

**How to create an admin:**
1. Click **"Create Admin"**
2. Enter display name, email, password (min 8 chars)
3. Click **"Create"**

**How to reset an admin's password:**
1. Click on an admin
2. Click **"Reset Password"**
3. Enter new password
4. Save

**How to delete an admin:**
1. Click on an admin
2. Click **"Delete"**
3. Confirm

---

## 5. Mobile App - Worker Guide

### Your Home Screen

After logging in, you see:

- **Session status card** — Shows if you're currently working or offline
- **Quick action buttons** — Record delivery, Start session, Log visit
- **Target banners** — Your progress toward goals
- **Ministry overview** — Your recent activity

### Starting a Work Session

A work session tracks your time in the field.

**How to start:**
1. From the Home screen, tap **"Start Session"**
2. Select the territory you're working in
3. Your GPS location starts being tracked
4. The timer begins

**How to end:**
1. Tap **"End Session"**
2. Your session is saved with duration and distance

> **Automatic sessions:** If you enter an assigned territory, the app may auto-start a session based on geofence detection.

### Viewing Your Territories

**Path:** Bottom nav → Territory

- **"My Areas" tab**: List of territories assigned to you
- **"Map" tab**: Interactive map showing territory polygons

**How to start work from a territory:**
1. Tap on a territory in the list or map
2. Tap **"Start Work"**
3. You'll be taken to the session tracking screen

**How to log a visit during a session:**
1. While in a session, tap **"Log Visit"**
2. Enter the address
3. Select an outcome:
   - **Contacted** — You spoke with someone
   - **Not Home** — Nobody was home
   - **Interested** — Person showed interest
   - **Do Not Call** — Person asked not to be contacted
   - **Completed** — Visit was successful
4. Add notes (optional)
5. Save

### Recording Donations

**Path:** Bottom nav → Delivery

**How to record a donation:**
1. Tap **"Record Donation"**
2. **Step 1 — Donor Info:** Enter donor name and contact details
3. **Step 2 — Amount & Payment:**
   - Enter amount
   - Select payment method: Cash, Check, Online
   - For online payments, a Stripe payment link can be sent
4. **Step 3 — Review:** Confirm details and submit
5. A digital receipt is generated

**How to record a book sale:**
1. Tap **"Record Book Sale"**
2. Select book type (4 options available)
3. Select language (English/Spanish)
4. Enter quantity and price
5. GPS location is auto-captured
6. Submit and receive a receipt

**How to view your history:**
1. Tap the **"History"** tab
2. Use date filters to narrow results
3. See all your donations and sales

### Filling Surveys

**Path:** Bottom nav → Survey

**How to fill a survey:**
1. Go to **"Available"** tab
2. Tap on a survey
3. Answer each question (types include text, number, date, choice, rating, photo, signature)
4. Some questions may require GPS location (auto-captured)
5. Submit when done

**How to view your responses:**
1. Go to **"My Responses"** tab
2. See all surveys you've completed

### Using Walkie-Talkie

**Path:** Menu → Walkie-Talkie

**How to talk:**
1. Select a channel (your team's channel)
2. **Hold the PTT (Push-To-Talk) button** to record
3. Release to send
4. Your voice message is sent to all team members in real-time

**Other features:**
- See who's online in the channel
- Play back voice messages with waveform visualization
- Send text messages alongside voice
- Reply to specific messages
- Mute yourself if needed
- Send alert messages for urgent communications

### Chatting with Your Team

**Path:** Menu → Chat

**How to start a conversation:**
1. Tap **"New Chat"**
2. Select a team member for direct message
3. Or select your team for group chat

**Features:**
- Real-time messaging with typing indicators
- See who's online
- Edit or delete your messages
- Unread message counter
- Team-wide chat room available

### Viewing Your Schedule

**Path:** Menu → My Schedule

See your assigned work shifts with territory pairings. If your leader has created a schedule, you'll see:
- Date and time of each shift
- Territory assigned to that shift
- Status (upcoming, in progress, completed)

### Viewing Your Targets

**Path:** Menu → Targets

See your personal performance targets:
- **Territory visits** — Number of visits to complete
- **Donations** — Donation amount goal
- **Prayer requests** — Number of prayer requests to collect
- Progress bars show how close you are to each target

### Viewing Your Achievements

**Path:** Menu → Achievements

See your gamification stats:
- **Badges earned** — Bronze, Silver, Gold, Platinum levels
- **XP and level** — Your overall progression
- **Categories** — Territory, Donation, Book Sale, Prayer, Visit, Streak, Session, Team

### Submitting Prayer Requests

**Path:** Menu → Prayer Requests

**How to submit:**
1. Tap **"New Prayer Request"**
2. Enter subject and description
3. Select category
4. Choose urgency level
5. Toggle "Submit anonymously" if desired
6. Submit

### Reading Blog Posts

**Path:** Menu → Blog / News

Browse organization news and articles. Tap any article to read the full content.

---

## 6. Mobile App - Team Leader Guide

As a Team Leader, you have **everything a Worker has**, PLUS these additional features:

### Your Team Leader Dashboard

**Path:** Bottom nav → Dashboard

Shows your team at a glance:
- **Total workers** in your team
- **Active sessions** right now
- **Total deliveries** recorded
- **Territories** assigned to your team
- **Surveys** available
- Quick management tiles for common actions
- Recent activity feed

### Managing Your Team

**Path:** Bottom nav → Team Members

See all your team members with:
- Online/offline status (green dot = online)
- Role (Worker or Leader)
- Last active time

**How to approve a worker:**
1. Go to **Worker Verification** (from dashboard or menu)
2. See pending join requests
3. Tap **"Approve"** to accept or **"Reject"** to decline
4. If rejecting, enter a reason

### Using the Command Center

**Path:** Menu → Command Center

This is your most powerful tool — a real-time map showing everything.

**Three modes:**

| Mode | What It Shows |
|------|--------------|
| **Overview** | All team data at once — workers, territories, stats |
| **Workers** | Focus on worker locations and movements |
| **Territories** | Focus on territory polygons and coverage |

**How to use:**
1. Select a mode from the top tabs
2. Workers appear as colored markers on the map
3. Click a worker to see their details
4. **Follow mode**: Tap "Follow" on a worker to track them in real-time
5. See worker trails (their path) as colored lines
6. View territory polygons with visit markers
7. Get geofence breach alerts (worker left assigned territory)

**Map layers you can toggle:**
- Worker locations
- Territory boundaries
- Worker trails
- Visit markers

### Creating Schedules

**Path:** Menu → Schedule

**How to create a schedule:**
1. Tap **"Create Schedule"**
2. Select a worker
3. Select a territory
4. Set date and time (shift)
5. Save

Workers will see this schedule in their "My Schedule" section.

### Managing Targets

**Path:** Menu → Targets

**How to create a target for your team:**
1. Tap **"Create Target"**
2. Select type: Territory visits, Donations, Prayer requests, or Sessions
3. Set the goal amount/count
4. Choose period: Daily, Weekly, Monthly, or Cumulative
5. Assign to your team or specific workers
6. Save

Workers will see their progress toward these targets in their app.

### Viewing Reports

**Path:** Menu → Reports

Three tabs of analytics:

- **Overview**: Team stats at a glance
- **Worker Performance**: Rankings by deliveries, visits, completion rate
- **Territory Coverage**: How well each territory is being worked

### Viewing Team Prayer Requests

**Path:** Menu → Prayer Requests

As a leader, you can see **all** prayer requests from your team (not just your own). You can:
- View request details
- Update status (pending → scheduled → in_progress → completed)
- See which worker collected each request

---

## 7. Feature Reference

### Territory Allocation Flow (Complete Chain)

This is the most important workflow to understand:

```
Step 1: ADMIN creates a territory
         (Admin Panel → Territories → Create Territory → draw polygon → save)

Step 2: ADMIN allocates territory to a Team Leader
         (Admin Panel → Territories → Search & Allocate → select territory → choose leader → Allocate)

Step 3: TEAM LEADER assigns territory to Workers
         (Mobile App → Command Center or Territory screen → assign to worker)

Step 4: WORKER does field work in the territory
         (Mobile App → Start Session → Log Visits → Record Donations)

Step 5: LEADER monitors progress
         (Mobile App → Command Center → real-time map + worker tracking)
```

> **You cannot skip steps.** If a leader doesn't have a territory allocated by the admin, they cannot assign it to workers.

### Work Session Flow

```
1. Worker taps "Start Session" or auto-starts via geofence
2. GPS tracking begins (every 3 seconds)
3. Worker logs visits (contacted/not home/interested/etc.)
4. Worker records donations
5. Worker taps "End Session"
6. Session data is saved: duration, distance, visits, donations
7. Leader can see all of this in Command Center and Reports
```

### Donation Recording Flow

```
1. Worker taps "Record Donation"
2. Enters donor info (name, contact)
3. Enters amount and payment method
4. If online: Stripe payment link is generated
5. GPS location is auto-captured
6. Receipt is generated
7. Donation appears in admin's Donations report
8. Leader can see it in team reports
```

### Survey Flow

```
1. ADMIN creates survey with questions
2. ADMIN assigns survey to teams/workers
3. WORKER sees survey in "Available" tab
4. WORKER fills out the form (GPS + signature may be required)
5. Response is submitted
6. LEADER and ADMIN can view responses and analytics
```

### Prayer Request Flow

```
1. WORKER collects a prayer request in the field
2. WORKER submits via mobile app (subject, category, urgency, details)
3. ADMIN sees it in Prayer Requests panel
4. LEADER sees it in their team prayer requests
5. ADMIN/LEADER updates status as it progresses
6. If "Home Visit" type: a preacher is assigned and a visit is scheduled
```

### Chat & Walkie-Talkie Flow

```
CHAT:
1. User opens Chat from menu
2. Creates a conversation (direct or team)
3. Messages are sent via REST API
4. Real-time delivery via WebSocket
5. Typing indicators show when someone is typing
6. Read receipts track message delivery

WALKIE-TALKIE:
1. User opens Walkie-Talkie from menu
2. Joins a channel (team channel)
3. Holds PTT button to record audio
4. Audio is uploaded to cloud storage
5. URL is broadcast to all participants via WebSocket
6. Other participants hear the audio in real-time
```

### Real-Time Location Tracking

```
1. Worker starts a session (manual or auto via geofence)
2. App streams GPS every 3 seconds (if moved >8 meters)
3. Location is sent to server: POST /api/geofence/location
4. Server caches location in Redis
5. Leader's Command Center receives WebSocket broadcasts
6. Worker marker moves on leader's map in real-time
7. Worker trail is drawn showing path taken
8. Geofence alerts fire if worker leaves assigned territory
```

---

## 8. Troubleshooting

### "Invalid credentials" when logging in

**Possible causes:**
- Wrong email or password (check for typos)
- Account not verified (check your email for verification link)
- Account not approved by team leader or admin
- SSL certificate issue (rare — contact support)

**What to do:**
1. Double-check your email and password
2. Check your spam folder for verification email
3. Ask your team leader or admin to approve your account
4. Use "Forgot Password" to reset if needed

### App shows "Network error"

**Possible causes:**
- No internet connection
- Server is temporarily down
- SSL certificate expired (admin needs to renew)

**What to do:**
1. Check your internet connection
2. Try again in a few minutes
3. Contact your admin if the problem persists

### GPS not tracking / Location not updating

**Possible causes:**
- Location permissions not granted to the app
- GPS is turned off on your phone
- Battery saver mode is restricting background location

**What to do:**
1. Go to your phone's Settings → Light Point → Location → "Always Allow"
2. Make sure GPS/Location is turned on
3. Disable battery saver for the Light Point app

### Walkie-Talkie not working

**Possible causes:**
- Microphone permission not granted
- No internet connection
- Supabase storage is down (for audio uploads)

**What to do:**
1. Grant microphone permission to the app
2. Check your internet connection
3. Try again — audio uploads may be slow on poor connections

### Can't see territories on the map

**Possible causes:**
- No territories allocated to you (team leader) or your team (worker)
- Map tiles not loading (internet issue)
- Zoom level too low (territories only show at zoom level 10+)

**What to do:**
1. Ask your admin to allocate territories to your leader
2. Ask your leader to assign territories to you
3. Zoom in on the map
4. Check your internet connection

### Admin: "Port 80 in use" error during SSL renewal

This happens when the nginx container is running during certbot renewal. The system has an automated script (`/usr/local/bin/renew-ssl.sh`) that handles this by stopping nginx temporarily. If you see this error, contact your server administrator.

---

*Last updated: July 2026*
