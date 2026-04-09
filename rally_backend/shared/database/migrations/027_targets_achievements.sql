-- Migration 027: Targets and Achievements System
-- Created: 2026-03-02

-- ============================================
-- TARGET SYSTEM
-- ============================================

-- Target definitions table
CREATE TABLE targets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(255) NOT NULL,
    description TEXT,
    target_type VARCHAR(50) NOT NULL CHECK (target_type IN ('territory', 'donation', 'prayer', 'visit', 'session')),
    target_unit VARCHAR(50) NOT NULL CHECK (target_unit IN ('count', 'amount', 'percentage', 'hours')),
    target_value DECIMAL(10,2) NOT NULL,
    period_type VARCHAR(50) NOT NULL CHECK (period_type IN ('daily', 'weekly', 'monthly', 'cumulative')),
    created_by UUID NOT NULL,
    created_by_role VARCHAR(50) NOT NULL CHECK (created_by_role IN ('superadmin', 'admin', 'team_leader')),
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_targets_created_by ON targets(created_by);
CREATE INDEX idx_targets_type ON targets(target_type);
CREATE INDEX idx_targets_active ON targets(is_active);

-- Target assignments table
CREATE TABLE target_assignments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    target_id UUID NOT NULL REFERENCES targets(id) ON DELETE CASCADE,
    assigned_to_type VARCHAR(50) NOT NULL CHECK (assigned_to_type IN ('team', 'worker')),
    assigned_to_id UUID NOT NULL,
    assigned_by UUID NOT NULL,
    period_start DATE,
    period_end DATE,
    status VARCHAR(50) DEFAULT 'active' CHECK (status IN ('active', 'completed', 'cancelled')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(target_id, assigned_to_type, assigned_to_id, period_start)
);

CREATE INDEX idx_target_assignments_target ON target_assignments(target_id);
CREATE INDEX idx_target_assignments_worker ON target_assignments(assigned_to_id) WHERE assigned_to_type = 'worker';
CREATE INDEX idx_target_assignments_team ON target_assignments(assigned_to_id) WHERE assigned_to_type = 'team';

-- Target progress tracking
CREATE TABLE target_progress (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    assignment_id UUID NOT NULL REFERENCES target_assignments(id) ON DELETE CASCADE,
    current_value DECIMAL(10,2) DEFAULT 0,
    last_updated TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    period_start DATE,
    period_end DATE,
    UNIQUE(assignment_id, period_start)
);

CREATE INDEX idx_target_progress_assignment ON target_progress(assignment_id);

-- ============================================
-- ACHIEVEMENT SYSTEM
-- ============================================

