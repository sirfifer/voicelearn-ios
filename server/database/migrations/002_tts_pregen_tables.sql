-- ============================================================================
-- TTS Pre-Generation Tables Migration
-- ============================================================================
--
-- This migration adds tables for:
-- - TTS Profiles (reusable voice configurations)
-- - TTS Pre-Generation Jobs (batch audio generation)
-- - TTS Comparison Sessions (A/B testing voices)
--
-- Apply with: psql $DATABASE_URL < migrations/002_tts_pregen_tables.sql
--
-- ============================================================================

-- Ensure required extension is available for uuid_generate_v4()
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================================================
-- TTS PROFILES (Reusable voice configurations)
-- ============================================================================

CREATE TABLE IF NOT EXISTS tts_profiles (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(255) NOT NULL UNIQUE,
    description TEXT,

    -- Provider and settings
    provider VARCHAR(50) NOT NULL,  -- 'chatterbox', 'vibevoice', 'piper', etc.
    voice_id VARCHAR(100) NOT NULL,
    settings JSONB NOT NULL DEFAULT '{}',  -- Provider-specific: {speed, exaggeration, cfg_weight, language, ...}

    -- Categorization
    tags TEXT[] DEFAULT '{}',  -- e.g., ['tutor', 'expressive', 'knowledge-bowl']
    use_case VARCHAR(100),  -- 'tutoring', 'questions', 'explanations', etc.

    -- Status
    is_active BOOLEAN DEFAULT true,
    is_default BOOLEAN DEFAULT false,  -- Default profile for the system

    -- Audit
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    created_from_session_id UUID,  -- Link to comparison session that created it

    -- Sample audio for preview
    sample_audio_path VARCHAR(500),
    sample_text TEXT
);

CREATE INDEX IF NOT EXISTS idx_tts_profiles_provider ON tts_profiles(provider);
CREATE INDEX IF NOT EXISTS idx_tts_profiles_tags ON tts_profiles USING GIN(tags);
CREATE INDEX IF NOT EXISTS idx_tts_profiles_active ON tts_profiles(is_active) WHERE is_active = true;

COMMENT ON TABLE tts_profiles IS 'Reusable TTS voice configurations with provider settings';
COMMENT ON COLUMN tts_profiles.settings IS 'Provider-specific settings like speed, exaggeration, cfg_weight';
COMMENT ON COLUMN tts_profiles.tags IS 'Categorization tags for filtering (e.g., tutor, knowledge-bowl)';

-- Module-to-profile associations
CREATE TABLE IF NOT EXISTS tts_module_profiles (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    module_id VARCHAR(100) NOT NULL,  -- e.g., 'knowledge-bowl', curriculum UUID
    profile_id UUID NOT NULL REFERENCES tts_profiles(id) ON DELETE CASCADE,
    context VARCHAR(100),  -- 'questions', 'explanations', 'hints', or NULL for all
    priority INTEGER DEFAULT 0,  -- Higher = preferred when multiple match
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(module_id, profile_id, context)
);

CREATE INDEX IF NOT EXISTS idx_tts_module_profiles_module ON tts_module_profiles(module_id);

COMMENT ON TABLE tts_module_profiles IS 'Associates TTS profiles with modules for default voice selection';

-- ============================================================================
-- TTS PRE-GENERATION JOBS
-- ============================================================================

CREATE TABLE IF NOT EXISTS tts_pregen_jobs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(255) NOT NULL,
    job_type VARCHAR(20) NOT NULL CHECK (job_type IN ('batch', 'comparison')),
    status VARCHAR(20) NOT NULL DEFAULT 'pending'
        CHECK (status IN ('pending', 'running', 'paused', 'completed', 'failed', 'cancelled')),

    -- Source specification
    source_type VARCHAR(50) NOT NULL,  -- 'curriculum', 'knowledge-bowl', 'custom'
    source_id VARCHAR(255),

    -- TTS configuration: Either reference a profile OR provide inline config
    profile_id UUID REFERENCES tts_profiles(id) ON DELETE SET NULL,
    tts_config JSONB,  -- Inline config if no profile; {provider, voice_id, speed, ...}
    -- Constraint: At least one must be set
    CONSTRAINT tts_config_required CHECK (profile_id IS NOT NULL OR tts_config IS NOT NULL),

    -- Output settings
    output_format VARCHAR(10) DEFAULT 'wav',
    normalize_volume BOOLEAN DEFAULT false,
    output_dir VARCHAR(500) NOT NULL,

    -- Progress
    total_items INTEGER DEFAULT 0,
    completed_items INTEGER DEFAULT 0,
    failed_items INTEGER DEFAULT 0,
    current_item_index INTEGER DEFAULT 0,
    current_item_text TEXT,

    -- Timing
    created_at TIMESTAMPTZ DEFAULT NOW(),
    started_at TIMESTAMPTZ,
    paused_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ DEFAULT NOW(),

    -- Error tracking
    last_error TEXT,
    consecutive_failures INTEGER DEFAULT 0
);

CREATE INDEX IF NOT EXISTS idx_tts_pregen_jobs_status ON tts_pregen_jobs(status);
CREATE INDEX IF NOT EXISTS idx_tts_pregen_jobs_created ON tts_pregen_jobs(created_at DESC);

COMMENT ON TABLE tts_pregen_jobs IS 'Batch TTS generation jobs with progress tracking and resume support';

