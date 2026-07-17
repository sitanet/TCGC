-- ============================================================================
-- Ask Wing AI Database Schema
-- PostgreSQL with pgvector extension for semantic search
-- ============================================================================

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS pgvector;

-- ============================================================================
-- Sermon Embeddings Table (for vector search)
-- ============================================================================

CREATE TABLE IF NOT EXISTS sermon_embeddings (
    id BIGSERIAL PRIMARY KEY,
    sermon_id INTEGER NOT NULL,
    chunk_index INTEGER NOT NULL,
    text_chunk TEXT NOT NULL,
    embedding vector(1536) NOT NULL,  -- OpenAI embedding dimension
    chunk_start_position INTEGER,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_sermon FOREIGN KEY(sermon_id) REFERENCES messages(id) ON DELETE CASCADE,
    CONSTRAINT unique_sermon_chunk UNIQUE(sermon_id, chunk_index)
);

-- Create IVFFlat index for faster similarity search (default for most use cases)
CREATE INDEX IF NOT EXISTS idx_sermon_embeddings_ivfflat 
ON sermon_embeddings USING ivfflat (embedding vector_cosine_ops)
WITH (lists = 100);

-- Alternative HNSW index for larger datasets (PostgreSQL 13.1+)
-- Uncomment to use instead of IVFFlat
-- CREATE INDEX IF NOT EXISTS idx_sermon_embeddings_hnsw 
-- ON sermon_embeddings USING hnsw (embedding vector_cosine_ops)
-- WITH (m = 16, ef_construction = 64);

-- Additional indexes for common queries
CREATE INDEX IF NOT EXISTS idx_sermon_embeddings_sermon_id ON sermon_embeddings(sermon_id);
CREATE INDEX IF NOT EXISTS idx_sermon_embeddings_created_at ON sermon_embeddings(created_at DESC);

-- ============================================================================
-- Chat Sessions Table
-- ============================================================================

CREATE TABLE IF NOT EXISTS chat_sessions (
    id BIGSERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL,
    session_id VARCHAR(100) UNIQUE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    last_activity TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    CONSTRAINT fk_user FOREIGN KEY(user_id) REFERENCES auth_user(id) ON DELETE CASCADE
);

-- Indexes for session queries
CREATE INDEX IF NOT EXISTS idx_chat_sessions_user_id ON chat_sessions(user_id);
CREATE INDEX IF NOT EXISTS idx_chat_sessions_session_id ON chat_sessions(session_id);
CREATE INDEX IF NOT EXISTS idx_chat_sessions_expires_at ON chat_sessions(expires_at);
CREATE INDEX IF NOT EXISTS idx_chat_sessions_user_created ON chat_sessions(user_id, created_at DESC);

-- ============================================================================
-- Chat Messages Table
-- ============================================================================

CREATE TABLE IF NOT EXISTS chat_messages (
    id BIGSERIAL PRIMARY KEY,
    session_id BIGINT NOT NULL,
    message_type VARCHAR(10) NOT NULL,  -- 'user' or 'ai'
    content TEXT NOT NULL,
    processing_time_ms INTEGER,  -- Time to generate response
    error_message TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_session FOREIGN KEY(session_id) REFERENCES chat_sessions(id) ON DELETE CASCADE,
    CONSTRAINT valid_message_type CHECK (message_type IN ('user', 'ai'))
);