-- Achievement definitions
CREATE TABLE achievements (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    category VARCHAR(50) NOT NULL CHECK (category IN ('territory', 'donation', 'prayer', 'visit', 'streak', 'session', 'team')),
    name VARCHAR(100) NOT NULL,
    description TEXT,
    icon VARCHAR(50),
    level VARCHAR(20) NOT NULL CHECK (level IN ('bronze', 'silver', 'gold', 'platinum')),
    level_order INT NOT NULL DEFAULT 1,
    criteria_type VARCHAR(50) NOT NULL CHECK (criteria_type IN ('count', 'streak', 'percentage', 'amount', 'hours')),
    criteria_value DECIMAL(10,2) NOT NULL,
    points INT DEFAULT 0,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_achievements_category ON achievements(category);
CREATE INDEX idx_achievements_level ON achievements(level);
CREATE INDEX idx_achievements_active ON achievements(is_active);

-- Worker earned achievements
CREATE TABLE worker_achievements (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    worker_id UUID NOT NULL,
    achievement_id UUID NOT NULL REFERENCES achievements(id) ON DELETE CASCADE,
    earned_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    progress DECIMAL(10,2) DEFAULT 0,
    UNIQUE(worker_id, achievement_id)
);

CREATE INDEX idx_worker_achievements_worker ON worker_achievements(worker_id);
CREATE INDEX idx_worker_achievements_achievement ON worker_achievements(achievement_id);

-- Worker levels and points summary
CREATE TABLE worker_levels (
    worker_id UUID PRIMARY KEY,
    total_points INT DEFAULT 0,
    current_level VARCHAR(20) DEFAULT 'bronze' CHECK (current_level IN ('bronze', 'silver', 'gold', 'platinum')),
    level_progress DECIMAL(5,2) DEFAULT 0,
    territory_badges INT DEFAULT 0,
    donation_badges INT DEFAULT 0,
    prayer_badges INT DEFAULT 0,
    visit_badges INT DEFAULT 0,
    streak_badges INT DEFAULT 0,
    session_badges INT DEFAULT 0,
    team_badges INT DEFAULT 0,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ============================================
-- SEED ACHIEVEMENT DEFINITIONS
-- ============================================

INSERT INTO achievements (category, name, description, icon, level, level_order, criteria_type, criteria_value, points) VALUES
-- Territory Achievements
('territory', 'First Steps', 'Complete your first territory', 'map', 'bronze', 1, 'count', 1, 10),
('territory', 'Territory Explorer', 'Complete 5 territories', 'map', 'bronze', 1, 'count', 5, 25),
('territory', 'Territory Hunter', 'Complete 15 territories', 'map', 'silver', 2, 'count', 15, 50),
('territory', 'Territory Titan', 'Complete 30 territories', 'map', 'gold', 3, 'count', 30, 100),
('territory', 'Master Mapper', 'Complete 50 territories', 'map', 'platinum', 4, 'count', 50, 200),

-- Coverage Achievements
('territory', 'Coverage Rookie', 'Cover 50% of a territory', 'percent', 'bronze', 1, 'percentage', 50, 15),
('territory', 'Coverage Expert', 'Cover 80% of a territory', 'percent', 'silver', 2, 'percentage', 80, 40),
('territory', 'Coverage Master', 'Cover 100% of a territory', 'percent', 'gold', 3, 'percentage', 100, 80),

-- Donation Achievements
('donation', 'First Gift', 'Receive your first donation', 'volunteer_activism', 'bronze', 1, 'count', 1, 10),
('donation', 'Fundraiser', 'Receive 5 donations', 'volunteer_activism', 'bronze', 1, 'count', 5, 25),
('donation', 'Money Maker', 'Receive 15 donations', 'volunteer_activism', 'silver', 2, 'count', 15, 50),
('donation', 'Generosity Champion', 'Receive 30 donations', 'volunteer_activism', 'gold', 3, 'count', 30, 100),
('donation', 'Fundraising Legend', 'Receive 50 donations', 'volunteer_activism', 'platinum', 4, 'count', 50, 200),

-- Donation Amount Achievements
('donation', 'Dollar Starter', 'Collect $100 in donations', 'attach_money', 'bronze', 1, 'amount', 100, 20),
('donation', 'Hundred Club', 'Collect $500 in donations', 'attach_money', 'silver', 2, 'amount', 500, 50),
('donation', 'Thousand Maker', 'Collect $1000 in donations', 'attach_money', 'gold', 3, 'amount', 1000, 100),
('donation', 'Five K Club', 'Collect $5000 in donations', 'attach_money', 'platinum', 4, 'amount', 5000, 250),

-- Prayer Achievements
('prayer', 'First Prayer', 'Complete your first prayer request', 'volunteer_activism', 'bronze', 1, 'count', 1, 10),
('prayer', 'Prayer Warrior', 'Complete 10 prayer requests', 'volunteer_activism', 'bronze', 1, 'count', 10, 25),
('prayer', 'Prayer Champion', 'Complete 25 prayer requests', 'volunteer_activism', 'silver', 2, 'count', 25, 50),
('prayer', 'Soul Shepherd', 'Complete 50 prayer requests', 'volunteer_activism', 'gold', 3, 'count', 50, 100),
('prayer', 'Miracle Worker', 'Complete 100 prayer requests', 'volunteer_activism', 'platinum', 4, 'count', 100, 200),

-- Home Visit Achievements
('prayer', 'Home Visitor', 'Complete 5 home visits', 'home', 'bronze', 1, 'count', 5, 20),
('prayer', 'Shepherd of Souls', 'Complete 10 home visits', 'home', 'silver', 2, 'count', 10, 40),
('prayer', 'Family Shepherd', 'Complete 25 home visits', 'home', 'gold', 3, 'count', 25, 80),
('prayer', 'Community Leader', 'Complete 50 home visits', 'home', 'platinum', 4, 'count', 50, 150),

-- Visit Achievements
('visit', 'First Steps', 'Make your first visit', 'directions_walk', 'bronze', 1, 'count', 1, 10),
('visit', 'Road Runner', 'Make 25 visits', 'directions_walk', 'bronze', 1, 'count', 25, 30),
('visit', 'Door Knocker', 'Make 50 visits', 'directions_walk', 'silver', 2, 'count', 50, 60),
('visit', 'Field Master', 'Make 100 visits', 'directions_walk', 'gold', 3, 'count', 100, 120),
('visit', 'Field Legend', 'Make 200 visits', 'directions_walk', 'platinum', 4, 'count', 200, 250),

-- Streak Achievements
('streak', 'Getting Started', 'Work 3 days in a row', 'local_fire_department', 'bronze', 1, 'streak', 3, 20),
('streak', 'On Fire', 'Work 7 days in a row', 'local_fire_department', 'silver', 2, 'streak', 7, 50),
('streak', 'Unstoppable', 'Work 14 days in a row', 'local_fire_department', 'gold', 3, 'streak', 14, 100),
('streak', 'Consistency King', 'Work 30 days in a row', 'local_fire_department', 'platinum', 4, 'streak', 30, 200),

-- Total Days Worked Achievements
('streak', 'Dedicated Worker', 'Work 10 days total', 'calendar_today', 'bronze', 1, 'count', 10, 25),
('streak', 'Faithful Servant', 'Work 25 days total', 'calendar_today', 'silver', 2, 'count', 25, 60),
('streak', 'Committed Missionary', 'Work 50 days total', 'calendar_today', 'gold', 3, 'count', 50, 120),
('streak', 'Lifelong Servant', 'Work 100 days total', 'calendar_today', 'platinum', 4, 'count', 100, 250),

-- Session Hours Achievements
('session', 'Time Keeper', 'Log 10 hours of session time', 'timer', 'bronze', 1, 'hours', 10, 20),
('session', 'Hour Master', 'Log 25 hours of session time', 'timer', 'silver', 2, 'hours', 25, 50),
('session', 'Time Champion', 'Log 50 hours of session time', 'timer', 'gold', 3, 'hours', 50, 100),
('session', 'Time Legend', 'Log 100 hours of session time', 'timer', 'platinum', 4, 'hours', 100, 200),

-- Team Achievements
('team', 'Team Player', 'Successfully refer 1 worker', 'groups', 'bronze', 1, 'count', 1, 30),
('team', 'Recruiter', 'Successfully refer 3 workers', 'groups', 'silver', 2, 'count', 3, 75),
('team', 'Team Builder', 'Successfully refer 5 workers', 'groups', 'gold', 3, 'count', 5, 150),
('team', 'Empire Builder', 'Successfully refer 10 workers', 'groups', 'platinum', 4, 'count', 10, 300);

-- Create function to calculate worker level based on points
CREATE OR REPLACE FUNCTION calculate_worker_level(total_points INT)
RETURNS VARCHAR(20) AS $$
BEGIN
    CASE
        WHEN total_points >= 1000 THEN RETURN 'platinum';
        WHEN total_points >= 500 THEN RETURN 'gold';
        WHEN total_points >= 200 THEN RETURN 'silver';
        ELSE RETURN 'bronze';
    END CASE;
END;
$$ LANGUAGE plpgsql;

-- Create function to calculate level progress percentage
CREATE OR REPLACE FUNCTION calculate_level_progress(total_points INT, current_level VARCHAR(20))
RETURNS DECIMAL(5,2) AS $$
DECLARE
    min_points INT;
    max_points INT;
    progress DECIMAL(5,2);
BEGIN
    CASE current_level
        WHEN 'bronze' THEN
            min_points := 0;
            max_points := 200;
        WHEN 'silver' THEN
            min_points := 200;
            max_points := 500;
        WHEN 'gold' THEN
            min_points := 500;
            max_points := 1000;
        WHEN 'platinum' THEN
            min_points := 1000;
            max_points := 2000;
        ELSE
            RETURN 0;
    END CASE;
    
    progress := (total_points - min_points)::DECIMAL / (max_points - min_points) * 100;
    RETURN LEAST(GREATEST(progress, 0), 100);
END;
$$ LANGUAGE plpgsql;
