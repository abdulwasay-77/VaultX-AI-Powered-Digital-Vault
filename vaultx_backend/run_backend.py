"""
Entry point used to compile the backend into a standalone .exe.
Not used during normal development (you'll keep using `uvicorn app.main1:app --reload` for that).

This starts the same FastAPI app, but in a way PyInstaller can freeze into one file,
with reload disabled (reload doesn't make sense in a shipped .exe).
"""
import sys
import os

# When PyInstaller builds with console=False, Windows gives this process
# NO stdout/stderr at all (they're None, not just hidden) — and uvicorn's
# logging setup crashes trying to use them. Redirect to a no-op target first.
if sys.stdout is None:
    sys.stdout = open(os.devnull, "w")
if sys.stderr is None:
    sys.stderr = open(os.devnull, "w")

import uvicorn

if __name__ == "__main__":
    uvicorn.run("app.main1:app", host="127.0.0.1", port=8000, reload=False)