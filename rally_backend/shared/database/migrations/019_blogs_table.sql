-- Migration: 019_blogs_table.sql
-- Description: Create blogs table for organizational announcements and posts

-- 1. Create blogs table
CREATE TABLE IF NOT EXISTS blogs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    title VARCHAR(500) NOT NULL,
    content TEXT NOT NULL,
    excerpt TEXT,
    image_url TEXT,
    author_id UUID NOT NULL,
    author_name VARCHAR(255),
    is_published BOOLEAN DEFAULT true,
    view_count INTEGER DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    FOREIGN KEY (author_id) REFERENCES users(id) ON DELETE CASCADE
);

-- 2. Create indexes for blogs
CREATE INDEX IF NOT EXISTS idx_blogs_author_id ON blogs(author_id);
CREATE INDEX IF NOT EXISTS idx_blogs_created_at ON blogs(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_blogs_is_published ON blogs(is_published);

-- 3. Create trigger to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_blogs_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS blogs_updated_at_trigger ON blogs;
CREATE TRIGGER blogs_updated_at_trigger
    BEFORE UPDATE ON blogs
    FOR EACH ROW
    EXECUTE FUNCTION update_blogs_updated_at();
