#!/usr/bin/env python
"""
PostgreSQL Setup Verification Script for Ask Wing AI

This script verifies that PostgreSQL 14+ with pgvector extension is properly
installed and configured for the Ask Wing AI feature.

Usage:
    python verify_postgresql_setup.py
    python verify_postgresql_setup.py --connection-only
    python verify_postgresql_setup.py --full-check
"""

import sys
import os
import argparse
import psycopg2
from psycopg2 import sql
from dotenv import load_dotenv
import json
from datetime import datetime

# Load environment variables
load_dotenv()


class PostgreSQLVerifier:
    """Verify PostgreSQL and pgvector installation and configuration."""
    
    def __init__(self, verbose=False):
        self.verbose = verbose
        self.results = []
        self.conn = None
        self.cursor = None
        
    def log(self, level, message, details=None):
        """Log verification results."""
        timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        log_entry = {
            'timestamp': timestamp,
            'level': level,
            'message': message,
            'details': details
        }
        self.results.append(log_entry)
        
        # Print to console
        prefix = {
            'OK': '✓',
            'WARNING': '⚠',
            'ERROR': '✗',
            'INFO': 'ℹ'
        }.get(level, '•')
        
        print(f"{prefix} [{level:8}] {message}")
        if details and self.verbose:
            print(f"           Details: {details}")
    
    def connect(self):
        """Connect to PostgreSQL database."""
        try:
            self.conn = psycopg2.connect(
                host=os.getenv('DB_HOST', 'localhost'),
                port=os.getenv('DB_PORT', '5432'),
                database=os.getenv('DB_NAME', 'ask_wing_ai'),
                user=os.getenv('DB_USER', 'ask_wing_user'),
                password=os.getenv('DB_PASSWORD', ''),
                connect_timeout=10
            )
            self.cursor = self.conn.cursor()
            self.log('OK', 'Connected to PostgreSQL database')
            return True
        except psycopg2.Error as e:
            self.log('ERROR', f'Failed to connect to PostgreSQL: {str(e)}')
            return False
    
    def check_postgresql_version(self):
        """Verify PostgreSQL version is 14 or higher."""
        try:
            self.cursor.execute("SELECT version();")
            version = self.cursor.fetchone()[0]
            
            # Extract version number
            if 'PostgreSQL' in version:
                version_num = int(version.split('PostgreSQL')[1].split('.')[0].strip())
                if version_num >= 14:
                    self.log('OK', f'PostgreSQL version check passed: {version_num}')
                    return True
                else:
                    self.log('ERROR', f'PostgreSQL version {version_num} is less than 14')
                    return False
        except Exception as e:
            self.log('ERROR', f'Failed to check PostgreSQL version: {str(e)}')
            return False
    
    def check_pgvector_extension(self):
        """Verify pgvector extension is installed."""
        try:
            self.cursor.execute("SELECT * FROM pg_extension WHERE extname = 'pgvector';")
            result = self.cursor.fetchone()
            
            if result:
                self.log('OK', 'pgvector extension is installed')
                return True
            else:
                self.log('ERROR', 'pgvector extension not found')
                self.log('INFO', 'Install pgvector using: CREATE EXTENSION pgvector;')
                return False
        except Exception as e:
            self.log('ERROR', f'Failed to check pgvector extension: {str(e)}')
            return False
    
    def check_vector_type(self):
        """Verify vector type is available."""
        try:
            self.cursor.execute("SELECT typname FROM pg_type WHERE typname = 'vector';")
            result = self.cursor.fetchone()
            
            if result:
                self.log('OK', 'Vector type is available')
                return True
            else:
                self.log('ERROR', 'Vector type not found (pgvector may not be properly installed)')
                return False
        except Exception as e:
            self.log('ERROR', f'Failed to check vector type: {str(e)}')
            return False
    
    def test_vector_operations(self):
        """Test basic vector operations."""
        try:
            # Create temporary table with vector column
            self.cursor.execute("""
                CREATE TEMP TABLE test_vectors (
                    id SERIAL PRIMARY KEY,
                    embedding VECTOR(1536)
                );
            """)
            
            # Insert test vector
            test_vector = '[' + ','.join(['0.1'] * 1536) + ']'
            self.cursor.execute("""
                INSERT INTO test_vectors (embedding) VALUES (%s::vector);
            """, (test_vector,))
            
            # Test similarity query
            self.cursor.execute("""
                SELECT id, embedding <-> %s::vector AS distance FROM test_vectors;
            """, (test_vector,))
            
            result = self.cursor.fetchone()
            if result:
                self.log('OK', f'Vector operations working correctly (distance: {result[1]})')
                return True
            else:
                self.log('ERROR', 'Vector operations test failed')
                return False
                
        except Exception as e:
            self.log('ERROR', f'Vector operations test failed: {str(e)}')
            return False
    
    def check_database_tables(self):
        """Check if required tables exist."""
        required_tables = [
            'sermon_embeddings',
            'chat_sessions',
            'chat_messages',
            'ask_wing_ai_questions',
            'citations'
        ]
        
        try:
            self.cursor.execute("""
                SELECT tablename FROM pg_tables 
                WHERE schemaname = 'public' AND tablename = ANY(%s);
            """, (required_tables,))
            
            existing_tables = [row[0] for row in self.cursor.fetchall()]
            missing_tables = set(required_tables) - set(existing_tables)
            
            if not missing_tables:
                self.log('OK', f'All required tables exist ({len(existing_tables)} tables)')
                return True
            else:
                self.log('WARNING', f'Missing tables: {", ".join(missing_tables)}')
                return False
                
        except Exception as e:
            self.log('ERROR', f'Failed to check tables: {str(e)}')
            return False
    
    def check_indexes(self):
        """Check if pgvector indexes are created."""
        try:
            self.cursor.execute("""
                SELECT indexname FROM pg_indexes 
                WHERE tablename = 'sermon_embeddings' AND indexdef LIKE '%vector%';
            """)
            
            indexes = self.cursor.fetchall()
            if indexes:
                self.log('OK', f'Vector indexes found: {len(indexes)} index(es)')
                for idx in indexes:
                    if self.verbose:
                        print(f"           - {idx[0]}")
                return True
            else:
                self.log('WARNING', 'No vector indexes found on sermon_embeddings table')
                return False
                
        except Exception as e:
            self.log('WARNING', f'Could not check indexes: {str(e)}')
            return False
    
    def check_connection_pooling(self):
        """Check PgBouncer setup (if enabled)."""
        use_pgbouncer = os.getenv('USE_PGBOUNCER', 'False').lower() == 'true'
        
        if not use_pgbouncer:
            self.log('INFO', 'Connection pooling (PgBouncer) not enabled')
            return True
        
        try:
            # Try to connect via PgBouncer port
            conn = psycopg2.connect(
                host=os.getenv('DB_HOST', 'localhost'),
                port='6432',
                database=os.getenv('DB_NAME', 'ask_wing_ai'),
                user=os.getenv('DB_USER', 'ask_wing_user'),
                password=os.getenv('DB_PASSWORD', ''),
                connect_timeout=5
            )
            conn.close()
            self.log('OK', 'PgBouncer connection successful on port 6432')
            return True
        except Exception as e:
            self.log('WARNING', f'PgBouncer connection failed: {str(e)}')
            return False
    
    def check_permissions(self):
        """Check database user permissions."""
        try:
            # Test SELECT permission
            self.cursor.execute("SELECT 1;")
            
            # Test INSERT permission (on a temporary table)
            self.cursor.execute("CREATE TEMP TABLE perm_test (id INT);")
            self.cursor.execute("INSERT INTO perm_test VALUES (1);")
            
            self.log('OK', 'Database user has necessary permissions')
            return True
        except Exception as e:
            self.log('ERROR', f'Permission check failed: {str(e)}')
            return False
    
    def check_configuration(self):
        """Check PostgreSQL configuration for optimization."""
        try:
            config_checks = {
                'shared_buffers': (256, 'MB'),
                'effective_cache_size': (1024, 'MB'),
                'work_mem': (4, 'MB'),
                'maintenance_work_mem': (64, 'MB'),
            }
            
            for setting, (min_val, unit) in config_checks.items():
                self.cursor.execute(f"SHOW {setting};")
                value = self.cursor.fetchone()[0]
                
                try:
                    # Parse value (e.g., "256MB" -> 256)
                    numeric_value = int(''.join(c for c in value if c.isdigit()))
                    if numeric_value >= min_val:
                        self.log('OK', f'{setting}: {value} (recommended: {min_val}{unit}+)')
                    else:
                        self.log('WARNING', f'{setting}: {value} (recommended: {min_val}{unit}+)')
                except:
                    self.log('INFO', f'{setting}: {value}')
                    
        except Exception as e:
            self.log('WARNING', f'Could not check PostgreSQL configuration: {str(e)}')
    
    def get_statistics(self):
        """Get database statistics."""
        try:
            self.cursor.execute("""
                SELECT 
                    schemaname,
                    tablename,
                    n_live_tup,
                    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) as size
                FROM pg_stat_user_tables
                WHERE schemaname = 'public'
                ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;
            """)
            
            stats = self.cursor.fetchall()
            if stats:
                self.log('INFO', f'Database statistics: {len(stats)} tables')
                for schema, table, rows, size in stats:
                    print(f"           - {table}: {rows} rows ({size})")
                return True
            else:
                self.log('INFO', 'No tables found in public schema')
                return True
                
        except Exception as e:
            self.log('WARNING', f'Could not retrieve statistics: {str(e)}')
            return False
    
    def verify_connection_string(self):
        """Verify connection string format."""
        try:
            host = os.getenv('DB_HOST', 'localhost')
            port = os.getenv('DB_PORT', '5432')
            db = os.getenv('DB_NAME', 'ask_wing_ai')
            user = os.getenv('DB_USER', 'ask_wing_user')
            
            conn_string = f"postgresql://{user}@{host}:{port}/{db}"
            self.log('INFO', f'Connection string: {conn_string}')
            return True
        except Exception as e:
            self.log('WARNING', f'Could not verify connection string: {str(e)}')
            return False
    
    def disconnect(self):
        """Close database connection."""
        if self.cursor:
            self.cursor.close()
        if self.conn:
            self.conn.close()
        self.log('INFO', 'Database connection closed')
    
    def run_full_check(self):
        """Run complete PostgreSQL setup verification."""
        print("\n" + "="*70)
        print("PostgreSQL Setup Verification for Ask Wing AI")
        print("="*70 + "\n")
        
        checks = [
            ('PostgreSQL Version', self.check_postgresql_version),
            ('pgvector Extension', self.check_pgvector_extension),
            ('Vector Type', self.check_vector_type),
            ('Vector Operations', self.test_vector_operations),
            ('Database Permissions', self.check_permissions),
            ('Database Tables', self.check_database_tables),
            ('Vector Indexes', self.check_indexes),
            ('Connection Pooling', self.check_connection_pooling),
        ]
        
        results = {}
        for check_name, check_func in checks:
            print(f"\nChecking: {check_name}")
            results[check_name] = check_func()
        
        print(f"\nChecking: PostgreSQL Configuration")
        self.check_configuration()
        
        print(f"\nDatabase Statistics:")
        self.get_statistics()
        
        print(f"\nConnection String:")
        self.verify_connection_string()
        
        # Summary
        print("\n" + "="*70)
        passed = sum(1 for v in results.values() if v)
        total = len(results)
        print(f"Verification Summary: {passed}/{total} checks passed")
        print("="*70 + "\n")
        
        return passed == total
    
    def save_results(self, filename='verification_results.json'):
        """Save verification results to JSON file."""
        with open(filename, 'w') as f:
            json.dump(self.results, f, indent=2)
        print(f"Results saved to {filename}")


def main():
    parser = argparse.ArgumentParser(
        description='Verify PostgreSQL and pgvector setup for Ask Wing AI'
    )
    parser.add_argument('-v', '--verbose', action='store_true',
                        help='Enable verbose output')
    parser.add_argument('-c', '--connection-only', action='store_true',
                        help='Only verify database connection')
    parser.add_argument('-f', '--full-check', action='store_true',
                        help='Run full verification check')
    parser.add_argument('-s', '--save', action='store_true',
                        help='Save results to JSON file')
    
    args = parser.parse_args()
    
    verifier = PostgreSQLVerifier(verbose=args.verbose)
    
    # Check connection
    if not verifier.connect():
        print("\nCannot proceed without database connection")
        return 1
    
    try:
        if args.connection_only:
            verifier.log('OK', 'Connection verification complete')
        else:
            # Run full check by default
            success = verifier.run_full_check()
            if args.save:
                verifier.save_results()
            return 0 if success else 1
    finally:
        verifier.disconnect()
    
    return 0


if __name__ == '__main__':
    sys.exit(main())