-- Individual items within a job
CREATE TABLE IF NOT EXISTS tts_pregen_job_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    job_id UUID NOT NULL REFERENCES tts_pregen_jobs(id) ON DELETE CASCADE,
    item_index INTEGER NOT NULL,

    text_content TEXT NOT NULL,
    text_hash VARCHAR(64) NOT NULL,  -- SHA-256 for dedup
    source_ref VARCHAR(255),  -- question_id, segment_id, etc.

    status VARCHAR(20) NOT NULL DEFAULT 'pending'
        CHECK (status IN ('pending', 'processing', 'completed', 'failed', 'skipped')),
    attempt_count INTEGER DEFAULT 0,

    -- Result
    output_file VARCHAR(500),
    duration_seconds REAL,
    file_size_bytes BIGINT,
    sample_rate INTEGER,

    last_error TEXT,
    processing_started_at TIMESTAMPTZ,
    processing_completed_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_tts_pregen_items_job ON tts_pregen_job_items(job_id);
CREATE INDEX IF NOT EXISTS idx_tts_pregen_items_status ON tts_pregen_job_items(job_id, status);
CREATE INDEX IF NOT EXISTS idx_tts_pregen_items_order ON tts_pregen_job_items(job_id, item_index);

COMMENT ON TABLE tts_pregen_job_items IS 'Individual items within a TTS generation job';

-- ============================================================================
-- TTS COMPARISON SESSIONS (A/B Testing)
-- ============================================================================

CREATE TABLE IF NOT EXISTS tts_comparison_sessions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(255) NOT NULL,
    description TEXT,
    status VARCHAR(20) NOT NULL DEFAULT 'draft'
        CHECK (status IN ('draft', 'generating', 'ready', 'archived')),
    config JSONB NOT NULL,  -- {samples: [...], configurations: [...]}
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_tts_comparison_sessions_status ON tts_comparison_sessions(status);

COMMENT ON TABLE tts_comparison_sessions IS 'A/B testing sessions for comparing TTS configurations';

-- Audio variants for comparison
CREATE TABLE IF NOT EXISTS tts_comparison_variants (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    session_id UUID NOT NULL REFERENCES tts_comparison_sessions(id) ON DELETE CASCADE,
    sample_index INTEGER NOT NULL,
    config_index INTEGER NOT NULL,

    text_content TEXT NOT NULL,
    tts_config JSONB NOT NULL,

    status VARCHAR(20) NOT NULL DEFAULT 'pending'
        CHECK (status IN ('pending', 'generating', 'ready', 'failed')),

    output_file VARCHAR(500),
    duration_seconds REAL,
    last_error TEXT
);

CREATE INDEX IF NOT EXISTS idx_tts_comparison_variants_session ON tts_comparison_variants(session_id);
CREATE INDEX IF NOT EXISTS idx_tts_comparison_variants_status ON tts_comparison_variants(session_id, status);

COMMENT ON TABLE tts_comparison_variants IS 'Individual audio variants for comparison (sample x config matrix)';

-- Ratings for variants
CREATE TABLE IF NOT EXISTS tts_comparison_ratings (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    variant_id UUID NOT NULL REFERENCES tts_comparison_variants(id) ON DELETE CASCADE,
    rating INTEGER CHECK (rating >= 1 AND rating <= 5),
    notes TEXT,
    rated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_tts_comparison_ratings_variant ON tts_comparison_ratings(variant_id);

COMMENT ON TABLE tts_comparison_ratings IS 'User ratings and notes for comparison variants';

-- ============================================================================
-- Add foreign key for created_from_session_id after tts_comparison_sessions exists
-- ============================================================================

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints
        WHERE constraint_name = 'tts_profiles_created_from_session_fk'
    ) THEN
        ALTER TABLE tts_profiles
        ADD CONSTRAINT tts_profiles_created_from_session_fk
        FOREIGN KEY (created_from_session_id)
        REFERENCES tts_comparison_sessions(id) ON DELETE SET NULL;
    END IF;
END $$;

-- ============================================================================
-- Helpful Views
-- ============================================================================

CREATE OR REPLACE VIEW tts_profile_summaries AS
SELECT
    p.id,
    p.name,
    p.provider,
    p.voice_id,
    p.tags,
    p.use_case,
    p.is_active,
    p.is_default,
    p.created_at,
    p.updated_at,
    (SELECT COUNT(*) FROM tts_module_profiles mp WHERE mp.profile_id = p.id) as module_count,
    (SELECT COUNT(*) FROM tts_pregen_jobs j WHERE j.profile_id = p.id) as job_count
FROM tts_profiles p;

CREATE OR REPLACE VIEW tts_job_summaries AS
SELECT
    j.id,
    j.name,
    j.job_type,
    j.status,
    j.source_type,
    j.profile_id,
    p.name as profile_name,
    j.total_items,
    j.completed_items,
    j.failed_items,
    CASE WHEN j.total_items > 0
         THEN ROUND((j.completed_items::numeric / j.total_items) * 100, 1)
         ELSE 0
    END as percent_complete,
    j.created_at,
    j.started_at,
    j.completed_at
FROM tts_pregen_jobs j
LEFT JOIN tts_profiles p ON j.profile_id = p.id;

COMMENT ON VIEW tts_profile_summaries IS 'Profile list with usage counts';
COMMENT ON VIEW tts_job_summaries IS 'Job list with progress percentages';

-- ============================================================================
-- Trigger function for automatic updated_at
-- ============================================================================

CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Apply updated_at triggers to tables with updated_at columns
CREATE TRIGGER update_tts_profiles_updated_at
    BEFORE UPDATE ON tts_profiles
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_tts_pregen_jobs_updated_at
    BEFORE UPDATE ON tts_pregen_jobs
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_tts_comparison_sessions_updated_at
    BEFORE UPDATE ON tts_comparison_sessions
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ============================================================================
-- Migration complete
-- ============================================================================

DO $$ BEGIN RAISE NOTICE 'TTS Pre-Generation tables migration complete'; END $$;
