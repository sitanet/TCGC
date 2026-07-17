# PostgreSQL Setup Guide for Ask Wing AI

## Overview

This guide provides step-by-step instructions for setting up PostgreSQL 14+ with the pgvector extension for the Ask Wing AI feature. The pgvector extension enables efficient semantic search across sermon embeddings.

## Prerequisites

- PostgreSQL 14 or higher
- pgvector extension (compatible with your PostgreSQL version)
- Python 3.8+ with pip
- psycopg2-binary for Django PostgreSQL support
- Connection pooling tool (PgBouncer recommended for production)

## Installation Steps

### 1. Install PostgreSQL 14+

#### On Windows
```bash
# Download the installer from https://www.postgresql.org/download/windows/
# Run the installer with these settings:
# - Version: PostgreSQL 14 or higher
# - Data directory: C:\Program Files\PostgreSQL\14\data
# - Port: 5432 (default)
# - Superuser password: [your secure password]
# - Install pgAdmin 4: Yes (recommended)

# Verify installation
psql --version
```

#### On macOS
```bash
# Using Homebrew (recommended)
brew install postgresql@14
brew services start postgresql@14

# Verify installation
psql --version
```

#### On Linux (Ubuntu/Debian)
```bash
sudo apt-get update
sudo apt-get install postgresql-14 postgresql-contrib-14

# Start PostgreSQL
sudo systemctl start postgresql
sudo systemctl enable postgresql

# Verify installation
psql --version
```

### 2. Install pgvector Extension

#### On Windows
```bash
# Download pre-built pgvector extension from:
# https://github.com/pgvector/pgvector/releases

# Extract and place in PostgreSQL extension directory:
# C:\Program Files\PostgreSQL\14\share\extension\

# Restart PostgreSQL service
```

#### On macOS
```bash
brew install pgvector
```

#### On Linux (Ubuntu/Debian)
```bash
# Build from source
git clone https://github.com/pgvector/pgvector.git
cd pgvector
make
sudo make install

# Or install from package manager
sudo apt-get install postgresql-14-pgvector
```

### 3. Create Database and Enable pgvector

```bash
# Connect to PostgreSQL as superuser
psql -U postgres

# In psql shell, execute:
CREATE DATABASE ask_wing_ai;
\c ask_wing_ai
CREATE EXTENSION pgvector;

# Verify installation
SELECT * FROM pg_extension WHERE extname = 'pgvector';

# Exit psql
\q
```

### 4. Create Database User with Appropriate Permissions

```bash
psql -U postgres

# Create database user for Django application
CREATE USER ask_wing_user WITH PASSWORD 'your_secure_password_here';

# Grant necessary permissions
GRANT CONNECT ON DATABASE ask_wing_ai TO ask_wing_user;
GRANT USAGE ON SCHEMA public TO ask_wing_user;
GRANT CREATE ON SCHEMA public TO ask_wing_user;

# Grant table creation and modification permissions
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO ask_wing_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO ask_wing_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT USAGE ON SEQUENCES TO ask_wing_user;

# Exit
\q
```

### 5. Verify pgvector Installation

```bash
# Connect as application user
psql -U ask_wing_user -d ask_wing_ai -h localhost

# Create test table with vector column
CREATE TABLE test_vectors (
    id SERIAL PRIMARY KEY,
    embedding VECTOR(1536)
);

# Insert test vector
INSERT INTO test_vectors (embedding) VALUES ('[0.1, 0.2, 0.3, ... 1536 dimensions]');

# Test similarity query
SELECT id, embedding <-> ARRAY[0.1, 0.2, 0.3, ...]::vector AS distance FROM test_vectors ORDER BY distance LIMIT 5;

# Drop test table
DROP TABLE test_vectors;

# Exit
\q
```

## Connection Pooling Setup (PgBouncer)

### Installation

#### On Windows
```bash
# Download from https://pgbouncer.github.io/
# Extract to a directory (e.g., C:\pgbouncer\)
```

#### On macOS
```bash
brew install pgbouncer
```

#### On Linux
```bash
sudo apt-get install pgbouncer
```

### Configuration

Create `pgbouncer.ini`:

