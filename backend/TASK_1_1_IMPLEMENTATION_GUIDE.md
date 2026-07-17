# Task 1.1: Set up PostgreSQL with pgvector Extension

## Task Overview

**Task ID:** 1.1 Set up PostgreSQL with pgvector extension  
**Phase:** Backend Infrastructure Setup  
**Requirements:** 5.6, 20.6  
**Status:** Implementation Guide

This task establishes the database infrastructure for Ask Wing AI, enabling semantic vector search across sermon embeddings. PostgreSQL with pgvector extension provides the foundation for the entire backend system.

## Requirements Mapped to This Task

### Requirement 5.6: Vector Database Setup
> "THE Indexed_Sermons SHALL be stored in a vector database optimized for semantic search (e.g., Pinecone, Weaviate, or PostgreSQL with pgvector)"

**Implementation:** PostgreSQL 14+ with pgvector extension

### Requirement 20.6: Sermon Indexing and Vector Storage
> "THE Indexed_Sermons SHALL be stored in a vector database optimized for semantic search (e.g., Pinecone, Weaviate, or PostgreSQL with pgvector)"

**Implementation:** Complete vector storage and indexing infrastructure

## Implementation Deliverables

This task includes the following deliverables:

1. **PostgreSQL Setup Guide** (`README_POSTGRESQL_SETUP.md`)
   - Step-by-step installation instructions for Windows, macOS, and Linux
   - pgvector extension installation
   - Database and user creation
   - PgBouncer connection pooling setup
   - Testing and verification procedures

2. **Django Database Configuration** (`database_config.py`)
   - Production-ready Django database settings
   - Connection pooling configuration
   - pgvector-specific settings
   - Health check configuration

3. **Database Schema Script** (`create_schema.sql`)
   - Complete PostgreSQL schema creation
   - Table definitions with pgvector support
   - Index creation (IVFFlat and HNSW options)
   - Performance monitoring views
   - Health check functions

4. **Environment Configuration** (`.env.example`)
   - Template for all environment variables
   - Database connection settings
   - OpenAI API configuration
   - Security and caching settings
   - Development vs. production profiles

5. **Python Requirements** (`requirements.txt`)
   - PostgreSQL driver (psycopg2)
   - pgvector Python support
   - Django and DRF dependencies
   - Supporting tools and libraries

6. **PgBouncer Configuration** (`pgbouncer.ini.example`)
   - Connection pooling configuration template
   - Performance tuning parameters
   - Monitoring and logging setup

7. **Verification Script** (`verify_postgresql_setup.py`)
   - Automated setup verification
   - Connection testing
   - pgvector functionality validation
   - Performance checks
   - Statistics collection

## Installation and Setup Steps

### Step 1: Install PostgreSQL 14+

**On Windows:**
```bash
# Download from https://www.postgresql.org/download/windows/
# Run installer with settings:
# - Version: PostgreSQL 14 or higher
# - Port: 5432
# - Superuser password: [secure password]

# Verify
psql --version
```

**On macOS:**
```bash
brew install postgresql@14
brew services start postgresql@14
psql --version
```

**On Linux (Ubuntu/Debian):**
```bash
sudo apt-get update
sudo apt-get install postgresql-14 postgresql-contrib-14
sudo systemctl start postgresql
psql --version
```

### Step 2: Install pgvector Extension

**Windows:**
- Download pre-built extension from https://github.com/pgvector/pgvector/releases
- Extract to PostgreSQL extension directory

**macOS:**
```bash
brew install pgvector
```

**Linux:**
```bash
git clone https://github.com/pgvector/pgvector.git
cd pgvector
make
sudo make install
```

### Step 3: Create Database and Enable pgvector

```bash
psql -U postgres

# In psql shell:
CREATE DATABASE ask_wing_ai;
\c ask_wing_ai
CREATE EXTENSION pgvector;
CREATE USER ask_wing_user WITH PASSWORD 'your_secure_password';
GRANT ALL PRIVILEGES ON DATABASE ask_wing_ai TO ask_wing_user;

\q
```

### Step 4: Create Schema

```bash
# Run schema creation script
psql -U ask_wing_user -d ask_wing_ai -h localhost < create_schema.sql
```

### Step 5: Configure Environment

```bash
# Copy environment template
cp .env.example .env

# Edit .env with your settings
DB_NAME=ask_wing_ai
DB_USER=ask_wing_user
DB_PASSWORD=your_secure_password_here
DB_HOST=localhost
DB_PORT=5432
```

### Step 6: Set Up Connection Pooling (Production)

```bash
# Install PgBouncer
# Windows: Download from https://pgbouncer.github.io/
# macOS: brew install pgbouncer
# Linux: sudo apt-get install pgbouncer

# Configure PgBouncer
cp pgbouncer.ini.example pgbouncer.ini

# Create userlist.txt
echo '"ask_wing_user" "your_password"' > /etc/pgbouncer/userlist.txt
chmod 600 /etc/pgbouncer/userlist.txt

# Start PgBouncer
pgbouncer -d pgbouncer.ini
```

