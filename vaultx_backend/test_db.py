from app.utils.database import db_manager

# Test connection
try:
    result = db_manager.execute_query("SELECT 1")
    print("✅ Database connected successfully!")
    print(f"Test query result: {result}")
except Exception as e:
    print(f"❌ Connection failed: {e}")