```ini
; PgBouncer Configuration for Ask Wing AI

[databases]
ask_wing_ai = host=localhost port=5432 dbname=ask_wing_ai

[pgbouncer]
logfile = /var/log/pgbouncer/pgbouncer.log
pidfile = /var/run/pgbouncer/pgbouncer.pid
listen_addr = localhost
listen_port = 6432
auth_type = md5
auth_file = /etc/pgbouncer/userlist.txt

; Connection pooling settings
pool_mode = transaction
max_client_conn = 1000
default_pool_size = 25
min_pool_size = 10
reserve_pool_size = 5
reserve_pool_timeout = 3
max_db_connections = 100
max_user_connections = 50

; Query timeout (seconds)
query_wait_timeout = 120
client_idle_timeout = 600
idle_in_transaction_session_timeout = 600

; Performance tuning
tcp_keepalives = 1
tcp_keepidle = 30
tcp_keepintvl = 10
tcp_keepcnt = 5

; Verbose logging
verbose = 1
log_connections = 1
log_disconnections = 1
log_pooler_stats = 1

; Statistics
stats_period = 60
```

### Setup User Credentials File

Create `/etc/pgbouncer/userlist.txt`:

```
"ask_wing_user" "password_hash_or_plain_password"
"postgres" "superuser_password"
```

### Start PgBouncer

```bash
# Linux/macOS
pgbouncer -d /etc/pgbouncer/pgbouncer.ini

# Windows
pgbouncer.exe -d pgbouncer.ini

# Verify connection
psql -U ask_wing_user -h localhost -p 6432 -d ask_wing_ai
```

## Django Configuration

### Install Required Python Packages

```bash
pip install psycopg2-binary==2.9.9
pip install django==4.2.0
pip install djangorestframework==3.14.0
```

### Update Django settings.py

```python
import os
from pathlib import Path

DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.postgresql',
        'NAME': os.environ.get('DB_NAME', 'ask_wing_ai'),
        'USER': os.environ.get('DB_USER', 'ask_wing_user'),
        'PASSWORD': os.environ.get('DB_PASSWORD', ''),
        'HOST': os.environ.get('DB_HOST', 'localhost'),
        'PORT': os.environ.get('DB_PORT', '6432'),  # PgBouncer port if using
        'CONN_MAX_AGE': 600,
        'ATOMIC_REQUESTS': False,
        'OPTIONS': {
            'connect_timeout': 10,
            'application_name': 'ask_wing_ai',
        }
    }
}

# Connection pooling settings
if os.environ.get('USE_PGBOUNCER', False):
    DATABASES['default']['PORT'] = '6432'
    DATABASES['default']['OPTIONS']['pooling_mode'] = 'transaction'
```

### Create .env File

```bash
# Database Configuration
DB_ENGINE=django.db.backends.postgresql
DB_NAME=ask_wing_ai
DB_USER=ask_wing_user
DB_PASSWORD=your_secure_password_here
DB_HOST=localhost
DB_PORT=5432  # or 6432 if using PgBouncer
USE_PGBOUNCER=False  # Set to True in production

# pgvector Configuration
PGVECTOR_DIMENSIONS=1536  # OpenAI embedding dimension
PGVECTOR_INDEX_TYPE=ivfflat  # or hnsw for larger datasets

# OpenAI Configuration
OPENAI_API_KEY=sk-proj-xxxxxxxxxxxxx
OPENAI_EMBEDDING_MODEL=text-embedding-3-small
OPENAI_GPT_MODEL=gpt-4
OPENAI_WHISPER_MODEL=whisper-1

# Security
SECRET_KEY=your-django-secret-key-here
DEBUG=False
ALLOWED_HOSTS=localhost,127.0.0.1,api.example.com

# Redis Configuration (for caching and celery)
REDIS_URL=redis://localhost:6379/0
```

## Database Schema and Indexes

### Create Tables with pgvector Support