### Step 7: Verify Setup

```bash
# Run verification script
python verify_postgresql_setup.py --full-check

# Or run connection test
python verify_postgresql_setup.py --connection-only
```

## Database Schema Overview

### Core Tables

#### 1. sermon_embeddings
- Stores vector embeddings for sermon chunks
- Enables semantic similarity search
- 1536-dimensional vectors (OpenAI standard)
- IVFFlat index for O(log n) search performance

**Fields:**
- `id`: Primary key
- `sermon_id`: Foreign key to messages table
- `chunk_index`: Position in transcript
- `text_chunk`: Original text content
- `embedding`: Vector(1536) for semantic search
- `chunk_start_position`: Character position in transcript
- `created_at`, `updated_at`: Timestamps

#### 2. chat_sessions
- Tracks user chat sessions
- Session-based chat history (cleared on exit)
- Expiration for cleanup

**Fields:**
- `id`: Primary key
- `user_id`: Foreign key to auth_user
- `session_id`: Unique session identifier
- `created_at`, `last_activity`, `expires_at`: Timestamps

#### 3. chat_messages
- Stores individual messages in a chat session
- Tracks processing time for performance monitoring
- Error tracking for debugging

**Fields:**
- `id`: Primary key
- `session_id`: Foreign key to chat_sessions
- `message_type`: 'user' or 'ai'
- `content`: Message text
- `processing_time_ms`: Response generation time
- `error_message`: Error details if any
- `created_at`: Timestamp

#### 4. ask_wing_ai_questions
- Logs all questions for moderation and analytics
- PII sanitization tracking
- Flagging system for policy violations

**Fields:**
- `id`: Primary key
- `user_id`: Foreign key to auth_user
- `question`: Original user question
- `question_sanitized`: PII-removed version
- `response_summary`: Summary (not full response)
- `flagged_for_review`: Boolean flag
- `flag_reason`: Reason for flagging
- `processing_time_ms`: Processing duration
- `created_at`: Timestamp

#### 5. citations
- Links AI responses to source sermon content
- Tracks similarity scores for relevance
- Stores timestamps for sermon navigation

**Fields:**
- `id`: Primary key
- `chat_message_id`: Foreign key to chat_messages
- `sermon_id`: Foreign key to messages
- `speaker_id`: Foreign key to speakers
- `text_chunk`: Cited text
- `estimated_timestamp`: MM:SS format
- `similarity_score`: 0-1 relevance score

### Indexes for Performance

**IVFFlat Index (default):**
```sql
CREATE INDEX idx_sermon_embeddings_ivfflat 
ON sermon_embeddings USING ivfflat (embedding vector_cosine_ops)
WITH (lists = 100);
```

**HNSW Index (optional, for larger datasets):**
```sql
CREATE INDEX idx_sermon_embeddings_hnsw 
ON sermon_embeddings USING hnsw (embedding vector_cosine_ops)
WITH (m = 16, ef_construction = 64);
```

## Configuration Parameters

### pgvector Settings

```python
PGVECTOR_DIMENSIONS = 1536  # OpenAI embedding dimension
PGVECTOR_INDEX_TYPE = 'ivfflat'  # or 'hnsw'
```

### Vector Search Settings

```python
VECTOR_SEARCH_CONFIG = {
    'top_k': 5,  # Return top 5 results
    'min_similarity_threshold': 0.7,  # Minimum relevance score
    'chunk_size': 1000,  # Characters per chunk
    'chunk_overlap': 200,  # Overlap between chunks
    'similarity_metric': 'cosine',  # Cosine similarity
}
```

### Connection Pooling (PgBouncer)

```ini
pool_mode = transaction           # Minimal latency for web apps
max_client_conn = 1000            # Maximum clients
default_pool_size = 25            # Connections per database/user
reserve_pool_size = 5             # Buffer for spikes
query_wait_timeout = 120          # 2-minute query timeout
```

## Performance Characteristics

### Expected Performance

| Operation | Latency | Notes |
|-----------|---------|-------|
| Vector Embedding Generation | < 3 sec | OpenAI API call |
| Vector Search (1M vectors) | < 2 sec | IVFFlat index |
| Similarity Score Calculation | < 100 ms | In-database computation |
| Chat Message Insert | < 10 ms | Simple INSERT |
| Session Lookup | < 5 ms | Indexed query |

### Tuning Recommendations

**For Development:**
- `default_pool_size = 10`
- `reserve_pool_size = 5`
- No index optimization needed

**For Production (100+ concurrent users):**
- `default_pool_size = 50`
- `reserve_pool_size = 20`
- Use HNSW index for 1M+ vectors
- Enable WAL archiving for backups
- Configure connection pooling at multiple levels

**For Large Deployments (10k+ vectors/day):**
- Partition tables by date
- Archive old embeddings
- Use read replicas for reporting
- Implement caching layer

## Monitoring and Maintenance

### Regular Maintenance

```bash
# Daily vacuum and analyze
VACUUM ANALYZE sermon_embeddings;
VACUUM ANALYZE chat_messages;

# Weekly reindex (if needed)
REINDEX TABLE sermon_embeddings;

# Monthly backup
pg_dump ask_wing_ai > backup_$(date +%Y%m%d).sql
```