-- Indexes for message queries
CREATE INDEX IF NOT EXISTS idx_chat_messages_session_id ON chat_messages(session_id);
CREATE INDEX IF NOT EXISTS idx_chat_messages_created_at ON chat_messages(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_chat_messages_session_created ON chat_messages(session_id, created_at DESC);

-- ============================================================================
-- Ask Wing AI Questions Table (for moderation and analytics)
-- ============================================================================

CREATE TABLE IF NOT EXISTS ask_wing_ai_questions (
    id BIGSERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL,
    question TEXT NOT NULL,
    question_sanitized TEXT NOT NULL,  -- PII removed version
    response_summary TEXT,
    flagged_for_review BOOLEAN DEFAULT FALSE,
    flag_reason VARCHAR(255),  -- Reason for flagging
    processing_time_ms INTEGER,  -- Time to process question
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_user FOREIGN KEY(user_id) REFERENCES auth_user(id) ON DELETE CASCADE
);

-- Indexes for moderation queries
CREATE INDEX IF NOT EXISTS idx_ask_wing_questions_user_id ON ask_wing_ai_questions(user_id);
CREATE INDEX IF NOT EXISTS idx_ask_wing_questions_flagged ON ask_wing_ai_questions(flagged_for_review);
CREATE INDEX IF NOT EXISTS idx_ask_wing_questions_created ON ask_wing_ai_questions(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_ask_wing_questions_user_created ON ask_wing_ai_questions(user_id, created_at DESC);

-- ============================================================================
-- Citations Table (links AI responses to source sermon content)
-- ============================================================================

CREATE TABLE IF NOT EXISTS citations (
    id BIGSERIAL PRIMARY KEY,
    chat_message_id BIGINT NOT NULL,
    sermon_id INTEGER NOT NULL,
    speaker_id INTEGER NOT NULL,
    text_chunk TEXT NOT NULL,
    estimated_timestamp VARCHAR(10),  -- MM:SS format
    similarity_score FLOAT,  -- 0-1 similarity score
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_message FOREIGN KEY(chat_message_id) REFERENCES chat_messages(id) ON DELETE CASCADE,
    CONSTRAINT fk_sermon FOREIGN KEY(sermon_id) REFERENCES messages(id) ON DELETE CASCADE,
    CONSTRAINT fk_speaker FOREIGN KEY(speaker_id) REFERENCES speakers(id) ON DELETE SET NULL
);

-- Indexes for citation queries
CREATE INDEX IF NOT EXISTS idx_citations_message_id ON citations(chat_message_id);
CREATE INDEX IF NOT EXISTS idx_citations_sermon_id ON citations(sermon_id);
CREATE INDEX IF NOT EXISTS idx_citations_similarity ON citations(similarity_score DESC);

-- ============================================================================
-- Transcription Status Fields (extended to existing Message/Sermon table)
-- ============================================================================

-- These ALTER statements add transcription tracking to the existing messages table
-- Uncomment and run if the columns don't already exist

-- ALTER TABLE messages ADD COLUMN IF NOT EXISTS transcript TEXT;
-- ALTER TABLE messages ADD COLUMN IF NOT EXISTS transcription_status VARCHAR(20) DEFAULT 'pending';
-- ALTER TABLE messages ADD COLUMN IF NOT EXISTS transcription_error TEXT;
-- ALTER TABLE messages ADD COLUMN IF NOT EXISTS transcription_retry_count INTEGER DEFAULT 0;
-- ALTER TABLE messages ADD COLUMN IF NOT EXISTS transcribed_at TIMESTAMP WITH TIME ZONE;
-- ALTER TABLE messages ADD COLUMN IF NOT EXISTS indexing_status VARCHAR(20) DEFAULT 'pending';
-- ALTER TABLE messages ADD COLUMN IF NOT EXISTS indexed_at TIMESTAMP WITH TIME ZONE;

-- Indexes for transcription and indexing status
-- CREATE INDEX IF NOT EXISTS idx_messages_transcription_status ON messages(transcription_status);
-- CREATE INDEX IF NOT EXISTS idx_messages_indexing_status ON messages(indexing_status);

-- ============================================================================
-- Rate Limiting Cache Table (for tracking daily question limits)
-- ============================================================================

CREATE TABLE IF NOT EXISTS rate_limit_cache (
    id BIGSERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL UNIQUE,
    daily_question_count INTEGER DEFAULT 0,
    reset_date DATE NOT NULL,
    last_question_time TIMESTAMP WITH TIME ZONE,
    CONSTRAINT fk_user FOREIGN KEY(user_id) REFERENCES auth_user(id) ON DELETE CASCADE
);

-- Index for rate limit queries
CREATE INDEX IF NOT EXISTS idx_rate_limit_cache_reset_date ON rate_limit_cache(reset_date);

-- ============================================================================
-- pgvector Configuration and Parameters
-- ============================================================================

-- Verify pgvector is installed
SELECT extname, extversion FROM pg_extension WHERE extname = 'pgvector';

-- Show vector types available
SELECT typname FROM pg_type WHERE typname LIKE '%vector%';

-- ============================================================================
-- Performance Monitoring Views
-- ============================================================================

-- View for monitoring embedding table size
CREATE OR REPLACE VIEW v_embedding_stats AS
SELECT 
    count(*) as total_embeddings,
    count(DISTINCT sermon_id) as unique_sermons,
    pg_size_pretty(pg_total_relation_size('sermon_embeddings'::regclass)) as table_size,
    NOW() as last_updated
FROM sermon_embeddings;

-- View for monitoring chat statistics
CREATE OR REPLACE VIEW v_chat_stats AS
SELECT 
    COUNT(DISTINCT user_id) as active_users,
    COUNT(*) as total_sessions,
    AVG((last_activity - created_at)::numeric) as avg_session_duration_seconds,
    NOW() as last_updated
FROM chat_sessions
WHERE created_at > NOW() - INTERVAL '24 hours';

-- View for monitoring question statistics
CREATE OR REPLACE VIEW v_question_stats AS
SELECT 
    COUNT(*) as total_questions,
    COUNT(FILTER (WHERE flagged_for_review)) as flagged_questions,
    AVG(processing_time_ms) as avg_processing_time_ms,
    COUNT(DISTINCT user_id) as unique_users,
    NOW() as last_updated
FROM ask_wing_ai_questions
WHERE created_at > NOW() - INTERVAL '24 hours';

-- ============================================================================
-- Database Health Checks
-- ============================================================================

-- Function to verify pgvector is working
CREATE OR REPLACE FUNCTION check_pgvector_health() RETURNS TABLE(status TEXT, message TEXT) AS $$
BEGIN
    -- Check if pgvector extension exists
    PERFORM 1 FROM pg_extension WHERE extname = 'pgvector';
    IF NOT FOUND THEN
        RETURN QUERY SELECT 'ERROR'::TEXT, 'pgvector extension not installed'::TEXT;
        RETURN;
    END IF;
    
    -- Check if vector type exists
    PERFORM 1 FROM pg_type WHERE typname = 'vector';
    IF NOT FOUND THEN
        RETURN QUERY SELECT 'ERROR'::TEXT, 'vector type not found'::TEXT;
        RETURN;
    END IF;
    
    -- All checks passed
    RETURN QUERY SELECT 'OK'::TEXT, 'pgvector is properly installed and configured'::TEXT;
END;
$$ LANGUAGE plpgsql;

-- Run health check
SELECT * FROM check_pgvector_health();

-- ============================================================================
-- Maintenance and Optimization Scripts
-- ============================================================================

-- Analyze tables for query optimization
ANALYZE sermon_embeddings;
ANALYZE chat_sessions;
ANALYZE chat_messages;
ANALYZE ask_wing_ai_questions;
ANALYZE citations;

-- Vacuum analyze (for production, run during low-traffic hours)
-- VACUUM ANALYZE sermon_embeddings;
-- VACUUM ANALYZE chat_sessions;
-- VACUUM ANALYZE chat_messages;
-- VACUUM ANALYZE ask_wing_ai_questions;
-- VACUUM ANALYZE citations;

-- ============================================================================
-- Completion
-- ============================================================================

-- Display table statistics
SELECT 
    schemaname,
    tablename,
    n_live_tup as row_count,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) as total_size
FROM pg_stat_user_tables
WHERE tablename IN (
    'sermon_embeddings',
    'chat_sessions',
    'chat_messages',
    'ask_wing_ai_questions',
    'citations',
    'rate_limit_cache'
)
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;

-- Display indexes
SELECT 
    schemaname,
    tablename,
    indexname,
    pg_size_pretty(pg_relation_size(indexrelid)) as index_size
FROM pg_stat_user_indexes
WHERE tablename IN (
    'sermon_embeddings',
    'chat_sessions',
    'chat_messages',
    'ask_wing_ai_questions',
    'citations'
)
ORDER BY pg_relation_size(indexrelid) DESC;

-- ============================================================================
-- End of Schema Creation Script
-- ============================================================================
