-- Final SQLite schema for VaultX_DB
-- Reviewed and adjusted from extract_schema.py output

CREATE TABLE IF NOT EXISTS "Users" (
    "user_id" INTEGER PRIMARY KEY AUTOINCREMENT,
    "master_password_hash" TEXT NOT NULL,
    "salt" TEXT NOT NULL,
    "pin_hash" TEXT,
    "created_at" TEXT,
    "username" TEXT NOT NULL UNIQUE,
    "email" TEXT NOT NULL UNIQUE
);

CREATE TABLE IF NOT EXISTS "Backups" (
    "id" INTEGER PRIMARY KEY AUTOINCREMENT,
    "user_id" INTEGER NOT NULL,
    "backup_file_path" TEXT NOT NULL,
    "file_size" INTEGER,
    "created_at" TEXT,
    FOREIGN KEY ("user_id") REFERENCES "Users"("user_id")
);

CREATE TABLE IF NOT EXISTS "Documents" (
    "id" INTEGER PRIMARY KEY AUTOINCREMENT,
    "user_id" INTEGER NOT NULL,
    "file_name" TEXT NOT NULL,
    "file_path_encrypted" BLOB NOT NULL,
    "file_size" INTEGER,
    "file_type" TEXT,
    "sensitivity_score" TEXT,
    "iv" BLOB NOT NULL,
    "category" TEXT,
    "uploaded_at" TEXT,
    FOREIGN KEY ("user_id") REFERENCES "Users"("user_id")
);

CREATE TABLE IF NOT EXISTS "Folders" (
    "id" INTEGER PRIMARY KEY AUTOINCREMENT,
    "user_id" INTEGER NOT NULL,
    "name" TEXT NOT NULL,
    "created_at" TEXT,
    FOREIGN KEY ("user_id") REFERENCES "Users"("user_id")
);

CREATE TABLE IF NOT EXISTS "Notes" (
    "id" INTEGER PRIMARY KEY AUTOINCREMENT,
    "user_id" INTEGER NOT NULL,
    "title" TEXT NOT NULL,
    "content_encrypted" BLOB NOT NULL,
    "iv" BLOB NOT NULL,
    "folder" TEXT,
    "updated_at" TEXT,
    "created_at" TEXT,
    FOREIGN KEY ("user_id") REFERENCES "Users"("user_id")
);

CREATE TABLE IF NOT EXISTS "Passwords" (
    "id" INTEGER PRIMARY KEY AUTOINCREMENT,
    "user_id" INTEGER NOT NULL,
    "title" TEXT NOT NULL,
    "username_encrypted" BLOB NOT NULL,
    "password_encrypted" BLOB NOT NULL,
    "iv" BLOB NOT NULL,
    "url" TEXT,
    "tag" TEXT,
    "strength_score" INTEGER,
    "risk_flag" INTEGER,
    "created_at" TEXT,
    FOREIGN KEY ("user_id") REFERENCES "Users"("user_id")
);