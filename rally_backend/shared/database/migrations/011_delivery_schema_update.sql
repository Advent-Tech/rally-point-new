-- Migration: 011_delivery_schema_update.sql
-- Description: Update deliveries table to match new simplified schema
-- This adds missing columns for the simplified delivery types, donation support, and offline sync

-- Add missing columns to deliveries table

-- Worker info
ALTER TABLE deliveries ADD COLUMN IF NOT EXISTS worker_name VARCHAR(255);

-- Recipient email
ALTER TABLE deliveries ADD COLUMN IF NOT EXISTS recipient_email VARCHAR(255);

-- Separate lat/long columns (in addition to PostGIS location column)
ALTER TABLE deliveries ADD COLUMN IF NOT EXISTS latitude DOUBLE PRECISION;
ALTER TABLE deliveries ADD COLUMN IF NOT EXISTS longitude DOUBLE PRECISION;

-- Priority
ALTER TABLE deliveries ADD COLUMN IF NOT EXISTS priority VARCHAR(50) DEFAULT 'medium';

-- Scheduling
ALTER TABLE deliveries ADD COLUMN IF NOT EXISTS scheduled_date TIMESTAMP WITH TIME ZONE;
ALTER TABLE deliveries ADD COLUMN IF NOT EXISTS completed_at TIMESTAMP WITH TIME ZONE;

-- Payment/Donation fields
ALTER TABLE deliveries ADD COLUMN IF NOT EXISTS payment_method VARCHAR(50);
ALTER TABLE deliveries ADD COLUMN IF NOT EXISTS payment_status VARCHAR(50);
ALTER TABLE deliveries ADD COLUMN IF NOT EXISTS stripe_payment_id VARCHAR(255);
ALTER TABLE deliveries ADD COLUMN IF NOT EXISTS receipt_number VARCHAR(100);
ALTER TABLE deliveries ADD COLUMN IF NOT EXISTS receipt_url TEXT;

-- Offline sync support
ALTER TABLE deliveries ADD COLUMN IF NOT EXISTS is_offline BOOLEAN DEFAULT FALSE;
ALTER TABLE deliveries ADD COLUMN IF NOT EXISTS synced_at TIMESTAMP WITH TIME ZONE;
ALTER TABLE deliveries ADD COLUMN IF NOT EXISTS offline_id VARCHAR(255);

-- Creator tracking
ALTER TABLE deliveries ADD COLUMN IF NOT EXISTS created_by UUID;

-- Make book_title optional (not needed for donations, and items table is used for literature)
ALTER TABLE deliveries ALTER COLUMN book_title DROP NOT NULL;

-- Indexes for new columns
CREATE INDEX IF NOT EXISTS idx_deliveries_priority ON deliveries(priority);
CREATE INDEX IF NOT EXISTS idx_deliveries_completed_at ON deliveries(completed_at);
CREATE INDEX IF NOT EXISTS idx_deliveries_payment_status ON deliveries(payment_status);
CREATE INDEX IF NOT EXISTS idx_deliveries_offline_id ON deliveries(offline_id);
CREATE INDEX IF NOT EXISTS idx_deliveries_is_offline ON deliveries(is_offline);
CREATE INDEX IF NOT EXISTS idx_deliveries_created_by ON deliveries(created_by);
CREATE INDEX IF NOT EXISTS idx_deliveries_scheduled_date ON deliveries(scheduled_date);

-- Create delivery_items table if not exists
CREATE TABLE IF NOT EXISTS delivery_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    delivery_id UUID NOT NULL REFERENCES deliveries(id) ON DELETE CASCADE,
    item_type VARCHAR(50) NOT NULL DEFAULT 'book', -- book, magazine, tract, brochure, other
    item_name VARCHAR(255) NOT NULL,
    quantity INTEGER NOT NULL DEFAULT 1,
    description TEXT,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_delivery_items_delivery_id ON delivery_items(delivery_id);

