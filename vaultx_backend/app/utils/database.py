import pyodbc
from app.config import config

class DatabaseManager:
    def __init__(self):
        self.connection_string = config.DATABASE_URL
    
    def execute_query(self, query: str, params=None):
        """Execute SQL query - creates NEW connection each time"""
        conn = pyodbc.connect(self.connection_string)
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
                        if isinstance(item, memoryview):
                            converted_row.append(bytes(item))
                        elif isinstance(item, bytes):
                            converted_row.append(item)
                        else:
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