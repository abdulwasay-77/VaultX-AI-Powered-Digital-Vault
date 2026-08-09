import sqlite3
import os
from app.config import config

SCHEMA_FILE = os.path.join(config.RESOURCE_DIR, 'sqlite_schema.sql')


class DatabaseManager:
    def __init__(self):
        self.db_path = config.DB_PATH
        self._init_schema()

    def _get_connection(self):
        conn = sqlite3.connect(self.db_path)
        # Enforce foreign key constraints (SQLite has them off by default)
        conn.execute("PRAGMA foreign_keys = ON")
        return conn

    def _init_schema(self):
        """Create tables on first run. Safe to call every startup —
        CREATE TABLE IF NOT EXISTS means existing data is never touched."""
        if not os.path.exists(SCHEMA_FILE):
            raise FileNotFoundError(
                f"sqlite_schema.sql not found at {SCHEMA_FILE}. "
                "This file must ship alongside the backend."
            )
        with open(SCHEMA_FILE, 'r', encoding='utf-8') as f:
            schema_sql = f.read()

        conn = self._get_connection()
        try:
            conn.executescript(schema_sql)
            conn.commit()
        finally:
            conn.close()

    def execute_query(self, query: str, params=None):
        """Execute SQL query - creates NEW connection each time.
        Same interface as before: SELECTs return rows, everything else
        returns the affected row count."""
        conn = self._get_connection()
        cursor = conn.cursor()

        try:
            if params:
                converted_params = []
                for p in params:
                    if isinstance(p, memoryview):
                        converted_params.append(bytes(p))
                    elif isinstance(p, bytearray):
                        converted_params.append(bytes(p))
                    else:
                        converted_params.append(p)
                cursor.execute(query, tuple(converted_params))
            else:
                cursor.execute(query)

            if query.strip().upper().startswith('SELECT'):
                rows = cursor.fetchall()
                result = []
                for row in rows:
                    converted_row = []
                    for item in row:
                        # sqlite3 already returns bytes for BLOB columns
                        converted_row.append(item)
                    result.append(tuple(converted_row))
                return result
            else:
                conn.commit()
                return cursor.rowcount

        except Exception as e:
            conn.rollback()
            raise e
        finally:
            cursor.close()
            conn.close()

    def close(self):
        pass


db_manager = DatabaseManager()