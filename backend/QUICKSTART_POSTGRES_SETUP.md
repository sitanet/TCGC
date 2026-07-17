# Quick Start: PostgreSQL + pgvector Setup for Ask Wing AI

## 5-Minute Quick Start

### Windows Quick Setup

```bash
# 1. Download and install PostgreSQL 14+
# Visit: https://www.postgresql.org/download/windows/
# Run installer, remember superuser password

# 2. Download pgvector extension
# Visit: https://github.com/pgvector/pgvector/releases
# Extract to: C:\Program Files\PostgreSQL\14\share\extension\

# 3. Create database
psql -U postgres -c "CREATE DATABASE ask_wing_ai;"
psql -U postgres -d ask_wing_ai -c "CREATE EXTENSION pgvector;"

# 4. Create user
psql -U postgres -d ask_wing_ai -c "CREATE USER ask_wing_user WITH PASSWORD 'SecurePassword123!';"
psql -U postgres -d ask_wing_ai -c "GRANT ALL ON DATABASE ask_wing_ai TO ask_wing_user;"

# 5. Create schema
psql -U ask_wing_user -d ask_wing_ai -h localhost < create_schema.sql

# 6. Verify
python verify_postgresql_setup.py --full-check
```

### macOS Quick Setup

```bash
# 1. Install PostgreSQL and pgvector
brew install postgresql@14 pgvector
brew services start postgresql@14

# 2. Create database
createdb ask_wing_ai
psql -d ask_wing_ai -c "CREATE EXTENSION pgvector;"

# 3. Create user
psql -d ask_wing_ai -c "CREATE USER ask_wing_user WITH PASSWORD 'SecurePassword123!';"
psql -d ask_wing_ai -c "GRANT ALL ON DATABASE ask_wing_ai TO ask_wing_user;"

# 4. Create schema
psql -U ask_wing_user -d ask_wing_ai -h localhost < create_schema.sql

# 5. Verify
python verify_postgresql_setup.py --full-check
```

### Linux Quick Setup (Ubuntu/Debian)

```bash
# 1. Install packages
sudo apt-get update
sudo apt-get install postgresql-14 postgresql-14-pgvector

# 2. Start PostgreSQL
sudo systemctl start postgresql
sudo systemctl enable postgresql

# 3. Create database
sudo -u postgres createdb ask_wing_ai
sudo -u postgres psql -d ask_wing_ai -c "CREATE EXTENSION pgvector;"

# 4. Create user
sudo -u postgres psql -d ask_wing_ai -c "CREATE USER ask_wing_user WITH PASSWORD 'SecurePassword123!';"
sudo -u postgres psql -d ask_wing_ai -c "GRANT ALL ON DATABASE ask_wing_ai TO ask_wing_user;"

# 5. Create schema
psql -U ask_wing_user -d ask_wing_ai -h localhost < create_schema.sql

# 6. Verify
python verify_postgresql_setup.py --full-check
```

## Configuration (2 Minutes)

```bash
# Copy environment template
cp .env.example .env

# Edit with your settings (minimum required)
DB_NAME=ask_wing_ai
DB_USER=ask_wing_user
DB_PASSWORD=SecurePassword123!
DB_HOST=localhost
DB_PORT=5432
OPENAI_API_KEY=sk-proj-your-key-here

# For development only, DEBUG is safe:
DEBUG=True
```

## Python Setup (3 Minutes)

```bash
# Create virtual environment
python -m venv venv

# Activate (Windows)
venv\Scripts\activate

# Activate (macOS/Linux)
source venv/bin/activate

# Install dependencies
pip install -r requirements.txt

# Verify database connection
python verify_postgresql_setup.py --connection-only
```

## Testing (2 Minutes)

```bash
# Run full verification
python verify_postgresql_setup.py --full-check

# Expected output:
# ✓ [OK      ] PostgreSQL version check passed: 14
# ✓ [OK      ] pgvector extension is installed
# ✓ [OK      ] Vector type is available
# ✓ [OK      ] Vector operations working correctly
# ✓ [OK      ] All required tables exist (5 tables)
# ...
# Verification Summary: 8/8 checks passed
```

