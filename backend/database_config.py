"""
Django Database Configuration for Ask Wing AI

This module provides database configuration with PostgreSQL and pgvector support.
Includes connection pooling configuration for production environments.
"""

import os
from pathlib import Path

# Database configuration
def get_database_config():
    """
    Get database configuration from environment variables.
    
    Supports both direct PostgreSQL and PgBouncer connection pooling.
    
    Environment Variables:
    - DB_ENGINE: Django database backend (default: django.db.backends.postgresql)
    - DB_NAME: Database name (default: ask_wing_ai)
    - DB_USER: Database user (default: ask_wing_user)
    - DB_PASSWORD: Database password (required)
    - DB_HOST: Database host (default: localhost)
    - DB_PORT: Database port (default: 5432 or 6432 for PgBouncer)
    - USE_PGBOUNCER: Use PgBouncer for connection pooling (default: False)
    - CONN_MAX_AGE: Maximum age of database connections in seconds (default: 600)
    
    Returns:
        dict: Django DATABASES configuration
    """
    
    # Determine which port to use based on PgBouncer setting
    use_pgbouncer = os.environ.get('USE_PGBOUNCER', 'False').lower() == 'true'
    default_port = '6432' if use_pgbouncer else '5432'
    pool_mode = 'transaction' if use_pgbouncer else 'connection'
    
    db_config = {
        'ENGINE': os.environ.get('DB_ENGINE', 'django.db.backends.postgresql'),
        'NAME': os.environ.get('DB_NAME', 'ask_wing_ai'),
        'USER': os.environ.get('DB_USER', 'ask_wing_user'),
        'PASSWORD': os.environ.get('DB_PASSWORD', ''),
        'HOST': os.environ.get('DB_HOST', 'localhost'),
        'PORT': os.environ.get('DB_PORT', default_port),
        'CONN_MAX_AGE': int(os.environ.get('CONN_MAX_AGE', '600')),
        'ATOMIC_REQUESTS': False,  # For better concurrency
        'OPTIONS': {
            'connect_timeout': 10,
            'application_name': 'ask_wing_ai',
            'isolation_level': 'READ_COMMITTED',  # For better concurrency
        }
    }
    
    # Add pgvector-specific settings
    db_config['OPTIONS']['pgvector'] = {
        'dimensions': int(os.environ.get('PGVECTOR_DIMENSIONS', '1536')),
        'index_type': os.environ.get('PGVECTOR_INDEX_TYPE', 'ivfflat'),
    }
    
    return db_config


DATABASES = {
    'default': get_database_config()
}


# Connection pooling configuration
PGBOUNCER_CONFIG = {
    'enabled': os.environ.get('USE_PGBOUNCER', 'False').lower() == 'true',
    'pool_mode': 'transaction',  # Minimal query latency
    'max_client_conn': 1000,
    'default_pool_size': 25,
    'min_pool_size': 10,
    'reserve_pool_size': 5,
    'reserve_pool_timeout': 3,  # seconds
    'max_db_connections': 100,
    'max_user_connections': 50,
    'query_wait_timeout': 120,  # seconds
    'client_idle_timeout': 600,  # seconds
    'idle_in_transaction_session_timeout': 600,  # seconds
}


# Database connection pool settings for development
if not os.environ.get('ENVIRONMENT') == 'production':
    # Development settings - smaller pool
    CONN_POOL = {
        'INITIAL': 5,
        'MAX_OVERFLOW': 10,
        'TIMEOUT': 30,
    }
else:
    # Production settings - larger pool
    CONN_POOL = {
        'INITIAL': 25,
        'MAX_OVERFLOW': 50,
        'TIMEOUT': 60,
    }


# pgvector index configuration
PGVECTOR_INDEX_CONFIG = {
    'index_type': os.environ.get('PGVECTOR_INDEX_TYPE', 'ivfflat'),
    'ivfflat': {
        'lists': 100,  # Number of cluster lists for IVFFlat index
    },
    'hnsw': {
        'm': 16,  # Number of bi-directional links per node (default: 16)
        'ef_construction': 64,  # Size of dynamic candidate list (default: 64)
    }
}


# Vector search configuration
VECTOR_SEARCH_CONFIG = {
    'embedding_model': os.environ.get('OPENAI_EMBEDDING_MODEL', 'text-embedding-3-small'),
    'embedding_dimensions': int(os.environ.get('PGVECTOR_DIMENSIONS', '1536')),
    'similarity_metric': 'cosine',  # or 'l2', 'inner_product'
    'top_k': 5,  # Number of results to return
    'min_similarity_threshold': 0.7,  # Minimum similarity score (0-1)
    'chunk_size': 1000,  # Characters per chunk
    'chunk_overlap': 200,  # Characters of overlap between chunks
}


# Logging configuration for database queries
LOGGING_CONFIG = {
    'version': 1,
    'disable_existing_loggers': False,
    'handlers': {
        'console': {
            'class': 'logging.StreamHandler',
        },
        'file': {
            'class': 'logging.handlers.RotatingFileHandler',
            'filename': 'logs/database.log',
            'maxBytes': 1024 * 1024 * 10,  # 10MB
            'backupCount': 5,
        }
    },
    'loggers': {
        'django.db.backends': {
            'handlers': ['console', 'file'],
            'level': 'DEBUG' if os.environ.get('DEBUG') == 'True' else 'INFO',
            'propagate': False,
        }
    }
}


# Database migration configuration
MIGRATION_MODULES = {
    'default': 'migrations',
}


# Default database settings for CLI commands
DEFAULT_DATABASE_NAME = os.environ.get('DB_NAME', 'ask_wing_ai')
DEFAULT_DATABASE_USER = os.environ.get('DB_USER', 'ask_wing_user')
DEFAULT_DATABASE_HOST = os.environ.get('DB_HOST', 'localhost')
DEFAULT_DATABASE_PORT = os.environ.get('DB_PORT', '5432')


# Test database configuration
TEST_DATABASE_CONFIG = {
    'NAME': 'test_ask_wing_ai',
    'USER': 'ask_wing_user',
    'HOST': 'localhost',
    'PORT': '5432',
    'CREATE_DB': True,
    'CREATE_USER': True,
    'MIRROR': None,
}


def get_connection_string(use_pgbouncer=False):
    """
    Generate a PostgreSQL connection string.
    
    Args:
        use_pgbouncer (bool): Use PgBouncer for connection pooling
        
    Returns:
        str: PostgreSQL connection string
    """
    config = get_database_config()
    port = '6432' if use_pgbouncer else config['PORT']
    
    return (
        f"postgresql://{config['USER']}:{config['PASSWORD']}@"
        f"{config['HOST']}:{port}/{config['NAME']}"
    )


# Database health check configuration
DATABASE_HEALTH_CHECK = {
    'enabled': True,
    'interval': 60,  # seconds
    'timeout': 10,   # seconds
    'query': 'SELECT 1;',
}


# Connection pool monitoring
CONNECTION_POOL_MONITORING = {
    'enabled': os.environ.get('ENVIRONMENT') == 'production',
    'log_level': 'INFO',
    'metrics_interval': 300,  # seconds
}


if __name__ == '__main__':
    print("Database Configuration")
    print("=" * 50)
    config = get_database_config()
    for key, value in config.items():
        if key != 'PASSWORD':
            print(f"{key}: {value}")
    print("=" * 50)
    print(f"Connection String: {get_connection_string()}")