### Monitoring Queries

```sql
-- Check table sizes
SELECT 
    tablename,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) as size
FROM pg_tables
WHERE schemaname = 'public'
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;

-- Monitor index usage
SELECT 
    tablename,
    indexname,
    idx_scan,
    idx_tup_read
FROM pg_stat_user_indexes
ORDER BY idx_scan DESC;

-- Check for slow queries
SELECT 
    query,
    mean_exec_time,
    max_exec_time,
    calls
FROM pg_stat_statements
WHERE query LIKE '%sermon_embeddings%'
ORDER BY mean_exec_time DESC;
```

## Testing the Setup

### Test Script

```bash
python verify_postgresql_setup.py --full-check
```

### Manual Testing

```python
import psycopg2
from pgvector.psycopg2 import register_vector

# Connect to database
conn = psycopg2.connect("dbname=ask_wing_ai user=ask_wing_user host=localhost")
register_vector(conn)
cursor = conn.cursor()

# Test vector operations
cursor.execute("""
    SELECT id, embedding <-> %s::vector AS distance
    FROM sermon_embeddings
    ORDER BY distance
    LIMIT 5;
""", ([0.1] * 1536,))

for row in cursor.fetchall():
    print(f"ID: {row[0]}, Distance: {row[1]}")

cursor.close()
conn.close()
```

## Django Integration

### Django Settings

```python
# settings.py
import os
from database_config import get_database_config

DATABASES = {
    'default': get_database_config()
}

# Vector search configuration
PGVECTOR_DIMENSIONS = int(os.environ.get('PGVECTOR_DIMENSIONS', 1536))
PGVECTOR_INDEX_TYPE = os.environ.get('PGVECTOR_INDEX_TYPE', 'ivfflat')
```

### Running Migrations

```bash
# Create initial migrations
python manage.py makemigrations

# Apply migrations
python manage.py migrate

# Create Django superuser
python manage.py createsuperuser
```

## Troubleshooting

### Common Issues

**1. pgvector extension not found**
```bash
# Solution: Install from source
git clone https://github.com/pgvector/pgvector.git
cd pgvector
make
sudo make install
```

**2. Connection timeout**
```ini
# In pgbouncer.ini
connect_timeout = 30
query_wait_timeout = 300
```

**3. Vector index slow**
```sql
-- Rebuild index with more clusters
DROP INDEX idx_sermon_embeddings_ivfflat;
CREATE INDEX idx_sermon_embeddings_ivfflat 
ON sermon_embeddings USING ivfflat (embedding vector_cosine_ops)
WITH (lists = 200);
```

**4. Out of memory during indexing**
```sql
-- Create index with parallel processing (PostgreSQL 11+)
CREATE INDEX CONCURRENTLY idx_sermon_embeddings_ivfflat 
ON sermon_embeddings USING ivfflat (embedding vector_cosine_ops)
WITH (lists = 100);
```

## Security Considerations

1. **Always use HTTPS for database connections in production**
2. **Store database credentials in environment variables only**
3. **Never commit .env file to version control**
4. **Use strong passwords for database users**
5. **Enable SSL certificates for PgBouncer**
6. **Restrict network access to database server**
7. **Regular backups with encryption**
8. **Audit database access logs**

## Next Steps

After completing this task:

1. **Task 1.2:** Create core database models
2. **Task 1.3:** Configure Django model relationships
3. **Task 1.4:** Set up environment variables and secrets management
4. **Phase 2:** Implement authentication and authorization
5. **Phase 3:** Build embedding and search services

## References

- [PostgreSQL Documentation](https://www.postgresql.org/docs/14/)
- [pgvector GitHub](https://github.com/pgvector/pgvector)
- [PgBouncer Documentation](https://pgbouncer.github.io/)
- [Django PostgreSQL Backend](https://docs.djangoproject.com/en/4.2/ref/databases/#postgresql-notes)
- [OpenAI Embeddings Documentation](https://platform.openai.com/docs/guides/embeddings)

## Success Criteria

✅ PostgreSQL 14+ installed and running  
✅ pgvector extension installed and verified  
✅ Database `ask_wing_ai` created  
✅ Application user `ask_wing_user` created with appropriate permissions  
✅ All tables created with pgvector support  
✅ Indexes created for performance  
✅ Django database configuration working  
✅ Environment variables configured  
✅ Connection pooling (PgBouncer) optional but recommended for production  
✅ Verification script confirms all components working  
✅ Tests pass for vector operations  

## Files Included in This Task

- `README_POSTGRESQL_SETUP.md` - Complete setup guide
- `database_config.py` - Django configuration
- `create_schema.sql` - Database schema
- `.env.example` - Environment template
- `requirements.txt` - Python dependencies
- `pgbouncer.ini.example` - Connection pooling config
- `verify_postgresql_setup.py` - Verification script
- `TASK_1_1_IMPLEMENTATION_GUIDE.md` - This file
