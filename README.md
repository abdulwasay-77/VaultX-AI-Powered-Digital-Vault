# VaultX — AI-Powered Digital Vault

VaultX is a locally-hosted desktop application for securely storing **passwords, sensitive documents, and personal notes** in a single encrypted vault. It uses a three-tier architecture: a Flutter desktop client, a REST API backend, and a relational database, with an Intelligent Rule-Based Engine (IRBE) that scores password strength, generates passwords, classifies document sensitivity, and computes a vault-wide health score.

> Built as part of the Software Engineering (CS-231) course project, University of Wah.

---

## ✨ Features

- **Authentication & Accounts** — registration with a master password, secure salted hashing, login with a 30-minute access token, optional 4-digit PIN unlock, and multi-profile support on one installation.
- **Password Vault** — encrypted CRUD for password entries, automatic strength scoring (Weak/Moderate/Strong/Very Strong) with feedback, a configurable secure password generator, tagging, and reused/weak password detection.
- **Document Vault** — encrypted upload/preview/download/delete for images, PDFs, videos, audio, and office files (up to 500 MB), with automatic sensitivity classification (Low/Medium/High) and category tagging.
- **Notes Vault** — rich-text notes organized into folders, with move/edit/delete support.
- **Risk Dashboard** — vault-wide health score, weak password list, reused password groups.
- **Smart Search** — single search bar across passwords, documents, and notes with relevance ranking and live suggestions.
- **Backup & Restore** — export the entire vault to a single encrypted backup file, restore via overwrite or smart-merge, backup history log, and integrity verification.

## 🔒 Security Notes

- All password, document, and note contents are encrypted **at rest** (AES-256) with a unique IV per record.
- Master passwords and PINs are stored only as salted hashes — never in plaintext.
- All cryptographic operations happen on the backend only.
- Access tokens expire after 30 minutes; the vault auto-locks after 5 minutes of inactivity.
- There is **no password recovery** — a forgotten master password permanently locks that vault's contents.

## 🏗️ Architecture

```
Desktop Client (Flutter)  <-->  Backend API (REST/JSON)  <-->  Relational Database
                                        |
                                 Encrypted file storage
                               (uploads/ and backups/)
```

## 📁 Project Structure

```
VaultX-AI-Powered-Digital-Vault/
├── vaultx_backend/         # Backend API (Python)
│   ├── app/
│   │   ├── main.py
│   │   ├── config.py
│   │   ├── models/         # Pydantic/DB schemas
│   │   ├── routes/         # auth, passwords, documents, notes, search, backup
│   │   ├── services/       # irbe.py (strength/sensitivity/health engine), search_engine.py
│   │   └── utils/          # database, encryption, hashing, jwt_handler
│   ├── uploads/             # Encrypted document blobs (ignored, kept via .gitkeep)
│   ├── backups/             # Exported vault backups (ignored, kept via .gitkeep)
│   ├── requirements.txt
│   └── .env.example         # Copy to .env and fill in real values (never commit .env)
│
└── vaultx_frontend/        # Flutter desktop client
    ├── lib/
    ├── windows/ / linux/ / macos/
    └── pubspec.yaml
```

## 🛠️ Tech Stack

| Layer        | Technology                                   |
|--------------|-----------------------------------------------|
| Frontend     | Flutter (desktop — Windows target)            |
| Backend      | Python REST API (auto-generated API docs)     |
| Database     | Relational database, trusted local connection |
| Security     | AES-256 encryption, salted password hashing, JWT |

## 🚀 Getting Started

### Prerequisites
- Python 3.10+
- Flutter SDK (with desktop/Windows support enabled)
- A running instance of the relational database used by the backend

### 1. Backend Setup

```bash
cd vaultx_backend
python -m venv venv
# Windows: venv\Scripts\activate | macOS/Linux: source venv/bin/activate
pip install -r requirements.txt

# Create your own .env from the example, then fill in real secrets
cp .env.example .env

# Run the API server (adjust to your actual entrypoint, e.g. app/main.py)
uvicorn app.main:app --reload
```

### 2. Frontend Setup

```bash
cd vaultx_frontend
flutter pub get
flutter run -d windows
```

### Environment Variables

Create `vaultx_backend/.env` (never committed) with values such as:

```
DATABASE_URL=your_database_connection_string
JWT_SECRET=your_jwt_secret
ACCESS_TOKEN_EXPIRE_MINUTES=30
MAX_UPLOAD_SIZE_MB=500
```

## 📄 Documentation

See the full **Software Requirements Specification (SRS)** in `/docs` (or the assignment submission) for detailed functional requirements, non-functional requirements, data model, and diagrams.

## 👥 Authors

- Abdul Wasay — UW-24-CS-BS-112
- Muhammad Fahad — UW-24-CS-BS-092

Course: Software Engineering (CS-231) — BSCS-4B, University of Wah
Instructor: Ma'am Sadia Waheed

## 📜 License

This project is currently unlicensed / for academic use. Add a license (e.g., MIT) if you plan to open-source it.