```sql
-- Enable pgvector extension
CREATE EXTENSION IF NOT EXISTS pgvector;

-- Sermon embeddings table
CREATE TABLE sermon_embeddings (
    id BIGSERIAL PRIMARY KEY,
    sermon_id INTEGER NOT NULL,
    chunk_index INTEGER NOT NULL,
    text_chunk TEXT NOT NULL,
    embedding vector(1536) NOT NULL,
    chunk_start_position INTEGER,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(sermon_id, chunk_index),
    FOREIGN KEY(sermon_id) REFERENCES messages(id) ON DELETE CASCADE
);

-- Create IVFFlat index for faster similarity search
CREATE INDEX ON sermon_embeddings USING ivfflat (embedding vector_cosine_ops)
WITH (lists = 100);

-- Alternative: HNSW index for larger datasets (PostgreSQL 13.1+)
-- CREATE INDEX ON sermon_embeddings USING hnsw (embedding vector_cosine_ops)
-- WITH (m = 16, ef_construction = 64);

-- Chat sessions table
CREATE TABLE chat_sessions (
    id BIGSERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL,
    session_id VARCHAR(100) UNIQUE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    last_activity TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    FOREIGN KEY(user_id) REFERENCES auth_user(id) ON DELETE CASCADE
);

CREATE INDEX ON chat_sessions(user_id, created_at);
CREATE INDEX ON chat_sessions(expires_at);

-- Chat messages table
CREATE TABLE chat_messages (
    id BIGSERIAL PRIMARY KEY,
    session_id BIGINT NOT NULL,
    message_type VARCHAR(10) NOT NULL,
    content TEXT NOT NULL,
    processing_time_ms INTEGER,
    error_message TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY(session_id) REFERENCES chat_sessions(id) ON DELETE CASCADE
);

CREATE INDEX ON chat_messages(session_id, created_at);

-- Ask Wing AI questions table (for moderation and analytics)
CREATE TABLE ask_wing_ai_questions (
    id BIGSERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL,
    question TEXT NOT NULL,
    question_sanitized TEXT NOT NULL,
    response_summary TEXT,
    flagged_for_review BOOLEAN DEFAULT FALSE,
    flag_reason VARCHAR(255),
    processing_time_ms INTEGER,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY(user_id) REFERENCES auth_user(id) ON DELETE CASCADE
);

CREATE INDEX ON ask_wing_ai_questions(user_id, created_at);
CREATE INDEX ON ask_wing_ai_questions(flagged_for_review);

-- Citations table
CREATE TABLE citations (
    id BIGSERIAL PRIMARY KEY,
    chat_message_id BIGINT NOT NULL,
    sermon_id INTEGER NOT NULL,
    speaker_id INTEGER NOT NULL,
    text_chunk TEXT NOT NULL,
    estimated_timestamp VARCHAR(10),
    similarity_score FLOAT,
    FOREIGN KEY(chat_message_id) REFERENCES chat_messages(id) ON DELETE CASCADE,
    FOREIGN KEY(sermon_id) REFERENCES messages(id) ON DELETE CASCADE,
    FOREIGN KEY(speaker_id) REFERENCES speakers(id) ON DELETE SET NULL
);

CREATE INDEX ON citations(chat_message_id);

-- Extensions to Message/Sermon table for transcription
ALTER TABLE messages ADD COLUMN IF NOT EXISTS transcript TEXT;
ALTER TABLE messages ADD COLUMN IF NOT EXISTS transcription_status VARCHAR(20) DEFAULT 'pending';
ALTER TABLE messages ADD COLUMN IF NOT EXISTS transcription_error TEXT;
ALTER TABLE messages ADD COLUMN IF NOT EXISTS transcription_retry_count INTEGER DEFAULT 0;
ALTER TABLE messages ADD COLUMN IF NOT EXISTS transcribed_at TIMESTAMP WITH TIME ZONE;
ALTER TABLE messages ADD COLUMN IF NOT EXISTS indexing_status VARCHAR(20) DEFAULT 'pending';
ALTER TABLE messages ADD COLUMN IF NOT EXISTS indexed_at TIMESTAMP WITH TIME ZONE;

CREATE INDEX ON messages(transcription_status);
CREATE INDEX ON messages(indexing_status);
```

## Production Optimization

### PgBouncer Connection Pool Tuning

```ini
; Connection pool settings for Ask Wing AI
pool_mode = transaction      ; Minimal query latency, good for web apps
max_client_conn = 1000       ; Maximum client connections
default_pool_size = 25       ; Default connections per database/user
min_pool_size = 10           ; Minimum connections to maintain
reserve_pool_size = 5        ; Extra connections for spikes
reserve_pool_timeout = 3     ; Seconds to wait for reserve connection

; For read-heavy workloads, consider:
; pool_mode = session
; default_pool_size = 50
; reserve_pool_size = 10
```

### PostgreSQL Configuration Tuning

Edit `/etc/postgresql/14/main/postgresql.conf`:

