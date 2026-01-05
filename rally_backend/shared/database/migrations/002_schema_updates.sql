-- Rally Point Schema Updates Migration
-- Adds missing columns and tables for delivery service

-- Update user_sessions refresh_token to TEXT for JWT tokens
ALTER TABLE user_sessions ALTER COLUMN refresh_token TYPE TEXT;

-- Make book_title nullable since new design uses delivery_items for item data
ALTER TABLE deliveries ALTER COLUMN book_title DROP NOT NULL;
ALTER TABLE deliveries ALTER COLUMN book_title SET DEFAULT '';

-- Make worker_id nullable for unassigned deliveries
ALTER TABLE deliveries ALTER COLUMN worker_id DROP NOT NULL;

-- Add missing columns to deliveries table
ALTER TABLE deliveries ADD COLUMN IF NOT EXISTS worker_name VARCHAR(255);
ALTER TABLE deliveries ADD COLUMN IF NOT EXISTS recipient_email VARCHAR(255);
ALTER TABLE deliveries ADD COLUMN IF NOT EXISTS latitude DECIMAL(10, 8);
ALTER TABLE deliveries ADD COLUMN IF NOT EXISTS longitude DECIMAL(11, 8);
ALTER TABLE deliveries ADD COLUMN IF NOT EXISTS priority VARCHAR(50) DEFAULT 'normal';
ALTER TABLE deliveries ADD COLUMN IF NOT EXISTS instructions TEXT;
ALTER TABLE deliveries ADD COLUMN IF NOT EXISTS scheduled_date TIMESTAMP WITH TIME ZONE;
ALTER TABLE deliveries ADD COLUMN IF NOT EXISTS assigned_at TIMESTAMP WITH TIME ZONE;
ALTER TABLE deliveries ADD COLUMN IF NOT EXISTS started_at TIMESTAMP WITH TIME ZONE;
ALTER TABLE deliveries ADD COLUMN IF NOT EXISTS completed_at TIMESTAMP WITH TIME ZONE;
ALTER TABLE deliveries ADD COLUMN IF NOT EXISTS estimated_time INTEGER;
ALTER TABLE deliveries ADD COLUMN IF NOT EXISTS actual_time INTEGER;
ALTER TABLE deliveries ADD COLUMN IF NOT EXISTS created_by UUID REFERENCES users(id) ON DELETE SET NULL;

-- Create delivery_items table
CREATE TABLE IF NOT EXISTS delivery_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    delivery_id UUID NOT NULL REFERENCES deliveries(id) ON DELETE CASCADE,
    item_type VARCHAR(100),
    item_name VARCHAR(255) NOT NULL,
    quantity INTEGER DEFAULT 1,
    description TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create delivery_updates table for tracking status changes
CREATE TABLE IF NOT EXISTS delivery_updates (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    delivery_id UUID NOT NULL REFERENCES deliveries(id) ON DELETE CASCADE,
    user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    user_name VARCHAR(255),
    status VARCHAR(50),
    message TEXT,
    latitude DECIMAL(10, 8),
    longitude DECIMAL(11, 8),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create delivery_routes table for route planning
CREATE TABLE IF NOT EXISTS delivery_routes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    team_id UUID NOT NULL REFERENCES teams(id) ON DELETE CASCADE,
    worker_id UUID REFERENCES users(id) ON DELETE SET NULL,
    worker_name VARCHAR(255),
    route_name VARCHAR(255),
    route_date DATE,
    status VARCHAR(50) DEFAULT 'pending',
    total_stops INTEGER DEFAULT 0,
    completed_stops INTEGER DEFAULT 0,
    estimated_time INTEGER,
    actual_time INTEGER,
    started_at TIMESTAMP WITH TIME ZONE,
    completed_at TIMESTAMP WITH TIME ZONE,
    created_by UUID REFERENCES users(id) ON DELETE SET NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create route_stops table for individual stops in a route
CREATE TABLE IF NOT EXISTS route_stops (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    route_id UUID NOT NULL REFERENCES delivery_routes(id) ON DELETE CASCADE,
    delivery_id UUID REFERENCES deliveries(id) ON DELETE SET NULL,
    stop_order INTEGER NOT NULL,
    status VARCHAR(50) DEFAULT 'pending',
    arrived_at TIMESTAMP WITH TIME ZONE,
    completed_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Add indexes for new tables
CREATE INDEX IF NOT EXISTS idx_delivery_items_delivery_id ON delivery_items(delivery_id);
CREATE INDEX IF NOT EXISTS idx_delivery_updates_delivery_id ON delivery_updates(delivery_id);
CREATE INDEX IF NOT EXISTS idx_delivery_routes_team_id ON delivery_routes(team_id);
CREATE INDEX IF NOT EXISTS idx_delivery_routes_worker_id ON delivery_routes(worker_id);
CREATE INDEX IF NOT EXISTS idx_delivery_routes_status ON delivery_routes(status);
CREATE INDEX IF NOT EXISTS idx_route_stops_route_id ON route_stops(route_id);
CREATE INDEX IF NOT EXISTS idx_route_stops_delivery_id ON route_stops(delivery_id);

-- Add trigger for delivery_routes updated_at
DROP TRIGGER IF EXISTS update_delivery_routes_updated_at ON delivery_routes;
CREATE TRIGGER update_delivery_routes_updated_at
    BEFORE UPDATE ON delivery_routes
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
