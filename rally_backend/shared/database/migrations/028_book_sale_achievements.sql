-- Migration 028: Add dedicated book_sale achievements
-- Created: 2026-04-02

-- 1) Expand achievements category check to include book_sale
DO $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM information_schema.table_constraints
        WHERE constraint_name = 'achievements_category_check'
          AND table_name = 'achievements'
    ) THEN
        ALTER TABLE achievements DROP CONSTRAINT achievements_category_check;
    END IF;
END $$;

ALTER TABLE achievements
    ADD CONSTRAINT achievements_category_check
    CHECK (category IN ('territory', 'donation', 'book_sale', 'prayer', 'visit', 'streak', 'session', 'team'));

-- 2) Add book_sale badge counter to worker_levels
ALTER TABLE worker_levels
    ADD COLUMN IF NOT EXISTS book_sale_badges INT DEFAULT 0;

-- 3) Seed dedicated book_sale achievement ladder (count + amount)
INSERT INTO achievements (category, name, description, icon, level, level_order, criteria_type, criteria_value, points, is_active, created_at)
SELECT * FROM (
    VALUES
      ('book_sale', 'First Book Sold', 'Record your first book sale', 'menu_book', 'bronze', 1, 'count', 1, 12, true, NOW()),
      ('book_sale', 'Book Seller', 'Record 5 book sales', 'menu_book', 'bronze', 1, 'count', 5, 28, true, NOW()),
      ('book_sale', 'Book Champion', 'Record 15 book sales', 'menu_book', 'silver', 2, 'count', 15, 60, true, NOW()),
      ('book_sale', 'Book Master', 'Record 30 book sales', 'menu_book', 'gold', 3, 'count', 30, 120, true, NOW()),
      ('book_sale', 'Book Legend', 'Record 60 book sales', 'menu_book', 'platinum', 4, 'count', 60, 240, true, NOW()),
      ('book_sale', 'Starter Seller', 'Collect $50 from book sales', 'attach_money', 'bronze', 1, 'amount', 50, 18, true, NOW()),
      ('book_sale', 'Book Revenue Builder', 'Collect $250 from book sales', 'attach_money', 'silver', 2, 'amount', 250, 45, true, NOW()),
      ('book_sale', 'Book Revenue Pro', 'Collect $750 from book sales', 'attach_money', 'gold', 3, 'amount', 750, 95, true, NOW()),
      ('book_sale', 'Book Revenue Elite', 'Collect $2000 from book sales', 'attach_money', 'platinum', 4, 'amount', 2000, 200, true, NOW())
) AS seed(category, name, description, icon, level, level_order, criteria_type, criteria_value, points, is_active, created_at)
WHERE NOT EXISTS (
    SELECT 1 FROM achievements a
    WHERE a.category = seed.category
      AND a.name = seed.name
);

-- 4) Backfill earned book_sale achievements from historical completed book-sale deliveries
WITH worker_book_sales AS (
    SELECT
        worker_id,
        COUNT(*)::numeric AS sales_count,
        COALESCE(SUM(COALESCE(donation_amount, 0)), 0)::numeric AS sales_amount
    FROM deliveries
    WHERE status = 'completed'
      AND delivery_type = 'book_sale'
      AND COALESCE(donation_amount, 0) > 0
    GROUP BY worker_id
),
eligible AS (
    SELECT
        w.worker_id,
        a.id AS achievement_id,
        a.points
    FROM worker_book_sales w
    JOIN achievements a
      ON a.category = 'book_sale'
     AND a.is_active = true
     AND (
          (a.criteria_type = 'count' AND w.sales_count >= a.criteria_value)
       OR (a.criteria_type = 'amount' AND w.sales_amount >= a.criteria_value)
     )
),
inserted AS (
    INSERT INTO worker_achievements (id, worker_id, achievement_id, earned_at, progress)
    SELECT gen_random_uuid(), e.worker_id, e.achievement_id, NOW(), 1.0
    FROM eligible e
    WHERE NOT EXISTS (
        SELECT 1
        FROM worker_achievements wa
        WHERE wa.worker_id = e.worker_id
          AND wa.achievement_id = e.achievement_id
    )
    RETURNING worker_id, achievement_id
),
point_delta AS (
    SELECT i.worker_id, COALESCE(SUM(a.points), 0)::int AS points_to_add
    FROM inserted i
    JOIN achievements a ON a.id = i.achievement_id
    GROUP BY i.worker_id
),
ensure_levels AS (
    INSERT INTO worker_levels (
        worker_id,
        total_points,
        current_level,
        level_progress,
        territory_badges,
        donation_badges,
        book_sale_badges,
        prayer_badges,
        visit_badges,
        streak_badges,
        session_badges,
        team_badges,
        updated_at
    )
    SELECT
        p.worker_id, 0, 'bronze', 0, 0, 0, 0, 0, 0, 0, 0, 0, NOW()
    FROM point_delta p
    ON CONFLICT (worker_id) DO NOTHING
    RETURNING worker_id
),
updated_points AS (
    UPDATE worker_levels wl
    SET total_points = wl.total_points + p.points_to_add,
        current_level = CASE
            WHEN wl.total_points + p.points_to_add >= 1000 THEN 'platinum'
            WHEN wl.total_points + p.points_to_add >= 500 THEN 'gold'
            WHEN wl.total_points + p.points_to_add >= 200 THEN 'silver'
            ELSE 'bronze'
        END,
        level_progress = CASE
            WHEN wl.total_points + p.points_to_add >= 1000 THEN ((wl.total_points + p.points_to_add - 1000)::float / 1000) * 100
            WHEN wl.total_points + p.points_to_add >= 500 THEN ((wl.total_points + p.points_to_add - 500)::float / 500) * 100
            WHEN wl.total_points + p.points_to_add >= 200 THEN ((wl.total_points + p.points_to_add - 200)::float / 300) * 100
            ELSE ((wl.total_points + p.points_to_add)::float / 200) * 100
        END,
        updated_at = NOW()
    FROM point_delta p
    WHERE wl.worker_id = p.worker_id
    RETURNING wl.worker_id
)
UPDATE worker_levels wl
SET book_sale_badges = badge_counts.badge_count,
    updated_at = NOW()
FROM (
    SELECT wa.worker_id, COUNT(*)::int AS badge_count
    FROM worker_achievements wa
    JOIN achievements a ON a.id = wa.achievement_id
    WHERE a.category = 'book_sale'
    GROUP BY wa.worker_id
) badge_counts
WHERE wl.worker_id = badge_counts.worker_id;