## Troubleshooting Quick Fixes

### "psql: command not found"
```bash
# Windows: Add PostgreSQL bin to PATH
# Or use full path: "C:\Program Files\PostgreSQL\14\bin\psql.exe"

# macOS: If using brew
brew install postgresql@14
echo 'export PATH="/usr/local/opt/postgresql@14/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc

# Linux: Install postgresql-client
sudo apt-get install postgresql-client
```

### "pgvector extension not found"
```bash
# Windows: Download from GitHub and extract to extension directory
# https://github.com/pgvector/pgvector/releases

# macOS: Reinstall
brew uninstall pgvector
brew install pgvector

# Linux: Build from source
git clone https://github.com/pgvector/pgvector.git
cd pgvector
make
sudo make install
```

### "Connection refused"
```bash
# Make sure PostgreSQL is running
# Windows: Use Services or restart
# macOS: brew services start postgresql@14
# Linux: sudo systemctl start postgresql
# Then verify: psql -U postgres -c "SELECT 1;"
```

### "Password authentication failed"
```bash
# Check .env file for correct password
# Verify user exists:
psql -U postgres -c "\du"

# Reset password if needed:
psql -U postgres -d ask_wing_ai -c "ALTER USER ask_wing_user WITH PASSWORD 'NewPassword123!';"
```

## Next Steps

1. **Django Integration** (see TASK_1_2)
   ```bash
   python manage.py migrate
   python manage.py createsuperuser
   ```

2. **Production Setup** (optional now)
   - Install PgBouncer (see pgbouncer.ini.example)
   - Enable SSL/TLS
   - Configure backups

3. **Development**
   - Create Django models (Task 1.2)
   - Build API endpoints (Task 7)
   - Implement services (Tasks 4-6)

## Production Checklist (Later)

- [ ] PostgreSQL version 14+
- [ ] pgvector extension installed
- [ ] PgBouncer connection pooling configured
- [ ] SSL/TLS certificates installed
- [ ] Database backups configured
- [ ] Monitoring and alerting set up
- [ ] Performance indexes created
- [ ] Security audit completed
- [ ] Disaster recovery tested

## Files Reference

| File | Purpose | Size |
|------|---------|------|
| README_POSTGRESQL_SETUP.md | Detailed setup guide | ~20 KB |
| create_schema.sql | Database schema | ~15 KB |
| database_config.py | Django configuration | ~12 KB |
| .env.example | Environment template | ~8 KB |
| requirements.txt | Python dependencies | ~3 KB |
| pgbouncer.ini.example | Connection pooling | ~8 KB |
| verify_postgresql_setup.py | Verification tool | ~18 KB |

## Common Commands

```bash
# Connect to database
psql -U ask_wing_user -d ask_wing_ai -h localhost

# List tables
\dt

# List extensions
\dx

# Exit psql
\q

# Backup database
pg_dump ask_wing_ai > backup.sql

# Restore database
psql ask_wing_ai < backup.sql

# Check vector search
SELECT COUNT(*) FROM sermon_embeddings;

# View table sizes
SELECT 
    tablename,
    pg_size_pretty(pg_total_relation_size('public.' || tablename)) AS size
FROM pg_tables
WHERE schemaname = 'public';
```

## Support

- **Full Setup Guide:** See README_POSTGRESQL_SETUP.md
- **Implementation Details:** See TASK_1_1_IMPLEMENTATION_GUIDE.md
- **Summary:** See TASK_1_1_SUMMARY.md
- **Verification:** Run `python verify_postgresql_setup.py --full-check`

## Performance Tips

```sql
-- Analyze tables for query optimization
VACUUM ANALYZE;

-- Check index usage
SELECT * FROM pg_stat_user_indexes WHERE idx_scan = 0;

-- Reindex if needed
REINDEX TABLE sermon_embeddings;
```

## Security Reminder

⚠️ **IMPORTANT:**
- Never commit .env file to version control
- Use strong passwords (min 20 characters)
- Use HTTPS in production
- Rotate API keys regularly
- Enable database audit logging
- Restrict network access to database

---

**Estimated Time: 12 minutes**

Ready to start? Begin with the setup for your OS above!
