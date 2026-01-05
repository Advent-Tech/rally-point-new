-- Migration: 008_receipts_donations.sql
-- Description: Create tables for receipts and donations tracking

-- Receipts table for book sales and literature distribution
CREATE TABLE IF NOT EXISTS receipts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    delivery_id UUID REFERENCES deliveries(id) ON DELETE SET NULL,
    session_id UUID REFERENCES territory_work_sessions(id) ON DELETE SET NULL,
    worker_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    worker_name VARCHAR(255) NOT NULL,
    team_id UUID NOT NULL REFERENCES teams(id) ON DELETE CASCADE,
    recipient_name VARCHAR(255) NOT NULL,
    recipient_phone VARCHAR(50),
    recipient_email VARCHAR(255),
    address TEXT,
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    receipt_type VARCHAR(50) NOT NULL DEFAULT 'book_sale', -- book_sale, literature, donation
    total_amount DECIMAL(12, 2) NOT NULL DEFAULT 0,
    currency VARCHAR(10) NOT NULL DEFAULT 'BDT',
    payment_method VARCHAR(50) NOT NULL DEFAULT 'cash', -- cash, mobile, card
    payment_ref VARCHAR(255),
    notes TEXT,
    receipt_number VARCHAR(50) NOT NULL UNIQUE,
    status VARCHAR(50) NOT NULL DEFAULT 'completed', -- pending, completed, cancelled, refunded
    issued_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

-- Receipt items table
CREATE TABLE IF NOT EXISTS receipt_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    receipt_id UUID NOT NULL REFERENCES receipts(id) ON DELETE CASCADE,
    item_type VARCHAR(50) NOT NULL DEFAULT 'book', -- book, magazine, tract, brochure, other
    item_name VARCHAR(255) NOT NULL,
    item_code VARCHAR(100),
    quantity INTEGER NOT NULL DEFAULT 1,
    unit_price DECIMAL(10, 2) NOT NULL DEFAULT 0,
    total_price DECIMAL(10, 2) NOT NULL DEFAULT 0,
    description TEXT,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

-- Donations table
CREATE TABLE IF NOT EXISTS donations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id UUID REFERENCES territory_work_sessions(id) ON DELETE SET NULL,
    worker_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    worker_name VARCHAR(255) NOT NULL,
    team_id UUID NOT NULL REFERENCES teams(id) ON DELETE CASCADE,
    donor_name VARCHAR(255) NOT NULL,
    donor_phone VARCHAR(50),
    donor_email VARCHAR(255),
    donor_address TEXT,
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    amount DECIMAL(12, 2) NOT NULL,
    currency VARCHAR(10) NOT NULL DEFAULT 'BDT',
    donation_type VARCHAR(50) NOT NULL DEFAULT 'one_time', -- one_time, recurring, pledge
    purpose VARCHAR(255),
    payment_method VARCHAR(50) NOT NULL DEFAULT 'cash', -- cash, mobile, card, check
    payment_ref VARCHAR(255),
    receipt_number VARCHAR(50) NOT NULL UNIQUE,
    is_anonymous BOOLEAN NOT NULL DEFAULT FALSE,
    notes TEXT,
    status VARCHAR(50) NOT NULL DEFAULT 'received', -- received, deposited, cancelled
    collected_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    deposited_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

-- Indexes for receipts
CREATE INDEX IF NOT EXISTS idx_receipts_worker_id ON receipts(worker_id);
CREATE INDEX IF NOT EXISTS idx_receipts_team_id ON receipts(team_id);
CREATE INDEX IF NOT EXISTS idx_receipts_session_id ON receipts(session_id);
CREATE INDEX IF NOT EXISTS idx_receipts_delivery_id ON receipts(delivery_id);
CREATE INDEX IF NOT EXISTS idx_receipts_receipt_number ON receipts(receipt_number);
CREATE INDEX IF NOT EXISTS idx_receipts_status ON receipts(status);
CREATE INDEX IF NOT EXISTS idx_receipts_receipt_type ON receipts(receipt_type);
CREATE INDEX IF NOT EXISTS idx_receipts_issued_at ON receipts(issued_at);
CREATE INDEX IF NOT EXISTS idx_receipts_created_at ON receipts(created_at);
CREATE INDEX IF NOT EXISTS idx_receipts_location ON receipts USING GIST (
    ST_SetSRID(ST_MakePoint(longitude, latitude), 4326)
) WHERE latitude IS NOT NULL AND longitude IS NOT NULL;

-- Indexes for receipt items
CREATE INDEX IF NOT EXISTS idx_receipt_items_receipt_id ON receipt_items(receipt_id);
CREATE INDEX IF NOT EXISTS idx_receipt_items_item_type ON receipt_items(item_type);

-- Indexes for donations
CREATE INDEX IF NOT EXISTS idx_donations_worker_id ON donations(worker_id);
CREATE INDEX IF NOT EXISTS idx_donations_team_id ON donations(team_id);
CREATE INDEX IF NOT EXISTS idx_donations_session_id ON donations(session_id);
CREATE INDEX IF NOT EXISTS idx_donations_receipt_number ON donations(receipt_number);
CREATE INDEX IF NOT EXISTS idx_donations_status ON donations(status);
CREATE INDEX IF NOT EXISTS idx_donations_donation_type ON donations(donation_type);
CREATE INDEX IF NOT EXISTS idx_donations_collected_at ON donations(collected_at);
CREATE INDEX IF NOT EXISTS idx_donations_created_at ON donations(created_at);
CREATE INDEX IF NOT EXISTS idx_donations_is_anonymous ON donations(is_anonymous);
CREATE INDEX IF NOT EXISTS idx_donations_location ON donations USING GIST (
    ST_SetSRID(ST_MakePoint(longitude, latitude), 4326)
) WHERE latitude IS NOT NULL AND longitude IS NOT NULL;

-- Sequences for receipt numbers
CREATE SEQUENCE IF NOT EXISTS receipt_number_seq START WITH 1000;
CREATE SEQUENCE IF NOT EXISTS donation_receipt_number_seq START WITH 1000;

-- Updated at trigger for receipts
CREATE OR REPLACE FUNCTION update_receipts_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_receipts_updated_at
    BEFORE UPDATE ON receipts
    FOR EACH ROW
    EXECUTE FUNCTION update_receipts_updated_at();

-- Updated at trigger for donations
CREATE OR REPLACE FUNCTION update_donations_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_donations_updated_at
    BEFORE UPDATE ON donations
    FOR EACH ROW
    EXECUTE FUNCTION update_donations_updated_at();

-- Comments
COMMENT ON TABLE receipts IS 'Digital receipts for book sales and literature distribution';
COMMENT ON TABLE receipt_items IS 'Individual items in a receipt';
COMMENT ON TABLE donations IS 'Donation collection records';
COMMENT ON COLUMN receipts.receipt_type IS 'Type of receipt: book_sale, literature, or donation';
COMMENT ON COLUMN donations.donation_type IS 'Type of donation: one_time, recurring, or pledge';
COMMENT ON COLUMN donations.is_anonymous IS 'Whether the donor wishes to remain anonymous';
