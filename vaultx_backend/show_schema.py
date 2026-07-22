"""
STANDALONE DATABASE SCHEMA VIEWER
Run this to see your database structure and data
NOT part of the main VaultX project
"""

import pyodbc

# Connection string (same as your config)
conn_str = (
    "DRIVER={ODBC Driver 17 for SQL Server};"
    "SERVER=localhost;"
    "DATABASE=VaultX_DB;"
    "Trusted_Connection=yes"
)

def show_schema():
    print("=" * 60)
    print("VAULTX DATABASE SCHEMA VIEWER")
    print("=" * 60)
    
    try:
        conn = pyodbc.connect(conn_str)
        cursor = conn.cursor()
        print("\n Database connected successfully!\n")
        
        # Get all tables
        tables_query = """
            SELECT TABLE_NAME 
            FROM INFORMATION_SCHEMA.TABLES 
            WHERE TABLE_TYPE = 'BASE TABLE'
            ORDER BY TABLE_NAME
        """
        cursor.execute(tables_query)
        tables = cursor.fetchall()
        
        print(" TABLES IN DATABASE:")
        print("-" * 40)
        for table in tables:
            table_name = table[0]
            print(f"   {table_name}")
            
            # Get column info for each table
            columns_query = """
                SELECT COLUMN_NAME, DATA_TYPE, IS_NULLABLE, CHARACTER_MAXIMUM_LENGTH
                FROM INFORMATION_SCHEMA.COLUMNS
                WHERE TABLE_NAME = ?
                ORDER BY ORDINAL_POSITION
            """
            cursor.execute(columns_query, (table_name,))
            columns = cursor.fetchall()
            
            print(f"\n     Columns in {table_name}:")
            for col in columns:
                col_name = col[0]
                data_type = col[1]
                nullable = "NULL" if col[2] == "YES" else "NOT NULL"
                max_len = f"({col[3]})" if col[3] else ""
                print(f"       ├─ {col_name}: {data_type}{max_len} {nullable}")
            
            # Get row count
            count_query = f"SELECT COUNT(*) FROM {table_name}"
            cursor.execute(count_query)
            row_count = cursor.fetchone()[0]
            print(f"\n      Row count: {row_count}")
            print()
        
        # Show actual data from each table
        print("\n" + "=" * 60)
        print(" ACTUAL DATA IN TABLES")
        print("=" * 60)
        
        for table in tables:
            table_name = table[0]
            print(f"\n {table_name}:")
            print("-" * 40)
            
            # Get all data
            cursor.execute(f"SELECT * FROM {table_name}")
            rows = cursor.fetchall()
            
            if rows:
                # Get column names
                col_names = [desc[0] for desc in cursor.description]
                print(f"   Columns: {', '.join(col_names)}")
                print()
                
                for i, row in enumerate(rows):
                    print(f"   Row {i+1}:")
                    for j, col_name in enumerate(col_names):
                        value = row[j]
                        # Truncate long values for display
                        if isinstance(value, bytes):
                            if len(value) > 50:
                                value = f"{value[:50]}... ({len(value)} bytes)"
                        elif isinstance(value, str) and len(value) > 100:
                            value = f"{value[:100]}..."
                        print(f"     {col_name}: {value}")
                    print()
            else:
                print("   (Empty table)\n")
        
        conn.close()
        
    except Exception as e:
        print(f" Error: {e}")

if __name__ == "__main__":
    show_schema()