```ini
# Connection settings
max_connections = 200
superuser_reserved_connections = 3

# Memory settings
shared_buffers = 256MB        # 25% of system RAM
effective_cache_size = 1GB    # 50% of system RAM
work_mem = 4MB                # shared_buffers / (max_connections * 2)
maintenance_work_mem = 64MB   # For CREATE INDEX operations

# Query tuning
random_page_cost = 1.1        # SSD-friendly
effective_io_concurrency = 200

# WAL settings
wal_buffers = 16MB
default_statistics_target = 100

# Logging
log_min_duration_statement = 1000  # Log queries slower than 1 second
log_line_prefix = '%t [%p]: [%l-1] user=%u,db=%d,app=%a,client=%h '
```

### Monitoring and Maintenance

```sql
-- Monitor table sizes
SELECT 
    schemaname,
    tablename,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS size
FROM pg_tables
WHERE schemaname NOT IN ('pg_catalog', 'information_schema')
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;

-- Monitor index usage
SELECT 
    schemaname,
    tablename,
    indexname,
    idx_scan,
    idx_tup_read,
    idx_tup_fetch
FROM pg_stat_user_indexes
ORDER BY idx_scan DESC;

-- Vacuum and analyze tables
VACUUM ANALYZE;

-- Reindex tables (only if necessary)
REINDEX TABLE sermon_embeddings;
```

## Troubleshooting

### Issue: pgvector extension not found

```bash
# Solution: Install from source
git clone https://github.com/pgvector/pgvector.git
cd pgvector
make
sudo make install

# Restart PostgreSQL
sudo systemctl restart postgresql
```

### Issue: Vector distance queries are slow

```sql
-- Drop existing index
DROP INDEX ON sermon_embeddings;

-- Recreate with different parameters
CREATE INDEX ON sermon_embeddings USING ivfflat (embedding vector_cosine_ops)
WITH (lists = 200);  -- Increase lists for larger datasets

-- Or use HNSW for better performance on large datasets
CREATE INDEX ON sermon_embeddings USING hnsw (embedding vector_cosine_ops)
WITH (m = 16, ef_construction = 64);
```

### Issue: PgBouncer connection timeout

```ini
; Increase timeouts in pgbouncer.ini
query_wait_timeout = 300  ; Increase to 5 minutes
client_idle_timeout = 900
idle_in_transaction_session_timeout = 900
```

## Testing the Setup

Create `test_db_connection.py`:

```python
import psycopg2
import os
from dotenv import load_dotenv

load_dotenv()

try:
    # Test direct database connection
    conn = psycopg2.connect(
        host=os.getenv('DB_HOST'),
        port=os.getenv('DB_PORT'),
        database=os.getenv('DB_NAME'),
        user=os.getenv('DB_USER'),
        password=os.getenv('DB_PASSWORD')
    )
    cursor = conn.cursor()
    
    # Test pgvector extension
    cursor.execute("SELECT * FROM pg_extension WHERE extname = 'pgvector';")
    result = cursor.fetchone()
    
    if result:
        print("✓ pgvector extension is installed")
    else:
        print("✗ pgvector extension is NOT installed")
    
    # Test vector operations
    cursor.execute("""
        CREATE TEMP TABLE test_vectors (
            id SERIAL PRIMARY KEY,
            embedding VECTOR(1536)
        );
    """)
    
    cursor.execute("""
        INSERT INTO test_vectors (embedding) VALUES 
        (ARRAY[0.1, 0.2, 0.3]);
    """)
    
    cursor.execute("""
        SELECT id, embedding <-> ARRAY[0.1, 0.2, 0.3]::vector AS distance 
        FROM test_vectors;
    """)
    
    result = cursor.fetchone()
    print(f"✓ Vector operations working: {result}")
    
    cursor.close()
    conn.close()
    print("✓ Database connection successful")
    
except psycopg2.Error as e:
    print(f"✗ Database connection error: {e}")
except Exception as e:
    print(f"✗ Error: {e}")
```

Run the test:

```bash
python test_db_connection.py
```

## Next Steps

After completing this setup:

1. Run Django migrations to create application tables
2. Set up Celery for async transcription tasks
3. Configure Redis for caching and session management
4. Set up monitoring and alerting for database performance
5. Implement automated backups

## References

- [PostgreSQL Official Documentation](https://www.postgresql.org/docs/14/)
- [pgvector GitHub Repository](https://github.com/pgvector/pgvector)
- [PgBouncer Documentation](https://pgbouncer.github.io/)
- [Django PostgreSQL Backend](https://docs.djangoproject.com/en/4.2/ref/databases/#postgresql-notes)