-- Create delivery_updates table for status history
CREATE TABLE IF NOT EXISTS delivery_updates (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    delivery_id UUID NOT NULL REFERENCES deliveries(id) ON DELETE CASCADE,
    user_id UUID NOT NULL,
    user_name VARCHAR(255) NOT NULL,
    status VARCHAR(50) NOT NULL,
    message TEXT,
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_delivery_updates_delivery_id ON delivery_updates(delivery_id);
CREATE INDEX IF NOT EXISTS idx_delivery_updates_user_id ON delivery_updates(user_id);
CREATE INDEX IF NOT EXISTS idx_delivery_updates_created_at ON delivery_updates(created_at);

-- Create delivery_routes table
CREATE TABLE IF NOT EXISTS delivery_routes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    team_id UUID NOT NULL REFERENCES teams(id) ON DELETE CASCADE,
    worker_id UUID NOT NULL,
    worker_name VARCHAR(255) NOT NULL,
    route_name VARCHAR(255) NOT NULL,
    route_date DATE NOT NULL,
    status VARCHAR(50) NOT NULL DEFAULT 'planned', -- planned, active, completed, cancelled
    total_stops INTEGER DEFAULT 0,
    completed_stops INTEGER DEFAULT 0,
    estimated_time INTEGER, -- minutes
    actual_time INTEGER, -- minutes
    started_at TIMESTAMP WITH TIME ZONE,
    completed_at TIMESTAMP WITH TIME ZONE,
    created_by UUID NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_delivery_routes_team_id ON delivery_routes(team_id);
CREATE INDEX IF NOT EXISTS idx_delivery_routes_worker_id ON delivery_routes(worker_id);
CREATE INDEX IF NOT EXISTS idx_delivery_routes_status ON delivery_routes(status);
CREATE INDEX IF NOT EXISTS idx_delivery_routes_route_date ON delivery_routes(route_date);

-- Create route_stops table
CREATE TABLE IF NOT EXISTS route_stops (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    route_id UUID NOT NULL REFERENCES delivery_routes(id) ON DELETE CASCADE,
    delivery_id UUID NOT NULL REFERENCES deliveries(id) ON DELETE CASCADE,
    stop_order INTEGER NOT NULL,
    status VARCHAR(50) NOT NULL DEFAULT 'pending', -- pending, completed, skipped
    arrived_at TIMESTAMP WITH TIME ZONE,
    completed_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_route_stops_route_id ON route_stops(route_id);
CREATE INDEX IF NOT EXISTS idx_route_stops_delivery_id ON route_stops(delivery_id);
CREATE INDEX IF NOT EXISTS idx_route_stops_status ON route_stops(status);

-- Update triggers
CREATE OR REPLACE FUNCTION update_delivery_routes_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_delivery_routes_updated_at ON delivery_routes;
CREATE TRIGGER trigger_delivery_routes_updated_at
    BEFORE UPDATE ON delivery_routes
    FOR EACH ROW
    EXECUTE FUNCTION update_delivery_routes_updated_at();

-- Comments
COMMENT ON COLUMN deliveries.priority IS 'Priority level: low, medium, high, urgent';
COMMENT ON COLUMN deliveries.payment_method IS 'Payment method for donations: cash, card, online';
COMMENT ON COLUMN deliveries.payment_status IS 'Payment status: pending, completed, failed, refunded';
COMMENT ON COLUMN deliveries.is_offline IS 'Whether this was created offline and synced later';
COMMENT ON COLUMN deliveries.offline_id IS 'Client-generated ID for offline records';
COMMENT ON TABLE delivery_items IS 'Items in a delivery (literature, books, etc)';
COMMENT ON TABLE delivery_updates IS 'Status update history for deliveries';
COMMENT ON TABLE delivery_routes IS 'Optimized delivery routes for workers';
COMMENT ON TABLE route_stops IS 'Stops in a delivery route';
