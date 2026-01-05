-- Migration: 015_complete_survey_schema.sql
-- Description: Complete survey schema with all missing tables and columns

-- 1. Add requires_location column to surveys table
ALTER TABLE surveys ADD COLUMN IF NOT EXISTS requires_location BOOLEAN DEFAULT false;

-- 2. Create survey_questions table
CREATE TABLE IF NOT EXISTS survey_questions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    survey_id UUID NOT NULL,
    question_text TEXT NOT NULL,
    question_type VARCHAR(50) NOT NULL,
    placeholder TEXT,
    options JSONB,
    validation JSONB,
    is_required BOOLEAN DEFAULT false,
    order_index INTEGER DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    FOREIGN KEY (survey_id) REFERENCES surveys(id) ON DELETE CASCADE
);

-- 3. Create survey_answers table
CREATE TABLE IF NOT EXISTS survey_answers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    response_id UUID NOT NULL,
    question_id UUID NOT NULL,
    answer TEXT,
    photo_urls JSONB,
    signature_url TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    FOREIGN KEY (response_id) REFERENCES survey_responses(id) ON DELETE CASCADE,
    FOREIGN KEY (question_id) REFERENCES survey_questions(id) ON DELETE CASCADE
);

-- 4. Create indexes for survey_questions
CREATE INDEX IF NOT EXISTS idx_survey_questions_survey_id ON survey_questions(survey_id);
CREATE INDEX IF NOT EXISTS idx_survey_questions_order ON survey_questions(survey_id, order_index);

-- 5. Create indexes for survey_answers
CREATE INDEX IF NOT EXISTS idx_survey_answers_response_id ON survey_answers(response_id);
CREATE INDEX IF NOT EXISTS idx_survey_answers_question_id ON survey_answers(question_id);

-- 6. Make surveys.questions column optional (since we now use survey_questions table)
ALTER TABLE surveys ALTER COLUMN questions DROP NOT NULL;
ALTER TABLE surveys ALTER COLUMN questions SET DEFAULT '[]'::jsonb;
